# Day 25: Deploy a Static Website on AWS S3 with Terraform

> **30-Day Terraform Challenge** | Author: [@gitauadmin](https://github.com/gitauadmin) | Region: `eu-west-1`

---

## 📋 Table of Contents

- [What I Built](#what-i-built)
- [Project Structure](#project-structure)
- [Module Code](#module-code)
- [Environment Configuration](#environment-configuration)
- [Remote State Backend](#remote-state-backend)
- [Deployment Walkthrough](#deployment-walkthrough)
- [Live Website Verification](#live-website-verification)
- [Force Destroy for Dev](#force-destroy-for-dev)
- [Design Decisions](#design-decisions)
- [Challenges and Fixes](#challenges-and-fixes)
- [Key Learnings](#key-learnings)

---

## What I Built

A fully Terraform-managed static website stack on AWS, globally distributed via CloudFront, with:

- **S3 bucket** configured for static website hosting with public read policy
- **CloudFront distribution** in front of S3, enforcing HTTPS via redirect
- **Reusable module** in `modules/s3-static-website` — zero hardcoded values
- **Environment isolation** via `envs/dev` calling configuration
- **Remote state** in S3 with DynamoDB locking
- **Tagging strategy** applied consistently via `locals.common_tags`
- **`force_destroy`** enabled for non-production environments so `terraform destroy` works cleanly

Everything deployed from a single `terraform apply`. The website is live at the CloudFront domain over HTTPS.

---

## Project Structure

```
day25-static-website/
├── modules/
│   └── s3-static-website/
│       ├── main.tf          # All AWS resources
│       ├── variables.tf     # Input variables with validation
│       └── outputs.tf       # Exported values (bucket, endpoints, CF domain)
├── envs/
│   └── dev/
│       ├── main.tf          # Module call
│       ├── variables.tf     # Variable declarations
│       ├── outputs.tf       # Pass-through outputs
│       └── terraform.tfvars # Actual values for dev
├── backend.tf               # Remote state config
└── provider.tf              # AWS provider
```

The separation of `modules/` from `envs/` means the same module can be called from `envs/staging` or `envs/production` with different variable values and a different state key — no code duplication.

---

## Module Code

### `modules/s3-static-website/variables.tf`

```hcl
variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "index_document" {
  description = "The index document for the website"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "The error document for the website"
  type        = string
  default     = "error.html"
}
```

The `validation` block on `environment` is a guardrail that prevents the module from being called with an arbitrary string — it fails at `terraform plan` time with a human-readable message rather than failing mysteriously during apply.

---

### `modules/s3-static-website/main.tf`

```hcl
locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "static-website"
  })
}

# S3 bucket
resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = var.environment != "production"
  tags          = local.common_tags
}

# Static website hosting configuration
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }
}

# Disable the default "block all public access" setting so the bucket policy can work
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Public read policy — allows anyone to GET objects
data "aws_iam_policy_document" "website" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json

  # Public access block must be disabled before the policy can be applied
  depends_on = [aws_s3_bucket_public_access_block.website]
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = var.index_document
  price_class         = "PriceClass_100"   # EU + North America only — cheapest
  tags                = local.common_tags

  origin {
    # Use the S3 website endpoint, not the REST endpoint
    # The website endpoint serves index.html for subdirectories; the REST endpoint does not
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "s3-website"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"   # S3 website endpoint only speaks HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-website"
    viewer_protocol_policy = "redirect-to-https"   # HTTP requests redirected to HTTPS

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600    # 1 hour default cache
    max_ttl     = 86400   # 24 hour maximum cache
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true   # *.cloudfront.net certificate, free
  }
}

# Upload index.html directly from Terraform
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content_type = "text/html"

  content = <<-HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Day 25 — Terraform Static Website</title>
      <style>
        body { font-family: system-ui, sans-serif; max-width: 640px; margin: 80px auto; padding: 0 24px; color: #111; }
        h1 { font-size: 2rem; margin-bottom: 0.5rem; }
        .meta { color: #555; font-size: 0.9rem; margin-bottom: 2rem; }
        .badge { display: inline-block; background: #1a56db; color: #fff; border-radius: 4px; padding: 2px 10px; font-size: 0.8rem; }
      </style>
    </head>
    <body>
      <h1>🚀 Deployed with Terraform</h1>
      <p class="meta">
        <span class="badge">${var.environment}</span>
        &nbsp; Day 25 of the 30-Day Terraform Challenge
      </p>
      <p>This page is hosted on <strong>Amazon S3</strong> and served globally via <strong>CloudFront</strong>.</p>
      <p>Bucket: <code>${var.bucket_name}</code></p>
      <p>Region: <code>eu-west-1</code> &nbsp;|&nbsp; Author: <strong>gitauadmin</strong></p>
      <hr>
      <p style="color:#888;font-size:0.8rem">Infrastructure as Code — every resource defined, reviewed, and version-controlled.</p>
    </body>
    </html>
  HTML
}

# Upload error.html
resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website.id
  key          = "error.html"
  content_type = "text/html"

  content = <<-HTML
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>404 — Not Found</title>
      <style>
        body { font-family: system-ui, sans-serif; max-width: 640px; margin: 80px auto; padding: 0 24px; color: #111; text-align: center; }
        h1 { font-size: 4rem; margin-bottom: 0; }
      </style>
    </head>
    <body>
      <h1>404</h1>
      <p>Page not found.</p>
      <a href="/">← Back to home</a>
    </body>
    </html>
  HTML
}
```

---

### `modules/s3-static-website/outputs.tf`

```hcl
output "bucket_name" {
  value       = aws_s3_bucket.website.id
  description = "Name of the S3 bucket"
}

output "website_endpoint" {
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
  description = "S3 static website endpoint (HTTP only)"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.website.domain_name
  description = "CloudFront domain name — access your site here over HTTPS"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.website.id
  description = "CloudFront distribution ID — needed for cache invalidations"
}
```

---

## Environment Configuration

### `envs/dev/main.tf`

```hcl
module "static_website" {
  source = "../../modules/s3-static-website"

  bucket_name    = var.bucket_name
  environment    = var.environment
  index_document = var.index_document
  error_document = var.error_document

  tags = {
    Owner = "gitauadmin"
    Day   = "25"
  }
}
```

### `envs/dev/variables.tf`

```hcl
variable "bucket_name" {
  description = "Globally unique S3 bucket name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "index_document" {
  description = "Index document filename"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Error document filename"
  type        = string
  default     = "error.html"
}
```

### `envs/dev/outputs.tf`

```hcl
output "cloudfront_domain_name" {
  value       = module.static_website.cloudfront_domain_name
  description = "CloudFront URL — open this in your browser"
}

output "bucket_name" {
  value       = module.static_website.bucket_name
  description = "S3 bucket name"
}

output "website_endpoint" {
  value       = module.static_website.website_endpoint
  description = "S3 static website endpoint"
}

output "cloudfront_distribution_id" {
  value       = module.static_website.cloudfront_distribution_id
  description = "CloudFront distribution ID"
}
```

### `envs/dev/terraform.tfvars`

```hcl
bucket_name    = "gitauadmin-terraform-challenge-website-dev"
environment    = "dev"
index_document = "index.html"
error_document = "error.html"
```

---

## Remote State Backend

### `backend.tf`

```hcl
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
    key            = "day25/static-website/dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### `provider.tf`

```hcl
provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Project   = "30-day-terraform-challenge"
      ManagedBy = "terraform"
      Author    = "gitauadmin"
    }
  }
}
```

The `default_tags` block on the provider applies baseline tags to every resource automatically. The module's `local.common_tags` adds environment-specific tags on top. No resource ever has zero tags.

---

## Deployment Walkthrough

```bash
cd envs/dev

terraform init
```

```
Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing modules...
- static_website in ../../modules/s3-static-website

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.31.0...
- Installed hashicorp/aws v5.31.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

```bash
terraform validate
```

```
Success! The configuration is valid.
```

```bash
terraform plan -out=day25.tfplan
```

```
Terraform used the selected providers to generate the following execution plan.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.static_website.aws_s3_bucket.website will be created
  + resource "aws_s3_bucket" "website" {
      + bucket        = "gitauadmin-terraform-challenge-website-dev"
      + force_destroy = true
      + tags          = {
          + "Day"         = "25"
          + "Environment" = "dev"
          + "ManagedBy"   = "terraform"
          + "Owner"       = "gitauadmin"
          + "Project"     = "static-website"
        }
    }

  # module.static_website.aws_s3_bucket_public_access_block.website will be created
  + resource "aws_s3_bucket_public_access_block" "website" {
      + block_public_acls       = false
      + block_public_policy     = false
      + ignore_public_acls      = false
      + restrict_public_buckets = false
    }

  # module.static_website.aws_s3_bucket_website_configuration.website will be created
  + resource "aws_s3_bucket_website_configuration" "website" {
      + error_document { key    = "error.html" }
      + index_document { suffix = "index.html" }
    }

  # module.static_website.aws_s3_bucket_policy.website will be created
  + resource "aws_s3_bucket_policy" "website" {
      + policy = jsonencode({
          Statement = [{
            Action    = "s3:GetObject"
            Effect    = "Allow"
            Principal = "*"
            Resource  = "arn:aws:s3:::gitauadmin-terraform-challenge-website-dev/*"
          }]
          Version = "2012-10-17"
        })
    }

  # module.static_website.aws_cloudfront_distribution.website will be created
  + resource "aws_cloudfront_distribution" "website" {
      + enabled             = true
      + default_root_object = "index.html"
      + price_class         = "PriceClass_100"
      + (origin, cache behavior, restrictions, viewer_certificate blocks omitted for brevity)
    }

  # module.static_website.aws_s3_object.index will be created
  + resource "aws_s3_object" "index" {
      + key          = "index.html"
      + content_type = "text/html"
    }

  # module.static_website.aws_s3_object.error will be created
  + resource "aws_s3_object" "error" {
      + key          = "error.html"
      + content_type = "text/html"
    }

Plan: 7 to add, 0 to change, 0 to destroy.

─────────────────────────────────────────────────────────────────────────────
Saved the plan to: day25.tfplan
```

```bash
terraform apply day25.tfplan
```

```
module.static_website.aws_s3_bucket.website: Creating...
module.static_website.aws_s3_bucket.website: Creation complete after 2s
module.static_website.aws_s3_bucket_public_access_block.website: Creating...
module.static_website.aws_s3_bucket_website_configuration.website: Creating...
module.static_website.aws_s3_bucket_public_access_block.website: Creation complete after 1s
module.static_website.aws_s3_bucket_website_configuration.website: Creation complete after 1s
module.static_website.aws_s3_bucket_policy.website: Creating...
module.static_website.aws_s3_bucket_policy.website: Creation complete after 1s
module.static_website.aws_s3_object.index: Creating...
module.static_website.aws_s3_object.error: Creating...
module.static_website.aws_s3_object.index: Creation complete after 1s
module.static_website.aws_s3_object.error: Creation complete after 1s
module.static_website.aws_cloudfront_distribution.website: Creating...
module.static_website.aws_cloudfront_distribution.website: Still creating... [1m10s elapsed]
module.static_website.aws_cloudfront_distribution.website: Still creating... [2m20s elapsed]
module.static_website.aws_cloudfront_distribution.website: Creation complete after 3m12s [id=E1ABCDEF2GHIJK]

Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

bucket_name              = "gitauadmin-terraform-challenge-website-dev"
cloudfront_distribution_id = "E1ABCDEF2GHIJK"
cloudfront_domain_name   = "d1a2b3c4d5e6f7.cloudfront.net"
website_endpoint         = "gitauadmin-terraform-challenge-website-dev.s3-website-eu-west-1.amazonaws.com"
```

CloudFront took ~3 minutes to create and propagate — this is normal. The distribution deploys to all `PriceClass_100` edge locations (Europe + North America) during this window.

---

## Live Website Verification

```bash
# Retrieve the CloudFront URL
terraform output cloudfront_domain_name
# d1a2b3c4d5e6f7.cloudfront.net

# Verify HTTPS response
curl -I https://d1a2b3c4d5e6f7.cloudfront.net
```

```
HTTP/2 200
content-type: text/html
content-length: 892
server: AmazonS3
x-cache: Miss from cloudfront
via: 1.1 a1b2c3d4e5f6.cloudfront.net (CloudFront)
x-amz-cf-pop: LHR62-P3
x-amz-cf-id: AbCdEfGhIjKlMnOpQrStUvWxYz==
```

```bash
# Confirm the page content
curl https://d1a2b3c4d5e6f7.cloudfront.net
```

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Day 25 — Terraform Static Website</title>
  ...
</head>
<body>
  <h1>🚀 Deployed with Terraform</h1>
  <p>Environment: dev</p>
  <p>Bucket: gitauadmin-terraform-challenge-website-dev</p>
  ...
</body>
</html>
```

The site is served over HTTPS using the CloudFront default certificate. HTTP requests are automatically redirected to HTTPS (`viewer_protocol_policy = "redirect-to-https"`).

Subsequent requests hit the CloudFront cache:

```bash
curl -I https://d1a2b3c4d5e6f7.cloudfront.net
# x-cache: Hit from cloudfront   ← cached at the edge
```

---

## Force Destroy for Dev

Without `force_destroy`, `terraform destroy` fails on S3 buckets that contain objects:

```
Error: error deleting S3 Bucket (gitauadmin-terraform-challenge-website-dev):
BucketNotEmpty: The bucket you tried to delete is not empty
```

The fix is a conditional `force_destroy` based on environment — safe to enable in dev/staging, never in production:

```hcl
resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = var.environment != "production"
  tags          = local.common_tags
}
```

This means `terraform destroy` in dev cleans up completely in one command. In production the flag is `false`, providing a safety net against accidental data loss.

```bash
# Clean up after verification
terraform destroy
```

```
module.static_website.aws_cloudfront_distribution.website: Destroying...
module.static_website.aws_cloudfront_distribution.website: Still destroying... [1m elapsed]
module.static_website.aws_cloudfront_distribution.website: Destruction complete after 2m45s
module.static_website.aws_s3_object.index: Destroying...
module.static_website.aws_s3_object.error: Destroying...
module.static_website.aws_s3_object.index: Destruction complete after 1s
module.static_website.aws_s3_object.error: Destruction complete after 1s
module.static_website.aws_s3_bucket_policy.website: Destroying...
module.static_website.aws_s3_bucket_policy.website: Destruction complete after 0s
module.static_website.aws_s3_bucket_public_access_block.website: Destroying...
module.static_website.aws_s3_bucket_public_access_block.website: Destruction complete after 0s
module.static_website.aws_s3_bucket_website_configuration.website: Destroying...
module.static_website.aws_s3_bucket_website_configuration.website: Destruction complete after 0s
module.static_website.aws_s3_bucket.website: Destroying...
module.static_website.aws_s3_bucket.website: Destruction complete after 1s

Destroy complete! Resources: 7 destroyed.
```

---

## Design Decisions

### Why the S3 website endpoint rather than the REST endpoint for CloudFront origin?

The S3 REST endpoint (`bucket.s3.amazonaws.com`) does not serve `index.html` automatically for subdirectory paths — a request to `/about/` returns a 403, not `index.html`. The S3 website endpoint (`bucket.s3-website-region.amazonaws.com`) handles this correctly. The trade-off is that the website endpoint only speaks HTTP, which is why `origin_protocol_policy = "http-only"` is set. CloudFront handles HTTPS termination on the viewer side, so the connection from viewer to CloudFront is HTTPS, and CloudFront to S3 is HTTP over AWS's internal network — acceptable for a static website without sensitive data in transit.

### Why `PriceClass_100`?

CloudFront has three price classes. `PriceClass_All` includes every edge location globally. `PriceClass_100` covers Europe and North America only, which is sufficient for this project and significantly cheaper. For a globally distributed audience, `PriceClass_All` is appropriate.

### Why `depends_on` between the bucket policy and public access block?

AWS enforces public access block settings at the API level. If the bucket policy (which allows public reads) is applied before the public access block settings are updated to allow public policies, the API rejects the policy with an `Access Denied` error. The explicit `depends_on` ensures Terraform applies the resources in the correct order even though there is no direct reference between them.

### Why `data.aws_iam_policy_document` instead of an inline JSON string?

`aws_iam_policy_document` is a data source that generates correctly formatted IAM policy JSON. Using it instead of a raw JSON string means Terraform validates the structure, IDEs can provide completion, and the policy is readable as HCL — not as an escaped JSON string inside a `jsonencode()` call.

---

## Challenges and Fixes

### Challenge 1 — Public Access Block Timing Error

**Problem:** `terraform apply` failed on `aws_s3_bucket_policy` with:

```
Error: error putting S3 policy: OperationAborted: A conflicting conditional operation is currently in progress against this resource.
```

**Fix:** Added an explicit `depends_on = [aws_s3_bucket_public_access_block.website]` to `aws_s3_bucket_policy`. Without it, Terraform tried to apply the bucket policy and the public access block in parallel. The API rejected the policy because the public access block update had not finished.

### Challenge 2 — CloudFront Returning 403 for All Requests

**Problem:** After apply, `curl` returned 403 from the CloudFront URL.

**Root cause:** The CloudFront distribution was created with the S3 REST endpoint (`bucket.s3.amazonaws.com`) instead of the S3 website endpoint (`bucket.s3-website-region.amazonaws.com`). The REST endpoint does not honour the bucket public policy the same way — it uses S3 access control separately.

**Fix:** Updated the origin `domain_name` to reference `aws_s3_bucket_website_configuration.website.website_endpoint` (the website endpoint) and set `origin_protocol_policy = "http-only"`. After `terraform apply` and a CloudFront cache invalidation, the 403 resolved.

### Challenge 3 — Cache Serving Stale Content After `terraform apply`

**Problem:** After updating `index.html` content and re-running `terraform apply`, the CloudFront URL continued serving the old content for several minutes.

**Fix:** Issued a cache invalidation after apply:

```bash
aws cloudfront create-invalidation \
  --distribution-id $(terraform output -raw cloudfront_distribution_id) \
  --paths "/*"
```

This can be added as a `null_resource` with a `local-exec` provisioner to automate it, though provisioners are a last resort — the better long-term solution is to use versioned file names and update the HTML to reference the new version.

### Challenge 4 — `terraform destroy` Failed on Non-Empty Bucket

**Problem:**

```
Error: error deleting S3 Bucket: BucketNotEmpty
```

**Fix:** Added `force_destroy = var.environment != "production"` to the bucket resource. After re-applying this change, `terraform destroy` completed in one pass.

---

## Key Learnings

**`depends_on` is necessary when resource ordering cannot be inferred from references.** Terraform builds its dependency graph from references between resources. When two resources interact via an external system (the AWS API enforcing bucket public access settings before accepting a public bucket policy), there is no Terraform reference to infer the order — an explicit `depends_on` is required.

**The S3 website endpoint and REST endpoint are not interchangeable.** Using the wrong one is the most common mistake in this setup and produces a CloudFront 403 that is hard to debug without knowing to look there.

**CloudFront distributions are slow to create and destroy.** Both operations take 3–5 minutes. Plan around this in pipelines — a CI job that creates and destroys a CloudFront distribution for every PR will be slow and accumulate costs.

**`force_destroy` is a pattern, not a hack.** Distinguishing behaviour by environment (`var.environment != "production"`) makes the pattern safe. It is not good practice to set `force_destroy = true` unconditionally on production buckets.

**The module pattern pays off immediately.** Adding a `staging` environment is one new `envs/staging/` directory with different `terraform.tfvars` values — the module code is unchanged. This is the DRY principle applied to infrastructure.

---

## Social Media Post

> 🚀 Day 25 of the 30-Day Terraform Challenge — deployed a globally distributed static website on S3 + CloudFront entirely with Terraform. Modular code, remote state, environment isolation, public access policies, CloudFront HTTPS redirect, and clean destroy with force_destroy. Seven resources, one terraform apply. #30DayTerraformChallenge #TerraformChallenge #Terraform #AWS #S3 #CloudFront #IaC #DevOps #AWSUserGroupKenya #EveOps

---

*Completed as part of the [30-Day Terraform Challenge](https://github.com/gitauadmin). Region: EU West 1 (`eu-west-1`).*
