# 🚀 Day 1 – Introduction to Terraform & Infrastructure as Code (IaC)

## 🎯 Objective

Today's goal was to understand the fundamentals of Infrastructure as Code (IaC) and set up a complete Terraform development environment. This included installing the required tools, configuring AWS access, and learning how Terraform fits into modern DevOps workflows.

---

## 🔧 Tools Used

- Terraform
- AWS CLI
- Amazon Web Services (AWS)
- Visual Studio Code
- HashiCorp Terraform Extension
- AWS Toolkit for VS Code
- Windows Terminal / Command Prompt

---

## 📌 Steps I Took

### Step 1: Created an AWS Account

Before working with Terraform, I needed a cloud provider. I created an **AWS account** using the AWS Free Tier, which is sufficient for learning and experimentation.

> Terraform will later use AWS to **provision infrastructure automatically**.

---

### Step 2: Installed Terraform on Windows

I downloaded Terraform from the **HashiCorp official website**, extracted the binary, and added it to my **system PATH** so it could be used globally from the terminal.

After installation, I verified it using:

```bash
terraform version
```

**Output:**
```
Terraform v1.14.7
on windows_386
```

---

### Step 3: Installed AWS CLI

Terraform interacts with AWS through credentials configured in the **AWS CLI**.

I installed AWS CLI and verified it using:

```bash
aws --version
```

**Output:**
```
aws-cli/2.32.2 Python/3.13.9 Windows/11 exe/AMD64
```

---

### Step 4: Configured AWS Credentials

I configured my AWS credentials so Terraform can authenticate with my AWS account.

```bash
aws configure
```

**Prompts filled in:**
```
AWS Access Key ID [None]: <your-access-key-id>
AWS Secret Access Key [None]: <your-secret-access-key>
Default region name [None]: eu-west-1
Default output format [None]: json
```

---

### Step 5: Verified AWS Authentication

After configuration, I tested whether my local machine could successfully communicate with AWS.

```bash
aws sts get-caller-identity
```

**Output:**
```json
{
  "UserId": "AIDAVSHYVF53JG6YSQEWT",
  "Account": "382773571446",
  "Arn": "arn:aws:iam::382773571446:user/gitauAdmin"
}
```

---

### Step 6: Installed VS Code Extensions

To make Terraform development easier, I installed the following extensions in **VS Code**:

- **HashiCorp Terraform Extension**
- **AWS Toolkit**

These extensions provide:
- Syntax highlighting
- Terraform formatting
- AWS resource support

---

## 💡 Key Learnings

- **Infrastructure as Code (IaC)** allows infrastructure to be managed using code instead of manual configuration.
- Terraform uses a **declarative approach** — you describe the desired state and Terraform handles the steps to reach it.
- Terraform can manage infrastructure across **multiple cloud providers** like AWS, Azure, and Google Cloud.
- Proper **environment setup** is critical before starting infrastructure automation.
