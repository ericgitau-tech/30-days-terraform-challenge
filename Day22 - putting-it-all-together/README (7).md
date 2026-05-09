# Day 22 — Putting It All Together: Application and Infrastructure Workflows with Terraform

> **30-Day Terraform Challenge** | Author: [@gitauadmin](https://github.com/gitauadmin/terraform-challenge) | Region: `eu-west-1`

---

## Overview

Day 22 is where everything converges. Over the last three weeks I built VPCs, EC2 clusters, load balancers, ASGs, remote state, modules, and testing frameworks — each as a standalone skill. Today I wired them into one coherent, end-to-end pipeline where application code and infrastructure code follow the same promotion discipline: version everything, test everything, enforce policy automatically, and never apply in production what was not reviewed in staging.

---

## Repository Structure

```
.
├── modules/
│   └── webserver-cluster/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── alarms.tf
│       └── tests/
│           └── cluster.tftest.hcl
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   └── backend.tf
│   ├── staging/
│   │   ├── main.tf
│   │   └── backend.tf
│   └── prod/
│       ├── main.tf
│       └── backend.tf
├── sentinel/
│   ├── require-instance-type.sentinel
│   ├── require-terraform-tag.sentinel
│   └── cost-check.sentinel
├── .github/
│   └── workflows/
│       └── terraform.yml
└── README.md
```

---

## Integrated CI Pipeline

**`.github/workflows/terraform.yml`:**

```yaml
name: Infrastructure CI

on:
  pull_request:
    branches: [main]

env:
  AWS_DEFAULT_REGION: eu-west-1

jobs:
  validate:
    name: Validate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Format check
        run: terraform fmt -check -recursive

      - name: Init (no backend)
        run: terraform init -backend=false
        working-directory: modules/webserver-cluster

      - name: Validate
        run: terraform validate
        working-directory: modules/webserver-cluster

      - name: Unit tests
        run: terraform test
        working-directory: modules/webserver-cluster

  plan:
    name: Plan
    runs-on: ubuntu-latest
    needs: validate
    env:
      AWS_ACCESS_KEY_ID:     ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Init
        run: terraform init
        working-directory: environments/staging

      - name: Plan
        run: terraform plan -out=ci.tfplan
        working-directory: environments/staging

      - name: Upload plan artifact
        uses: actions/upload-artifact@v4
        with:
          name: terraform-plan
          path: environments/staging/ci.tfplan
          retention-days: 5
```

**Jobs run in sequence:** `validate` must pass before `plan` runs. The saved plan file is uploaded as a CI artifact — the same file that gets promoted to production, never regenerated.

**Passing workflow run:** Both jobs green on the PR. `validate` completed in 42 seconds, `plan` in 1 minute 18 seconds. The `ci.tfplan` artifact was uploaded and pinned to the run.

---

## Sentinel Policies

### Policy 1 — Allowed Instance Types

**`sentinel/require-instance-type.sentinel`:**

```hcl
import "tfplan/v2" as tfplan

allowed_instance_types = [
  "t2.micro",
  "t2.small",
  "t2.medium",
  "t3.micro",
  "t3.small",
]

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is not "aws_instance" or
    rc.change.after.instance_type in allowed_instance_types
  }
}
```

**What it blocks:** Any `aws_instance` resource using a type not in the approved list — `c5.4xlarge`, `m5.large`, `r6i.2xlarge`, and so on. This policy runs after `terraform plan` completes and before the apply step is permitted. No amount of PR approval bypasses it.

**Why it matters:** Without this, a misconfigured module or a rushed production fix can spin up expensive instances and the cost only surfaces on the AWS bill at month end. Sentinel catches it at plan time, every time, across every workspace.

---

### Policy 2 — Require ManagedBy Tag

**`sentinel/require-terraform-tag.sentinel`:**

```hcl
import "tfplan/v2" as tfplan

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.change.after.tags["ManagedBy"] is "terraform"
  }
}
```

**What it blocks:** Any resource being created or modified without the `ManagedBy = "terraform"` tag — EC2 instances, security groups, S3 buckets, CloudWatch alarms, everything.

**Why it matters:** Tag compliance is the foundation of cost allocation and drift detection. Resources missing this tag cannot be attributed to a team or project. More importantly, any resource missing this tag is a signal it may have been created manually outside Terraform — the policy enforces that infrastructure-as-code is the only path to production.

---

### Policy 3 — Cost Estimation Gate

**`sentinel/cost-check.sentinel`:**

```hcl
import "tfrun"

maximum_monthly_increase = 50.0

main = rule {
  tfrun.cost_estimate.delta_monthly_cost < maximum_monthly_increase
}
```

**Threshold:** USD $50/month delta per apply. Any single plan that would increase the monthly bill by more than $50 is blocked until explicitly reviewed.

**Terraform Cloud cost estimation output (recent run):**

```
Cost estimation:
  + $3.65/month  (aws_cloudwatch_metric_alarm.high_cpu)

  Monthly cost change: +$3.65
  Sentinel policy: PASSED (delta $3.65 < $50.00 limit)
```

Set to `hard-mandatory` enforcement mode — it cannot be overridden by a workspace operator.

---

## Immutable Artifact Promotion

The key architectural insight from Chapter 10: the **same artifact** that was reviewed must be the one that runs in production. Nothing is regenerated between environments.

```
PR opened
  → CI runs: terraform plan -out=ci.tfplan  (staging)
  → ci.tfplan uploaded as GitHub Actions artifact
  → Sentinel policies evaluated against this plan
  → Cost estimation gate evaluated against this plan
  → PR reviewed and approved

Merge to main
  → ci.tfplan downloaded from artifact store
  → terraform apply ci.tfplan  (staging)
  → Staging verified

Promote to production
  → Same ci.tfplan promoted (not regenerated)
  → terraform apply ci.tfplan  (prod)
```

**Why regenerating the plan breaks this guarantee:** If you run `terraform plan` again between staging and production, you get a new plan reflecting the state of the world at that moment. Another team may have applied something. A resource may have drifted. The plan the reviewer approved is no longer the plan that runs. The saved plan file is the chain of custody.

---

## Side-by-Side Comparison: Application vs Infrastructure Workflow

| Component | Application Code | Infrastructure Code |
|---|---|---|
| **Source of truth** | Git repository | Git repository |
| **Local run** | `npm start` / `python app.py` | `terraform plan` |
| **Artifact** | Docker image / compiled binary | Saved `.tfplan` file |
| **Versioning** | Semantic version tag on image | Semantic version tag on module |
| **Automated tests** | Unit + integration tests | `terraform test` + Terratest |
| **Policy enforcement** | Linting / SAST / OWASP scan | Sentinel policies |
| **Cost gate** | N/A | Cost estimation policy |
| **Promotion** | Same image promoted across envs | Same plan promoted across envs |
| **Deployment** | `docker run` / Kubernetes rollout | `terraform apply <plan>` |
| **Rollback** | Redeploy previous image tag | `terraform apply <previous plan>` |

The two workflows are structurally identical. The terminology differs. The artifact type differs. The blast radius of a bad deploy differs enormously. The discipline is the same.

---

## Journey Reflection

### What I built over 22 days

- **Networking:** Custom VPC with public and private subnets, route tables, internet gateway, NAT gateway — eu-west-1
- **Compute:** EC2 instances, launch configurations, Auto Scaling Groups, webserver cluster module
- **Load balancing:** Application Load Balancer with target groups and health checks
- **Storage:** S3 buckets for state with versioning and encryption, DynamoDB table for state locking
- **Observability:** CloudWatch metric alarms on CPU and ASG metrics
- **Security:** Security groups with least-privilege rules, IAM roles and instance profiles
- **DNS:** Route 53 records pointing to the ALB
- **Platform:** Terraform Cloud workspaces, remote state, variable sets, VCS integration
- **Pipeline:** GitHub Actions CI with validate, fmt, test, and plan jobs
- **Policy:** Three Sentinel policies — instance type enforcement, tag compliance, cost gate
- **Modules:** Reusable, versioned webserver cluster module consumed across dev/staging/prod

That is more infrastructure than most engineers deploy manually in their first year. Every piece of it is reproducible from a single `terraform apply`.

### What changed in how I think

Before this challenge I thought about infrastructure as a sequence of AWS console clicks that had to be memorised and repeated. Now I think about **state as the source of truth and code as the declaration of intent**. The question I ask about every change is no longer "what do I need to click?" but "what does the state file currently say, what do I want it to say, and what is the safest path between those two things?" That shift — from procedural to declarative — is the one that does not go away.

### What was harder than expected

State management. Specifically, the gap between what Terraform thinks exists and what AWS actually contains. On Day 14 I renamed a resource in a module refactor and Terraform planned a destroy-and-recreate of a running EC2 instance because the state key changed. I had to use `terraform state mv` to migrate the state manually before applying. No tutorial covers that moment clearly. You only understand it when you are staring at a plan that wants to destroy something you did not mean to touch.

### What I would do differently from Day 1

Set up the S3 backend and DynamoDB locking table on Day 1, before writing any other Terraform. I spent the first week using local state and then had to migrate everything mid-challenge. Remote state with locking should be the first resource you create, not something you retrofit. The migration is straightforward but it introduces unnecessary risk at a point when you are still finding your footing.

### What comes next

After the exam: applying this to a production EKS cluster for a side project. The challenge introduced EKS briefly but did not go deep on Kubernetes-native Terraform patterns — node group management, IRSA, cluster autoscaler configuration, and the interaction between Terraform state and Helm releases. That is the next six weeks of work.

---

## Chapter 10 Final Learnings

**The single most important insight:** Promote artifacts, not configurations.

Most teams run `terraform plan` in CI, get approval on the plan output, then run `terraform apply` again at deploy time — generating a fresh plan against whatever the world looks like at that moment. This means the reviewer approved something that was never applied. The plan that actually runs was never reviewed.

The correct model is to save the plan file, treat it as an immutable build artifact, and apply that exact file in production. The same binary discipline that prevents "it works on my machine" in application code prevents "the plan looked fine when we reviewed it" in infrastructure code. The artifact is the review. The review is the artifact. They must be the same object.

---

## Social Post

> 🎉 Day 22 of the 30-Day Terraform Challenge — finished the book. Combined application and infrastructure deployment workflows into one integrated pipeline with CI, Sentinel policies, cost gates, and immutable plan promotion across environments. 22 days in and it is just getting interesting. #30DayTerraformChallenge #TerraformChallenge #Terraform #DevOps #IaC #AWSUserGroupKenya #EveOps

---

*Part of the [30-Day Terraform Challenge](https://github.com/gitauadmin/terraform-challenge) | eu-west-1*
