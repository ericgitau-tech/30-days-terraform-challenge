# 📘 30-Day Terraform Challenge — Day 28

## Exam Preparation: Practice Exams 1 & 2 | HashiCorp Terraform Associate Certification

---

> 🎯 **Challenge Goal:** Complete a full 30-day structured Terraform learning journey, culminating in the HashiCorp Terraform Associate Certification — built through daily hands-on labs, real-world scenarios, and rigorous self-assessment.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Objectives](#objectives)
- [Exam Results](#exam-results)
- [Domain Performance Analysis](#domain-performance-analysis)
- [Wrong-Answer Analysis](#wrong-answer-analysis)
- [Hands-On Revision](#hands-on-revision)
- [Pattern Recognition & Key Learnings](#pattern-recognition--key-learnings)
- [Roadmap: Days 29 & 30](#roadmap-days-29--30)
- [Conclusion](#conclusion)
- [Connect](#connect)

---

## 🧭 Overview

On **Day 28** of the 30-Day Terraform Challenge, I simulated real exam conditions by completing **two full-length timed practice exams** (57 questions each, 60 minutes each). This lab was designed to benchmark readiness for the **HashiCorp Terraform Associate Certification**, identify knowledge gaps, and build a targeted revision plan for the final stretch.

This isn't just studying — this is **deliberate, measurable preparation**.

---

## 🎯 Objectives

- ✅ Simulate exam conditions with two back-to-back timed practice exams
- ✅ Analyze every incorrect answer for root cause
- ✅ Identify weak domains using accuracy thresholds (< 70%)
- ✅ Reinforce understanding with hands-on Terraform commands
- ✅ Document a structured improvement plan for Days 29–30

---

## 📊 Exam Results

| Exam | Score | Percentage | Condition |
|------|-------|------------|-----------|
| Practice Exam 1 | 41 / 57 | **72%** | Timed, no resources |
| Practice Exam 2 | 45 / 57 | **79%** | Timed, different source |

> 📈 **+7% improvement** from Exam 1 to Exam 2, demonstrating active learning during the session and effective warm-up.

---

## 🏗️ Domain Performance Analysis

A granular breakdown of accuracy by exam domain — used to pinpoint exactly where focused effort is needed.

| Domain | Attempted | Correct | Accuracy | Status |
|---|---|---|---|---|
| IaC Concepts | 6 | 5 | 83% | ✅ Strong |
| Configuration Language | 6 | 5 | 83% | ✅ Strong |
| Terraform Purpose | 5 | 4 | 80% | ✅ Strong |
| Terraform Basics | 8 | 6 | 75% | ✅ Passing |
| Core Workflow | 7 | 5 | 71% | ✅ Passing |
| Terraform Cloud | 6 | 4 | 67% | ⚠️ Weak |
| Modules | 6 | 4 | 67% | ⚠️ Weak |
| Terraform CLI | 7 | 4 | 57% | ❌ Critical |
| State Management | 6 | 3 | 50% | ❌ Critical |

### 🚨 Weak Domains Flagged for Intensive Review
- **State Management** — 50% *(highest priority)*
- **Terraform CLI** — 57%
- **Modules** — 67%
- **Terraform Cloud** — 67%

---

## 🔍 Wrong-Answer Analysis

Each incorrect answer was reviewed systematically: topic identified, error type classified, and a corrective hands-on action performed.

| # | Topic | My Answer | Correct Answer | Error Type | Fix Applied |
|---|-------|-----------|----------------|------------|-------------|
| 1 | `terraform state rm` | Removes resource from config | Removes resource from **state only** | Concept confusion | Ran `terraform state rm` on test resource |
| 2 | `terraform init` | Applies configuration | Initializes working directory | Command confusion | Executed `terraform init` in live project |
| 3 | Modules usage | Only reusable within same file | Reusable across **all** configurations | Scope misunderstanding | Created and called a reusable module |
| 4 | `terraform plan` | Applies changes | Shows **execution plan** | Misinterpreted behavior | Ran `terraform plan` before apply |
| 5 | State file purpose | Stores configuration | Stores **infrastructure state** | Conceptual gap | Used `terraform state list` to observe |

> 💡 **Key Insight:** Most errors stem from **confusing similarly-named commands** and **state vs. configuration** distinctions — a common pattern in Terraform certification exams.

---

## 🛠️ Hands-On Revision

All weak areas were reinforced with direct CLI practice — no theory without action.

### State Management Commands
```bash
# List all resources tracked in state
terraform state list

# Inspect a specific resource in state
terraform state show <resource_address>

# Remove a resource from state (without destroying it)
terraform state rm <resource_address>
```

### Core CLI Workflow
```bash
# Initialize the working directory and download providers
terraform init

# Preview planned infrastructure changes
terraform plan

# Apply changes to match the desired configuration
terraform apply
```

### Module Practice

Created a reusable module structure and called it from the root configuration:

```hcl
# modules/server/main.tf
resource "aws_instance" "server" {
  ami           = var.ami
  instance_type = var.instance_type
}

# root/main.tf — calling the module
module "web_server" {
  source        = "./modules/server"
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}
```

---

## 🧠 Pattern Recognition & Key Learnings

After reviewing all wrong answers across both exams, three recurring patterns emerged:

1. **State ≠ Configuration** — Terraform state tracks *real infrastructure*; configuration files describe *desired infrastructure*. These are fundamentally different concepts.

2. **Command purpose specificity** — `init`, `plan`, `apply`, `destroy` each have a single, precise responsibility. Confusing any two is a common trap in exam scenarios.

3. **Modules scope** — Modules are not file-scoped. They are reusable, composable, and callable from any configuration — this is one of Terraform's greatest strengths.

---

## 🗺️ Roadmap: Days 29 & 30

With only two days remaining, effort will be laser-focused:

| Day | Focus Area | Goal |
|-----|------------|------|
| **Day 29** | Terraform CLI & State Management | Achieve > 80% accuracy in both domains |
| **Day 29** | Module creation & composition | Build and call 2 custom modules end-to-end |
| **Day 30** | Terraform Cloud features | Review workspaces, remote runs, sentinel policies |
| **Day 30** | Full mock exam | Target ≥ 85% under timed, closed-resource conditions |

---

## ✅ Conclusion

Day 28 was a turning point in this challenge — not just studying Terraform, but **measuring readiness under pressure**. The structured review process converted vague uncertainty into concrete, actionable tasks. Going from 72% to 79% within a single session confirms the method works.

The remaining two days will be used to eliminate the weakest domains entirely and walk into the final exam with confidence.

> *"You can't improve what you don't measure."* — This lab proved exactly that.

---



---

<div align="center">

**⭐ Star this repo if you find it useful — and follow along for the final two days!**

![Terraform](https://img.shields.io/badge/Terraform-Associate-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Day](https://img.shields.io/badge/Day-28%20of%2030-orange?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-In%20Progress-blue?style=for-the-badge)

</div>
