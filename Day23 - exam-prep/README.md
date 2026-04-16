# 📚 Day 23 — Exam Preparation: Brushing Up on Key Terraform Concepts

> **30-Day Terraform Challenge** | Focus: HashiCorp Terraform Associate Exam Readiness

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Domain Audit](#-domain-audit)
- [Study Plan](#-study-plan)
- [CLI Command Mastery](#-cli-command-mastery)
- [Non-Cloud Provider Deep Dive](#-non-cloud-provider-deep-dive)
- [Key Concepts to Remember for the Exam](#-key-concepts-to-remember-for-the-exam)
- [Reflection](#-reflection)
- [Resources](#-resources)

---

## 🎯 Overview

Day 23 was about stepping back from building and focusing on **exam readiness**. Rather than writing new infrastructure, the goal was to honestly audit which Terraform domains I know well and which ones need more work — then build a structured plan to close those gaps before the HashiCorp Terraform Associate exam.

The three pillars of today's work:

| Pillar | What I Did |
|---|---|
| **Domain Audit** | Rated my confidence (1–5) across all exam objective domains |
| **Study Plan** | Built a time-boxed plan targeting the weak areas |
| **CLI Mastery** | Reviewed every key command — what it does, when to use it, and what it does NOT do |

> 💡 **Key insight from today:** The exam tests *Terraform behaviour* — especially around state management and command outcomes — not just syntax. You need to know what happens *under the hood*, not just what the code looks like.

---

## 📊 Domain Audit

An honest self-assessment across all HashiCorp Terraform Associate exam objective domains.

| Domain | Confidence (1–5) | Status |
|---|:---:|---|
| Understand IaC concepts | 5 | ✅ Strong |
| Understand Terraform's purpose | 5 | ✅ Strong |
| Understand Terraform basics | 5 | ✅ Strong |
| Navigate core Terraform workflow | 4 | ✅ Good — minor gaps |
| Interact with Terraform modules | 5 | ✅ Strong |
| Implement and maintain state | 5 | ✅ Strong |
| Use Terraform CLI outside core workflow | 3 | ⚠️ Needs work |
| Read, generate, and modify configuration | 3 | ⚠️ Needs work |
| Understand Terraform Cloud capabilities | 3 | ⚠️ Needs work |

### 🔍 Audit Analysis

**Strong areas (4–5):** The fundamentals are solid. IaC concepts, core workflow, state management, and modules are all well understood — these were built up through hands-on labs in Days 1–22.

**Weak areas (3):** Three domains need focused attention:
- **CLI outside core workflow** — commands like `state mv`, `state rm`, `import`, and `workspace` that go beyond the basic init/plan/apply cycle
- **Read, generate, and modify configuration** — complex `for` expressions, dynamic blocks, and advanced HCL patterns
- **Terraform Cloud capabilities** — workspace variable types, Sentinel policies, cost estimation, and remote operations

---

## 🗓️ Study Plan

A focused, time-boxed plan targeting the three weak domains identified in the audit.

| Topic | Confidence | Study Method | Time |
|---|:---:|---|:---:|
| `terraform state` commands | 🟡 Developing | Run each command against test infrastructure | 45 min |
| Complex `for` expressions | 🟡 Developing | Write 5 examples from scratch | 30 min |
| Sentinel policy syntax | 🟡 Developing | Read docs and write two policies | 45 min |
| Terraform Cloud variables | 🟡 Developing | Review workspace variable types | 30 min |
| Official sample questions | 🟢 Ready | Work through all, review wrong answers | 60 min |

**Total focused study time: ~3.5 hours**

### 📌 Study Tips Applied

- **Active recall over passive reading** — write the commands from memory first, then check
- **Hands-on over notes** — run every `state` command against real (or test) infrastructure
- **Wrong answers are the most valuable** — every sample question answered incorrectly reveals an exact gap to close

---

## ⌨️ CLI Command Mastery

A complete self-test reference for every key Terraform CLI command. For each command: what it does, when to use it, and critical exam notes.

---

### 🔵 Core Workflow Commands

#### `terraform init`
**What it does:** Downloads required providers, configures the backend, and initialises the working directory.  
**When to use:** Whenever you add a new provider, change a module source, or set up a project for the first time.  
**Exam note:** Must be run before any other command. Re-run after any change to `required_providers` or `terraform` backend block.

```bash
terraform init
terraform init -upgrade   # upgrade provider versions
terraform init -reconfigure  # force backend reconfiguration
```

---

#### `terraform validate`
**What it does:** Checks configuration syntax and internal consistency.  
**When to use:** After writing or editing `.tf` files to catch errors before planning.  
**Exam note:** ⚠️ Does NOT check credentials, does NOT query real infrastructure, does NOT validate that resource names exist in AWS.

```bash
terraform validate
```

---

#### `terraform fmt`
**What it does:** Reformats `.tf` files to the canonical Terraform style (indentation, spacing, alignment).  
**When to use:** Before committing code, or to clean up formatting.  
**Exam note:** ⚠️ Does NOT validate logic or check for errors — it only fixes formatting.

```bash
terraform fmt          # format current directory
terraform fmt -recursive  # format all subdirectories
terraform fmt -check   # exit non-zero if files need formatting (use in CI)
```

---

#### `terraform plan`
**What it does:** Compares your current configuration against the state file and shows exactly what will be created, changed, or destroyed — without doing anything.  
**When to use:** Before every `apply` to review the proposed changes.  
**Exam note:** Uses state as the source of truth for current infrastructure. Does not make any API calls to create resources.

```bash
terraform plan
terraform plan -out=tfplan        # save plan to file
terraform plan -var="env=dev"     # pass variable inline
terraform plan -destroy           # preview what destroy would remove
```

---

#### `terraform apply`
**What it does:** Executes the plan — creates, updates, or replaces infrastructure as needed — and updates the state file.  
**When to use:** When you are ready to make real changes to infrastructure.  
**Exam note:** If given a saved plan file (`terraform apply tfplan`), it skips the confirmation prompt.

```bash
terraform apply
terraform apply -auto-approve     # skip confirmation (use with caution)
terraform apply tfplan            # apply a saved plan file
```

---

#### `terraform destroy`
**What it does:** Removes all infrastructure resources defined in the configuration and clears them from state.  
**When to use:** To tear down an environment completely.  
**Exam note:** Equivalent to `terraform apply -destroy`. Resources with `prevent_destroy = true` will cause this to fail.

```bash
terraform destroy
terraform destroy -target=aws_s3_bucket.example  # destroy one resource
```

---

### 🟠 State Management Commands

#### `terraform output`
**What it does:** Reads and displays output values directly from the state file.  
**When to use:** After an apply, to retrieve values like IP addresses, ARNs, or connection strings.  
**Exam note:** ⚠️ Reads from **state only** — does NOT query providers or make API calls.

```bash
terraform output
terraform output sns_topic_arn    # read a specific output
terraform output -json            # machine-readable output
```

---

#### `terraform state list`
**What it does:** Lists all resources currently tracked in the state file.  
**When to use:** To see what Terraform is managing, or to find the exact resource address for other state commands.

```bash
terraform state list
terraform state list aws_s3_bucket.*  # filter by resource type
```

---

#### `terraform state show`
**What it does:** Shows the full attributes of a specific resource as stored in state.  
**When to use:** To inspect the current values Terraform has recorded for a resource (IDs, ARNs, tags, etc.).

```bash
terraform state show aws_s3_bucket.state
terraform state show module.vpc.aws_vpc.main
```

---

#### `terraform state mv`
**What it does:** Moves (renames) a resource within the state file, or moves it to a different state file.  
**When to use:** When refactoring — e.g. renaming a resource or moving it into a module — without destroying and recreating the real infrastructure.  
**Exam note:** ⚠️ Does NOT affect real infrastructure — only updates the state file.

```bash
terraform state mv aws_instance.old_name aws_instance.new_name
terraform state mv -state-out=other.tfstate aws_s3_bucket.example aws_s3_bucket.example
```

---

#### `terraform state rm`
**What it does:** Removes a resource from the state file without destroying the actual resource in the cloud.  
**When to use:** When you want Terraform to "forget" about a resource — e.g. before importing it differently, or when handing management to another tool.  
**Exam note:** ⚠️ The real AWS resource is NOT deleted. Only the state record is removed.

```bash
terraform state rm aws_s3_bucket.example
```

---

#### `terraform import`
**What it does:** Imports an existing cloud resource into Terraform state so it can be managed going forward.  
**When to use:** When adopting infrastructure that was created manually or by another tool.  
**Exam note:** ⚠️ Does NOT generate `.tf` configuration code — you must write the resource block yourself first.

```bash
terraform import aws_s3_bucket.example my-existing-bucket-name
terraform import aws_instance.web i-1234567890abcdef0
```

---

### 🟣 Workspace & Environment Commands

#### `terraform workspace`
**What it does:** Manages multiple isolated state environments (workspaces) within the same configuration.  
**When to use:** To maintain separate states for `dev`, `staging`, and `production` without duplicating code.

```bash
terraform workspace list           # list all workspaces
terraform workspace new staging    # create a new workspace
terraform workspace select dev     # switch to a workspace
terraform workspace show           # show current workspace
terraform workspace delete staging # delete a workspace
```

---

### 🟤 Utility Commands

#### `terraform providers`
**What it does:** Displays all providers required by the current configuration, including version constraints.

```bash
terraform providers
terraform providers lock   # update the dependency lock file
```

---

#### `terraform login`
**What it does:** Authenticates the Terraform CLI with Terraform Cloud, storing credentials locally.  
**When to use:** Before using Terraform Cloud as a remote backend or for remote operations.

```bash
terraform login
terraform login app.terraform.io
```

---

#### `terraform graph`
**What it does:** Generates a dependency graph of all resources in DOT format, which can be visualised with Graphviz.  
**When to use:** To understand resource dependencies and troubleshoot ordering issues.

```bash
terraform graph | dot -Tsvg > graph.svg
```

---

## 🎲 Non-Cloud Provider Deep Dive

Not all Terraform providers interact with cloud services. The `random` and `local` providers are common exam topics and have important behavioural differences to understand.

### Complete Example

```hcl
# ── Random Provider ──────────────────────────────────────────
resource "random_id" "server_id" {
  byte_length = 8
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "random_pet" "server_name" {}

# ── Local Provider ────────────────────────────────────────────
resource "local_file" "config_output" {
  content  = "Server ID: ${random_id.server_id.hex}\nServer Name: ${random_pet.server_name.id}"
  filename = "${path.module}/server-config.txt"
}

# ── Output (sensitive) ───────────────────────────────────────
output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}
```

---

### 🎲 The `random` Provider

| Resource | What It Generates | Common Use Case |
|---|---|---|
| `random_id` | Random byte sequence (hex, base64, decimal) | Unique suffix for resource names |
| `random_password` | Cryptographically random string | Database passwords, API keys |
| `random_pet` | Human-readable random name (e.g. `happy-fox`) | Friendly resource naming |
| `random_string` | Configurable random string | Custom ID formats |
| `random_integer` | Random integer in a range | Port numbers, random selection |

**Key exam behaviours:**
- Values are generated **once** on first `apply` and stored in state
- Values only change if the resource is **tainted or recreated** — not on every apply
- This makes `random` values **deterministic within a lifecycle** — ideal for stable unique identifiers
- `random_password` with `sensitive = true` means the value is hidden in plan/apply output but still stored in state

---

### 📁 The `local` Provider

| Resource | What It Does |
|---|---|
| `local_file` | Creates a file on the local machine running Terraform |
| `local_sensitive_file` | Same as `local_file` but marks content as sensitive |

**Key exam behaviours:**
- Files are created on the machine **running Terraform** — not on any remote server
- In a CI/CD pipeline, the file is created on the CI runner
- In Terraform Cloud remote operations, the file is created on the Terraform Cloud runner
- Useful for generating config files, scripts, or SSH keys as part of a deployment

**`path.module` explained:**

```hcl
filename = "${path.module}/server-config.txt"
```

`path.module` is a built-in Terraform expression that resolves to the directory containing the current `.tf` file. This ensures the output file is always created relative to the module, not the working directory.

---

## 🧠 Key Concepts to Remember for the Exam

These are the behavioural rules that are most commonly tested:

### State Behaviour
- State is the **source of truth** — Terraform compares config against state, not against live infrastructure directly
- `terraform plan` and `apply` both refresh state by default (can be disabled with `-refresh=false`)
- `state rm` removes tracking but does NOT delete the real resource
- `state mv` renames in state but does NOT recreate the real resource
- `import` brings a resource into state but does NOT write `.tf` configuration

### Command Behaviour
- `validate` — syntax only, no cloud calls
- `fmt` — formatting only, no logic check
- `output` — reads state only, no cloud calls
- `plan -out=file` → `apply file` — skips the confirmation prompt

### Terraform Cloud
- **Workspace variables** come in two types: Terraform variables (equivalent to `var.x`) and Environment variables (e.g. `AWS_ACCESS_KEY_ID`)
- **Sentinel** runs as a policy-as-code gate between `plan` and `apply` — it can soft-fail (warn) or hard-fail (block)
- **Remote operations** mean plan and apply run on Terraform Cloud infrastructure, not your local machine

### Modules
- Modules do NOT inherit the parent's provider configuration by default
- Output values must be explicitly declared to be accessible outside the module
- `source` can be a local path (`./modules/vpc`), Terraform Registry (`hashicorp/vpc/aws`), or a Git URL

### Workspaces
- Each workspace has its own state file
- The default workspace is always named `default`
- Reference the current workspace in config with `terraform.workspace`

---

## 🪞 Reflection

> *"This exercise made it clear that while my foundation is strong, areas like Terraform Cloud, advanced CLI usage, and configuration patterns still need reinforcement. The biggest takeaway is that the exam focuses heavily on understanding Terraform behaviour — especially around state and command outcomes — rather than just syntax."*

### What went well
- All foundational domains (IaC concepts, basics, state, modules) are solid from the hands-on labs in previous days
- The CLI self-test revealed specific command gaps rather than broad weaknesses — which is much easier to fix
- Building the study plan with time estimates made the remaining preparation feel manageable

### What needs more work
- Terraform Cloud workspace and variable behaviour
- Sentinel policy syntax and the soft-fail vs hard-fail distinction
- Complex `for` expressions and dynamic blocks in HCL

### Action items before the exam
- [ ] Run every `terraform state` command against a live test environment
- [ ] Write 5 `for` expression examples covering lists, maps, and filtering
- [ ] Create two Sentinel policies — one soft-fail, one hard-fail
- [ ] Complete the full set of official HashiCorp sample questions
- [ ] Review all workspace variable type differences in Terraform Cloud docs

---

## 📚 Resources

- [HashiCorp Terraform Associate Exam Study Guide](https://developer.hashicorp.com/terraform/tutorials/certification-003/associate-study-003)
- [Official Exam Review — Terraform Associate 003](https://developer.hashicorp.com/terraform/tutorials/certification-003/associate-review-003)
- [Terraform CLI Commands Reference](https://developer.hashicorp.com/terraform/cli/commands)
- [Terraform State Documentation](https://developer.hashicorp.com/terraform/language/state)
- [Random Provider Registry](https://registry.terraform.io/providers/hashicorp/random/latest/docs)
- [Local Provider Registry](https://registry.terraform.io/providers/hashicorp/local/latest/docs)
- [Sentinel Policy Language](https://docs.hashicorp.com/sentinel)
- [Terraform Cloud Workspaces](https://developer.hashicorp.com/terraform/cloud-docs/workspaces)

---

## 🔗 Part of the 30-Day Terraform Challenge

| Day | Topic |
|---|---|
| Day 12 | Zero-Downtime Deployments (`create_before_destroy`, Blue/Green) |
| Day 13 | Sensitive Data with AWS Secrets Manager + Remote State |
| Day 14 | Multi-Region AWS Deployments |
| Day 15 | EKS Cluster + Kubernetes + Docker Provider |
| Day 16 | Production-Grade Infrastructure (Tagging, Lifecycle, Validation) |
| Day 21 | CI/CD with Terraform Cloud + GitHub Actions |
| **Day 23** | **Exam Preparation — Domain Audit & CLI Mastery ← You are here** |

---

<div align="center">

**Author:** Kongeso Emmanuel
**Challenge:** 30-Day Terraform Challenge
**Focus:** HashiCorp Terraform Associate Exam Preparation

⭐ *If this helped you, consider starring the repo!*

</div>
