<!-- BANNER -->
<p align="center">
  <img src="images/banner.png" alt="Day 15 Banner" width="100%"/>
</p>

<!-- BADGES -->
<p align="center">
  <img src="https://img.shields.io/badge/Terraform-v1.14.7-7B42F6?style=for-the-badge&logo=terraform&logoColor=white"/>
  <img src="https://img.shields.io/badge/AWS-EKS%20v1.31-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white"/>
  <img src="https://img.shields.io/badge/Kubernetes-v1.34.1-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker-v28.5.1-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Region-eu--west--1-232F3E?style=for-the-badge&logo=amazonaws&logoColor=white"/>
  <img src="https://img.shields.io/badge/Status-Completed-3FB950?style=for-the-badge"/>
</p>
 
---

# 🚀 Day 15 — Advanced Providers, Docker & Kubernetes on EKS

> **30-Day Terraform Challenge** | Working with Multiple Terraform Providers in Production

This project demonstrates how to build **advanced multi-provider Terraform architectures** that mirror real-world DevOps workflows. Instead of a single-provider setup, this lab goes further — deploying across multiple AWS regions, managing Docker containers, and provisioning a full production-grade Kubernetes cluster on Amazon EKS — **all from Terraform, with zero manual AWS console clicks.**

---

## 📋 Table of Contents

- [Project Overview](#-project-overview)
- [Architecture](#-architecture)
- [Folder Structure](#-folder-structure)
- [Prerequisites](#-prerequisites)
- [Part 1 — Multi-Region S3 with Provider Modules](#-part-1--multi-region-s3-with-provider-modules)
- [Part 2 — Docker NGINX Deployment](#-part-2--docker-nginx-deployment-local)
- [Part 3 — Amazon EKS Cluster](#-part-3--amazon-eks-cluster-deployment)
- [Part 4 — Kubernetes NGINX Deployment](#-part-4--kubernetes-nginx-deployment)
- [Challenges & Fixes](#-challenges--fixes)
- [Key Learnings](#-key-learnings)
- [Cleanup](#-cleanup)
- [Final Checklist](#-final-checklist)

---

## 🎯 Project Overview

| Item | Detail |
|------|--------|
| **Challenge Day** | Day 15 of 30 |
| **Topic** | Advanced Providers — Part 2 |
| **Primary Region** | `eu-west-1` (Ireland) |
| **Terraform Version** | v1.14.7 |
| **Total Resources Deployed** | 55 AWS resources |
| **Kubernetes Version** | 1.31 (eks-f69f56f) |
| **Node Type** | t3.small (2 nodes) |
| **Providers Used** | AWS · Docker · Kubernetes |

### What Was Built

| Part | What | Where |
|------|------|-------|
| **Part 1** | Multi-region S3 buckets via reusable modules | eu-west-1 + us-east-1 |
| **Part 2** | Docker NGINX container managed by Terraform | Local (localhost:8080) |
| **Part 3** | Full Amazon EKS cluster + VPC + Node Group | eu-west-1 |
| **Part 4** | Kubernetes NGINX deployment (2 pods) | EKS cluster |

---

## 🏗️ Architecture

<p align="center">
  <img src="images/architecture.png" alt="Architecture Diagram" width="100%"/>
</p>

The architecture spans three distinct infrastructure layers managed by Terraform simultaneously:

1. **AWS Layer** — VPC, subnets, NAT Gateway, EKS control plane, EC2 worker nodes, and S3 buckets across two regions
2. **Container Layer** — Docker provider managing a local NGINX container on the developer machine
3. **Kubernetes Layer** — Kubernetes provider connecting to EKS and deploying application workloads

> **Key design principle:** The root module controls all providers. Modules receive providers passed down from the root — making every module reusable across regions and environments without code changes.

---

## 📁 Folder Structure

```
day15/
├── modules/
│   └── multi-region-app/
│       ├── main.tf          # S3 bucket resources (uses configuration_aliases)
│       └── variables.tf     # app_name and suffix variables
├── part1-multi-region/
│   └── main.tf              # Root config — defines aliased providers + calls module
├── part2-docker/
│   └── main.tf              # Docker provider + NGINX container
└── part3-eks/
    ├── vpc.tf               # VPC, subnets, NAT Gateway, route tables
    ├── eks.tf               # EKS cluster + managed node group
    └── k8s.tf               # Kubernetes provider + NGINX deployment
```

---

## ✅ Prerequisites

Before starting, confirm all tools are installed:

```bash
terraform -v           # Terraform v1.14.7+
aws --version          # AWS CLI v2
aws sts get-caller-identity   # Confirm IAM credentials are configured
docker --version       # Docker Desktop running
kubectl version --client      # kubectl v1.34+
```

<p align="center">
  <img src="images/screenshot_tools_check.jpg" alt="Tools verification" width="90%"/>
</p>

> All tools confirmed: Terraform, AWS CLI (authenticated as `gitauAdmin`), Docker Desktop, and kubectl.

---

## 🌍 Part 1 — Multi-Region S3 with Provider Modules

### Concept Explained

This is one of the most important Terraform patterns you will use in real production work. The challenge is: **how do you make a module deploy to different regions without hardcoding the region inside the module?**

The answer is **provider passing**:

| Concept | What It Does |
|---------|-------------|
| `configuration_aliases` | Declared inside the module. Tells Terraform the module expects multiple provider instances (e.g. `aws.primary` and `aws.replica`) |
| Provider aliases | Allow two instances of the same provider to coexist — each pointing to a different AWS region |
| `providers = {}` | Used in the module call to map root-level providers to the names the module expects |
| Root controls scope | Modules never define providers internally — they receive them. This is what makes modules reusable |

### Step 1 — Create the Folder

```bash
mkdir -p ~/day15/modules/multi-region-app
mkdir -p ~/day15/part1-multi-region
```

### Step 2 — Module Code

**`modules/multi-region-app/main.tf`**

```hcl
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.primary, aws.replica]
    }
  }
}

resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${var.app_name}-primary-${var.suffix}"
}

resource "aws_s3_bucket" "replica" {
  provider = aws.replica
  bucket   = "${var.app_name}-replica-${var.suffix}"
}
```

**`modules/multi-region-app/variables.tf`**

```hcl
variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "suffix" {
  description = "Unique suffix to make bucket names globally unique"
  type        = string
}
```

### Step 3 — Root Configuration

**`part1-multi-region/main.tf`**

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary provider — Ireland (where we operate from)
provider "aws" {
  alias  = "primary"
  region = "eu-west-1"
}

# Replica provider — US East (for redundancy)
provider "aws" {
  alias  = "replica"
  region = "us-east-1"
}

module "multi_region_app" {
  source   = "../modules/multi-region-app"
  app_name = "day15app"
  suffix   = "382773"   # First 6 digits of AWS account — ensures global uniqueness

  providers = {
    aws.primary = aws.primary
    aws.replica = aws.replica
  }
}
```

> 💡 **Why the suffix?** S3 bucket names must be globally unique across every AWS account in the world. Using your account number as a suffix prevents naming collisions.

### Step 4 — Deploy

```bash
cd ~/day15/part1-multi-region
terraform init
terraform plan
terraform apply
```

### Result

<p align="center">
  <img src="images/screenshot_part1_vscode.jpg" alt="Part 1 VS Code" width="90%"/>
</p>

> VS Code showing the provider aliases and module configuration for Part 1.

<p align="center">
  <img src="images/screenshot_s3_part1_terminal.jpg" alt="S3 Buckets created" width="90%"/>
</p>

> Two S3 buckets created: `day15app-primary-382773` in **eu-west-1** and `day15app-replica-382773` in **us-east-1**.

---

## 🐳 Part 2 — Docker NGINX Deployment (Local)

### Concept Explained

Instead of running `docker run nginx`, Terraform manages the entire Docker lifecycle — pulling the image, creating the container, and mapping ports. The container is tracked in state, version-controlled, and destroyed cleanly with `terraform destroy`.

This is foundational before moving to Kubernetes: first understand containers locally, then orchestrate them at scale.

### Step 1 — Create the Folder

```bash
mkdir -p ~/day15/part2-docker
```

### Step 2 — Terraform Code

**`part2-docker/main.tf`**

```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Pull the NGINX image from Docker Hub
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false
}

# Run the container and map port 8080 → 80
resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "terraform-nginx"

  ports {
    internal = 80
    external = 8080
  }
}
```

### Step 3 — Deploy

```bash
cd ~/day15/part2-docker
terraform init
terraform apply
```

### Step 4 — Verify

```bash
# Check the container is running
docker ps
```

Then open your browser at `http://localhost:8080`

### Result

<p align="center">
  <img src="images/screenshot_docker_vscode.jpg" alt="Docker VS Code" width="90%"/>
</p>

> Docker provider code in VS Code and `terraform apply` output showing the container being created.

<p align="center">
  <img src="images/screenshot_docker_ps.jpg" alt="docker ps output" width="90%"/>
</p>

> `docker ps` confirming `terraform-nginx` container is running with port `0.0.0.0:8080->80/tcp`.

<p align="center">
  <img src="images/screenshot_nginx_browser.jpg" alt="NGINX browser" width="90%"/>
</p>

> NGINX Welcome Page confirmed at `http://localhost:8080` — container is live.

---

## ☸️ Part 3 — Amazon EKS Cluster Deployment

> ⚠️ **Cost Warning:** EKS creates billable AWS resources. Estimated cost: **~$0.50–$1.00 for a 1–2 hour lab session**. Always run `terraform destroy` when finished.

### What Gets Created (55 Resources)

| Resource | Purpose | Cost |
|----------|---------|------|
| EKS Control Plane | Managed Kubernetes API server | ~$0.10/hr |
| 2x EC2 t3.small | Worker nodes that run your pods | ~$0.02/hr each |
| NAT Gateway | Lets private nodes reach internet for image pulls | ~$0.045/hr |
| VPC + Subnets | Isolated network for the cluster | Free |
| IAM Roles | Permissions for EKS + nodes | Free |
| Security Groups | Firewall rules | Free |

### Step 1 — Create the Folder

```bash
mkdir -p ~/day15/part3-eks
```

### Step 2 — VPC Configuration

**`part3-eks/vpc.tf`**

```hcl
terraform {
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

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  # Span across 2 availability zones for high availability
  azs             = ["eu-west-1a", "eu-west-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true   # One NAT GW saves cost in dev
  enable_dns_hostnames = true

  # These tags are REQUIRED — EKS uses them to discover which subnets to use
  tags = {
    "kubernetes.io/cluster/terraform-challenge-cluster" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/terraform-challenge-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                   = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/terraform-challenge-cluster" = "shared"
    "kubernetes.io/role/elb"                            = "1"
  }
}
```

### Step 3 — EKS Cluster Configuration

**`part3-eks/eks.tf`**

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "terraform-challenge-cluster"
  cluster_version = "1.31"   # Use 1.31 — 1.29 AMIs no longer available in eu-west-1

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Allow kubectl access from your machine
  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.small"]
    }
  }

  tags = {
    Environment = "dev"
    Project     = "day15"
  }
}
```

### Step 4 — Kubernetes Provider and NGINX Deployment

**`part3-eks/k8s.tf`**

```hcl
# This provider connects Terraform to the EKS cluster dynamically
# No manual kubeconfig editing required
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks", "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region", "eu-west-1"
    ]
  }
}

resource "kubernetes_deployment" "nginx" {
  depends_on = [module.eks]

  metadata {
    name = "nginx-deployment"
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "nginx" }
    }

    template {
      metadata {
        labels = { app = "nginx" }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port  { container_port = 80 }
        }
      }
    }
  }
}
```

> 💡 **How the Kubernetes provider authenticates:** The `exec` block calls `aws eks get-token` to generate a short-lived bearer token using your IAM credentials. This means authentication is tied to your AWS IAM identity — no static passwords or kubeconfig secrets.

### Step 5 — Deploy

```bash
cd ~/day15/part3-eks

# Download all modules and providers (takes ~1 min)
terraform init

# Preview the 55 resources that will be created
terraform plan

# Deploy — takes 10-15 minutes
terraform apply
```

> ⏳ The EKS control plane alone takes **~8 minutes** — this is normal. AWS is provisioning a fully managed Kubernetes API server behind the scenes. Do not cancel.

---

## 🎯 Part 4 — Kubernetes NGINX Deployment Verification

### Step 1 — Authenticate kubectl to the Cluster

After `terraform apply` completes, connect your local `kubectl` to the new cluster:

```bash
aws eks update-kubeconfig \
  --region eu-west-1 \
  --name terraform-challenge-cluster
```

If you hit `Unauthorized` errors, grant your IAM user cluster admin access:

```bash
aws eks create-access-entry \
  --cluster-name terraform-challenge-cluster \
  --principal-arn arn:aws:iam::382773571446:user/gitauAdmin \
  --region eu-west-1

aws eks associate-access-policy \
  --cluster-name terraform-challenge-cluster \
  --principal-arn arn:aws:iam::382773571446:user/gitauAdmin \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region eu-west-1
```

### Step 2 — Verify Cluster Health

```bash
# Both nodes should show STATUS: Ready
kubectl get nodes

# All system pods should show Running
kubectl get pods -A
```

### Step 3 — Deploy NGINX

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
EOF
```

### Step 4 — Verify Pods

```bash
kubectl get pods
kubectl get deployment nginx-deployment
```

Expected output:
```
NAME                               READY   STATUS    RESTARTS   AGE
nginx-deployment-54b9c68f67-ggpr9  1/1     Running   0          15s
nginx-deployment-54b9c68f67-mwfzt  1/1     Running   0          15s
```

### Result

<p align="center">
  <img src="images/screenshot_eks_nodes.jpg" alt="EKS nodes running" width="90%"/>
</p>

> Two EKS worker nodes with `STATUS: Ready` running Kubernetes `v1.31.14-eks-f69f56f`. All system pods (CoreDNS, kube-proxy, aws-node) confirmed healthy.

<p align="center">
  <img src="images/screenshot_nginx_pods.jpg" alt="NGINX pods running" width="90%"/>
</p>

> Two NGINX pods running with `STATUS: Running` and deployment showing `READY 2/2`. Both pods are scheduled across the two worker nodes.

---

## 🐛 Challenges & Fixes

Real issues encountered during this lab — documented for future reference.

### Issue 1 — EKS v1.29 AMI Not Available

```
Error: InvalidParameterException: Requested AMI for this version 1.29 is not supported
```

**Root cause:** AWS periodically deprecates older EKS AMIs in specific regions. Version 1.29 AMIs were no longer available in `eu-west-1` at the time of this lab.

**Fix:** Updated `cluster_version` from `"1.29"` to `"1.31"` in `eks.tf`.

```hcl
# Before
cluster_version = "1.29"

# After
cluster_version = "1.31"
```

---

### Issue 2 — Cannot Upgrade 1.29 → 1.31 Directly

```
Error: Unsupported Kubernetes minor version update from 1.29 to 1.31
```

**Root cause:** EKS only allows upgrading one minor version at a time (1.29 → 1.30 → 1.31). Trying to jump two versions is rejected.

**Fix:** Destroyed the partial cluster and redeployed fresh with version 1.31.

```bash
terraform destroy   # Clean up broken state
terraform apply     # Redeploy fresh with 1.31
```

---

### Issue 3 — kubectl Unauthorized Error

```
error: You must be logged in to the server (the server has asked for the client to provide credentials)
```

**Root cause:** When EKS creates a cluster, only the IAM entity that created it (in this case, the Terraform execution role) has access by default. The `gitauAdmin` IAM user needed to be explicitly added to the cluster access entries.

**Fix:** Used the EKS Access Entries API (introduced in EKS 1.30) to grant cluster admin access to the IAM user.

```bash
aws eks create-access-entry --cluster-name terraform-challenge-cluster \
  --principal-arn arn:aws:iam::382773571446:user/gitauAdmin --region eu-west-1

aws eks associate-access-policy --cluster-name terraform-challenge-cluster \
  --principal-arn arn:aws:iam::382773571446:user/gitauAdmin \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster --region eu-west-1
```

---

### Issue 4 — Provider Alias Mismatch

```
Error: Provider configuration not present
```

**Root cause:** The provider names in the module call `providers = {}` block did not exactly match the aliases defined in the root providers.

**Fix:** Provider names must match character-for-character.

```hcl
# Correct — names match exactly
providers = {
  aws.primary = aws.primary
  aws.replica = aws.replica
}
```

---

### Issue 5 — Deprecated kubernetes_deployment Warning

```
Warning: Deprecated Resource — use kubernetes_deployment_v1
```

**Root cause:** The `kubernetes_deployment` resource has been superseded by `kubernetes_deployment_v1` in newer versions of the Kubernetes provider.

**Impact:** This is a warning only — the resource still works and the deployment was successful. In future labs, use `kubernetes_deployment_v1` instead.

---

## 🧠 Key Learnings

### Why Modules Cannot Define Their Own Providers

Modules are designed to be **reusable** across multiple environments, regions, and accounts. If a module hardcoded `region = "eu-west-1"` in its own provider, it would be locked to Ireland. By receiving providers from the root module:

- The same module deploys to `eu-west-1` in dev and `ap-southeast-1` in production
- No changes to the module code — only the root changes
- Teams can safely share modules without them unexpectedly affecting the wrong region

### What `configuration_aliases` Does

When a module needs **multiple instances** of the same provider, it must declare the expected aliases using `configuration_aliases`. Without this:

```hcl
# Without configuration_aliases — Terraform throws an error:
# "Module does not support provider aws.replica"

# With configuration_aliases — Terraform knows to expect both:
configuration_aliases = [aws.primary, aws.replica]
```

### How the Kubernetes Provider Authenticates to EKS

The `exec` block in the Kubernetes provider calls `aws eks get-token` to generate a **short-lived bearer token** (expires in 15 minutes). This means:

- Authentication uses your IAM identity — no passwords or static tokens
- Every `terraform plan` or `kubectl` command gets a fresh token automatically
- IAM permissions control who can access the cluster
- No manual kubeconfig management for the Terraform deployment

### EKS Access Entries vs `aws-auth` ConfigMap

EKS 1.30+ introduced **Access Entries** as the modern way to manage cluster access. The older method was editing the `aws-auth` ConfigMap directly, which was error-prone and could lock you out of your own cluster. Access Entries are managed through the EKS API and are far safer.

---

## 🗑️ Cleanup

> ⚠️ **Do this immediately after the lab to stop AWS charges.**

```bash
# Step 1 — Delete the Kubernetes deployment
kubectl delete deployment nginx-deployment

# Step 2 — Destroy all EKS infrastructure (takes 8-12 min)
cd ~/day15/part3-eks
terraform destroy

# Step 3 — Destroy Docker container
cd ~/day15/part2-docker
terraform destroy -auto-approve

# Step 4 — Destroy S3 buckets
cd ~/day15/part1-multi-region
terraform destroy -auto-approve
```

**Verify everything is gone:**

```bash
aws eks list-clusters --region eu-west-1
# Expected: { "clusters": [] }

aws s3 ls | grep day15
# Expected: (empty)

docker ps
# Expected: (no terraform-nginx container)
```

---

## ✅ Final Checklist

<p align="center">
  <img src="images/screenshot_checklist.jpg" alt="Final Checklist" width="80%"/>
</p>

| Task | Status |
|------|--------|
| Multi-provider module (eu-west-1 + us-east-1 S3) | ✅ Completed |
| Docker NGINX container running on localhost:8080 | ✅ Completed |
| EKS cluster deployed (Kubernetes v1.31) | ✅ Completed |
| Kubernetes NGINX deployment (2 pods, READY 2/2) | ✅ Completed |
| kubectl access configured and verified | ✅ Completed |
| All screenshots captured | ✅ Completed |
| All resources destroyed (no ongoing costs) | ✅ Completed |

---

## 📊 Resources Summary

```
Part 1 — Multi-Region S3
  ├── aws_s3_bucket.primary   (eu-west-1)
  └── aws_s3_bucket.replica   (us-east-1)

Part 2 — Docker
  ├── docker_image.nginx      (nginx:latest)
  └── docker_container.nginx  (terraform-nginx, port 8080)

Part 3+4 — EKS (55 resources)
  ├── module.vpc              (VPC, 4 subnets, NAT GW, IGW, route tables)
  ├── module.eks              (EKS control plane, IAM roles, OIDC, security groups)
  ├── node_group.default      (2x t3.small EC2 instances)
  └── kubernetes_deployment   (nginx-deployment, 2 replicas)
```

---

## 🔗 Related Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Terraform Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
- [AWS EKS Access Entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html)
- [Kubernetes Deployment Docs](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

---

<p align="center">
  <strong>Day 15 Complete</strong> &nbsp;|&nbsp; 30-Day Terraform Challenge
  <br/><br/>
  <img src="https://img.shields.io/badge/Next-Day%2016-7B42F6?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/AWS-Certified%20Journey-FF9900?style=for-the-badge&logo=amazonaws"/>
</p>
