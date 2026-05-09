# Day 17 — Manual Testing of Terraform Infrastructure

> **30-Day Terraform Challenge** | Chapter 9: Terraform Testing

---

## Overview

This document covers Day 17 of the 30-Day Terraform Challenge, focused entirely on **manual testing** of Terraform-managed AWS infrastructure. Before any automated testing pipeline can be trusted, you must first understand what you are testing, why it matters, and how to verify it by hand. This entry documents the full manual test checklist, execution results, multi-environment comparison, cleanup verification, and key learnings from Chapter 9 of *Terraform: Up & Running* by Yevgeniy Brikman.

---

## What Was Tested

The target infrastructure is a **webserver cluster** built across Days 3–16, consisting of:

- An Auto Scaling Group (ASG) of EC2 instances
- An Application Load Balancer (ALB)
- Security groups for the ALB and EC2 instances
- Launch configuration / launch template
- Target group and listener rules

Testing was run against both a **dev** environment and a **production** environment.

---

## Manual Test Checklist

Use this checklist against any Terraform-managed environment. Every item is binary — PASS or FAIL.

### 1. Provisioning Verification

```
[ ] terraform init completes without errors
[ ] terraform validate passes cleanly (no warnings)
[ ] terraform plan shows the expected number and type of resources
[ ] terraform apply completes without errors
[ ] No unexpected resource diffs appear after apply
```

### 2. Resource Correctness

```
[ ] All expected resources are visible in the AWS Console
[ ] Resource names match variables defined in variables.tf
[ ] Tags are applied correctly to all resources
[ ] Resources are in the correct AWS region
[ ] Security group inbound/outbound rules match configuration exactly
[ ] No extra rules exist; no rules are missing
[ ] ALB is in the correct subnets
[ ] ASG min/max/desired capacity matches configuration
```

### 3. Functional Verification

```
[ ] ALB DNS name resolves (nslookup / dig)
[ ] curl http://<alb-dns> returns the expected HTTP response body
[ ] curl returns HTTP 200 status code
[ ] All ASG instances pass ALB target group health checks
[ ] Manually stopping one EC2 instance triggers ASG replacement
[ ] Replacement instance passes health checks within expected time
```

### 4. State Consistency

```
[ ] terraform plan returns "No changes" immediately after a clean apply
[ ] State file in S3 (or local) accurately reflects what exists in AWS
[ ] No resources exist in AWS that are not tracked in state
[ ] No resources are tracked in state that do not exist in AWS
```

### 5. Regression Check

```
[ ] Adding a tag to a resource shows only that tag change in terraform plan
[ ] No unrelated resources appear as changed in the plan
[ ] After applying the tag change, terraform plan returns clean
[ ] Reverting the change and re-applying returns the environment to baseline
```

---

## Test Execution Results

### Test 1 — terraform init

```
Command:  terraform init
Expected: Terraform initialized successfully, providers downloaded
Actual:   Terraform has been successfully initialized!
Result:   PASS
```

### Test 2 — terraform validate

```
Command:  terraform validate
Expected: Success! The configuration is valid.
Actual:   Success! The configuration is valid.
Result:   PASS
```

### Test 3 — terraform plan (dev)

```
Command:  terraform plan -var-file="dev.tfvars"
Expected: Plan: 12 to add, 0 to change, 0 to destroy.
Actual:   Plan: 12 to add, 0 to change, 0 to destroy.
Result:   PASS
```

### Test 4 — terraform apply (dev)

```
Command:  terraform apply -var-file="dev.tfvars" -auto-approve
Expected: Apply complete! Resources: 12 added, 0 changed, 0 destroyed.
Actual:   Apply complete! Resources: 12 added, 0 changed, 0 destroyed.
Result:   PASS
```

### Test 5 — ALB DNS Resolves

```
Command:  nslookup my-app-alb-123456.us-east-1.elb.amazonaws.com
Expected: Returns one or more IP addresses
Actual:   Non-authoritative answer returned two IPs (multi-AZ)
Result:   PASS
```

### Test 6 — ALB Returns Expected Response

```
Command:  curl -s http://my-app-alb-123456.us-east-1.elb.amazonaws.com
Expected: "Hello World v2"
Actual:   "Hello World v2"
Result:   PASS
```

### Test 7 — Health Checks on All Instances

```
Command:  AWS Console → EC2 → Target Groups → Targets tab
Expected: All targets show "healthy"
Actual:   All targets show "healthy"
Result:   PASS
```

### Test 8 — ASG Self-Healing

```
Command:  Manually stopped one EC2 instance via AWS Console
Expected: ASG launches a replacement within ~3 minutes
Actual:   Replacement instance launched and became healthy within 4 minutes
Result:   PASS
```

### Test 9 — terraform plan returns clean after apply

```
Command:  terraform plan -var-file="dev.tfvars"
Expected: No changes. Your infrastructure matches the configuration.
Actual:   1 resource change detected — missing tag on aws_security_group.instance
Result:   FAIL

Fix:      The security group for EC2 instances was created before a
          "ManagedBy = terraform" tag was added to the tagging convention.
          The tag block was added to aws_security_group.instance in main.tf
          and terraform apply was re-run.
          Follow-up terraform plan returned: No changes.
```

### Test 10 — Regression Check (Tag Change)

```
Command:  Added tag Environment = "dev-test" to aws_launch_template, ran terraform plan
Expected: Plan shows exactly 1 change — the tag update on the launch template
Actual:   Plan shows exactly 1 change — tag update on aws_launch_template.webserver
Result:   PASS
```

---

## Multi-Environment Comparison

| Check | Dev | Production | Notes |
|---|---|---|---|
| terraform apply | PASS | PASS | No differences |
| ALB DNS resolves | PASS | PASS | — |
| curl response | PASS | PASS | — |
| Health checks | PASS | PASS | — |
| terraform plan clean after apply | PASS | FAIL (initially) | See below |
| Instance type | t2.micro | t3.small | As expected per tfvars |
| Security group drift | None | 1 rule drift | See below |

### Unexpected Finding — Production Security Group Drift

After applying production, `terraform plan` showed an unexpected inbound rule on the ALB security group. Investigation revealed a manually-added rule for port 8080 that existed in AWS but was not in the Terraform configuration. This rule was added during an earlier troubleshooting session and never removed.

**Resolution:** The rule was removed from the AWS Console and the state was refreshed with:

```bash
terraform refresh -var-file="prod.tfvars"
terraform plan -var-file="prod.tfvars"
# Confirmed: No changes.
```

**Lesson:** This is exactly what manual testing catches that `terraform validate` cannot — drift between real infrastructure and configuration that `validate` never sees.

---

## Cleanup Process

After every test run, all resources are destroyed immediately.

### Step 1 — Preview the Destroy

```bash
terraform plan -destroy -var-file="dev.tfvars"
```

Review the output carefully. Confirm the resource count matches what was applied.

### Step 2 — Execute Destroy

```bash
terraform destroy -var-file="dev.tfvars"
```

Type `yes` when prompted. Do not use `-auto-approve` on destroy — the manual confirmation is a safeguard.

### Step 3 — Verify Cleanup via AWS CLI

After destroy completes, run both commands and confirm they return empty results:

```bash
# Should return empty Reservations array
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=terraform" \
  --query "Reservations[*].Instances[*].InstanceId"

# Should return empty LoadBalancers array
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[*].LoadBalancerArn"
```

**Expected output for both commands after clean destroy:**

```json
[]
```

**Actual output after destroy:**

```json
[]
[]
```

Result: **CLEAN** — no orphaned resources found.

> **Note:** Also manually verified in the AWS Console that EC2 instances, security groups, load balancers, and target groups were all removed. Terraform left no orphaned resources in this run.

---

## Chapter 9 Learnings

### What Does "Cleaning Up After Tests" Mean?

Brikman's point is simple but easy to underestimate: destroying test infrastructure is not the same as running `terraform destroy` and walking away. Cleanup means verifying that destruction was complete. A partial failure mid-destroy (network timeout, IAM permission error, resource dependency conflict) can leave resources running in your account without any record in state — meaning future `terraform plan` will not detect them, and they will silently accumulate cost.

The author describes this as harder than it sounds because:

1. **Terraform destroy can fail silently** — some resources are skipped without errors if dependencies aren't in the right order
2. **State can desync** — if a resource is deleted outside Terraform, it disappears from state but the real AWS object may still exist
3. **Orphaned resources are invisible** — they won't show in `terraform plan`, won't appear in your codebase, but they do show in your AWS bill

### The Risk of Not Cleaning Up Between Runs

- Cost accumulation — ALBs, NAT Gateways, and running EC2 instances all incur hourly charges
- State pollution — leftover resources can conflict with the next `terraform apply`, causing confusing errors
- False test confidence — if you run a test against infrastructure that wasn't fully destroyed and rebuilt, you may be testing against a partially-configured environment and not know it

---

## Lab Takeaways

### Lab 1 — State Migration

This lab involved moving Terraform state from local to remote (S3 backend). The key learning is that the state file is the source of truth for what Terraform believes exists. Migrating state is not just copying a file — it requires changing the `backend` block in configuration and running `terraform init` again to trigger the migration. If done incorrectly, Terraform treats the existing infrastructure as new resources and attempts to create duplicates.

**Command used:**

```bash
terraform init -migrate-state
```

### Lab 2 — Import Existing Infrastructure

`terraform import` solves the problem of infrastructure that was created outside of Terraform — manually in the console, via a script, or by another tool — that you now want to manage with Terraform.

**What it solves:** It writes an existing resource into the Terraform state file so Terraform becomes aware of it.

**What it does NOT solve:** It does not write the Terraform configuration (`.tf` files) for you. After importing, you must manually write the resource block that matches the imported resource, then run `terraform plan` to confirm there are no diffs. If your configuration doesn't match the real resource exactly, Terraform will attempt to modify or recreate the resource on the next apply.

**Example command used:**

```bash
terraform import aws_security_group.imported_sg sg-0abc123456def7890
```

After import, a full `terraform plan` was run and differences were resolved iteratively until the plan returned clean.

---

## Challenges and Fixes

### Challenge 1 — Missing Tag on Security Group Causing Dirty Plan

**Root cause:** A tagging convention (`ManagedBy = terraform`) was added after the security group was first created. The security group resource in `main.tf` was not updated with the new tag block.

**Fix:** Added the missing `tags` block to `aws_security_group.instance`, ran `terraform apply`, confirmed clean plan.

### Challenge 2 — Production Security Group Drift

**Root cause:** A port 8080 inbound rule was manually added to the production ALB security group during an earlier debugging session and never cleaned up. Terraform had no record of it.

**Fix:** Removed the rule manually from the AWS Console, ran `terraform refresh`, confirmed clean plan.

### Challenge 3 — Destroy Left One Target Group Orphaned

During the initial destroy test run, the ALB was removed but the target group remained. This happens when the target group has a dependency on the listener which was destroyed first, leaving the target group in a detached state that Terraform couldn't cleanly handle.

**Fix:** Manually deleted the orphaned target group from the AWS Console:

```bash
aws elbv2 delete-target-group \
  --target-group-arn arn:aws:elasticloadbalancing:us-east-1:123456789:targetgroup/my-app-tg/abc123
```

**Lesson:** Always verify cleanup with AWS CLI commands after destroy. Do not assume `terraform destroy` is complete just because the command exited successfully.

---

## Repository Structure

```
day-17-manual-testing/
├── README.md                  # This file
├── main.tf                    # Core infrastructure resources
├── variables.tf               # Input variable definitions
├── outputs.tf                 # Output values (ALB DNS name etc.)
├── dev.tfvars                 # Dev environment variable values
├── prod.tfvars                # Production environment variable values
├── backend.tf                 # Remote state configuration (S3)
└── test-results/
    ├── dev-test-run.md        # Full test results for dev
    └── prod-test-run.md       # Full test results for production
```

---

## Key Commands Reference

```bash
# Initialise working directory
terraform init

# Validate configuration syntax
terraform validate

# Preview changes before applying
terraform plan -var-file="dev.tfvars"

# Apply infrastructure
terraform apply -var-file="dev.tfvars"

# Preview destruction
terraform plan -destroy -var-file="dev.tfvars"

# Destroy all managed resources
terraform destroy -var-file="dev.tfvars"

# Refresh state to detect drift
terraform refresh -var-file="dev.tfvars"

# Import an existing resource into state
terraform import aws_security_group.example sg-0abc123456

# Post-destroy verification
aws ec2 describe-instances \
  --filters "Name=tag:ManagedBy,Values=terraform" \
  --query "Reservations[*].Instances[*].InstanceId"

aws elbv2 describe-load-balancers \
  --query "LoadBalancers[*].LoadBalancerArn"
```

---

## Social Media Post

> 🔍 Day 17 of the 30-Day Terraform Challenge — manual testing deep dive. Built a structured test checklist, ran it against dev and production environments, documented every pass and failure. Manual testing is not optional — it is the foundation everything else is built on. #30DayTerraformChallenge #TerraformChallenge #Terraform #Testing #DevOps #IaC #AWSUserGroupKenya #EveOps

---

*Part of the [30-Day Terraform Challenge](https://github.com/ericgitau-tech) | Eric Gitau*
