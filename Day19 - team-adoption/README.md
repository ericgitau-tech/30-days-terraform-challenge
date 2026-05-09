# Day 19: Adopting Infrastructure as Code in Your Team

> **30-Day Terraform Challenge** | Author: [@gitauadmin](https://github.com/gitauadmin) | Region: `eu-west-1`

---

## 📋 Table of Contents

- [What I Accomplished](#what-i-accomplished)
- [Current State Assessment](#current-state-assessment)
- [Four-Phase IaC Adoption Plan](#four-phase-iac-adoption-plan)
- [Business Case Table](#business-case-table)
- [Terraform Import Practice](#terraform-import-practice)
- [Terraform Cloud Lab Takeaways](#terraform-cloud-lab-takeaways)
- [Chapter 10 Learnings](#chapter-10-learnings)
- [Challenges](#challenges)
- [Blog Post Summary](#blog-post-summary)

---

## What I Accomplished

Today's focus shifted from writing Terraform code to the harder challenge: **getting a team to actually adopt it**. I read Chapter 10 of *Terraform: Up & Running* by Yevgeniy Brikman, completed the Terraform Cloud and Terraform Enterprise hands-on labs, audited my organisation's current infrastructure practices, and built a realistic four-phase adoption plan backed by a business case.

---

## Current State Assessment

### How is infrastructure currently provisioned?

Infrastructure is provisioned through a **mix of manual AWS Console clicks and ad-hoc Bash/Python scripts**. Some resources (VPCs, EC2 instances, S3 buckets) were created by hand during early-stage growth and have never been codified. A handful of newer workloads use partial CloudFormation templates, but there is no unified IaC standard. Terraform is used by one or two engineers individually but not as a team practice.

### How many people are involved in infrastructure changes and what is the approval process?

Approximately **3–5 engineers** touch infrastructure, plus a team lead who provides verbal approval for significant changes. There is no formal change-management process: changes are discussed in Slack, someone makes the change in the console, and a message is sent after the fact. There is no pull-request-based review for infrastructure. No change log is maintained consistently.

### How often do infrastructure changes cause incidents or unexpected behaviour?

Roughly **once or twice per month** an infrastructure change causes unexpected behaviour — a misconfigured security group blocking traffic, an S3 bucket policy change breaking an application, or an EC2 instance type being resized during peak hours. Most incidents trace back to a manual action taken without a second pair of eyes.

### Is there existing drift between documented infrastructure and actual infrastructure?

Yes — significantly. The Confluence wiki documents the architecture as it existed roughly **12–18 months ago**. Since then, dozens of resources have been added, modified, or deleted without updating the docs. Anyone trying to reconstruct the environment from documentation would fail. This is the single biggest operational risk the team carries.

### Are secrets managed properly?

Partially. AWS credentials are shared via a team Slack channel in some cases, and several Lambda functions have hardcoded credentials in environment variables rather than using IAM roles or AWS Secrets Manager. Database passwords are stored in a `.env` file in the repository (in a private repo, but still a bad practice). This is a known issue that has been deprioritised due to delivery pressure.

### Team readiness

| Dimension | Current State |
|---|---|
| Version control for infra | Almost none. App code is in Git; infra is not. |
| Executive appetite for change | Low-to-moderate. Leadership cares about uptime, not tooling. |
| Trust in automated deployments | Low. The team is not yet comfortable with `terraform apply` running unattended. |
| Terraform familiarity | 2 out of 5 engineers have used Terraform. 3 have not. |

---

## Four-Phase IaC Adoption Plan

### Phase 1 — Start with Something New (Weeks 1–2)

**Goal:** Create a success story with zero migration risk.

**What gets done:**
Provision a brand-new S3 bucket (used for storing CloudWatch log exports) entirely with Terraform. This resource does not exist yet, so there is no migration risk. Remote state is stored in an existing S3 bucket with a DynamoDB lock table.

**Who does it:** One senior engineer and one junior engineer pair on this together. The junior engineer writes the code; the senior reviews and approves the PR.

**Terraform configuration:**

```hcl
# main.tf
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "gitauadmin-terraform-state-eu-west-1"
    key            = "phase1/cloudwatch-logs/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-1"
}

resource "aws_s3_bucket" "cloudwatch_log_exports" {
  bucket = "gitauadmin-cloudwatch-log-exports-eu-west-1"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
}

resource "aws_s3_bucket_versioning" "cloudwatch_log_exports" {
  bucket = aws_s3_bucket.cloudwatch_log_exports.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudwatch_log_exports" {
  bucket = aws_s3_bucket.cloudwatch_log_exports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudwatch_log_exports" {
  bucket = aws_s3_bucket.cloudwatch_log_exports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Success criteria:**
- `terraform apply` completes without errors
- Bucket exists in the AWS Console
- State file is visible in the remote S3 backend
- All team members can run `terraform plan` and read the output
- Code is merged via a reviewed pull request

**Estimated duration:** 1–2 weeks

---

### Phase 2 — Import Existing Infrastructure (Weeks 3–6)

**Goal:** Bring the most critical existing resources under Terraform state management without recreating them.

**What gets done:**
Using `terraform import`, bring in the production VPC, primary application security group, and the main application S3 bucket. Prioritise resources that have caused incidents. Do not try to import everything — start with the highest-risk resources only.

**Who does it:** Senior engineer leads. Junior engineer observes, then attempts one import independently with review.

**Import commands:**

```bash
# Import the production VPC
terraform import aws_vpc.production vpc-0abc123def456789

# Import the primary application security group
terraform import aws_security_group.app_servers sg-0abc123def456789

# Import the existing application S3 bucket
terraform import aws_s3_bucket.app_assets gitauadmin-app-assets-eu-west-1
```

**Resource blocks written to match the imported state:**

```hcl
resource "aws_vpc" "production" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "production-vpc"
    ManagedBy = "terraform"
  }
}

resource "aws_security_group" "app_servers" {
  name        = "app-servers-sg"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.production.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "app-servers-sg"
    ManagedBy = "terraform"
  }
}

resource "aws_s3_bucket" "app_assets" {
  bucket = "gitauadmin-app-assets-eu-west-1"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

**Expected `terraform plan` output after import:**

```
aws_vpc.production: Refreshing state... [id=vpc-0abc123def456789]
aws_security_group.app_servers: Refreshing state... [id=sg-0abc123def456789]
aws_s3_bucket.app_assets: Refreshing state... [id=gitauadmin-app-assets-eu-west-1]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```

**Success criteria:**
- `terraform plan` shows no changes after each import
- Imported resources are visible in the state file
- No resources were destroyed or recreated during the import process

**Estimated duration:** 3–4 weeks (import + write matching configs + review)

---

### Phase 3 — Establish Team Practices (Weeks 7–10)

**Goal:** Make Terraform the standard way the whole team works — not just a personal tool.

**What gets done:**

1. **Internal module registry:** Extract reusable patterns (S3 buckets with standard encryption and access controls, security groups with standard egress rules) into versioned internal modules stored in the same Git organisation.

2. **Pull request requirements:** All infrastructure changes must be proposed via PR. PRs must include the output of `terraform plan`. No infrastructure change is applied without at least one approval.

3. **CI pipeline checks:** Add `terraform fmt -check` and `terraform validate` to the CI pipeline. PRs that fail formatting or validation cannot be merged.

4. **State locking:** Enforce state locking via DynamoDB on all workspaces. Any `terraform apply` that cannot acquire the lock fails immediately.

5. **Console change policy:** Communicate clearly to the team: any resource managed by Terraform must not be modified in the console. Drift is now a bug. A weekly `terraform plan` run in CI alerts the team to any drift.

**Who does it:** Team lead sets up CI pipeline and module structure. All engineers participate in PR reviews for infrastructure from this point forward.

**Sample CI step (GitHub Actions):**

```yaml
name: Terraform Checks

on:
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.0

      - name: Terraform Format Check
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init -backend=false

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=tfplan
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

**Success criteria:**
- All engineers have submitted at least one infrastructure PR
- CI blocks at least one bad change before it reaches production
- No manual console changes to Terraform-managed resources in a 4-week period
- At least two reusable modules exist in the internal registry

**Estimated duration:** 3–4 weeks

---

### Phase 4 — Automate Deployments (Weeks 11–14)

**Goal:** Infrastructure changes follow the same automated deployment process as application code.

**What gets done:**
Connect Terraform to the CI/CD pipeline so that a merge to `main` triggers `terraform apply` automatically. Use Terraform Cloud (or a self-hosted runner with proper IAM role assumptions) as the execution environment. Implement environment-specific workspaces (`dev`, `staging`, `production`) so that changes flow through environments before reaching production.

**Who does it:** Senior engineer architects the pipeline. Team lead approves the design. All engineers are responsible for their own module changes passing through the pipeline.

**Workspace strategy:**

```bash
# Create environment-specific workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new production

# Select workspace before planning
terraform workspace select production
terraform plan
```

**Success criteria:**
- A merge to `main` triggers `terraform apply` without manual intervention
- Production deployments require a manual approval gate in the pipeline
- The team has gone 30 days without a manual infrastructure change to production
- New team members can provision a full environment by following the README alone

**Estimated duration:** 3–4 weeks

---

## Business Case Table

This table uses estimates based on our actual experience over the last 12 months.

| Business Problem | IaC Solution | Measurable Outcome |
|---|---|---|
| ~2 incidents/month from manual console changes | Code review catches mistakes before `terraform apply` | Target: fewer than 1 incident/month from infrastructure changes |
| ~4 hours per engineer per week spent on repetitive environment setup | Reusable Terraform modules provision environments in minutes | Recover ~8 engineer-hours per week across the team |
| No audit trail — "who changed the security group?" is unanswerable | Every change is a Git commit with author, timestamp, and PR link | Full audit trail for SOC 2 and ISO 27001 compliance evidence |
| Dev/staging environments differ from production, causing "works on staging" bugs | Identical Terraform configs for all environments via workspaces | Eliminate environment-parity incidents (currently ~1 per sprint) |
| New engineer takes 2–3 weeks to understand and safely change infrastructure | Documented, version-controlled configurations with README | Onboarding time for infra changes cut to 3–5 days |
| Credentials shared in Slack or hardcoded in Lambda functions | IAM roles for all services; AWS Secrets Manager for remaining secrets | Zero hardcoded credentials in codebase within 60 days |
| Drift between wiki documentation and actual infrastructure | Terraform state is the single source of truth | Documentation drift eliminated; state file is always current |

**Estimated annual value of reduced incidents:** If each incident costs 4 engineering-hours to resolve at a fully-loaded rate of $75/hour, reducing from 24 to 6 incidents per year saves approximately **$5,400/year** in incident response alone — before counting customer impact or SLA penalties.

---

## Terraform Import Practice

### Scenario

Imported an existing S3 bucket that was created manually in the console 6 months ago. The bucket stores application access logs and had never been managed by Terraform.

### Step 1 — Write the resource block first

```hcl
# logs.tf
resource "aws_s3_bucket" "access_logs" {
  bucket = "gitauadmin-access-logs-eu-west-1"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "access-logs"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### Step 2 — Run the import

```bash
# Initialise first
terraform init

# Import the existing bucket into state
terraform import aws_s3_bucket.access_logs gitauadmin-access-logs-eu-west-1

# Import the associated resources
terraform import aws_s3_bucket_server_side_encryption_configuration.access_logs gitauadmin-access-logs-eu-west-1
terraform import aws_s3_bucket_public_access_block.access_logs gitauadmin-access-logs-eu-west-1
```

### Import output

```
aws_s3_bucket.access_logs: Importing from ID "gitauadmin-access-logs-eu-west-1"...
aws_s3_bucket.access_logs: Import prepared!
  Prepared aws_s3_bucket for import
aws_s3_bucket.access_logs: Refreshing state... [id=gitauadmin-access-logs-eu-west-1]

Import successful!

The resources that were imported are shown above. These resources are now in
your Terraform state and will henceforth be managed by Terraform.
```

### Step 3 — Verify with `terraform plan`

```bash
terraform plan
```

```
aws_s3_bucket.access_logs: Refreshing state... [id=gitauadmin-access-logs-eu-west-1]
aws_s3_bucket_server_side_encryption_configuration.access_logs: Refreshing state... [id=gitauadmin-access-logs-eu-west-1]
aws_s3_bucket_public_access_block.access_logs: Refreshing state... [id=gitauadmin-access-logs-eu-west-1]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```

The `No changes` output confirms the written resource block exactly matches the existing resource. The bucket is now under Terraform management with no recreation risk.

---

## Terraform Cloud Lab Takeaways

### What the Terraform Cloud lab demonstrated

The lab walked through connecting a Terraform configuration to Terraform Cloud, configuring a workspace, storing variables, and triggering runs via version control integration (VCS-driven workflows). The key workflow is: push to Git → Terraform Cloud detects the change → plan runs automatically → a team member reviews the plan output → apply is triggered with a single click or automatically on merge.

### What Terraform Cloud provides that a plain S3 backend does not

| Capability | S3 Backend | Terraform Cloud |
|---|---|---|
| Remote state storage | ✅ Yes | ✅ Yes |
| State locking | ✅ Yes (via DynamoDB) | ✅ Yes (built-in) |
| Remote execution | ❌ No — runs locally | ✅ Yes — runs in Terraform Cloud |
| Plan output in UI | ❌ No | ✅ Yes — visible to all team members |
| VCS integration (auto-plan on PR) | ❌ No | ✅ Yes |
| Policy enforcement (Sentinel) | ❌ No | ✅ Yes (Team/Business tier) |
| Audit logging | ❌ No | ✅ Yes |
| Variable management with secrets | ❌ Manual | ✅ Encrypted variable store |
| Team access controls | ❌ No | ✅ Yes — per-workspace RBAC |

The most significant difference in practice is **remote execution with a shared UI**. With an S3 backend, every engineer runs `terraform apply` from their own machine, which means the plan can differ based on local provider versions, local variable values, or environment state. Terraform Cloud runs every plan and apply in a consistent, reproducible environment, and every team member can see the output without needing terminal access. This is the difference between infrastructure operations being a solo activity and a team activity.

---

## Chapter 10 Learnings

### What does the author identify as the most common reason IaC adoption fails?

Brikman argues the most common failure mode is **attempting to do too much at once** — teams try to migrate all existing infrastructure to Terraform in a single project, underestimate the complexity, stall, and abandon the effort. The migration becomes a multi-month initiative that competes with delivery work and produces no visible results during the effort, making it easy for leadership to cancel.

The second failure mode he identifies is **not getting buy-in before starting**. Engineers adopt Terraform individually, create isolated configurations that nobody else can use or review, and then leave the organisation — leaving behind Terraform state that the remaining team does not know how to operate. IaC without team buy-in creates a new form of knowledge silo.

### Do I agree based on my own experience?

Yes — both failure modes map directly to what I have seen. The "migrate everything" instinct is strong because it feels like the right way to do it cleanly. But it consistently underestimates the archaeology required to correctly describe existing infrastructure in code. Resources have undocumented dependencies. Security groups have accumulated rules over years. IAM policies have exceptions nobody remembers the reason for. Every import surfaces a conversation that takes time.

### What would I add?

The failure mode the book does not emphasise enough is **underestimating the cultural change required**. Engineers who have spent years making infrastructure changes by clicking in the console develop habits and muscle memory around that workflow. Telling them to write code, open a pull request, wait for review, and wait for CI is not just a process change — it feels slower, even when it is not. The team needs to experience the pain of the old way (an incident caused by an unreviewed manual change) before the new way feels worth it. Sometimes adoption accelerates fastest after a production incident that Terraform would have prevented.

---

## Challenges

### Technical challenges

The hardest technical challenge is writing resource blocks that exactly match existing infrastructure for the import to succeed with `No changes`. Real-world resources have accumulated attributes — lifecycle rules, notification configurations, logging settings, replication rules — that were added over time and are not obvious from the console. Each undocumented attribute causes `terraform plan` to show a drift that needs to be resolved before the import is clean.

### Organisational challenges

Getting the team to stop making manual console changes is harder than it sounds. The console is fast and familiar. Opening a PR, waiting for CI, waiting for review, and waiting for apply takes longer — especially for small, urgent changes. The team needs to internalise that the short-term slowness prevents the long-term incidents. This requires leadership backing the process even under deadline pressure.

### Cultural challenges

The deepest challenge is **trust in automation**. Most engineers in the team have been burned by automation failures — a deployment script that applied changes in the wrong environment, a misconfigured pipeline that deleted a resource. That history makes them reluctant to hand control to `terraform apply` running unattended. Building that trust requires starting small, being transparent when things go wrong, and demonstrating that the guardrails (state locking, plan review, approval gates) make automated apply safer than manual apply — not more dangerous.

---

## Blog Post Summary

**Title: How to Convince Your Team to Adopt Infrastructure as Code**

The technical part of Terraform is the easy part. You can learn `resource`, `variable`, `output`, and `module` in a weekend. What takes months — sometimes years — is convincing a team to change how they work, building trust in automated deployments, and migrating existing infrastructure without breaking production.

The business case is straightforward: fewer incidents, faster onboarding, full audit trail, environment parity. But business cases alone do not change behaviour. What changes behaviour is a shared experience of pain — an incident caused by an unreviewed manual change that Terraform would have caught — followed by a credible alternative. Phase 1 of the adoption plan is not about infrastructure. It is about creating a story the team can point to and say: that worked, it was safe, and it was faster than we expected.

The most common failure mode is trying to migrate everything at once. Do not do it. Start with something new. Add one resource, get comfortable with the workflow, then import one existing resource. Build the muscle memory before you build the policy.

The cultural shift matters as much as the technical one. Give the team time to learn. Run `terraform plan` in code review before `terraform apply` is automated. Let engineers make mistakes in a sandbox. The goal is not to prevent all mistakes — it is to make mistakes visible and recoverable before they reach production.

---

