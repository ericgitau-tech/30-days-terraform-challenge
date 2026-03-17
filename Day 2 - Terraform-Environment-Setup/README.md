# Day 2 – Setting Up the Terraform Development Environment

> **Goal:** Fully configure a Terraform development environment to provision real infrastructure on AWS — including IAM credential setup, tool installation, and end-to-end validation.

---

## 🛠️ Tools Used

| Tool | Purpose |
|------|---------|
| **Terraform v1.14.7** | Infrastructure as Code engine |
| **AWS CLI v2.32.2** | Bridge between local tools and AWS |
| **IAM (Identity and Access Management)** | Secure, scoped AWS credentials |
| **Visual Studio Code** | Primary IDE |
| **HashiCorp Terraform Extension** | Syntax highlighting, IntelliSense, formatting |
| **AWS Toolkit for VS Code** | AWS resource integration inside the editor |
| **Windows Terminal / PowerShell** | Command execution |

---

## 📋 Steps

### Step 1 — Understand Terraform Authentication

Terraform does **not** log into AWS directly. It delegates authentication to the **AWS CLI**, which reads credentials stored locally at:

```
~/.aws/credentials
```

These credentials come from a dedicated **IAM user** with programmatic access. This keeps root credentials out of any automation pipeline.

---

### Step 2 — Create a Dedicated IAM User

Using root credentials for automation is a security anti-pattern. A dedicated IAM user was created specifically for Terraform.

**Steps taken in the AWS Console:**

1. Open **IAM → Users**
2. Create a new user
3. Enable **Programmatic Access**
4. Attach appropriate permissions (scoped for learning purposes)

AWS generates two values on user creation — **Access Key ID** and **Secret Access Key** — which are used to configure the CLI. These are only shown once.

![IAM Access Key Retrieval](images/iam_keys.png)

> ⚠️ **Security reminder:** Never store access keys in plain text, a code repository, or source code. Download the `.csv` immediately and store it securely.

---

### Step 3 — Install and Verify Terraform

Terraform was installed on Windows and verified via PowerShell:

```powershell
terraform version
# Terraform v1.14.7
# on windows_386
```

---

### Step 4 — Install and Verify AWS CLI

The AWS CLI installation was confirmed:

```powershell
aws --version
# aws-cli/2.32.2 Python/3.13.9 Windows/11 exe/AMD64
```

---

### Step 5 — Configure AWS CLI Credentials

The CLI was configured using the IAM credentials from Step 2:

```powershell
aws configure
```

Inputs provided during configuration:

| Prompt | Value |
|--------|-------|
| AWS Access Key ID | `AKIAVSHYVF53F72X4XH7` |
| AWS Secret Access Key | `********************` |
| Default region name | `eu-west-1` |
| Default output format | `json` |

---

### Step 6 — Verify AWS Identity

After configuring credentials, connectivity to AWS was validated:

```powershell
aws sts get-caller-identity
```

**Expected output:**
```json
{
    "UserId": "AIDAVSHYVF53JG6YSQEWT",
    "Account": "382773571446",
    "Arn": "arn:aws:iam::382773571446:user/gitauAdmin"
}
```

A successful response confirms Terraform can now authenticate with AWS.

---

### Step 7 — Verify AWS Configuration

A final config audit was run to confirm all values are correctly stored:

```powershell
aws configure list
```

**Output:**

```
      Name                    Value             Type    Location
      ----                    -----             ----    --------
   profile                <not set>             None    None
access_key     ****************4XH7 shared-credentials-file
secret_key     ****************Ykjx shared-credentials-file
    region                eu-west-1      config-file    ~/.aws/config
```

![Terminal — CLI Configuration, Identity Verification & Config Audit](images/terminal_steps.png)

---

### Step 8 — Install VS Code Extensions

Two extensions were installed to improve the Terraform development workflow:

- **HashiCorp Terraform** — syntax highlighting, IntelliSense, auto-formatting, module explorer
- **AWS Toolkit** — CodeCatalyst, Infrastructure Composer, Lambda, S3, CloudWatch Logs, and more

![VS Code Extensions — HashiCorp Terraform and AWS Toolkit](images/vscode_extensions.png)

---

## 💡 Key Learnings

- Terraform authenticates with AWS through **AWS CLI credentials** — it does not interact with AWS directly.
- Using **IAM users instead of root credentials** is a foundational cloud security practice.
- The **AWS CLI acts as a bridge** between local tools (Terraform, VS Code) and AWS services.
- Proper environment setup and validation prevents silent failures during deployments.
- Running `aws sts get-caller-identity` and `aws configure list` are essential sanity checks before writing any Terraform code.

---

## 🧠 Reflection

Day 2 reinforced that environment setup is not a formality — it is the **foundation for all automation work** that follows. Details like scoped IAM permissions, credential file hygiene, and verification commands are the same habits used in real production environments.

With tools configured and validated, the next step is writing actual Terraform configuration files and watching infrastructure get provisioned from code.

---

*Day 2 of Terraform Learning Journal — Eric Gitau*
