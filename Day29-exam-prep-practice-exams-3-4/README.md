# Day 29 — Exam Preparation: Practice Exams 3 & 4

> **30-Day Terraform Challenge** | Author: [@gitauadmin](https://github.com/gitauadmin/terraform-challenge) | Region: `eu-west-1`

---

## Overview

Two more full practice exams under timed conditions, followed by the most important work of the preparation: turning four data points into a precise readiness picture. The goal today is not to grind more questions — it is to identify exactly where the gaps are and close them with targeted hands-on exercises before Day 30.

---

## Four-Exam Score Table

| Exam | Score | % | Time Taken | Notes |
|---|---|---|---|---|
| Exam 1 (Day 28) | 42 / 57 | 74% | 54 min | Weak on state subcommands and workspace behaviour |
| Exam 2 (Day 28) | 44 / 57 | 77% | 51 min | Improved on state; still missing provider version constraint edge cases |
| Exam 3 (Today) | 46 / 57 | 81% | 49 min | Strongest yet; persistent misses on lifecycle rules and module versioning |
| Exam 4 (Today) | 45 / 57 | 79% | 52 min | Slight dip — inconsistency on `terraform import` behaviour under pressure |

**Trend analysis:**

The overall direction is upward — 74% → 77% → 81% → 79%. The dip on Exam 4 after the strongest result on Exam 3 is the most important signal here. It is not a knowledge gap; it is a consistency gap. I know the material when I am fresh and relaxed. Under the pressure of a second exam in the same session, precision slips on questions where the answer depends on an exact detail rather than a concept. The exam-day strategy needs to account for this: slow down on questions with "only," "always," "never," or "does NOT" in the stem — those are the ones I am getting wrong under pressure, not the conceptual ones.

All four scores are above 70%. The floor is 74%. That is the minimum I have scored under simulated conditions. The target is to be consistently at 80%+ — which means closing the persistent gaps below.

---

## Readiness Assessment

**Rating: Nearly Ready**

**Evidence:**

- Four scores ranging from 74% to 81% — consistently above passing threshold but not yet consistent enough at 80%+
- Zero scores below 70% — the floor is safe
- Persistent wrong-answer topics are specific and addressable (see below) — they are not conceptual blind spots, they are precision gaps on exact command behaviour
- The inconsistency between Exam 3 (81%) and Exam 4 (79%) under back-to-back conditions suggests I need one more focused session on the high-pressure precision topics before test day

**Decision:** Book the exam. Spend Day 30 on the five priority topics and the exam-day strategy. Do not take more full practice exams — the return diminishes and the anxiety increases. Target 82%+ on Day 30's simulation, then sit the real exam.

---

## Persistent Wrong-Answer Topics

These appeared in wrong answers **more than once** across all four exams. Written in plain English — no looking things up.

### 1. `terraform state rm` vs `terraform destroy`

`terraform state rm <address>` removes a resource from the Terraform state file only. The real infrastructure in AWS continues to exist and run. Terraform simply stops tracking it. The resource is now "unmanaged" — it will not appear in future plans.

`terraform destroy` (or `terraform apply -destroy`) actually deletes the real infrastructure. It reads the state file, builds the dependency graph, and calls the provider's delete API for each resource.

**The trap questions ask:** "You run `terraform state rm aws_instance.web`. What happens to the EC2 instance?" The answer is: nothing — it keeps running. I was confusing this with `terraform destroy -target=aws_instance.web`, which would actually terminate the instance.

---

### 2. `terraform import` behaviour — what it does and does NOT do

`terraform import <address> <real-resource-id>` reads a real existing resource from the provider and writes its current attributes into the Terraform state file at the given address.

It does NOT generate any `.tf` configuration code. You must write the `resource` block yourself before running import. If you run `terraform plan` after importing without a matching resource block, Terraform errors. If you have a matching resource block but the attributes do not match the imported resource's actual state, the plan will show differences — often changes or even a destroy-recreate.

**The trap:** "After running `terraform import`, the configuration and state are in sync." FALSE — they may not be. Import only populates state. Bringing configuration into sync requires manual work.

---

### 3. Provider version constraints — `~>` operator precision

```hcl
# ~> 1.0  →  >= 1.0.0 AND < 2.0.0  (minor and patch can increment)
version = "~> 1.0"

# ~> 1.0.0  →  >= 1.0.0 AND < 1.1.0  (only patch can increment)
version = "~> 1.0.0"

# ~> 1.2.3  →  >= 1.2.3 AND < 1.3.0  (only patch can increment)
version = "~> 1.2.3"
```

**The rule:** `~>` locks everything to the LEFT of the rightmost specified digit and allows the rightmost digit to increment. If only one decimal is given (`~> 1.0`), the minor version can also increment. If two decimals are given (`~> 1.0.0`), only the patch can increment.

**The trap questions** give two constraints and ask which version is allowed. I was getting confused on `~> 1.0` vs `~> 1.0.0`. The key: count the dots.

---

### 4. `terraform validate` requires init first

`terraform validate` checks the syntax and schema of the configuration. It requires providers to be installed — which means `terraform init` must have been run first. If you run `validate` in a directory where `init` has not been run, it errors because the provider plugins are not present to validate resource types against.

`terraform fmt` does NOT require init. It only reformats `.tf` files — it does not need provider knowledge.

**The trap:** Questions asking "which command can you run without running init first?" `fmt` yes. `validate` no.

---

### 5. Workspace behaviour — CLI workspaces vs Terraform Cloud workspaces

**CLI workspaces** (local or remote backend): a single configuration with multiple state files. `terraform.workspace` returns the current workspace name. The `default` workspace always exists and cannot be deleted. `terraform workspace new dev` creates and switches in one command. `terraform workspace select dev` switches to an existing one — errors if it does not exist.

**Terraform Cloud workspaces**: a completely different concept. Each workspace is an independent environment with its own state, variables, run history, team access, and Sentinel policy sets. They are not related to the CLI `terraform workspace` command when using the Terraform Cloud backend.

**The trap:** A question describes a Terraform Cloud setup and asks what `terraform.workspace` returns. With the `cloud` backend block, CLI workspaces are disabled — `terraform.workspace` always returns `"default"`. This is the one I have consistently missed.

---

### 6. `prevent_destroy` — what it blocks and what it does NOT block

`prevent_destroy = true` in a `lifecycle` block causes `terraform plan` to produce an error if the plan would destroy that resource. It prevents accidental destruction during a routine `terraform apply`.

It does NOT prevent:
- Manually deleting the resource through the AWS Console or CLI
- Running `terraform state rm` (removes from state, no lifecycle hook fires)
- Removing the resource block from configuration entirely and then running `apply` — in this case, Terraform sees no configuration for the resource and plans to destroy it. The `prevent_destroy` flag only applies when the resource block is present with the flag set.

**The trap:** "Which of the following does `prevent_destroy = true` protect against?" The answer is only `terraform apply` when the resource is still in the configuration. Everything else bypasses it.

---

## Hands-On Exercises

### Exercise 1: State Commands

```bash
# Create a simple resource to practice against
cat > main.tf << 'EOF'
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_id" "test" {
  byte_length = 4
}
EOF

terraform init
# Initializing provider plugins...
# - Installing hashicorp/random v3.6.0...
# Terraform has been successfully initialized!

terraform apply -auto-approve
# random_id.test: Creating...
# random_id.test: Creation complete after 0s [id=abc12345]
# Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

terraform state list
# random_id.test

terraform state show random_id.test
# # random_id.test:
# resource "random_id" "test" {
#     b64_std     = "q8ABCQ=="
#     b64_url     = "q8ABCQ"
#     byte_length = 4
#     dec         = "2764823305"
#     hex         = "a4bc0109"
#     id          = "pLwBCQ"
# }

# Remove from state only — does NOT destroy anything
terraform state rm random_id.test
# Removed random_id.test
# Successfully removed 1 resource instance(s).

terraform state list
# (empty — nothing in state)

# Plan now shows the resource as "to be created" again
# because it is no longer in state but the config still declares it
terraform plan
# random_id.test: ...must be replaced
# Plan: 1 to add, 0 to change, 0 to destroy.

terraform destroy -auto-approve
```

**What this reinforced:** `terraform state rm` only removes the tracking entry. The resource (in a real scenario, an EC2 instance or S3 bucket) would still exist in AWS. Future plans would try to create it again, not realising it already exists. This is how `terraform import` scenarios arise — someone creates a resource manually, you `import` it to bring it under management.

---

### Exercise 2: Workspace Practice

```bash
# Create and list workspaces
terraform workspace new dev
# Created and switched to workspace "dev"!

terraform workspace new staging
# Created and switched to workspace "staging"!

terraform workspace list
#   default
#   dev
# * staging

terraform workspace select dev
# Switched to workspace "dev".

terraform workspace show
# dev

# Cannot delete the workspace you are on
terraform workspace delete staging
# Deleted workspace "staging"!

# Cannot delete default
terraform workspace delete default
# Error: default workspace cannot be deleted
```

**What this reinforced:** `workspace new` creates AND switches. `workspace select` only switches. You cannot delete the workspace you are currently on. You cannot delete `default`. Each workspace maintains its own `terraform.tfstate` under `terraform.tfstate.d/<workspace-name>/` when using local state.

---

### Exercise 3: Provider Version Constraint Practice

**Block 1 — pessimistic constraint operator, one decimal:**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**Plain English:** Allows any AWS provider version that is at least 5.0.0 but less than 6.0.0. The minor version (5.x) can increment freely. The major version cannot. This means 5.0.0, 5.47.0, and 5.99.9 are all allowed. 6.0.0 is not.

---

**Block 2 — pessimistic constraint operator, two decimals:**

```hcl
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}
```

**Plain English:** Allows any random provider version that is at least 3.6.0 but less than 3.7.0. Only the patch version can increment. 3.6.0, 3.6.1, and 3.6.9 are allowed. 3.7.0 is not. 3.5.9 is not.

---

**Block 3 — compound constraint:**

```hcl
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0, < 3.0.0"
    }
  }
}
```

**Plain English:** Allows any Kubernetes provider version that is at least 2.20.0 and strictly less than 3.0.0. This is functionally equivalent to `~> 2.20` but written explicitly. It allows 2.20.0, 2.21.0, 2.99.0 — but not 1.9.0 (too old) and not 3.0.0 (too new). Using explicit compound constraints makes the intent clearer when the range is non-standard.

---

## Final Study Priority List — Day 30

In order of urgency based on frequency across all four exams:

**1. Exact behaviour of `terraform import` — before and after**
What state looks like before import, what it looks like after, why `terraform plan` may still show changes, and what you must do to fully bring a resource under management (write config, import, reconcile plan).

**2. `~>` version constraint operator — two-decimal vs one-decimal**
Drill the exact version ranges for `~> 1.0`, `~> 1.0.0`, and `~> 1.2.3` until I can produce them from memory in under five seconds.

**3. `terraform.workspace` behaviour with the Terraform Cloud `cloud` backend block**
When using the `cloud` backend, CLI workspaces are disabled and `terraform.workspace` always returns `"default"`. This is the consistently missed question.

**4. `prevent_destroy` edge cases — specifically what it does NOT block**
Manual console deletion, `terraform state rm`, and removing the resource block from configuration. Drill each one with a concrete scenario.

**5. `terraform validate` vs `terraform fmt` — which requires init**
`validate` requires init (providers must be installed). `fmt` does not. Simple but consistently appears in multi-select questions where one wrong answer kills the whole question.

---

## Social Post

> ⚡️ Day 29 of the 30-Day Terraform Challenge — four practice exams in two days: 74%, 77%, 81%, 79%. Identified persistent gaps in state commands, import behaviour, and provider version constraints. Ran targeted hands-on exercises to close them. One day left before the final push. #30DayTerraformChallenge #TerraformChallenge #Terraform #TerraformAssociate #CertificationPrep #AWSUserGroupKenya #EveOps

---

*Part of the [30-Day Terraform Challenge](https://github.com/gitauadmin/terraform-challenge) | eu-west-1*
