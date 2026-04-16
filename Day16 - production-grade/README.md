# 🏗️ Day 16 — Building Production-Grade Infrastructure with Terraform

> **30-Day Terraform Challenge** | AWS Region: `eu-west-1` | Platform: Windows + Git Bash

---

## 📋 Table of Contents

- [Overview](#-overview)
- [What I Built](#-what-i-built)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Project Structure](#-project-structure)
- [Step-by-Step Implementation](#-step-by-step-implementation)
  - [Step 1 — Set Up Project Folder](#step-1--set-up-project-folder)
  - [Step 2 — Write the Terraform Code](#step-2--write-the-terraform-code) 
  - [Step 3 — Initialize Terraform](#step-3--initialize-terraform)
  - [Step 4 — Test Input Validation](#step-4--test-input-validation)
  - [Step 5 — Run the Terraform Plan](#step-5--run-the-terraform-plan) 
  - [Step 6 — Apply to AWS](#step-6--apply-to-aws)
- [Key Concepts Explained](#-key-concepts-explained)
  - [Common Tagging with locals](#1-common-tagging-with-locals)
  - [Lifecycle Rules](#2-lifecycle-rules)
  - [Input Validation](#3-input-validation)
  - [CloudWatch Alarms & SNS](#4-cloudwatch-alarms--sns)
- [Before vs After Refactors](#-before-vs-after-refactors)
- [Production Checklist](#-production-checklist)
- [Lessons Learned](#-lessons-learned)
- [Resources](#-resources)

---

## 🎯 Overview

Most beginners stop at **"my Terraform works."**
Production engineers go further — they make Terraform **safe, scalable, and team-ready.**

This lab is about that transition. I took a fresh Terraform project and applied real production patterns used by DevOps teams at scale: consistent tagging, lifecycle protection, input validation, and infrastructure monitoring via CloudWatch.

| Before This Lab | After This Lab |
|---|---|
| Code that "just works" | Code that is safe and team-ready |
| Hardcoded values | Variables with validation rules |
| No tags | Common tags on every resource |
| No protection | `prevent_destroy` lifecycle rules |
| No monitoring | CloudWatch alarm + SNS alerting |

---

## 🔧 What I Built

| Resource | Purpose |
|---|---|
| `aws_s3_bucket` | Terraform remote state storage with `prevent_destroy` |
| `aws_sns_topic` | Alert notification channel for infrastructure events |
| `aws_cloudwatch_metric_alarm` | Triggers when EC2 CPU exceeds 80% |

All resources are tagged consistently using a `locals`-based tagging strategy and deployed to `eu-west-1` (Ireland).

---

## 🏛️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS eu-west-1 Region                      │
│                                                             │
│   ┌──────────────┐    triggers    ┌──────────────────────┐  │
│   │  CloudWatch  │ ─────────────► │     SNS Topic        │  │
│   │  CPU Alarm   │   (CPU > 80%)  │  (my-cluster-alerts) │  │
│   └──────────────┘                └──────────────────────┘  │
│                                                             │
│   ┌──────────────────────────────┐                          │
│   │         S3 Bucket            │                          │
│   │   (Terraform Remote State)   │                          │
│   │   lifecycle: prevent_destroy │                          │
│   └──────────────────────────────┘                          │
│                                                             │
│   🏷️  All resources tagged:  Environment | ManagedBy |      │
│       Project | Owner | Name                                │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Prerequisites

Before starting, make sure you have the following ready:

- [x] **Terraform** installed (`terraform -version` to verify)
- [x] **Git Bash** on Windows
- [x] **AWS CLI** configured (`aws configure`) with `eu-west-1` as default region
- [x] **VS Code** or any text editor
- [x] An AWS account with permissions to create S3, SNS, and CloudWatch resources

---

## 📁 Project Structure

```
day16-production/
├── main.tf          # Core resources: S3, SNS, CloudWatch
├── variables.tf     # All input variables with validation rules
├── locals.tf        # Common tags used across all resources
├── outputs.tf       # Outputs: SNS ARN, bucket name
└── modules/
    └── services/
        └── webserver-cluster/   # Reserved for future use
```

---

## 🚀 Step-by-Step Implementation

### Step 1 — Set Up Project Folder

Open **Git Bash** and run the following commands:

```bash
# Go to your working directory
cd ~/Downloads

# Create the project folder
mkdir day16-production
cd day16-production

# Create sub-folders for future modules
mkdir -p modules/services/webserver-cluster

# Create all four Terraform files
touch main.tf variables.tf outputs.tf locals.tf

# Confirm everything is in place
ls -la
```

📸 **Screenshot — Folder structure confirmed:**

![Folder Structure](day16-assets/screenshot-01-folder-structure.jpg)

> All four Terraform files (`main.tf`, `variables.tf`, `outputs.tf`, `locals.tf`) and the `modules/` directory are visible in the terminal.

---

### Step 2 — Write the Terraform Code

Open the project in VS Code:

```bash
code .
```

#### 📄 `variables.tf` — Input Variables with Validation

This file defines all the inputs your infrastructure accepts. The `validation` blocks prevent incorrect values from ever reaching AWS.

```hcl
variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t2.micro"

  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Must be a t2 or t3 instance type."
  }
}

variable "cluster_name" {
  type    = string
  default = "my-cluster"
}

variable "project_name" {
  type    = string
  default = "day16-project"
}

variable "team_name" {
  type    = string
  default = "devops-team"
}

variable "state_bucket_name" {
  type        = string
  description = "S3 bucket name for Terraform state"
  default     = "my-terraform-state-day16"
}
```

📸 **Screenshot — Validation blocks in VS Code:**

![Variables Validation](day16-assets/screenshot-02-variables-validation.jpg)

> Both `validation` blocks are clearly visible — one for `environment` and one for `instance_type`.

---

#### 📄 `locals.tf` — Common Tagging Strategy

This file defines a single set of tags that are automatically applied to **every** resource. Change it once, and it updates everywhere.

```hcl
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    Owner       = var.team_name
  }
}
```

📸 **Screenshot — Common tags defined in locals.tf:**

![Locals Tags](day16-assets/screenshot-03-locals-tags.jpg)

> The `common_tags` local value is defined and will be merged into every resource using `merge(local.common_tags, {...})`.

---

#### 📄 `main.tf` — Core Infrastructure

This is the main file that creates all three AWS resources. Notice three important patterns here:
- `provider` is pinned to `~> 5.0` (maintainability)
- Tags use `merge(local.common_tags, {...})` (observability)
- The S3 bucket has a `lifecycle` block (reliability)

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# ── S3 Bucket for Terraform Remote State ──────────────────────
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-state-bucket"
  })

  lifecycle {
    prevent_destroy = true   # ← Protects against accidental deletion
  }
}

# ── SNS Topic for Infrastructure Alerts ───────────────────────
resource "aws_sns_topic" "alerts" {
  name = "${var.cluster_name}-alerts"

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-alerts"
  })
}

# ── CloudWatch Alarm — High CPU Utilisation ────────────────────
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-high-cpu-alarm"
  })
}
```

📸 **Screenshot — main.tf showing lifecycle block and tagging:**

![Main Lifecycle](day16-assets/screenshot-04-main-lifecycle.jpg)

> The `lifecycle { prevent_destroy = true }` block is visible on the S3 bucket, alongside `merge(local.common_tags, {...})` being used for tagging.

---

#### 📄 `outputs.tf` — Expose Key Values

```hcl
output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = aws_sns_topic.alerts.arn
}

output "state_bucket_name" {
  description = "Name of the S3 state bucket"
  value       = aws_s3_bucket.state.bucket
}
```

---

### Step 3 — Initialize Terraform

Download the AWS provider and prepare the working directory:

```bash
terraform init
```

You should see:

```
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.x.x...

Terraform has been successfully initialized!
```

📸 **Screenshot — terraform init success:**

![Terraform Init](day16-assets/screenshot-05-terraform-init.jpg)

> The AWS provider is downloaded and Terraform is successfully initialized. The terminal shows the provider version being installed.

> **💡 Tip for Windows/Git Bash:** If you see a `bash: cd: /user/day16-production: No such file or directory` error, make sure you use `~/Downloads/day16-production` not `/user/...`.

---

### Step 4 — Test Input Validation

Before applying anything real, we deliberately pass a **wrong** value to prove our validation blocks work:

```bash
terraform plan -var="environment=wrong" -var="state_bucket_name=my-tf-state-day16-yourname"
```

**Expected output — a red error:**

```
╷
│ Error: Invalid value for variable
│
│   on variables.tf line 1:
│    1: variable "environment" {
│     ├────────────────
│     │ var.environment is "wrong"
│
│ Environment must be dev, staging, or production.
│
│ This was checked by the validation rule at variables.tf:5,3-13.
╵
```

📸 **Screenshot — Validation error triggered on purpose:**

![Validation Error](day16-assets/screenshot-06-validation-error.jpg)

> ✅ This error is **expected and good!** It proves that Terraform will reject any invalid environment name before a single resource is touched in AWS.

> **⚠️ Windows/Git Bash Note:** Always run multi-variable commands on a **single line**. The `\` line continuation character does not work reliably in Git Bash. Use:
> ```bash
> terraform plan -var="environment=dev" -var="state_bucket_name=my-tf-state-day16-yourname"
> ```

---

### Step 5 — Run the Terraform Plan

Now run with correct values. Replace `yourname` with your actual name — S3 bucket names must be **globally unique** across all of AWS:

```bash
terraform plan -var="environment=dev" -var="state_bucket_name=my-tf-state-day16-yourname"
```

You will see a preview of the 3 resources that will be created, with all tags listed:

```
Terraform will perform the following actions:

  # aws_cloudwatch_metric_alarm.high_cpu will be created
  + resource "aws_cloudwatch_metric_alarm" "high_cpu" {
      + alarm_name  = "my-cluster-high-cpu"
      + tags = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "my-cluster-high-cpu-alarm"
          + "Owner"       = "devops-team"
          + "Project"     = "day16-project"
        }
      ...
    }

  # aws_s3_bucket.state will be created
  + resource "aws_s3_bucket" "state" {
      + bucket = "my-tf-state-day16-yourname"
      + tags = {
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Name"        = "my-cluster-state-bucket"
          ...
        }
    }

  # aws_sns_topic.alerts will be created
  + resource "aws_sns_topic" "alerts" {
      + name = "my-cluster-alerts"
      ...
    }

Plan: 3 to add, 0 to change, 0 to destroy.
```

---

### Step 6 — Apply to AWS

Deploy the real resources to your AWS account:

```bash
terraform apply -var="environment=dev" -var="state_bucket_name=my-tf-state-day16-yourname"
```

When prompted, type `yes`:

```
Do you want to perform these actions?
  Enter a value: yes
```

📸 **Screenshot — Apply complete:**

![Apply Complete](day16-assets/screenshot-07-apply-complete.jpg)

> `Apply complete! Resources: 3 added, 0 changed, 0 destroyed.` — All three resources are live in AWS `eu-west-1`. The outputs show the SNS topic ARN and the S3 bucket name.

> **🧹 Clean Up:** To avoid AWS charges after the lab, destroy the resources:
> ```bash
> # First, comment out the lifecycle prevent_destroy block in main.tf, then:
> terraform destroy -var="environment=dev" -var="state_bucket_name=my-tf-state-day16-yourname"
> ```

---

## 💡 Key Concepts Explained

### 1. Common Tagging with `locals`

In real companies, every AWS resource **must** be tagged. Tags are used by the finance team to track costs per project, by the ops team to filter resources, and by automation tools to identify and manage infrastructure.

**The pattern:**

```hcl
# Define once in locals.tf
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    Owner       = var.team_name
  }
}

# Apply everywhere using merge()
resource "aws_s3_bucket" "example" {
  tags = merge(local.common_tags, {
    Name = "my-specific-bucket-name"   # resource-specific tag added here
  })
}
```

`merge()` combines the common tags with any resource-specific tags. If there is a conflict, the resource-specific tag wins.

---

### 2. Lifecycle Rules

Lifecycle rules control what Terraform can and cannot do to a resource.

| Rule | What It Does | When to Use |
|---|---|---|
| `prevent_destroy = true` | Blocks `terraform destroy` on this resource | Databases, S3 state buckets, critical resources |
| `create_before_destroy = true` | Creates the replacement before deleting the old one | EC2 instances, load balancers — avoids downtime |
| `ignore_changes = [...]` | Ignores drift on specified attributes | When other tools also manage the resource |

**Example — protecting your state bucket:**

```hcl
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}
```

If someone runs `terraform destroy`, Terraform will refuse:

```
Error: Instance cannot be destroyed
  Resource aws_s3_bucket.state has lifecycle.prevent_destroy set
```

---

### 3. Input Validation

Validation rules run **before** Terraform touches any resources. They act as a safety gate at the entry point of your configuration.

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}
```

**Why this matters in a team:**
- Without validation: a developer sets `environment = "prod"` (typo) → tags are wrong → cost tracking breaks → hard to debug
- With validation: Terraform immediately rejects `"prod"` with a clear error message before anything is created

---

### 4. CloudWatch Alarms & SNS

CloudWatch monitors your AWS resources. When a metric crosses a threshold, it fires an alarm action — in this case, publishing a message to an SNS topic.

```
EC2 Instance → CloudWatch (monitors CPU) → Alarm fires at 80% → SNS Topic → (email/Slack/PagerDuty)
```

```hcl
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2          # Must breach threshold 2 times in a row
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120        # Check every 120 seconds
  statistic           = "Average"
  threshold           = 80         # Alert when CPU > 80%

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

---

## 🔄 Before vs After Refactors

These three changes represent the core shift from "it works" code to production-grade code.

### Refactor 1 — Tagging

| | Code |
|---|---|
| **Before** | `tags = { Name = "instance" }` |
| **After** | `tags = merge(local.common_tags, { Name = "${var.cluster_name}-instance" })` |

**Why:** Consistent tags across every resource. One change in `locals.tf` propagates everywhere. Finance can now track costs per environment and per project automatically.

---

### Refactor 2 — Lifecycle Protection

| | Code |
|---|---|
| **Before** | `resource "aws_db_instance" "db" { }` |
| **After** | `resource "aws_db_instance" "db" { lifecycle { prevent_destroy = true } }` |

**Why:** Without this, `terraform destroy` can permanently delete a production database. With it, Terraform refuses and shows an explicit error — protecting you from accidental data loss.

---

### Refactor 3 — Input Validation

| | Code |
|---|---|
| **Before** | `variable "environment" { type = string }` |
| **After** | `variable "environment" { validation { condition = contains([...], var.environment) } }` |

**Why:** Without validation, typos like `"prod"` or `"PROD"` silently pass through. With validation, Terraform catches the mistake immediately with a clear, human-readable error.

---

## ✅ Production Checklist

This is the checklist used to audit the code at the end of the lab:

### Code Structure
- [x] No hardcoded values — all values come from `variables.tf`
- [x] `locals` used for shared values
- [x] Inputs are well-defined with descriptions
- [x] Outputs exist for key values

### Reliability
- [x] `prevent_destroy` enabled on the S3 state bucket
- [x] Unique resource naming using `var.cluster_name`
- [ ] `create_before_destroy` — add to EC2/ASG resources when needed
- [ ] ASG uses ELB health check — not applicable in this lab

### Security
- [x] No secrets hardcoded anywhere in the code
- [x] Remote state S3 bucket provisioned
- [ ] `sensitive = true` on secret variables — add when secrets are used
- [ ] IAM least privilege — ensure your AWS credentials are scoped

### Observability
- [x] Tags on ALL resources using `merge(local.common_tags, {...})`
- [x] CloudWatch alarm created for high CPU
- [x] SNS topic created for alert routing

### Maintainability
- [x] AWS provider pinned to `~> 5.0`
- [x] Region set to `eu-west-1`
- [ ] README exists — ✅ you are reading it!
- [ ] `.gitignore` — add `**/.terraform` and `*.tfstate` before pushing to GitHub

---

## 📝 Lessons Learned

1. **Git Bash on Windows does not support `\` line continuation** — always write multi-variable Terraform commands on a single line.

2. **S3 bucket names must be globally unique** — always append your name or a unique suffix (e.g., `my-tf-state-day16-gitau`).

3. **`prevent_destroy` protects you from yourself** — when you want to destroy the bucket after the lab, you must comment out that lifecycle block first, then run destroy.

4. **Validation errors are good news** — when the validation test shows a red error, that means your guard rails are working exactly as intended.

5. **`merge()` is more powerful than it looks** — it lets you layer tags: common tags from `locals` + resource-specific tags from the resource block, with resource-specific tags always winning on conflict.

---

## 📚 Resources

- [Terraform Lifecycle Meta-Arguments](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [Terraform Input Validation](https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules)
- [AWS CloudWatch Metric Alarms](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm)
- [AWS SNS Topics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic)
- [Terraform locals](https://developer.hashicorp.com/terraform/language/values/locals)

---

## 🔗 Part of the 30-Day Terraform Challenge

| Day | Topic |
|---|---|
| Day 12 | Zero-Downtime Deployments (`create_before_destroy`, Blue/Green) |
| Day 13 | Sensitive Data with AWS Secrets Manager + Remote State |
| Day 14 | Multi-Region AWS Deployments |
| Day 15 | EKS Cluster + Kubernetes + Docker Provider |
| **Day 16** | **Production-Grade Infrastructure ← You are here** |
| Day 21 | CI/CD with Terraform Cloud + GitHub Actions |

---

<div align="center">

**Author:** Kongeso Emmanuel  
**Region:** `eu-west-1` (Ireland)  
**Challenge:** 30-Day Terraform Challenge  
**Tool:** Terraform + AWS  

⭐ *If this helped you, consider starring the repo!*

</div>
