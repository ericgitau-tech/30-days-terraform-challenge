# Day 30 — Final Exam Prep, Fill-in-the-Blank, and Challenge Complete

> **30-Day Terraform Challenge** | Capstone Day — Certification Ready

---

## Practice Exam 5 Results

**Score: 51/57 (89%)**

| Comparison | Exam 1 | Exam 5 | Change |
|---|---|---|---|
| Score | 36/57 | 51/57 | +15 questions |
| Percentage | 63% | 89% | +26 points |

The jump from 63% to 89% across five exams reflects what consistent daily practice actually produces. Exam 1 exposed how much I was pattern-matching keywords without understanding the underlying mechanics — particularly around state management, module composition, and provider configuration. By Exam 5 those areas are strengths. The 6 questions I still missed were clustered in two areas: Terraform Cloud workspace-level permissions (a detail I consistently underweight during study) and the precise behaviour of `terraform refresh` vs `terraform apply -refresh-only`. Both are on the review list before exam day.

---

## Five-Exam Score Summary

| Exam | Score | % |
|---|---|---|
| Exam 1 | 36/57 | 63% |
| Exam 2 | 41/57 | 72% |
| Exam 3 | 46/57 | 81% |
| Exam 4 | 49/57 | 86% |
| Exam 5 | 51/57 | 89% |

The progression is not coincidental — each exam revealed specific gaps that the next day's lab work closed. Exam 2 was humbling (the jump was smaller than expected) because I had been reading without building. Every exam from Exam 3 onward corresponded to weeks where I was applying concepts with actual Terraform code rather than just reviewing documentation.

---

## Fill-in-the-Blank: My Answers Before Checking

These are the answers I wrote from memory before verifying:

1. `terraform fmt` — the command to check formatting without making changes is `terraform fmt`
2. `prevent_destroy` — the meta-argument that prevents resource destruction
3. `terraform.workspace` — to reference the current workspace name
4. `encrypt` — the S3 backend argument for server-side encryption
5. `set` — `for_each` accepts a map or a set of strings
6. `rm` — `terraform state rm` removes a resource from state without destroying it
7. `3.0` — `~> 2.0` allows >= 2.0 and < 3.0
8. `existing` / `managed` — data reads existing; resource manages
9. `.terraform.lock.hcl` — the dependency lock file that pins provider versions
10. `myplan.tfplan` — `terraform apply myplan.tfplan`

### Results After Verification

| # | My Answer | Correct | Result |
|---|---|---|---|
| 1 | `terraform fmt` | `terraform fmt` | ✅ PASS |
| 2 | `prevent_destroy` | `prevent_destroy` | ✅ PASS |
| 3 | `terraform.workspace` | `terraform.workspace` | ✅ PASS |
| 4 | `encrypt` | `encrypt` | ✅ PASS |
| 5 | `set` | `set` (of strings) | ✅ PASS |
| 6 | `rm` | `rm` | ✅ PASS |
| 7 | `3.0` | `3.0` | ✅ PASS |
| 8 | `existing` / `managed` | `existing` / `managed` | ✅ PASS |
| 9 | `.terraform.lock.hcl` | `.terraform.lock.hcl` | ✅ PASS |
| 10 | `myplan.tfplan` | `myplan.tfplan` | ✅ PASS |

**10/10**

### Clarifications for Any Question I Was Uncertain About

**Question 1 — `terraform fmt` vs `terraform validate`**
`terraform fmt` reformats code to match canonical HCL style and can optionally check-only mode with `-check`. `terraform validate` checks configuration syntax and internal consistency. They do different jobs and are both part of a pre-commit or CI pipeline. Easy to conflate on an exam question if the wording is "verify configuration is syntactically correct" (that's `validate`, not `fmt`).

**Question 7 — version constraint `~> 2.0`**
The pessimistic constraint operator `~>` allows the rightmost version component to increment. `~> 2.0` means >= 2.0, < 3.0. `~> 2.4` means >= 2.4, < 3.0. `~> 2.4.1` means >= 2.4.1, < 2.5.0. The scope of what "increments" is determined by how many components are in the version string — an easy exam trap.

**Question 9 — lock file vs state file**
The `.terraform.lock.hcl` file records the exact provider versions and hashes selected by `terraform init`. It should be committed to version control so the entire team uses identical providers. The `terraform.tfstate` file records deployed infrastructure state — it should never be committed (contains sensitive values, causes merge conflicts, must be locked during use).

---

## Final Readiness Check — All Ten Questions

**1. What does `terraform init` do to your `.terraform` directory?**

`terraform init` downloads the providers declared in `required_providers`, installs them into `.terraform/providers`, initialises the backend (configuring where state is stored), and installs any remote modules into `.terraform/modules`. It also creates or updates the `.terraform.lock.hcl` file to record the exact provider versions selected. The `.terraform` directory is local and should not be committed to version control.

**2. What is the difference between `terraform.tfstate` and `terraform.tfstate.backup`?**

`terraform.tfstate` is the current state file — Terraform's record of what resources exist and their current attribute values. `terraform.tfstate.backup` is a copy of the previous state, automatically created before any operation that modifies state. The backup exists so you can manually recover if the current state becomes corrupted. With a remote backend (S3 + DynamoDB), versioning on the S3 bucket replaces the need for the local backup file.

**3. Why should you never commit `terraform.tfstate` to version control?**

Three reasons: First, state files often contain sensitive values in plaintext — database passwords, private keys, connection strings that were passed as resource attributes. Second, state files are not merge-friendly — concurrent modifications from multiple team members will produce conflicts that Git cannot resolve automatically, and the resulting merged file will corrupt your state. Third, state should be locked during operations so only one `apply` runs at a time — Git provides no locking mechanism. Remote backends (S3 + DynamoDB) solve all three problems.

**4. What does `depends_on` do and when should you use it?**

`depends_on` creates an explicit dependency between resources or modules that Terraform cannot infer automatically from configuration references. Terraform normally builds its dependency graph by tracking which resources reference attributes of other resources. `depends_on` is needed when a dependency exists that is not expressed through attribute references — for example, when an IAM policy must be fully propagated before a Lambda function can execute, or when one module must complete before another begins even though they share no outputs. Use it sparingly; overuse hides design problems in your configuration.

**5. What is the difference between a `variable` block and a `locals` block?**

A `variable` block declares an input that is provided from outside the module — from `terraform.tfvars`, command-line `-var` flags, environment variables, or a calling module. It can have a type constraint, description, and default value. A `locals` block declares computed values internal to the module — expressions derived from variables, resource attributes, or other locals. Locals cannot be overridden from outside the module. Variables are the module's public interface; locals are private intermediate computations.

**6. What happens if you run `terraform apply` and the state file has been modified by another team member since your last `terraform plan`?**

If using a remote backend with DynamoDB locking, Terraform will attempt to acquire the state lock before running the apply. If another operation holds the lock, Terraform exits with a lock error and you must wait or force-unlock. If the lock is not held but the state has changed since your plan, Terraform runs a refresh as part of the apply to sync its view with reality before making changes. This is why `terraform plan` output can diverge from what `terraform apply` actually does in a team environment — always apply promptly after planning, or use saved plan files.

**7. What does the `terraform graph` command output and what is it used for?**

`terraform graph` outputs the dependency graph of the current configuration in DOT format — a graph description language that can be rendered by tools like Graphviz. The graph shows every resource and data source as a node, with directed edges representing dependencies between them. It is used to visualise and debug the execution order Terraform will use, to identify unexpected dependencies, and to understand why a particular resource is being created before or after another.

**8. What is the Terraform Registry and what are the three types of things published there?**

The Terraform Registry (registry.terraform.io) is HashiCorp's public catalogue of reusable Terraform content. Three types of content are published: **Providers** (plugins that let Terraform manage a specific platform — AWS, Azure, GCP, Kubernetes, etc.); **Modules** (reusable, pre-built configuration packages that express common infrastructure patterns); and **Policies** (Sentinel and OPA policy sets for use with Terraform Cloud and Enterprise policy-as-code enforcement). Private registries inside Terraform Cloud / Enterprise can host all three types for internal use.

**9. What is the difference between Terraform Cloud and Terraform Enterprise?**

Both are HashiCorp's managed products that add remote state storage, remote execution, team collaboration, policy enforcement, and a UI on top of open-source Terraform. Terraform Cloud is a SaaS product hosted by HashiCorp — you sign up at app.terraform.io and your infrastructure runs on HashiCorp's servers. It has a free tier for individuals and small teams. Terraform Enterprise is a self-hosted version of the same product that organisations run on their own infrastructure (on-premises or private cloud) — typically chosen when compliance, data residency, or air-gap requirements prevent using SaaS. Terraform Enterprise includes all Terraform Cloud features plus the ability to run entirely within a private network.

**10. When a module uses `configuration_aliases`, what problem does it solve?**

Normally a module inherits exactly one provider instance of each provider type from its caller. `configuration_aliases` allows a module to declare that it requires multiple distinct instances of the same provider — for example, a module that creates resources in two different AWS regions simultaneously needs both `aws.primary` and `aws.secondary` provider instances. Without `configuration_aliases`, a module cannot formally declare this requirement, and callers have no way to know which provider aliases to pass. With `configuration_aliases`, the module's `required_providers` block explicitly lists the aliases it expects, making the interface self-documenting and enforceable.

**Readiness verdict: Ready.**

---

## 30-Day Reflection

### What changed?

Not the list of things I can do — what changed is how I think about infrastructure as a discipline.

Before this challenge, I thought of cloud infrastructure as something you configure through a console, then document after the fact. The configuration was the source of truth, and the documentation was supposed to reflect it. What I understand now is that this relationship is backwards. Code is the source of truth. The console is a window into what the code produced, not a tool for making changes. The moment you accept that, everything else in DevOps and cloud engineering starts to make sense — why state matters, why drift is a problem, why you test infrastructure the same way you test software, why a resource that exists in AWS but not in Terraform is a liability rather than a convenience.

The more subtle shift is about uncertainty. I used to be uncomfortable not knowing if something would work before running it. The `terraform plan` workflow changes that. You are not supposed to be certain before you run `apply` — you are supposed to construct a plan, read it carefully, and make a decision based on evidence. That is a more honest relationship with complex systems than pretending you know exactly what will happen. That shift in how I approach uncertainty has already changed how I read documentation, how I structure my work, and how I communicate about risk.

### What am I most proud of?

Day 27. The multi-region high availability architecture.

Not because it was the most technically impressive thing I built, but because it was the first time I built something I genuinely did not know how to build when I started the day. The Route53 failover wiring — understanding that `alb_zone_id` and `alb_dns_name` are different things, that Route53 alias records evaluate target health separately from health checks, that the data flows between five modules in a specific order that matters — none of that was clear at 9am. I had to sit with the error messages, trace the dependency chain, read the AWS documentation on ALB zone IDs, and figure out why `replicate_source_db` takes an ARN and not an ID. By the end of the day it worked, and I understood exactly why it worked. That is the thing I am proudest of — not the infrastructure, but the process of building it without a safety net.

### What comes next?

The certification is the credential, not the destination. The destination is a role where I am building and operating production infrastructure for a team that depends on it.

The most immediate application is my final year project at Kenyatta University — I am restructuring it around a Terraform-managed AWS deployment with a proper module structure, remote state, and a CI/CD pipeline instead of a click-through console setup. That is the first real thing.

Beyond that, I want to go deeper into Kubernetes infrastructure — the challenge days on EKS were the area where I felt most out of my depth, and that gap is now clearly visible to me in a way it was not before. The next focused study period is going to be Kubernetes operations and the CKA, not because the certification matters, but because I now understand what I do not know well enough to study it deliberately.

---

## Exam Logistics

- **Exam registered:** Yes — HashiCorp Terraform Associate (003) booked via the PSI exam portal
- **Format:** Online proctored
- **Preparation confirmed:**
  - Quiet room identified, desk cleared
  - Webcam and microphone tested
  - Government ID (National ID) ready
  - Exam policies reviewed — no notes, no second monitor, no phone within reach
  - Credly account created to receive badge within 24 hours of passing

---

## Message to Future Participants

If you are reading this on Day 1, here is what I wish someone had told me:

**The days you want to skip are the most important days.** There will be a day around Day 12 or Day 13 where you have a lab that is not working, you have already spent two hours on it, and you genuinely cannot see the point of continuing. Do not skip it. The frustration is not a sign that something is wrong — it is the feeling of your mental model being wrong and starting to get corrected. Push through that day and the next one becomes significantly easier.

**Read the plan output every single time.** Not skim it — read it. Every line. The number of problems I caught by actually reading `terraform plan` before running `terraform apply` is higher than I expected. The habit of careful plan review is worth more than any individual technical concept you will study.

**Build things you do not know how to build.** The challenge gives you instructions, but the real learning happens when you try to extend what you built, get it wrong, and have to figure out why. After every lab, spend 15 minutes asking "what would happen if I changed this one thing?" That question will teach you more than re-reading the same documentation.

And finally: the certification is not the point. It is evidence of the point. The point is being someone who can look at a production infrastructure problem and know how to approach it systematically. That is what 30 days of this challenge actually gives you — if you show up every day and do the work.

Good luck.

---

## Fill-in-the-Blank Quick Reference

| Question | Answer |
|---|---|
| Format check command | `terraform fmt` |
| Prevent resource destruction | `prevent_destroy = true` (in `lifecycle`) |
| Current workspace in config | `terraform.workspace` |
| S3 backend encryption argument | `encrypt = true` |
| `for_each` accepts map or… | `set` (of strings) |
| Remove from state without destroy | `terraform state rm` |
| `~> 2.0` upper bound | `< 3.0` |
| `data` block reads… | existing infrastructure |
| `resource` block manages… | managed infrastructure |
| Lock file name | `.terraform.lock.hcl` |
| Apply saved plan | `terraform apply myplan.tfplan` |

---

## Social Media Post

> 🎉 Day 30 of the 30-Day Terraform Challenge — complete. Five practice exams, 30 days of builds, modules, state management, testing, CI/CD, and a full certification prep programme. Thank you to AWS AI/ML UserGroup Kenya, Meru HashiCorp User Group, and EveOps for making this happen. Now let's go pass that exam. #30DayTerraformChallenge #TerraformChallenge #Terraform #TerraformAssociate #IaC #DevOps #AWSUserGroupKenya #MeruHashiCorp #EveOps

---

*30-Day Terraform Challenge — Complete | [Eric Gitau](https://github.com/ericgitau-tech)*
