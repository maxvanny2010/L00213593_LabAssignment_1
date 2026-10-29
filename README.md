# ATU CloudFormation Lab

[![Launch AWS Cloud Website](https://img.shields.io/badge/AWS_CLOUD-LAUNCH_WEBSITE-FF9900?style=for-the-badge&labelColor=232F3E&logo=amazonaws&logoColor=white)](https://d2caxeghfi5itf.cloudfront.net/)

**Atlantic Technological University (ATU)**
**Programme:** Postgraduate Diploma in Computing in DevOps
**Module:** Infrastructure as Code for DevOps Pipelines
**Lecturer:** Ruth Lennon
**Student:** Maksym Voronianskyi
**Student Number:** L00213593
**Academic Year:** 2026/2027

## Project Overview

This project explores AWS Infrastructure as Code using CloudFormation, with a static website, a Java 21 serverless
message API, a DynamoDB database, and a containerised Java application on EC2. Development follows an iterative
Git/GitHub workflow; implementation decisions, tests, failures and recovery steps are retained in
the [development history](#development-history).

## Architecture

| Layer                  | AWS resources                                                      | Purpose                                                                   |
|------------------------|--------------------------------------------------------------------|---------------------------------------------------------------------------|
| Web                    | Private S3 bucket, CloudFront OAC                                  | HTTPS website delivery without direct public S3 access                    |
| Serverless application | API Gateway HTTP API, Java 21 Lambda                               | Public `GET /message` and IAM-protected `POST /message`                   |
| Data                   | DynamoDB                                                           | Message storage shared by Lambda and EC2 Java applications                |
| EC2 application        | VPC, subnet, Security Group, IAM Instance Profile, EC2, Docker     | Separate Java HTTP server; private localhost health and message endpoints |
| Automation             | CloudFormation, Maven, GitHub Actions, ECR Public, Systems Manager | IaC provisioning, builds, container publication and verification          |

The EC2 application uses the published image
`public.ecr.aws/e1c9y1q6/atu-ec2-app:fc4b4b71c4c1a131b6be47e4e48534ad37f7e921`. The public image is reused when
deploying into another AWS account. The EC2 application has no inbound Security Group access; its local endpoints are
verified with AWS Systems Manager.

## Deployment in Your Own AWS Account

The two supported procedures target a **clean AWS account/Region** with no existing project stacks. They provision AWS
resources which may incur charges. Use a properly authorized IAM identity; do not use root credentials for routine
deployment.

**Prerequisites:** Ubuntu 24.04 on WSL2 (tested), AWS CLI v2 for Linux, Java 21, Maven, `curl`, and network access to
Maven and Amazon ECR Public. Native Linux Bash is expected to be compatible but has not been independently tested. **Git
Bash on Windows is not a verified environment:** the scripts use Unix temporary paths with AWS CLI `file://` arguments.
Set `AWS_REGION` for the target deployment (default: **`eu-west-1`**).

**Deployment IAM permissions:** Use an authenticated **non-root IAM identity** in the target account with permission to:

- Manage CloudFormation stacks and change sets, including validation, descriptions, exports, resource inspection,
  creation, updates and deletion.
- Create, configure, inspect and delete the lab's S3 buckets and objects (including versions and delete markers) and
  CloudFront distribution, Origin Access Control and associated bucket policy.
- Manage the lab's Lambda function, CloudWatch Logs log group, API Gateway HTTP API, DynamoDB table, VPC/network
  resources and EC2 instance.
- Create and delete the project IAM roles, policies and instance profile, including `iam:PassRole` for the Lambda and
  EC2 service roles, and read the public Amazon Linux AMI parameter from SSM.
- Run the verification commands using AWS Systems Manager (for example `ssm:DescribeInstanceInformation`,
  `ssm:SendCommand` and `ssm:GetCommandInvocation`) and use `dynamodb:PutItem` when `--seed-demo` is selected.

These are **permission categories, not a ready-to-attach least-privilege IAM policy**. The precise action/resource
scopes depend on the target account and its permission boundaries; an IAM administrator should grant the needed access
before deployment. `AdministratorAccess` was used for isolated testing, but is **not a requirement or a recommended
long-term permission**. The seven-stack fresh deployment does not create the optional IAM bootstrap or ECR repository.
The deployment identity must already have its permissions before running the script.

Authenticate to the **target** AWS account and verify the selected identity:

```bash
aws sts get-caller-identity
```

### Option 1 — Manual Deployment

Follow the **[Manual AWS Deployment Guide](docs/MANUAL_DEPLOYMENT.md)** to execute the CloudFormation, Maven, S3 and
verification commands individually, in dependency order. This is the recommended option for understanding how the
resources are provisioned.

### Option 2 — Automated Deployment

```bash
git clone https://github.com/maxvanny2010/L00213593_LabAssignment_1.git
cd L00213593_LabAssignment_1
bash scripts/deploy.sh
```

The script checks AWS identity, requires a `DEPLOY` confirmation, refuses to overwrite existing lab stacks, packages the
Lambda JAR, deploys the infrastructure, generates the account-specific website API configuration and verifies the
application. ECR repository creation, GitHub OIDC and the optional developer IAM bootstrap are not part of this
fresh-account deployment.

**Verification status:** On 28 and 29 October 2026, complete automated deployments succeeded in a second Region (
`eu-west-2`) under temporary IAM users in the same AWS account. Seven stacks reached `CREATE_COMPLETE`; Java build, API
GET, SSM Docker/Java checks, website loading, demo data seeding and cleanup passed. A deployment in a completely
separate AWS account has not been verified. See [Testing](docs/DESIGN_AND_TESTING.md) for details.

### Demonstration Data and Cleanup

For a clean AWS Region, `bash scripts/deploy.sh` deploys the infrastructure without adding sample data. To populate one
demonstration record in DynamoDB and verify that it appears through the public GET endpoint, use:

```bash
bash scripts/deploy.sh --seed-demo
```

After deployment, open the CloudFront website and click **Load Messages**. The demonstration message is
`CloudFormation deployment successful!`. The optional seed is written using the deploying IAM identity (
`dynamodb:PutItem` required); the public POST endpoint remains IAM-protected. The seed option cannot be used on an
already deployed stack because `deploy.sh` intentionally refuses existing project stacks.

**Cleanup (any AWS account and supported Region):** `scripts/destroy.sh` selects the target AWS account from the
authenticated AWS CLI identity and requires an explicitly set `AWS_REGION`. It refuses root credentials and checks the
expected project ownership tags on each stack before deleting. **Data loss is permanent** (including DynamoDB and both
S3 buckets). Review the printed target account, Region and stack names before entering the dynamically generated
confirmation phrase. For example:

```bash
export AWS_PROFILE=your-iam-profile
export AWS_REGION=eu-west-2
bash scripts/destroy.sh
```

The confirmation phrase is `DELETE-<account-id>-<region>`, using the actual target values printed by the script. Run
cleanup only for a dedicated lab deployment; do not use it against shared resources. AWS charges may continue for
unrelated resources.

## Project Files

```text
infrastructure/               CloudFormation templates
  static-website.yaml
  lambda-artifacts.yaml
  three-tier.yaml
  bootstrap/                  Optional developer IAM bootstrap
  ec2/                        Networking, IAM, instance, ECR and OIDC
common/                       Reusable Java business logic
lambda-app/                   Java Lambda implementation
ec2-app/                      Java HTTP application
web/                          Static website and JavaScript
scripts/deploy.sh             Automated clean-region deployment (optional demo seed)
scripts/destroy.sh            Guarded cleanup of selected account/Region lab stacks
docs/                         Detailed documentation and screenshots
```

## Development History

Each documented iteration links to the relevant GitHub Pull Request where available. See
the [PR index](docs/PULL_REQUESTS.md) for project changes through PR #31. PR #31 was merged; post-audit remediation is
prepared on the `fix/32-final-audit-remediation` branch.

The full implementation log is preserved without summarising away individual steps, test results, commands or design
decisions:

- [Iterations 0–16: S3, CloudFront, Lambda, API Gateway, DynamoDB and web integration](docs/DEVELOPMENT_00-16.md)
- [Iterations 17–28: Shared Java modules, EC2 infrastructure, IAM and Systems Manager](docs/DEVELOPMENT_17-28.md)
- [Iterations 29.1–29.8.8: Docker, CI/CD, ECR and cross-account reproducibility](docs/DEVELOPMENT_29.md)
- [Design decisions, testing summary and Part A(b) conclusion](docs/DESIGN_AND_TESTING.md)

## Documentation

- [Pull Request History (PR #1–#31)](docs/PULL_REQUESTS.md)

- [Manual AWS Deployment Guide](docs/MANUAL_DEPLOYMENT.md)
- [Complete bibliography with original reference numbers](docs/REFERENCES.md)

## References

Technical details and decisions are supported by the [full reference list](docs/REFERENCES.md), with original citation
numbers retained.
