# Day 18 — Automated Testing of Terraform Infrastructure

> **30-Day Terraform Challenge** | Chapter 9: Automated Testing — Unit, Integration, and End-to-End

---

## Overview

Manual testing does not scale. This entry implements all three layers of Terraform automated testing against the webserver cluster built across Days 3–17:

| Layer | Tool | Deploys Real Infra | Speed | Cost |
|---|---|---|---|---|
| Unit | `terraform test` | No | Seconds | Free |
| Integration | Terratest (Go) | Yes | 5–15 min | Low |
| End-to-End | Terratest (Go) | Yes | 15–30 min | Medium |

All three layers are wired into a GitHub Actions CI/CD pipeline that runs unit tests on every pull request and integration tests on every merge to `main`.

---

## Repository Structure

```
day-18-automated-testing/
├── modules/
│   └── services/
│       └── webserver-cluster/
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── webserver_cluster_test.tftest.hcl   ← Unit tests
├── test/
│   ├── go.mod
│   ├── go.sum
│   ├── webserver_cluster_test.go                   ← Integration tests
│   └── full_stack_test.go                          ← End-to-end tests
├── .github/
│   └── workflows/
│       └── terraform-test.yml                      ← CI/CD pipeline
└── README.md
```

---

## Layer 1 — Unit Tests with `terraform test`

Unit tests validate logic and configuration correctness against a **plan only** — no AWS resources are created, no costs incurred, and tests complete in seconds.

### Test File

**`modules/services/webserver-cluster/webserver_cluster_test.tftest.hcl`**

```hcl
variables {
  cluster_name  = "test-cluster"
  instance_type = "t2.micro"
  min_size      = 1
  max_size      = 2
  environment   = "dev"
}

# Test 1: ASG name prefix is derived from cluster_name variable
run "validate_cluster_name" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.example.name_prefix == "test-cluster-"
    error_message = "ASG name prefix must match the cluster_name variable"
  }
}

# Test 2: Launch configuration instance type matches the variable
run "validate_instance_type" {
  command = plan

  assert {
    condition     = aws_launch_configuration.example.instance_type == "t2.micro"
    error_message = "Instance type must match the instance_type variable"
  }
}

# Test 3: Security group allows inbound traffic on port 8080
run "validate_security_group_port" {
  command = plan

  assert {
    condition = contains(
      [for rule in aws_security_group.instance.ingress : rule.from_port],
      8080
    )
    error_message = "Security group must allow traffic on port 8080"
  }
}

# Test 4: ASG min size is never less than 1 (prevents zero-instance deployments)
run "validate_min_size" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.example.min_size >= 1
    error_message = "ASG min_size must be at least 1 to ensure availability"
  }
}

# Test 5: Max size is greater than or equal to min size
run "validate_max_gte_min" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.example.max_size >= aws_autoscaling_group.example.min_size
    error_message = "ASG max_size must be >= min_size"
  }
}
```

### What Each Block Tests and Why

| Run Block | What It Tests | Why It Matters |
|---|---|---|
| `validate_cluster_name` | ASG name prefix matches variable | Prevents naming collisions across environments |
| `validate_instance_type` | Launch config uses declared instance type | Catches tfvars mismatches before any deploy |
| `validate_security_group_port` | Port 8080 is open on the instance SG | Ensures the app port is never accidentally removed |
| `validate_min_size` | ASG will never have zero instances | Prevents silent outages from misconfigured scaling |
| `validate_max_gte_min` | Max >= Min in ASG config | Invalid ASG config fails silently without this check |

### Running Unit Tests

```bash
cd modules/services/webserver-cluster
terraform init
terraform test
```

### Unit Test Output

```
modules/services/webserver-cluster/webserver_cluster_test.tftest.hcl... in progress
  run "validate_cluster_name"... pass
  run "validate_instance_type"... pass
  run "validate_security_group_port"... pass
  run "validate_min_size"... pass
  run "validate_max_gte_min"... pass
modules/services/webserver-cluster/webserver_cluster_test.tftest.hcl... tearing down
modules/services/webserver-cluster/webserver_cluster_test.tftest.hcl... pass

Success! 5 passed, 0 failed.
```

---

## Layer 2 — Integration Tests with Terratest

Integration tests deploy **real AWS infrastructure**, run assertions against live resources, and destroy everything when done. Written in Go using the [Terratest](https://github.com/gruntwork-io/terratest) library.

### Setup

```bash
cd test
go mod init test
go get github.com/gruntwork-io/terratest/modules/terraform
go get github.com/gruntwork-io/terratest/modules/http-helper
go get github.com/gruntwork-io/terratest/modules/random
go get github.com/stretchr/testify/assert
```

### Integration Test File

**`test/webserver_cluster_test.go`**

```go
package test

import (
  "fmt"
  "testing"
  "time"

  http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
  "github.com/gruntwork-io/terratest/modules/random"
  "github.com/gruntwork-io/terratest/modules/terraform"
  "github.com/stretchr/testify/assert"
)

func TestWebserverClusterIntegration(t *testing.T) {
  t.Parallel()

  // Unique ID prevents name collisions if tests run concurrently
  uniqueID    := random.UniqueId()
  clusterName := fmt.Sprintf("test-cluster-%s", uniqueID)

  terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
    TerraformDir: "../modules/services/webserver-cluster",
    Vars: map[string]interface{}{
      "cluster_name":  clusterName,
      "instance_type": "t2.micro",
      "min_size":      1,
      "max_size":      2,
      "environment":   "dev",
    },
  })

  // defer runs LAST, even if the test panics or an assertion fails.
  // This guarantees AWS resources are always cleaned up.
  defer terraform.Destroy(t, terraformOptions)

  // Deploy infrastructure
  terraform.InitAndApply(t, terraformOptions)

  // Read the ALB DNS name from Terraform outputs
  albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
  url        := fmt.Sprintf("http://%s", albDnsName)

  // Assert ALB output is not empty
  assert.NotEmpty(t, albDnsName, "ALB DNS name output must not be empty")

  // Retry HTTP GET for up to 5 minutes — ALB needs time to register instances
  // 40 retries x 10 second wait = 400 seconds maximum
  http_helper.HttpGetWithRetryWithCustomValidation(
    t,
    url,
    nil,
    40,
    10*time.Second,
    func(status int, body string) bool {
      return status == 200 && len(body) > 0
    },
  )
}
```

### Why `defer terraform.Destroy` Is Critical

`defer` in Go runs the deferred function at the end of the surrounding function — **regardless of how that function exits**:

- If an assertion fails → destroy still runs
- If the test panics → destroy still runs
- If the HTTP check times out → destroy still runs

Without `defer`, any test failure would leave EC2 instances, ALBs, security groups, and target groups running in AWS with no Terraform state to track them — accumulating cost indefinitely.

### Running Integration Tests

```bash
cd test
go test -v -timeout 30m -run TestWebserverClusterIntegration ./...
```

### Integration Test Output

```
=== RUN   TestWebserverClusterIntegration
=== PAUSE TestWebserverClusterIntegration
=== CONT  TestWebserverClusterIntegration

TestWebserverClusterIntegration 10:23:11 Running terraform [init -upgrade=false]
TestWebserverClusterIntegration 10:23:18 Running terraform [apply -input=false -auto-approve ...]
TestWebserverClusterIntegration 10:27:42 Apply complete! Resources: 12 added, 0 changed, 0 destroyed.
TestWebserverClusterIntegration 10:27:43 Making HTTP GET to http://test-cluster-ab12cd.us-east-1.elb.amazonaws.com
TestWebserverClusterIntegration 10:27:43 Got HTTP 502 — retrying (1/40)
TestWebserverClusterIntegration 10:27:53 Got HTTP 502 — retrying (2/40)
TestWebserverClusterIntegration 10:28:13 Got HTTP 200 — PASS
TestWebserverClusterIntegration 10:28:13 Running terraform [destroy -auto-approve ...]
TestWebserverClusterIntegration 10:31:14 Destroy complete! Resources: 12 destroyed.
--- PASS: TestWebserverClusterIntegration (487.32s)
PASS
ok      test    487.322s
```

---

## Layer 3 — End-to-End Tests

End-to-end tests deploy the **complete infrastructure stack** — networking first, then application — and verify the full path works as a combined unit. They catch cross-module integration failures that isolated module tests cannot find.

### End-to-End Test File

**`test/full_stack_test.go`**

```go
package test

import (
  "fmt"
  "testing"
  "time"

  http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
  "github.com/gruntwork-io/terratest/modules/random"
  "github.com/gruntwork-io/terratest/modules/terraform"
)

func TestFullStackEndToEnd(t *testing.T) {
  t.Parallel()

  uniqueID := random.UniqueId()

  // Step 1: Deploy VPC (networking foundation)
  vpcOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
    TerraformDir: "../modules/networking/vpc",
    Vars: map[string]interface{}{
      "vpc_name": fmt.Sprintf("test-vpc-%s", uniqueID),
    },
  })

  // Destroy VPC last — defer is LIFO (last registered = first destroyed)
  // App must be destroyed before VPC due to subnet/SG dependencies
  defer terraform.Destroy(t, vpcOptions)
  terraform.InitAndApply(t, vpcOptions)

  vpcID     := terraform.Output(t, vpcOptions, "vpc_id")
  subnetIDs := terraform.OutputList(t, vpcOptions, "private_subnet_ids")

  // Step 2: Deploy application using VPC outputs as inputs
  appOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
    TerraformDir: "../modules/services/webserver-cluster",
    Vars: map[string]interface{}{
      "cluster_name":  fmt.Sprintf("test-app-%s", uniqueID),
      "vpc_id":        vpcID,
      "subnet_ids":    subnetIDs,
      "environment":   "dev",
      "instance_type": "t2.micro",
      "min_size":      1,
      "max_size":      2,
    },
  })

  // App defer registered after VPC defer — so app is destroyed first (LIFO)
  defer terraform.Destroy(t, appOptions)
  terraform.InitAndApply(t, appOptions)

  // Step 3: Verify the full stack works end to end
  albDnsName := terraform.Output(t, appOptions, "alb_dns_name")
  url        := fmt.Sprintf("http://%s", albDnsName)

  http_helper.HttpGetWithRetry(
    t, url, nil,
    200, "Hello",
    40, 10*time.Second,
  )
}
```

### Running End-to-End Tests

```bash
cd test
go test -v -timeout 45m -run TestFullStackEndToEnd ./...
```

> **Note on `defer` ordering:** Go executes deferred calls in LIFO order. The app defer is registered after the VPC defer, so the app is destroyed first — which is required, since the VPC cannot be deleted while the app's subnets and security groups still exist inside it.

---

## CI/CD Pipeline — GitHub Actions

**`.github/workflows/terraform-test.yml`**

```yaml
name: Terraform Tests

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.6.0"

      - name: Terraform Init
        run: terraform init
        working-directory: modules/services/webserver-cluster

      - name: Run Unit Tests
        run: terraform test
        working-directory: modules/services/webserver-cluster

  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    if: github.event_name == 'push'   # Only on merge to main, not PRs
    needs: unit-tests                  # Blocked if unit tests fail

    env:
      AWS_ACCESS_KEY_ID:     ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_DEFAULT_REGION:    us-east-1

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: "1.21"

      - name: Install dependencies
        run: go mod download
        working-directory: test

      - name: Run Integration Tests
        run: go test -v -timeout 30m -run TestWebserverClusterIntegration ./...
        working-directory: test
```

### Pipeline Design Decisions

**Unit tests run on every PR** — they cost nothing, take seconds, and require no AWS credentials. Every engineer gets instant feedback before code review.

**Integration tests run only on push to main** — deploying real infrastructure on every PR across a team would create parallel resource conflicts and unpredictable costs. Integration tests are the post-merge gate.

**`needs: unit-tests`** — prevents expensive infrastructure provisioning when configuration is already known to be broken. The fast gate runs before the slow gate.

**AWS credentials** — stored as GitHub Actions repository secrets (`Settings → Secrets → Actions`). A dedicated CI IAM user is created with the minimum permissions Terraform needs. Never reuse an existing user with unknown permission scope.

---

## Test Layer Comparison

| Test Type | Tool | Deploys Real Infra | Time | Cost | What It Catches |
|---|---|---|---|---|---|
| Unit | `terraform test` | No | Seconds | Free | Config logic errors, variable mismatches, wrong port numbers, broken naming conventions, invalid resource attributes |
| Integration | Terratest | Yes | 5–15 min | ~$0.05–0.10/run | Provisioning failures, IAM permission errors, health check failures, broken ALB routing, ASG misconfigurations |
| End-to-End | Terratest | Yes | 15–30 min | ~$0.20–0.50/run | Cross-module dependency failures, VPC subnet misconfigurations, networking failures between modules that each pass in isolation |

---

## Chapter 9 Learnings

### Integration Test vs End-to-End Test — Key Difference

An **integration test** deploys a single module in isolation and asserts it works on its own. It answers: *does this module do what it says it does?*

An **end-to-end test** deploys multiple modules together and asserts the combined system works as a whole. It answers: *do these modules work correctly with each other?*

The distinction matters because a module can pass every integration test and still fail in production when it receives outputs from another module in an unexpected format, or when two modules create resources that conflict in a shared VPC.

### Why Unit Tests on Every PR, E2E Tests Less Frequently?

It is about the cost-to-feedback ratio. Unit tests give immediate feedback at zero cost — they belong in the fastest possible loop. End-to-end tests take 30 minutes and cost money. Running E2E on every PR across a team means potentially dozens of parallel 30-minute AWS deployments per day, which is expensive, slow to queue, and reduces the signal-to-noise ratio of the feedback. The right strategy: unit tests on every PR, integration tests on merge to main, E2E tests on a schedule or before major releases.

---

## Labs Completed

### Lab 1 — Import Existing Infrastructure

`terraform import` brings existing AWS resources under Terraform management by writing them into state. It does **not** generate `.tf` configuration — that must be written manually.

```bash
# Import the resource into state
terraform import aws_security_group.legacy sg-0abc123456def7890

# Check what Terraform sees vs. what your config says
terraform plan

# Iterate on .tf until plan returns: No changes.
```

The risk: if your configuration doesn't match the real resource exactly, Terraform will attempt to modify or recreate it on the next apply. Always verify with a clean plan after every import.

### Lab 2 — Terraform Cloud

Terraform Cloud provides remote state storage, remote plan/apply execution, and a run history UI.

```hcl
# backend.tf
terraform {
  cloud {
    organization = "your-org-name"
    workspaces {
      name = "webserver-cluster-dev"
    }
  }
}
```

```bash
terraform login        # Authenticates to Terraform Cloud
terraform init         # Prompts to migrate existing state to the cloud backend
```

Terraform Cloud's free tier replaces S3 + DynamoDB for teams getting started with remote state.

---

## Challenges and Fixes

### Challenge 1 — Go Module Version Conflict

**Error:**
```
go: github.com/gruntwork-io/terratest/modules/http-helper: no required module provides this package
```

**Root cause:** `go mod init` was run but dependencies were not downloaded before running tests.

**Fix:**
```bash
go mod tidy
go mod download
```

`go mod tidy` resolved all missing transitive dependencies automatically.

---

### Challenge 2 — Terratest HTTP Timeout (ALB Not Ready)

**Error:**
```
Max retries exceeded. Last response: 502 Bad Gateway
```

**Root cause:** The ALB was provisioned but instance health checks had not yet passed within the original 300-second window.

**Fix:** Increased retry count from 30 to 40 (400 seconds total):

```go
http_helper.HttpGetWithRetryWithCustomValidation(
  t, url, nil,
  40,              // was 30
  10*time.Second,
  func(status int, body string) bool {
    return status == 200 && len(body) > 0
  },
)
```

---

### Challenge 3 — GitHub Actions IAM Permission Denied

**Error:**
```
Error: creating EC2 Security Group: UnauthorizedOperation: You are not authorized to perform this operation.
```

**Root cause:** The IAM user in GitHub Actions secrets was a read-only monitoring user repurposed for CI without updating its policy.

**Fix:** Created a dedicated CI IAM user with a policy scoped to the specific AWS actions Terraform requires. Updated GitHub Actions secrets with the new credentials.

**Lesson:** Always use a dedicated IAM user for CI with minimum required permissions. Never reuse users with unknown permission scope.

---

### Challenge 4 — Unit Test Fails on `ingress[0]` Index with Dynamic Blocks

**Error:**
```
Error: Invalid index — The given key does not identify an element in this collection value.
```

**Root cause:** The security group uses a `dynamic` ingress block, which is not exposed as an indexed list in Terraform plan expressions.

**Fix:** Replaced index access with a `contains` + `for` expression:

```hcl
# Before (fails with dynamic blocks)
condition = aws_security_group.instance.ingress[0].from_port == 8080

# After (works with dynamic blocks)
condition = contains(
  [for rule in aws_security_group.instance.ingress : rule.from_port],
  8080
)
```

---

## Key Commands Reference

```bash
# Unit tests — plan only, no real infrastructure
terraform init
terraform test

# Integration tests — deploys real AWS resources
cd test
go mod tidy
go test -v -timeout 30m -run TestWebserverClusterIntegration ./...

# End-to-end tests
go test -v -timeout 45m -run TestFullStackEndToEnd ./...

# Run all tests in the test directory
go test -v -timeout 45m ./...

# Import existing resource into state
terraform import aws_security_group.example sg-0abc123456def7890

# Terraform Cloud authentication and init
terraform login
terraform init
```

---

## Social Media Post

> 🚀 Day 18 of the 30-Day Terraform Challenge — automated testing end to end. Native `terraform test` for unit tests, Terratest for integration tests, GitHub Actions for CI/CD. Infrastructure that is tested automatically on every commit is infrastructure you can deploy with confidence. #30DayTerraformChallenge #TerraformChallenge #Terraform #Testing #DevOps #CI/CD #AWSUserGroupKenya #EveOps

---

*Part of the [30-Day Terraform Challenge](https://github.com/ericgitau-tech) | Eric Gitau*
