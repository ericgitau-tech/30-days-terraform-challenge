# 🌍 Day 14 — Getting Started with Terraform Providers & Multi-Region Deployments

<div align="center">

![Terraform](https://img.shields.io/badge/Terraform-v1.0%2B-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-S3-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![Provider](https://img.shields.io/badge/Provider-hashicorp%2Faws%20~%3E%205.0-blue?style=for-the-badge)
![Regions](https://img.shields.io/badge/Regions-eu--west--1%20%7C%20eu--west--2-green?style=for-the-badge)
![Status](https://img.shields.io/badge/Lab-Completed%20✅-success?style=for-the-badge)

**Deploying multi-region AWS infrastructure using Terraform provider aliases**

*Part of my 30-Day Terraform Challenge — Day 14*

</div>

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Learning Objectives](#-learning-objectives)
- [Prerequisites](#-prerequisites)
- [Project Structure](#-project-structure)
- [What is a Terraform Provider?](#-what-is-a-terraform-provider)
- [Step-by-Step Implementation](#-step-by-step-implementation)
  - [Step 1 — Create Project Structure](#step-1--create-project-structure)
  - [Step 2 — Configure Providers](#step-2--configure-providers)
  - [Step 3 — Create Multi-Region S3 Buckets](#step-3--create-multi-region-s3-buckets)
  - [Step 4 — Initialize Terraform](#step-4--initialize-terraform)
  - [Step 5 — Plan the Deployment](#step-5--plan-the-deployment)
  - [Step 6 — Apply and Deploy](#step-6--apply-and-deploy)
  - [Step 7 — Verify in AWS Console](#step-7--verify-in-aws-console)
- [Understanding the Lock File](#-understanding-the-terraform-lock-file)
- [Key Concepts Explained](#-key-concepts-explained)
- [Troubleshooting](#-troubleshooting)
- [Best Practices](#-best-practices)
- [Real-World Applications](#-real-world-applications)
- [Key Learnings](#-key-learnings)
- [Clean Up](#-clean-up)
- [Conclusion](#-conclusion)

---

## 🚀 Overview

In this lab, I deployed **two Amazon S3 buckets simultaneously across two different AWS regions** using a single Terraform configuration. The key technique is **provider aliases** — a powerful Terraform feature that lets you manage infrastructure across multiple regions or accounts from one codebase.

| Item | Details |
|------|---------|
| **Primary Region** | `eu-west-1` — Europe (Ireland) |
| **Secondary Region** | `eu-west-2` — Europe (London) |
| **AWS Service** | Amazon S3 (Simple Storage Service) |
| **Terraform Provider** | `hashicorp/aws ~> 5.0` |
| **Terraform Version** | `>= 1.0.0` |
| **Lab Day** | Day 14 of 30 |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    terraform apply                               │
│                         │                                        │
│           ┌─────────────┴──────────────┐                        │
│           ▼                            ▼                         │
│  ┌─────────────────┐        ┌─────────────────┐                 │
│  │  DEFAULT         │        │  ALIAS           │                │
│  │  provider "aws"  │        │  provider "aws"  │                │
│  │  region=eu-west-1│        │  alias=eu_west_2 │                │
│  └────────┬────────┘        │  region=eu-west-2│                │
│           │                  └────────┬────────┘                │
│           ▼                           ▼                          │
│  ┌─────────────────┐        ┌─────────────────┐                 │
│  │  🪣 S3 Bucket   │        │  🪣 S3 Bucket   │                 │
│  │  PRIMARY        │        │  REPLICA        │                 │
│  │  eu-west-1      │        │  eu-west-2      │                 │
│  │  (Ireland)      │        │  (London)       │                 │
│  └─────────────────┘        └─────────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Learning Objectives

By completing this lab, you will:

- ✅ Understand what a **Terraform provider** is and how it communicates with AWS
- ✅ Learn how to **install and version** providers using `required_providers`
- ✅ Use **provider aliases** to manage multiple AWS regions from one config
- ✅ Deploy real infrastructure across **two AWS regions** simultaneously
- ✅ Understand the **`.terraform.lock.hcl`** file and why it matters for team consistency

---

## ✅ Prerequisites

Before starting this lab, make sure you have the following:

### AWS Setup
- An **AWS Account** (Free Tier is sufficient)
- An **IAM User** with the following permissions:
  - `AmazonS3FullAccess`
  - `IAMFullAccess`

### Software
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0.0
- [AWS CLI](https://aws.amazon.com/cli/) configured
- [Visual Studio Code](https://code.visualstudio.com/) with the HashiCorp Terraform extension

### Verify installations

```bash
# Check Terraform
terraform -version

# Check AWS CLI
aws --version

# Configure AWS credentials
aws configure
```

When running `aws configure`, enter your credentials like this:

```
AWS Access Key ID [None]: YOUR_ACCESS_KEY
AWS Secret Access Key [None]: YOUR_SECRET_KEY
Default region name [None]: eu-west-1
Default output format [None]: json
```

---

## 📁 Project Structure

```
terraform-multi-region/
│
├── providers.tf          # Provider configuration & version pinning
├── main.tf               # S3 bucket resources (multi-region)
├── variables.tf          # Input variables (placeholder, good practice)
│
├── .terraform/           # Auto-generated — provider binaries (do not edit)
├── .terraform.lock.hcl   # Auto-generated — provider version lock (COMMIT THIS)
└── terraform.tfstate     # Auto-generated — state file (do not edit manually)
```

> 💡 **Note:** The `.terraform/` folder and `terraform.tfstate` should be added to `.gitignore`. The `.terraform.lock.hcl` file should **always** be committed to Git.

---

## 🔌 What is a Terraform Provider?

A **Terraform provider** is a plugin that acts as the bridge between your Terraform code and a cloud platform's API.

```
Your .tf files  →  Terraform Provider  →  AWS API  →  Real Infrastructure
```

Think of it like a **translator**:
- You write HCL (HashiCorp Configuration Language) in your `.tf` files
- The provider translates that into AWS API calls
- AWS creates the actual resources

Without a provider, Terraform has no way to talk to AWS (or Azure, GCP, etc.).

### Provider Registry

All official providers live at [registry.terraform.io](https://registry.terraform.io). The AWS provider is published by HashiCorp themselves:

```
registry.terraform.io/hashicorp/aws
```

### What is a Provider Alias?

When you need to use the **same provider** (e.g., AWS) but in **multiple configurations** (e.g., different regions), you use an **alias**:

```hcl
# Default provider — used automatically
provider "aws" {
  region = "eu-west-1"
}

# Aliased provider — must be referenced explicitly with provider = aws.name
provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"
}
```

---

## 🛠️ Step-by-Step Implementation

---

### Step 1 — Create Project Structure

Open your terminal and run:

```bash
cd Downloads/
mkdir terraform-multi-region
cd terraform-multi-region
touch main.tf providers.tf variables.tf
```

**What each command does:**
- `mkdir` — creates a new project folder
- `cd` — moves into that folder
- `touch` — creates three empty files you will fill in the next steps

**Screenshot 1 — Terminal after creating the project folder:**

![Screenshot 1 - Project Structure](images/screenshot1-project-structure.png)

> The terminal confirms the three files (`main.tf`, `providers.tf`, `variables.tf`) were created successfully inside the `terraform-multi-region` directory.

---

### Step 2 — Configure Providers

Open `providers.tf` in VS Code and add the following:

```hcl
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider — Primary region (Ireland)
provider "aws" {
  region = "eu-west-1"
}

# Aliased provider — Secondary region (London)
provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"
}
```

**Line-by-line breakdown:**

| Code | What It Does |
|------|-------------|
| `required_version = ">= 1.0.0"` | Ensures Terraform itself is at least version 1.0 |
| `source = "hashicorp/aws"` | Points to the official AWS provider on the registry |
| `version = "~> 5.0"` | Allows any `5.x` version but **never** jumps to `6.0` automatically |
| First `provider "aws"` block | The **default** provider — used for all resources unless specified otherwise |
| `alias = "eu_west_2"` | Gives the second provider a nickname so resources can reference it |
| `region = "eu-west-2"` | Routes all API calls through the London region |

> **Why pin versions with `~> 5.0`?**
> AWS releases provider updates frequently. Without pinning, a `terraform init` run next month could install version `6.0` with breaking changes, and your infrastructure code could silently stop working. Version pinning keeps your team on a known-good version.

---

### Step 3 — Create Multi-Region S3 Buckets

Open `main.tf` in VS Code and add the following:

```hcl
# Primary bucket (eu-west-1 - Ireland)
resource "aws_s3_bucket" "primary" {
  bucket = "my-primary-bucket-euwest1-yourname-2024"
}

# Replica bucket (eu-west-2 - London)
resource "aws_s3_bucket" "replica" {
  provider = aws.eu_west_2
  bucket   = "my-replica-bucket-euwest2-yourname-2024"
}
```

> ⚠️ **Important:** Replace `yourname` with your actual name or initials. S3 bucket names must be **globally unique** across all AWS accounts worldwide. If the name is taken, the apply will fail with a `BucketAlreadyExists` error.

**How Terraform decides which region to use:**

```
aws_s3_bucket.primary  →  no provider = line  →  uses DEFAULT  →  eu-west-1 (Ireland)
aws_s3_bucket.replica  →  provider = aws.eu_west_2  →  uses ALIAS  →  eu-west-2 (London)
```

---

### Step 4 — Initialize Terraform

```bash
terraform init
```

This command:
1. Reads your `providers.tf` file
2. Downloads the `hashicorp/aws` provider plugin from the registry
3. Creates a `.terraform/` folder containing the provider binary
4. Creates a `.terraform.lock.hcl` file locking the exact version installed

**Screenshot 2 — VS Code showing `providers.tf` code and `terraform init` running in the terminal:**

![Screenshot 2 - Providers Config and Terraform Init](images/screenshot2-providers-init.png)

> The VS Code editor shows the complete `providers.tf` configuration with both the default (eu-west-1) and aliased (eu-west-2) providers. The integrated terminal below shows `terraform init` successfully downloading `hashicorp/aws v5.100.0`. Notice in the left sidebar that the `.terraform` folder and `terraform.lock.hcl` file have appeared after initialization.

---

### Step 5 — Plan the Deployment

```bash
terraform plan
```

This is a **dry run** — it shows exactly what Terraform will create without making any real changes. Think of it as a preview before you commit.

**Screenshot 3 — `main.tf` code and `terraform plan` output:**

![Screenshot 3 - Main.tf and Terraform Plan](images/screenshot3-main-plan.png)

> The editor shows the complete `main.tf` with both bucket resources — the primary bucket using the default provider and the replica bucket explicitly referencing `aws.eu_west_2`. The terminal output confirms that `aws_s3_bucket.primary` will be created in `eu-west-1` and `aws_s3_bucket.replica` will be created in `eu-west-2`. The plan ends with **"Plan: 2 to add, 0 to change, 0 to destroy"**.

**Reading the plan output:**

```
# aws_s3_bucket.primary will be created      ← Ireland bucket
  + resource "aws_s3_bucket" "primary" {
      + bucket = "my-primary-bucket-euwest1-..."

# aws_s3_bucket.replica will be created      ← London bucket
  + resource "aws_s3_bucket" "replica" {
      + bucket = "my-replica-bucket-euwest2-..."

Plan: 2 to add, 0 to change, 0 to destroy.
```

The `+` symbol means "will be created". Always review the plan carefully before applying.

---

### Step 6 — Apply and Deploy

```bash
terraform apply
```

Terraform will display the plan one more time and ask for confirmation:

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only "yes" will be accepted to approve.

  Enter a value: yes
```

Type `yes` and press Enter. After a few seconds you should see:

```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

---

### Step 7 — Verify in AWS Console

1. Go to [https://s3.console.aws.amazon.com/s3](https://s3.console.aws.amazon.com/s3)
2. Click **"General purpose buckets"** in the left sidebar
3. Select **"All AWS Regions"** in the filter dropdown
4. You should see both buckets with their respective regions

**Screenshot 4 — AWS S3 Console confirming both buckets deployed in separate regions:**

![Screenshot 4 - AWS Console showing both buckets](images/screenshot4-aws-console.png)

> This is the key proof of the entire lab. The AWS S3 console with "All AWS Regions" selected shows exactly two buckets: **`my-primary-bucket-euwest1`** in *Europe (Ireland) eu-west-1* and **`my-replica-bucket-euwest2`** in *Europe (London) eu-west-2*. Both were created at the exact same time (`April 1, 2026, 09:00:15`) from a single `terraform apply` command — demonstrating the power of provider aliases. This is multi-region Infrastructure as Code in action.

---

## 🔒 Understanding the Terraform Lock File

After running `terraform init`, a file called `.terraform.lock.hcl` is automatically created. Open it in VS Code — it will look like this:

```hcl
provider "registry.terraform.io/hashicorp/aws" {
  version     = "5.100.0"
  constraints = "~> 5.0"
  hashes = [
    "h1:abc123defghijklmnopqrstuvwxyz...",
  ]
}
```

### What each field means:

| Field | Meaning |
|-------|---------|
| `version` | The **exact** version of the provider that was installed |
| `constraints` | The version rule you specified in `providers.tf` |
| `hashes` | A cryptographic fingerprint to verify the provider hasn't been tampered with |

### Should you commit this file to Git? YES ✅

```bash
# Add to Git — always
git add .terraform.lock.hcl

# Add to .gitignore — never commit these
echo ".terraform/" >> .gitignore
echo "terraform.tfstate" >> .gitignore
echo "terraform.tfstate.backup" >> .gitignore
```

**Why committing the lock file matters:**

Without it, imagine this scenario:
- You run `terraform init` today → installs `aws 5.20.0`
- Your teammate runs `terraform init` next month → installs `aws 5.99.0`
- The provider has breaking changes in `5.99.0`
- Your teammate's `terraform apply` now behaves differently from yours

With the lock file committed, everyone installs `5.20.0` — guaranteed.

---

## 📚 Key Concepts Explained

### Provider vs Resource

```hcl
# PROVIDER — how Terraform connects to AWS (what and where)
provider "aws" {
  region = "eu-west-1"
}

# RESOURCE — what you want to create
resource "aws_s3_bucket" "primary" {
  bucket = "my-bucket-name"
}
```

### Default vs Aliased Provider

```hcl
# DEFAULT — used automatically by all resources
provider "aws" {
  region = "eu-west-1"     # ← Ireland
}

# ALIASED — must be called explicitly with provider = aws.alias_name
provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"     # ← London
}

# Using the default (no provider = line needed)
resource "aws_s3_bucket" "primary" {
  bucket = "my-primary-bucket"
  # Terraform automatically uses the default provider (eu-west-1)
}

# Using the alias (must specify explicitly)
resource "aws_s3_bucket" "replica" {
  provider = aws.eu_west_2   # ← tells Terraform to use London
  bucket   = "my-replica-bucket"
}
```

### Version Pinning Syntax

```hcl
version = "5.20.0"    # Exact version only — very strict
version = ">= 5.0.0"  # Any version 5.0.0 or higher — too loose
version = "~> 5.0"    # Any 5.x version — RECOMMENDED (safe middle ground)
version = "~> 5.20.0" # Any 5.20.x version — even more specific
```

---

## 🔥 Troubleshooting

### ❌ `BucketAlreadyExists`

```
Error: creating Amazon S3 (Simple Storage) Bucket: BucketAlreadyOwnedByYou
```

**Fix:** S3 bucket names are globally unique across ALL AWS accounts. Change the bucket name to something more specific:

```hcl
bucket = "my-primary-bucket-euwest1-johnsmith-20241201"
#                                    ^^^^^^^^^ ^^^^^^^^^
#                                    your name   date
```

---

### ❌ Provider alias not found

```
Error: Invalid provider configuration reference
```

**Fix:** The alias name in your `resource` block must exactly match the alias in your `provider` block:

```hcl
# In providers.tf
provider "aws" {
  alias = "eu_west_2"   # ← defined here
}

# In main.tf
resource "aws_s3_bucket" "replica" {
  provider = aws.eu_west_2  # ← must match exactly (case-sensitive)
}
```

---

### ❌ No valid credentials / AuthFailure

```
Error: No valid credential sources found
```

**Fix:** Re-run `aws configure` and ensure your credentials are correct:

```bash
aws configure
# Then verify with:
aws sts get-caller-identity
```

---

### ❌ Region mismatch / resource in wrong region

**Fix:** Always double-check the `region =` value in each provider block. A common mistake is copy-pasting the provider block and forgetting to change the region:

```hcl
# ✅ Correct
provider "aws" {
  region = "eu-west-1"    # Ireland
}
provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"    # London ← make sure this is different
}
```

---

### ❌ Error acquiring the state lock

```
Error: Error acquiring the state lock
```

**Fix:** Another `terraform apply` may be running. If you are certain no other process is active:

```bash
terraform force-unlock <lock-id>
```

---

## ✨ Best Practices

```hcl
# ✅ DO — always pin provider versions
version = "~> 5.0"

# ✅ DO — commit the lock file
git add .terraform.lock.hcl

# ✅ DO — use descriptive alias names
alias = "eu_west_2"       # clear
alias = "us_east_prod"    # even better — region + environment

# ✅ DO — run plan before every apply
terraform plan
terraform apply

# ❌ DON'T — hardcode AWS credentials in .tf files
provider "aws" {
  access_key = "AKIAIOSFODNN7EXAMPLE"  # NEVER do this — use IAM roles
  secret_key = "wJalrXUtnFEMI..."      # NEVER do this — use env variables
}

# ❌ DON'T — commit the .terraform folder or state file
echo ".terraform/" >> .gitignore
echo "*.tfstate" >> .gitignore
```

---

## 🌍 Real-World Applications

The multi-region provider pattern you learned in this lab is used across the industry:

| Use Case | How This Pattern Applies |
|----------|--------------------------|
| **Multi-Region Disaster Recovery** | Deploy identical infrastructure in two regions — if Ireland goes down, London takes over automatically |
| **Global Applications** | Companies like Netflix serve users from the nearest region to reduce latency |
| **Data Residency / GDPR** | Keep EU user data in EU regions (`eu-west-1`, `eu-central-1`) to comply with regulations |
| **Multi-Account Enterprises** | Use aliases not just for regions but for different AWS accounts (dev, staging, prod) |
| **Blue-Green Deployments** | Run two identical environments in parallel during deployments for zero-downtime releases |

---

## 🧠 Key Learnings

| Concept | Summary |
|---------|---------|
| **Terraform Provider** | A plugin that translates your HCL code into AWS API calls |
| **`required_providers`** | Tells Terraform which provider to download and from where |
| **Version Pinning (`~> 5.0`)** | Locks to major version 5 to prevent breaking changes |
| **Provider Alias** | A nickname that lets you use the same provider in multiple configurations |
| **`provider = aws.eu_west_2`** | Directs a specific resource to use the aliased (London) provider |
| **`.terraform.lock.hcl`** | Records the exact installed version — always commit this file |
| **`terraform init`** | Downloads providers — always run first in a new project |
| **`terraform plan`** | Dry run — see changes before they happen |
| **`terraform apply`** | Executes the plan and creates real infrastructure on AWS |
| **`terraform destroy`** | Removes all resources managed by this configuration |

---

## 🧹 Clean Up

> ⚠️ **Important:** Always clean up your lab resources to avoid unexpected AWS charges.

```bash
terraform destroy
```

Terraform will show you the resources it plans to remove and ask for confirmation:

```
Plan: 0 to add, 0 to change, 2 to destroy.

Do you really want to destroy all resources?
  Enter a value: yes

Destroy complete! Resources: 2 destroyed.
```

Both S3 buckets (Ireland and London) will be permanently deleted.

---

## ✅ Conclusion

In this lab, I successfully:

- 🟢 Configured **two AWS providers** — a default (eu-west-1) and an aliased (eu-west-2) — in a single `providers.tf` file
- 🟢 Deployed **two S3 buckets simultaneously across two different European regions** using a single `terraform apply` command
- 🟢 Understood **provider version pinning** and how `~> 5.0` protects against breaking changes
- 🟢 Verified both buckets live in the **AWS Console** under "All AWS Regions"
- 🟢 Learned why the **`.terraform.lock.hcl`** file must always be committed to Git

The provider alias pattern is the foundation of enterprise-grade multi-region and multi-account Infrastructure as Code. Once you master this, you can manage an entire global cloud environment from a single Terraform configuration.

---

## 📌 Next Steps

- **Day 15** → Passing providers into Terraform modules
- Explore [S3 Cross-Region Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html) using the same two buckets
- Try expanding this lab to use a **third region** with a second alias

---

<div align="center">

**Made with ❤️ by Kongeso Emmanuel**

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=for-the-badge&logo=linkedin)](https://linkedin.com)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-181717?style=for-the-badge&logo=github)](https://github.com)

`#Terraform` `#DevOps` `#AWS` `#InfrastructureAsCode` `#CloudComputing` `#30DayTerraformChallenge`

</div>
