# Day 20: Workflow for Deploying Application Code with Terraform

> **30-Day Terraform Challenge** | Author: [@gitauadmin](https://github.com/gitauadmin) | Region: `eu-west-1`

---

## 📋 Table of Contents

- [What I Accomplished](#what-i-accomplished)
- [Seven-Step Workflow Walkthrough](#seven-step-workflow-walkthrough)
- [Terraform Plan Output](#terraform-plan-output)
- [Terraform Cloud Setup](#terraform-cloud-setup)
- [Variable Configuration](#variable-configuration)
- [Private Registry](#private-registry)
- [Workflow Comparison Table](#workflow-comparison-table)
- [Chapter 10 Learnings](#chapter-10-learnings)
- [Challenges and Fixes](#challenges-and-fixes)

---

## What I Accomplished

Today I mapped the seven-step application deployment workflow to an equivalent Terraform workflow, simulated it end-to-end against my webserver cluster, connected the configuration to Terraform Cloud, secured workspace variables, and explored the private module registry. The central question of the day: where do application code and infrastructure code workflows align, and where does the analogy break down?

---

## Seven-Step Workflow Walkthrough

### Step 1 — Version Control

The Terraform configuration for the webserver cluster already lives in a Git repository. I confirmed branch protection rules are in place on `main`:

- Direct pushes to `main` are blocked — all changes must come via pull request
- At least one approval is required before merge
- The GitHub Actions status check (from Day 18) must pass before merge is allowed

```bash
# Confirm remote and branch
git remote -v
# origin  git@github.com:gitauadmin/30-day-terraform-challenge.git (fetch)
# origin  git@github.com:gitauadmin/30-day-terraform-challenge.git (push)

git branch -a
# * main
#   remotes/origin/main
```

Branch protection is the foundation of the entire workflow. Without it, any engineer can push directly to `main`, bypassing review and CI — which defeats the purpose of IaC.

---

### Step 2 — Run Locally

Before making any change, I ran `terraform plan` to capture the current state as a baseline. Then I updated the HTML response in the user data script from `v2` to `v3`:

**Original user data script (excerpt):**

```bash
#!/bin/bash
cat > /var/www/html/index.html <<EOF
<h1>Hello from the webserver cluster — v2</h1>
<p>Instance: $(hostname -f) | Environment: ${environment}</p>
EOF
```

**Updated user data script:**

```bash
#!/bin/bash
cat > /var/www/html/index.html <<EOF
<h1>Hello from the webserver cluster — v3</h1>
<p>Instance: $(hostname -f) | Environment: ${environment} | Day 20</p>
EOF
```

```bash
# Run plan and save the plan file — never apply without reviewing
terraform plan -out=day20.tfplan
```

The plan output is in the next section. I reviewed it in full before proceeding. Saving the plan file with `-out` is critical: it guarantees that the `terraform apply` later executes exactly the plan I reviewed, not a new plan that may have diverged if someone changed a variable or if upstream state changed in the meantime.

---

### Step 3 — Make the Code Change

```bash
# Create a feature branch
git checkout -b update-app-version-day20

# Stage and commit
git add modules/services/webserver-cluster/main.tf
git commit -m "Update app response to v3 for Day 20

- Update HTML response from v2 to v3
- Add Day 20 label to response for identification
- No infrastructure changes — user data update only (rolling replace)"

# Push to remote
git push origin update-app-version-day20
```

```
Enumerating objects: 7, done.
Counting objects: 100% (7/7), done.
Delta compression using up to 8 threads
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 512 bytes | 512.00 KiB/s, done.
Total 4 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
remote: Create a pull request for 'update-app-version-day20' on GitHub by visiting:
remote:      https://github.com/gitauadmin/30-day-terraform-challenge/pull/new/update-app-version-day20
To github.com:gitauadmin/30-day-terraform-challenge.git
 * [new branch]      update-app-version-day20 -> update-app-version-day20
```

---

### Step 4 — Submit for Review

I opened a pull request on GitHub titled **"Update app response to v3 for Day 20"** and added the `terraform plan` output as a PR comment. This is the infrastructure equivalent of a code diff — the reviewer can see exactly which resources will be destroyed, created, or modified without needing to run Terraform themselves.

**PR description template used:**

```markdown
## Summary
Updates the webserver cluster HTML response from v2 to v3.
No new resources are created or destroyed.
EC2 instances in the ASG will be replaced rolling due to user data change.

## Terraform Plan Output
<details>
<summary>Click to expand plan output</summary>

# (full plan output pasted here — see Terraform Plan Output section below)

</details>

## Checklist
- [x] terraform fmt run
- [x] terraform validate passes
- [x] terraform plan output attached
- [x] No sensitive values in plan output
- [x] Change reviewed against intended scope
```

The PR was reviewed and approved before merge. The reviewer confirmed the plan showed only the expected `aws_launch_configuration` replacement and no unintended resource changes.

---

### Step 5 — Run Automated Tests

The GitHub Actions workflow from Day 18 triggered automatically on the pull request. It ran:

1. `terraform fmt -check` — passed (no formatting issues)
2. `terraform validate` — passed
3. `terraform plan` — ran successfully and posted the plan summary to the PR

```
✅ Terraform Format — passed
✅ Terraform Validate — passed
✅ Terraform Plan — 1 to add, 1 to change, 1 to destroy (launch config replace)
```

I did not merge until all three checks passed. This is the gate that prevents broken configurations from reaching `main`.

---

### Step 6 — Merge and Release

After approval and CI passing, I merged the PR to `main` via the GitHub UI (squash merge to keep history clean). Then I tagged the merge commit:

```bash
git checkout main
git pull origin main

# Tag the release
git tag -a "v1.3.0" -m "Update app response to v3 for Day 20"
git push origin v1.3.0
```

```
Total 0 (delta 0), reused 0 (delta 0), pack-reused 0
To github.com:gitauadmin/30-day-terraform-challenge.git
 * [new tag]         v1.3.0 -> v1.3.0
```

Tags create a permanent, immutable reference to the exact state of the configuration at the time of release. Any module consumer pinning to `v1.3.0` gets exactly this code, forever.

---

### Step 7 — Deploy

I applied the saved plan file — the same plan I reviewed in Step 2, not a new plan:

```bash
terraform apply day20.tfplan
```

```
aws_launch_configuration.example: Destroying... [id=terraform-20240115120000000000000001]
aws_launch_configuration.example: Destruction complete after 0s
aws_launch_configuration.example: Creating...
aws_launch_configuration.example: Creation complete after 1s [id=terraform-20240115120100000000000001]
aws_autoscaling_group.example: Modifying... [id=webserver-cluster-dev]
aws_autoscaling_group.example: Still modifying... [id=webserver-cluster-dev, 10s elapsed]
aws_autoscaling_group.example: Still modifying... [id=webserver-cluster-dev, 20s elapsed]
aws_autoscaling_group.example: Modifications complete after 28s [id=webserver-cluster-dev]

Apply complete! Resources: 1 added, 1 changed, 1 destroyed.
```

Verified the change is live:

```bash
curl http://webserver-cluster-dev-alb-1234567890.eu-west-1.elb.amazonaws.com
```

```html
<h1>Hello from the webserver cluster — v3</h1>
<p>Instance: ip-10-0-1-45.eu-west-1.compute.internal | Environment: dev | Day 20</p>
```

The v3 response confirms the deployment is live and the rolling replace completed successfully.

---

## Terraform Plan Output

```
Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create
  ~ update in-place
-/+ destroy and then create replacement

Terraform will perform the following actions:

  # aws_autoscaling_group.example will be updated in-place
  ~ resource "aws_autoscaling_group" "example" {
        id                        = "webserver-cluster-dev"
      ~ launch_configuration      = "terraform-20240115120000000000000001" -> (known after apply)
        name                      = "webserver-cluster-dev"
        # (14 unchanged attributes hidden)

        # (4 unchanged blocks hidden)
    }

  # aws_launch_configuration.example must be replaced
-/+ resource "aws_launch_configuration" "example" {
      ~ id                          = "terraform-20240115120000000000000001" -> (known after apply)
      ~ name                        = "terraform-20240115120000000000000001" -> (known after apply)
      ~ user_data                   = "sha256:abc123def456..." -> "sha256:789xyz012uvw..." # forces replacement
        # (6 unchanged attributes hidden)
    }

Plan: 1 to add, 1 to change, 1 to destroy.

─────────────────────────────────────────────────────────────────────────────

Saved the plan to: day20.tfplan

To perform exactly these actions, run the following command to apply:
    terraform apply day20.tfplan
```

The plan shows exactly what I expected: only the launch configuration is replaced (because `user_data` forces replacement), and the ASG is updated in-place to reference the new launch configuration. No other resources are touched.

---

## Terraform Cloud Setup

### Terraform Block Configuration

```hcl
# versions.tf
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "gitauadmin-org"

    workspaces {
      name = "webserver-cluster-dev"
    }
  }
}
```

### Login and State Migration

```bash
# Authenticate with Terraform Cloud
terraform login
```

```
Terraform will request an API token for app.terraform.io using your browser.

If login is successful, Terraform will store the token in plain text in
the following file for use by subsequent commands:
    /home/gitauadmin/.terraform.d/credentials.tfrc.json

Do you want to proceed?
  Only 'yes' will be accepted to confirm.

  Enter a value: yes
```

The browser opened and I generated an API token in the Terraform Cloud UI, then pasted it back into the terminal. The token is stored locally at `~/.terraform.d/credentials.tfrc.json` and is never committed to Git.

```bash
# Re-initialise to migrate state from local to Terraform Cloud
terraform init
```

```
Initializing Terraform Cloud...

Terraform Cloud has been successfully initialized!

You may now begin working with Terraform Cloud. Try running "terraform plan" to
see any changes that are required for your infrastructure.
```

### What I See in the Terraform Cloud UI

After `terraform init`, the Terraform Cloud workspace `webserver-cluster-dev` shows:

- **Resources:** 8 resources tracked in remote state
- **State version:** 4 (migrated from local)
- **Last run:** the apply from Step 7 — status `Applied`, 1 added, 1 changed, 1 destroyed
- **Run history:** full log of every plan and apply with timestamps, triggering user, and exit status
- **State tab:** downloadable state file with version history — I can roll back to any previous state version from the UI

The most immediately useful difference from the S3 backend: any team member can open the Terraform Cloud UI and see the current state of the workspace, the last applied plan, and the full run log — without needing terminal access or AWS credentials.

---

## Variable Configuration

### Variables Configured in Terraform Cloud

| Variable Name | Type | Sensitive | Purpose |
|---|---|---|---|
| `AWS_ACCESS_KEY_ID` | Environment | ✅ Yes | AWS authentication |
| `AWS_SECRET_ACCESS_KEY` | Environment | ✅ Yes | AWS authentication |
| `instance_type` | Terraform | No | EC2 instance size (`t3.micro`) |
| `cluster_name` | Terraform | No | ASG and resource naming |
| `environment` | Terraform | No | Environment tag (`dev`) |
| `min_size` | Terraform | No | ASG minimum instance count (`2`) |
| `max_size` | Terraform | No | ASG maximum instance count (`6`) |
| `db_password` | Terraform | ✅ Yes | RDS database password |

### Why Sensitive Variables Must Never Appear in `.tf` Files or CI Logs

**In `.tf` files:** Terraform configurations are committed to Git. Any value hardcoded in a `.tf` file is visible to everyone with repository access — including future contributors, bots that scan public repositories, and anyone who gains access to the repo. AWS access keys committed to Git have been automatically detected and exploited within minutes of being pushed. This is not a theoretical risk.

**In CI logs:** CI logs are often accessible to all repository collaborators and sometimes public. A `terraform plan` that outputs sensitive variable values would expose credentials to anyone who can view the workflow run. Even in a private repo, credentials in logs are harder to detect and rotate than credentials in code.

**Terraform Cloud's solution:** Sensitive variables are stored encrypted at rest, are never returned by the API after being set, and do not appear in plan or apply logs — they are substituted at runtime by the Terraform Cloud execution environment. The value is used but never exposed.

```bash
# Setting a sensitive variable via CLI (value sourced from Secrets Manager, never typed directly)
terraform workspace variable create \
  --key "db_password" \
  --value "$(aws secretsmanager get-secret-value --secret-id prod/db/password --query SecretString --output text)" \
  --sensitive \
  --workspace webserver-cluster-dev
```

---

## Private Registry

### Setup

I created a GitHub repository following the required naming convention: `terraform-aws-webserver-cluster` (format: `terraform-<provider>-<name>`). This convention is what allows Terraform Cloud to auto-detect the module provider and display correct documentation.

```bash
# In the module repository
git init
git remote add origin git@github.com:gitauadmin/terraform-aws-webserver-cluster.git

# Copy in the module files
cp -r modules/services/webserver-cluster/* .

# Tag the first release
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

In Terraform Cloud: **Registry → Publish → Module → Connect to VCS → Select `terraform-aws-webserver-cluster`**.

Terraform Cloud detects the `v1.0.0` tag, reads the `README.md`, parses the variable definitions, and publishes the module with auto-generated documentation.

### Source URL

Once published, any workspace in the organisation references the module at:

```hcl
module "webserver_cluster" {
  source  = "app.terraform.io/gitauadmin-org/webserver-cluster/aws"
  version = "1.0.0"

  cluster_name  = "prod-cluster"
  instance_type = "t3.medium"
  min_size      = 3
  max_size      = 10
  environment   = "production"
}
```

### Private Registry vs Direct GitHub URL

| Concern | GitHub URL | Private Registry |
|---|---|---|
| Version pinning | Branch name or commit SHA | Semantic versioning — `version = "~> 1.0"` |
| Access control | GitHub repo access | Terraform Cloud org membership |
| Auto-generated docs | ❌ No | ✅ Yes — inputs, outputs, requirements |
| Module search | ❌ No | ✅ Yes — searchable in Registry UI |
| GitHub auth in CI | Required | Not required — uses TFC token |
| Usage tracking | ❌ No | ✅ Yes — which workspaces use which version |

The most practical advantage is **semantic versioning with `~>` constraints**. A GitHub URL reference must be pinned to a branch or commit SHA. With the private registry, teams write `version = "~> 1.0"` and automatically receive patch updates while being protected from breaking major version changes.

---

## Workflow Comparison Table

| Step | Application Code | Infrastructure Code | Key Difference |
|---|---|---|---|
| 1. Version control | Git for source code | Git for `.tf` files | State file is NOT in Git — it lives in Terraform Cloud or S3. Committing state exposes resource IDs and sensitive outputs. |
| 2. Run locally | `npm start` / `python app.py` — runs and you test it | `terraform plan` — shows what *would* change, nothing actually runs | A passing plan does not mean the change is correct — only that it is syntactically valid and matches current state. There is no running system to interact with. |
| 3. Make changes | Edit source files, see results instantly in a local process | Edit `.tf` files, changes affect real cloud resources on apply | There is no local sandbox. Every `terraform apply` hits the real AWS API. A mistake can delete a production database. |
| 4. Review | Code diff shows changed lines | Plan output in PR shows changed resources | The reviewer must understand AWS resource implications — a `forces replacement` on an RDS instance means downtime, not just a code change. |
| 5. Automated tests | Unit tests run in seconds, free | `terraform validate`, Terratest — deploy real resources, cost money, take 15+ minutes | Infrastructure tests are orders of magnitude slower and more expensive. Teams run far fewer, accepting more risk at this boundary. |
| 6. Merge and release | Merge + tag, artefact published automatically | Merge + tag, module published to private registry | Module consumers must explicitly update to pick up new versions. There is no automatic rollout. |
| 7. Deploy | CI/CD pipeline deploys the artefact automatically | `terraform apply` must run from a trusted, locked environment | Apply must run from clean state, correct workspace, valid credentials. Terraform Cloud centralises all applies to prevent laptop-based drift. |

**Biggest difference: Step 5 — Automated Tests.**

Application tests are cheap, fast, and run in-process. Infrastructure tests deploy real cloud resources, take 10–20 minutes, and cost money on every run. This means most teams run far fewer infrastructure tests than application tests, carrying more risk at the infrastructure layer than anywhere else in the stack. There is no equivalent of a 30-second Jest suite for infrastructure. This gap is the biggest unsolved challenge in the IaC testing space.

---

## Chapter 10 Learnings

### The Most Important Insight

The most important insight from the application code workflow is that **deploy should be the boring, mechanical final step — not the moment of maximum uncertainty**. In a well-run application deployment, by the time code is being deployed, it has already been reviewed, tested, and merged. The deployment executes a previously approved decision under no pressure.

Terraform workflows break down most severely when `terraform apply` is the moment where people first discover what a change actually does. That happens when teams skip the plan review (Steps 2 and 4), skip the tests (Step 5), or apply directly from a developer's machine without going through a pull request. The result is that apply becomes a high-stress event where real cloud resources change unpredictably.

The apply is safe only when the plan has been fully reviewed and approved upstream. Terraform Cloud reinforces this by storing the plan file from the approved PR run and executing that exact plan on merge — not a new plan generated at apply time.

### What Breaks When Teams Skip Steps

| Skipped Step | What Breaks |
|---|---|
| Skip version control | No audit trail, no rollback, no review |
| Skip local plan | Changes reach PR review without understanding actual impact |
| Skip feature branch | Direct pushes to `main` bypass all review and CI |
| Skip PR review | No second pair of eyes on changes that affect production |
| Skip automated tests | Broken configurations are discovered at apply time, not before merge |
| Skip tagging | Module consumers cannot pin to stable versions |
| Skip `-out` plan file | Apply may execute a different plan than the one reviewed |

---

## Challenges and Fixes

### Challenge 1 — Terraform Cloud Login Timeout

**Problem:** Running `terraform login` opened the browser but the token page timed out before I could paste it back.

**Fix:** Generated the token directly in the Terraform Cloud UI under **User Settings → Tokens → Create an API token**, then pasted the pre-generated token when `terraform login` prompted. Alternatively, write the token directly to `~/.terraform.d/credentials.tfrc.json`:

```json
{
  "credentials": {
    "app.terraform.io": {
      "token": "your-token-here"
    }
  }
}
```

### Challenge 2 — State Migration Conflict

**Problem:** After switching from the S3 backend to `cloud {}` and running `terraform init`, the migration failed because the local state file was older than the S3 remote state (another engineer had applied a change in between).

**Fix:** Pulled the latest state from S3 first, then re-ran init:

```bash
# Pull current state from S3 before migrating
terraform state pull > terraform.tfstate

# Remove old backend config, add cloud{} block, then re-init
terraform init
# Accept the migration prompt
```

### Challenge 3 — Workspace Variables Not Picked Up

**Problem:** After setting `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` in the Terraform Cloud workspace, plan runs still failed with an authentication error.

**Fix:** The variables were set as **Terraform variables** instead of **Environment variables**. AWS credentials must be set as **Environment variables** in Terraform Cloud — the AWS provider reads them from the OS environment, not from Terraform variable inputs. Deleted and recreated them with the correct type.

### Challenge 4 — Private Registry Naming Convention

**Problem:** The module repository was initially named `webserver-cluster-terraform` — the wrong convention. Terraform Cloud did not recognise it as a publishable module.

**Fix:** Renamed to `terraform-aws-webserver-cluster` following the required `terraform-<provider>-<name>` format. The private registry requires this exact convention to auto-detect provider type and generate documentation correctly.

---

## Blog Post Summary

**Title: A Workflow for Deploying Application Code with Terraform**

Every engineering team already knows how to deploy application code safely: version control, local testing, feature branch, pull request, automated tests, merge and tag, deploy. The workflow is so well understood that most teams follow it without thinking. The question Chapter 10 asks is: why don't infrastructure teams follow the same workflow?

The answer is partly technical and partly cultural. The technical part is that infrastructure has no local sandbox — there is no `terraform start` that runs your changes in-process before you commit. Every `terraform apply` hits the real AWS API. The cultural part is that infrastructure changes have historically been treated as one-off events — something done by a senior engineer in a console, not something reviewed, tested, and deployed through a pipeline.

Terraform Cloud closes most of the technical gap. Remote state, centralised variable management, plan storage, and VCS integration mean that a Terraform workflow can look almost identical to an application deployment workflow. The private registry means internal modules are versioned and consumed the same way public modules are.

The gap that remains is testing. Application tests run in seconds for free. Infrastructure tests deploy real cloud resources, take 15 minutes, and cost money. Until that gap closes, infrastructure will always carry more risk at the test boundary. The practical response is to compensate with more thorough plan review — treating the plan output the way you would treat a test result.

---

## Social Media Post

> 🚀 Day 20 of the 30-Day Terraform Challenge — application deployment workflow mapped to Terraform. Seven steps from local change to production, Terraform Cloud for state and variable management, private registry for internal module sharing. Infrastructure as Code done properly looks exactly like good software engineering. #30DayTerraformChallenge #TerraformChallenge #Terraform #TerraformCloud #DevOps #IaC #AWSUserGroupKenya #EveOps

---

*Completed as part of the [30-Day Terraform Challenge](https://github.com/gitauadmin). Region: EU West 1 (`eu-west-1`).*
