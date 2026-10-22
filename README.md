# ATU CloudFormation Lab

[![Launch AWS Cloud Website](https://img.shields.io/badge/AWS_CLOUD-LAUNCH_WEBSITE-FF9900?style=for-the-badge&labelColor=232F3E&logo=amazonaws&logoColor=white)](https://d2caxeghfi5itf.cloudfront.net/)

**Atlantic Technological University (ATU)**

**Programme:** Postgraduate Diploma in Computing in DevOps
**Module:** Infrastructure as Code for DevOps Pipelines

**Lecturer:** Ruth Lennon  
**Student:** Maksym Voronianskyi  
**Student Number:** L00213593  
**Academic Year:** 2026/2027

---

## 1. Project Overview

This project is part of the CloudFormation Lab assignment at the Atlantic Technological University (ATU).

The main objective is to design, deploy and manage AWS infrastructure using AWS CloudFormation
and Infrastructure as Code (IaC) principles. AWS CloudFormation uses templates
to define and manage AWS resources as stacks [[1]](#ref-1).

The project will be developed in small stages. Each stage will introduce
new features, improve the infrastructure and document the changes.

Git and GitHub will be used to manage source code, track changes and organise
development through branches and Pull Requests.
This follows AWS guidance on version control and code reviews
for infrastructure templates [[2]](#ref-2).

## 2. Project Objectives

The project consists of two main parts.

### Part A(a) — Implementation Status

The static website infrastructure has been deployed and verified using AWS CloudFormation.

| Component              | Implementation                                            | Status    |
|------------------------|-----------------------------------------------------------|-----------|
| Amazon S3              | Private bucket provisioned using CloudFormation           | Completed |
| S3 Security            | Block Public Access, Bucket Policy and disabled ACLs      | Completed |
| Amazon CloudFront      | HTTPS delivery using Origin Access Control (OAC)          | Completed |
| Static Website         | HTML page deployed and accessible through CloudFront      | Completed |
| S3 Encryption          | Server-side encryption using SSE-S3 (AES256)              | Completed |
| S3 Versioning          | Previous object versions are preserved                    | Completed |
| S3 Lifecycle           | Noncurrent versions expire after 30 days                  | Completed |
| IAM Security           | Permissions restricted using least privilege              | Completed |
| Testing and Validation | CloudFormation, AWS CLI and access control tests          | Completed |
| Documentation          | README, screenshots, architecture diagram and Git history | Completed |

**Deployment Status:** Completed and verified.
**CloudFormation Stack:** `ATU-Static-Website`
**AWS Region:** `eu-west-1`

### Part A(b) — Three-Tier Architecture

**Status:** Planned.

The next stage will implement a three-tier architecture consisting of a Web Tier, Application Tier and Database Tier.

The infrastructure will be defined and deployed using AWS CloudFormation.

### Part A(b) — Three-Tier Architecture

Design and deploy a three-tier architecture consisting of:

- **Web Tier:** User interface.
- **Application Tier:** Application logic and request processing.
- **Database Tier:** Data storage and management.

The infrastructure will be managed using AWS CloudFormation.

## 3. Development Approach

The project follows an incremental development approach.

Each stage will include:

1. Creating a new Git feature branch.
2. Implementing a small change.
3. Testing the changes.
4. Documenting the implementation and design decisions.
5. Creating a Pull Request.
6. Reviewing and merging the changes into the main branch.

This approach will help maintain a clear development
history and make each improvement easier to understand.
It is consistent with AWS CloudFormation best practices
for version control, code reviews and validation [[2]](#ref-2).

## 4. Project Structure

The initial project structure is:

```text
L00213593_LabAssignment_1/
├── infrastructure/
├── web/
├── docs/
│   └── CODE_OF_CONDUCT.md
├── README.md
└── .gitignore
```

Additional files and directories will be introduced as the project develops.

## 5. Development Progress

### Iteration 0 — Project Initialisation

**Objective:** Prepare the repository and document the project objectives.

**Planned activities:**

- Initialise the Git repository.
- Create the initial project structure.
- Add the README file.
- Configure `.gitignore`.

**Next step:** Create the first static HTML page.

### Iteration 1 — Static HTML Website

**Objective:** Create a basic HTML page for the static website.

**Implementation:**

- Created `web/index.html`.
- Added the student name and student number.
- Added a project overview and infrastructure section.
- Used semantic HTML elements to organise the page.

**Design Decision:**

I decided to use plain HTML without a frontend framework.
The first part of the assignment requires a static website, so a simple HTML page is sufficient.

This approach has fewer dependencies and does not require a build process.
However, it provides fewer features than a modern frontend framework.

AWS documentation confirms that Amazon S3 can store static website content, including HTML files [[3]](#ref-3).

**Testing:**

The page was opened locally in a web browser. The project title, student name, student number and other content were
displayed correctly.

**Next Step:**

Create a CloudFormation template to provision an Amazon S3 bucket.

### Iteration 2 — S3 Infrastructure with CloudFormation

**Objective:** Define, deploy and verify a private S3 bucket using an AWS CloudFormation template.

**Implementation:**

- Created `infrastructure/static-website.yaml` with `AWS::S3::Bucket`.
- Enabled Block Public Access and `BucketOwnerEnforced` to disable ACL-based access management.
- Configured SSE-S3 encryption (`AES256`), resource tags and CloudFormation outputs.
  SSE-S3 uses Amazon S3 managed keys [[7]](#ref-7).
- Used a recognisable bucket prefix with an account-regional namespace.

**Access Control Decision:**

S3 supports Access Control Lists (ACLs) and resource policies. For this project,
ACLs are disabled using `BucketOwnerEnforced`. Permissions are managed through IAM
and bucket policies instead [[4]](#ref-4). The bucket remains private; CloudFront
will be configured later to serve the website publicly.

`BlockPublicAcls` prevents new public ACLs, while `IgnorePublicAcls` ignores existing
public ACL permissions. These overlap with disabled ACLs, but are retained as an
additional safeguard if the ownership configuration changes. `BlockPublicPolicy` blocks new public bucket policies (not
all bucket policies),
and `RestrictPublicBuckets` limits access when a bucket policy is public [[5]](#ref-5).

**Bucket Naming Decision:**

I decided to use a custom S3 bucket name prefix with the account-regional namespace instead of a fully autogenerated
name.

This makes the bucket easier to identify and helps avoid naming conflicts with buckets belonging to other AWS accounts.

CloudFormation can generate the account and Region suffix automatically using the `BucketNamePrefix`
property [[6]](#ref-6).

**Alternative:** Use an automatically generated bucket name or define a complete name using `BucketName` and `!Sub`.

**Limitation:** The bucket prefix must follow Amazon S3 naming rules. Changes to bucket naming properties may require
resource replacement.

#### AWS CLI Configuration and Troubleshooting

**Objective:** Configure secure AWS CLI access and validate the CloudFormation template.

**1. AWS CLI authentication**

I installed AWS CLI v2 and attempted to validate the CloudFormation template. The first attempt failed with the
following error:

```text
NoCredentials: Unable to locate credentials
```

The CLI was not authenticated with AWS.

I initially signed in using my AWS root account. However, I decided to create a separate IAM user for development to
avoid using root credentials for daily tasks.

I created:

- IAM user: `atu-devops-lab`
- IAM group: `ATU-DevOps-Lab-Developers`
- MFA authentication for additional account security
- Local AWS CLI profile: `atu-lab`

I used browser-based authentication to obtain temporary credentials without creating permanent access keys.

```powershell
aws login --profile atu-lab --region eu-west-1
```

**2. Identity verification**

I verified the authenticated user with AWS Security Token Service (STS):

```powershell
aws sts get-caller-identity --profile atu-lab
```

**Result:** AWS confirmed that the request was made by the IAM user `atu-devops-lab`, rather than the root user.

**3. CloudFormation permission error**

The next attempt to validate the template failed:

```text
AccessDenied: not authorized to perform:
cloudformation:ValidateTemplate
```

The IAM user had permission to sign in, but did not have permission to validate CloudFormation templates.

To resolve this issue, I created a customer-managed IAM policy called `ATU-CloudFormation-Lab-Policy`.

The policy initially allowed only one action:

```json
{
  "Effect": "Allow",
  "Action": "cloudformation:ValidateTemplate",
  "Resource": "*"
}
```

I attached this policy to the `ATU-DevOps-Lab-Developers` group.

This follows the principle of least privilege, where permissions are granted only when required [[8]](#ref-8).

**4. Successful template validation**

I repeated the validation using the configured AWS profile:

```powershell
aws cloudformation validate-template `
  --template-body file://infrastructure/static-website.yaml `
  --region eu-west-1 `
  --profile atu-lab
```

**Result: Passed**

CloudFormation returned the template description and an empty parameters list:

```json
{
  "Parameters": [],
  "Description": "ATU CloudFormation Lab - Part A(a). Creates a private S3 bucket for static website content.\n"
}
```

This confirmed that AWS CloudFormation could read and parse the template successfully. It did not confirm that the
infrastructure had been deployed.

**Lessons Learned:**

- AWS CLI authentication and IAM permissions are separate processes.
- An authenticated user does not automatically have access to AWS services.
- Named CLI profiles make it easier to select the correct AWS identity.
- IAM permissions can be added gradually instead of granting full administrator access.
- CloudFormation template validation should be performed before deployment.

AWS CLI configuration and authentication are documented in the official AWS CLI User Guide [[9]](#ref-9).

#### Extending IAM Permissions for Deployment

**Objective:** Allow the IAM user to deploy and manage the S3 infrastructure using CloudFormation.

Initially, the IAM policy allowed only `cloudformation:ValidateTemplate`. This was sufficient to validate the YAML
template, but not to create AWS resources.

Before deployment, I extended the customer-managed policy `ATU-CloudFormation-Lab-Policy`.

The permissions were organised into three groups:

| Permission Group    | Purpose                                                                          |
|---------------------|----------------------------------------------------------------------------------|
| `ValidateTemplates` | Validate CloudFormation templates before deployment.                             |
| `ManageLabStack`    | Create, update, inspect and delete the CloudFormation stack and its change sets. |
| `ManageLabS3Bucket` | Create and configure the S3 bucket used by the website.                          |

**Design Decision:**

I decided to extend the existing IAM policy rather than grant `AdministratorAccess`.

The CloudFormation permissions are restricted to the `ATU-Static-Website` stack in the `eu-west-1` Region and its
associated change sets.

The S3 permissions are restricted to bucket names beginning with `atu-l00213593-web-`.

This follows the principle of least privilege and reduces the scope of permissions available to the IAM
user [[8]](#ref-8).

**Why are Change Sets required?**

The AWS CLI `cloudformation deploy` command uses change sets to prepare and execute infrastructure changes. They allow
CloudFormation to identify which resources will be created or updated.

**Limitation:**

The initial permissions may need further adjustment during deployment. Any additional permissions will be reviewed and
documented rather than granting unrestricted access.

**Validation:**

IAM policy update: **Completed**.

CloudFormation stack deployment: **Passed** (`CREATE_COMPLETE`).

The initial permission set was sufficient for this S3-only deployment.

AWS explains CloudFormation actions, resources and permissions in its IAM access
control documentation [[10]](#ref-10).

#### Deployment and AWS CLI Verification

**Deployment:** I deployed the CloudFormation template using `aws cloudformation deploy`.
AWS CLI uses a change set to create or update the stack [[11]](#ref-11).

```powershell
aws cloudformation deploy `
  --template-file infrastructure/static-website.yaml `
  --stack-name ATU-Static-Website `
  --region eu-west-1 `
  --profile atu-lab
```

**Result:** `Successfully created/updated stack - ATU-Static-Website`.

**Stack status and outputs:** The `describe-stacks` command returns information about
the specified stack, including its status and output values [[12]](#ref-12).

```powershell
aws cloudformation describe-stacks `
  --stack-name ATU-Static-Website `
  --region eu-west-1 `
  --profile atu-lab `
  --query "Stacks[0].StackStatus" `
  --output text
```

**Result:** `CREATE_COMPLETE`.

Using the same command with `--query "Stacks[0].Outputs" --output table`
returned `WebsiteBucketName` and `WebsiteBucketArn`. The generated bucket name
was `atu-l00213593-web-897068845214-eu-west-1-an`.

**Security and configuration checks:** I checked the deployed S3 configuration
using AWS CLI commands documented in the official command reference:

| CLI command                                               | What it verifies                         | Actual result                 |
|-----------------------------------------------------------|------------------------------------------|-------------------------------|
| `aws s3api get-public-access-block` [[13]](#ref-13)       | Four settings that prevent public access | All four set to `true`        |
| `aws s3api get-bucket-encryption` [[14]](#ref-14)         | Default server-side encryption           | `AES256` (SSE-S3)             |
| `aws s3api get-bucket-ownership-controls` [[15]](#ref-15) | Object ownership and ACL configuration   | `BucketOwnerEnforced`         |
| `aws s3api get-bucket-tagging` [[16]](#ref-16)            | Resource metadata                        | All four project tags present |

Each S3 command was run with `--bucket atu-l00213593-web-897068845214-eu-west-1-an`,
`--region eu-west-1` and `--profile atu-lab`.

The tagging response also included three automatically added CloudFormation tags:
`aws:cloudformation:stack-name`, `aws:cloudformation:stack-id` and
`aws:cloudformation:logical-id`.

**Conclusion:** The S3 resource was created and its access restrictions,
encryption, object ownership and tags were confirmed using AWS CLI.
At the end of Iteration 2, the bucket was private and the website was not yet publicly accessible.
Iteration 3 added CloudFront delivery and controlled access to S3.

### Iteration 3 — CloudFront Delivery and Private S3 Access

**Implementation**

Added `AWS::CloudFront::OriginAccessControl` to the CloudFormation template.

**Design Decision**

I selected Origin Access Control (OAC) instead of the older Origin Access Identity (OAI).
OAC allows CloudFront to send authenticated requests to a private S3 bucket using AWS Signature Version
4 [[17]](#ref-17).

**Validation**

The CloudFormation template was checked using `aws cloudformation validate-template`.

#### CloudFront Distribution

**Implementation**

Added `AWS::CloudFront::Distribution` to deliver the static website through HTTPS.
The distribution uses the private S3 bucket as its origin and connects to the previously configured OAC.

**Design Decisions**

I selected `PriceClass_100` to limit CloudFront delivery locations mainly to North America and Europe and help control
costs [[18]](#ref-18).
I configured `redirect-to-https` to redirect HTTP requests to HTTPS.
Because OAC is used instead of the older OAI mechanism, `OriginAccessIdentity` is set to an empty string, as described
in AWS documentation [[19]](#ref-19).
I selected the AWS managed `CachingOptimized` cache policy to reduce repeated requests to S3. Its policy ID is provided
in the official AWS documentation [[20]](#ref-20).

#### S3 Bucket Policy for CloudFront

**Implementation**

Added `AWS::S3::BucketPolicy` to allow CloudFront to read objects from the private S3 bucket.

**Design Decision**

I decided to keep the S3 bucket private and allow access only through the configured CloudFront distribution.
The policy grants `s3:GetObject` permission to the CloudFront service. The `AWS:SourceArn` condition restricts access to
the specific distribution created by this project.
This follows the AWS recommendation for using Origin Access Control with a private S3 origin [[21]](#ref-21).

**Validation**

The updated CloudFormation template was successfully checked using `aws cloudformation validate-template`.

The CloudFront distribution and bucket policy were deployed successfully (stack status: `UPDATE_COMPLETE`).

**CloudFront Distribution ARN**

A CloudFront distribution defines how content is delivered from an origin, such as an S3 bucket. AWS automatically
assigns a unique Distribution ID when the resource is created.

The bucket policy uses `AWS:SourceArn` to restrict `s3:GetObject` access to this specific distribution.

The ARN follows the AWS-defined format `arn:partition:cloudfront::account-id:distribution/distribution-id`.
CloudFormation uses `!Sub` to insert the AWS partition, account ID and generated Distribution ID automatically.

This avoids hardcoding resource identifiers and ensures that the bucket policy refers to the correct CloudFront
distribution [[21]](#ref-21).

#### CloudFront Outputs

**Implementation**

Added `WebsiteURL` and `WebsiteDistributionId` to the CloudFormation outputs.

**Design Decision**

I decided to use CloudFormation outputs instead of manually copying the distribution domain name and ID from the AWS
Console.

CloudFormation returns the generated distribution domain through `${WebsiteDistribution.DomainName}` inside `!Sub` (
equivalent to `Fn::GetAtt`) and the distribution ID using `!Ref` [[22]](#ref-22).

The outputs were verified after deployment using `aws cloudformation describe-stacks`.

#### Extending IAM Permissions for CloudFront

**Objective**

Allow the `atu-devops-lab` IAM user to deploy and manage CloudFront resources using CloudFormation.

**Implementation**

Updated the existing customer-managed policy `ATU-CloudFormation-Lab-Policy`.
Added permissions for:

- Creating and managing CloudFront distributions.
- Creating and managing Origin Access Controls (OAC).
- Reading, updating and deleting the S3 bucket policy.

**Design Decision**

I extended the existing IAM policy instead of granting `AdministratorAccess`.
CloudFront management permissions are restricted to distribution and OAC resources in my AWS account where supported.
Some creation operations require `Resource: "*"`.
This approach follows the principle of least privilege [[8]](#ref-8).

**Limitation**

The IAM policy was updated manually through the AWS Console and is not currently managed by the CloudFormation template.

**Validation**

The IAM policy changes were saved successfully.
The permissions were successfully exercised during the CloudFormation deployment.

#### Static Website Deployment and S3 Permissions

**Objective**

Upload the static HTML website to the private S3 bucket and verify that it is accessible through CloudFront.

**Problem**

The first attempt to upload `web/index.html` failed:

```text
AccessDenied: not authorized to perform: s3:PutObject
because no identity-based policy allows the s3:PutObject action
```

The IAM user `atu-devops-lab` had permissions to create and configure the S3 bucket but did not have permission to
upload objects.

**Solution**

I extended the existing IAM policy `ATU-CloudFormation-Lab-Policy` by adding a separate statement named
`UploadWebsiteIndex`.

```json
{
  "Sid": "UploadWebsiteIndex",
  "Effect": "Allow",
  "Action": "s3:PutObject",
  "Resource": "arn:aws:s3:::atu-l00213593-web-897068845214-eu-west-1-an/index.html"
}
```

I decided to restrict `s3:PutObject` to the specific `index.html` object instead of allowing uploads to all objects in
the bucket.

This follows the principle of least privilege [[8]](#ref-8).

**Deployment**

After updating the IAM policy, I repeated the upload:

```powershell
aws s3 cp web/index.html `
  s3://atu-l00213593-web-897068845214-eu-west-1-an/index.html `
  --content-type "text/html" `
  --region eu-west-1 `
  --profile atu-lab
```

**Result:** The HTML file was uploaded successfully.

**CloudFormation Verification**

The `ATU-Static-Website` stack was successfully updated.
Stack status: `UPDATE_COMPLETE`.
CloudFormation returned the following outputs:

| Output                | Value                                         |
|-----------------------|-----------------------------------------------|
| WebsiteBucketName     | `atu-l00213593-web-897068845214-eu-west-1-an` |
| WebsiteDistributionId | `EV2KPMP2U0HIG`                               |
| WebsiteURL            | https://d2caxeghfi5itf.cloudfront.net         |

**Website Testing**

I opened the CloudFront URL in a web browser using HTTPS.
The website displayed correctly, including:

- Project title and module information.
- Student name and student number.
- Project overview and infrastructure information.
- Centred page layout and CSS styling.

**Result: Passed**

The static website is accessible through CloudFront over HTTPS while the S3 bucket remains private.

**Website Screenshot**

The screenshot below shows the static website successfully delivered through Amazon CloudFront over HTTPS.

![Deployed ATU CloudFormation website](docs/screenshots/cloudfront-website.png)

#### S3 Direct Access Security Test

**Objective**

Verify that the static website is accessible through CloudFront while direct public access to the S3 bucket is denied.

**Test**

I sent an unauthenticated HTTP request directly to the S3 object:

```powershell
curl.exe -I https://atu-l00213593-web-897068845214-eu-west-1-an.s3.eu-west-1.amazonaws.com/index.html
```

**Expected Result:** `403 Forbidden`.

**Actual Result:** `403 Forbidden`.

**Conclusion**

The test confirmed that direct anonymous access to the S3 object is denied.
The website remains accessible through CloudFront over HTTPS.

This is consistent with the private S3 origin configuration and Origin Access Control (OAC) approach recommended by
AWS [[21]](#ref-21).

**Security Test Screenshot**

![S3 direct access denied](docs/screenshots/s3-access-denied.png)

#### CloudFront and S3 Access Control Diagram

**Architecture Overview**

The diagram below illustrates how CloudFront provides access to the static website while direct anonymous requests to
the private S3 bucket are denied.

![CloudFront and S3 access control architecture](docs/screenshots/cloudfront-s3-architecture.png)

**Security Explanation**

CloudFront uses Origin Access Control (OAC) to sign requests to the private S3 bucket.
The bucket policy allows `s3:GetObject` only for requests from the configured CloudFront distribution, using the
`AWS:SourceArn` condition.

Direct anonymous requests are denied with `403 Forbidden`,
as confirmed by the security test [[21]](#ref-21).

### Iteration 4 — S3 Versioning

**Objective**
Enable S3 Versioning to preserve previous versions of website files.

**Implementation**
Added `VersioningConfiguration` to the `WebsiteBucket` resource in `infrastructure/static-website.yaml`.

```yaml
VersioningConfiguration:
  Status: Enabled
```

**Design Decision**
I decided to enable S3 Versioning to protect website files from accidental overwriting or deletion.
When a new version of `index.html` is uploaded, Amazon S3 retains the previous version. This makes it possible to
recover earlier website content if needed [[23]](#ref-23).

**Limitation**
Previous versions consume storage space and may increase costs. A Lifecycle rule was added in Iteration 5 to
manage older versions.

**Validation**

The CloudFormation template was successfully validated using `aws cloudformation validate-template`.

The `ATU-Static-Website` stack was successfully updated using `aws cloudformation deploy`.

S3 Versioning was verified using `aws s3api get-bucket-versioning`.

**Result: Passed**

The command returned `Status: Enabled`, confirming that S3 Versioning is enabled.

### Iteration 5 — S3 Lifecycle Management

**Objective**
Automatically remove previous versions of website files to reduce unnecessary storage costs.

**Implementation**
Added `LifecycleConfiguration` to the `WebsiteBucket` resource in `infrastructure/static-website.yaml`.

```yaml
LifecycleConfiguration:
  Rules:
    - Id: DeleteOldWebsiteVersions
      Status: Enabled
      NoncurrentVersionExpiration:
        NoncurrentDays: 30
```

**Design Decision**

I decided to keep previous versions of website files for 30 days after they become noncurrent.
S3 Lifecycle automatically removes these older versions after the retention period while preserving the current version
of `index.html`.
This helps control storage costs while allowing recently replaced files to be recovered [[24]](#ref-24).

**Limitation**
Lifecycle expiration is asynchronous. S3 may not physically remove an eligible version immediately after the retention
period.

**Validation**

The CloudFormation template was successfully validated using `aws cloudformation validate-template`.

The Lifecycle configuration was successfully deployed through CloudFormation.

I verified the configuration using `aws s3api get-bucket-lifecycle-configuration`.

**Result: Passed**

The response confirmed that the `DeleteOldWebsiteVersions` rule is enabled and configured to expire noncurrent object
versions after 30 days.

**IAM Permission Troubleshooting**

The first CloudFormation deployment failed because the IAM user `atu-devops-lab` did not have permission to perform
`s3:PutLifecycleConfiguration`. CloudFormation reported `UPDATE_FAILED` for `WebsiteBucket` and then completed the
rollback (`UPDATE_ROLLBACK_COMPLETE`).

I extended the customer-managed policy `ATU-CloudFormation-Lab-Policy` with a separate statement named
`ManageWebsiteVersioningAndLifecycle`.

The statement grants `s3:PutBucketVersioning`, `s3:GetBucketVersioning`, `s3:PutLifecycleConfiguration` and
`s3:GetLifecycleConfiguration` on the specific website bucket only.

The first retry also failed because I had not saved the IAM policy changes in the AWS Console. After saving the policy,
I repeated the CloudFormation deployment successfully.

This approach follows the principle of least privilege [[8]](#ref-8).

### Iteration 6 — Three-Tier Architecture: Java Lambda Setup

**Objective**

Prepare a Java application for the Application Tier of Part A(b).

**Implementation**

- Created the Maven project with `pom.xml` in the repository root and the handler at
  `src/main/java/ie/atu/lab/MessageHandler.java`.
- Configured the Maven Compiler Plugin to compile the application using Java 21, a runtime supported by AWS
  Lambda [[25]](#ref-25).
- Added `com.amazonaws:aws-lambda-java-core` for the `RequestHandler` interface and Lambda `Context`
  object [[26]](#ref-26).
- Added the AWS SDK for Java 2.x `software.amazon.awssdk:dynamodb` module for future database
  operations [[27]](#ref-27).
- Imported the AWS SDK BOM under Maven `dependencyManagement` to manage compatible SDK module versions without declaring
  a separate version for DynamoDB [[27]](#ref-27).
- Configured Maven Shade Plugin to package the Java code and dependencies into a single JAR for Lambda
  deployment [[28]](#ref-28) [[29]](#ref-29).
- Implemented a basic `MessageHandler` returning a JSON response. The `RequestHandler` interface, `handleRequest` method
  and `Context` logging API follow the AWS Lambda Java handler documentation [[26]](#ref-26).

**Design Decision**

I selected Java 21 and Maven for the Application Tier. I decided to use a simple Java Lambda handler instead of Spring
Boot to keep the application small and avoid unnecessary dependencies.

The AWS SDK BOM manages the versions of AWS SDK modules, while `aws-lambda-java-core` is declared separately because it
does not belong to the `software.amazon.awssdk` BOM [[27]](#ref-27).

Maven Shade Plugin creates a deployment JAR containing the application and its
dependencies [[28]](#ref-28) [[29]](#ref-29).

**Validation**

The Maven project was successfully built from the repository root using `mvn clean package`.

**Result:** `BUILD SUCCESS`. Maven Shade Plugin reported overlapping `META-INF` resources during packaging; these
warnings did not prevent the build.

**Limitation**

The Lambda function has not yet been deployed to AWS. API Gateway and DynamoDB integration will be implemented in the
next iterations.

### Iteration 7 — DynamoDB Database Tier

**Objective**
Define a DynamoDB table for storing messages in the three-tier application.

**Implementation**

- Added the `MessagesTable` resource to `infrastructure/three-tier.yaml`.
- Configured the `id` attribute as a String partition key.
- Selected `PAY_PER_REQUEST` billing mode.
- Added resource tags and a CloudFormation output for the table name.

**Design Decision**
I selected Amazon DynamoDB because it is a managed NoSQL database and does not require database server administration.
The `PAY_PER_REQUEST` billing mode was selected because the application is small and the number of requests is expected
to be low.
The table name is generated using `!Sub` and the `${AWS::StackName}` pseudo parameter instead of hardcoding the stack
name [[30]](#ref-30) [[31]](#ref-31).
The table is defined using the `AWS::DynamoDB::Table` resource [[32]](#ref-32).

**Validation**
The CloudFormation template was successfully validated using `aws cloudformation validate-template`.

**Result:** Template validation passed.

**Limitation**
The DynamoDB table has not yet been deployed. The Java Lambda integration will be implemented in a later iteration.

### Iteration 8 — Lambda Execution Role

**Objective**
Define an IAM execution role for the Java Lambda function.

**Implementation**

- Added `MessageLambdaRole` to `infrastructure/three-tier.yaml`.
- Configured a trust policy allowing AWS Lambda to assume the role.
- Attached the AWS-managed `AWSLambdaBasicExecutionRole` policy for CloudWatch logging.
- Added permissions for `dynamodb:PutItem`, `dynamodb:GetItem` and `dynamodb:Scan`.
- Restricted DynamoDB access to the `MessagesTable` ARN using `!GetAtt`.

**Design Decision**
I decided to create a separate execution role for the Java Lambda function instead of using the IAM user that deploys
the infrastructure.
The role follows the principle of least privilege by granting access only to the required DynamoDB operations and the
project table [[33]](#ref-33) [[34]](#ref-34).

**Validation**
The CloudFormation template was successfully validated using `aws cloudformation validate-template`.
CloudFormation returned `CAPABILITY_IAM`, confirming that IAM resource creation must be explicitly acknowledged during
deployment.

**Result:** Template validation passed.

**Limitation**
The IAM role has not yet been deployed. The CloudFormation stack will require `CAPABILITY_IAM` and appropriate
deployment permissions.

### Iteration 9 — DynamoDB Template Review and Security Checks

**Objective**

Review static-analysis findings for the DynamoDB table and document why additional CloudFormation settings were
considered.

**How the changes were identified**

After defining the `MessagesTable` resource, I inspected the CloudFormation template using editor/static-analysis
checks. The checks reported missing `DeletionPolicy`, `UpdateReplacePolicy` and `SSESpecification` properties. These
findings prompted me to consult the official AWS CloudFormation and DynamoDB documentation rather than assuming that the
properties were mandatory or that the table was unencrypted.

**Resource lifecycle decisions**

- `DeletionPolicy` controls what happens when the stack is deleted or when the table resource is removed from the
  template [[35]](#ref-35).
- `UpdateReplacePolicy` controls what happens to the previous physical table if a stack update replaces
  it [[36]](#ref-36).
- For this temporary lab table, I chose to explicitly specify `Delete` for both properties to make the cleanup behaviour
  clear and avoid retaining unused lab resources. This decision accepts the risk of losing test messages during stack
  deletion or resource replacement.
- A production database containing important information would require a different data-retention and recovery decision;
  `Retain` would be safer than deleting its data automatically.

**Encryption review**

The security check first reported that `SSESpecification` was missing. After I explicitly set `SSEEnabled: false`, it
reported that its required value was `true`.

I checked the AWS documentation and found that DynamoDB encrypts all table data at rest by default. For CloudFormation,
`SSEEnabled: false` or omitting `SSESpecification` uses an AWS owned key, whereas `SSEEnabled: true` selects AWS KMS
encryption using an AWS managed key, which has different key-management characteristics and may have different cost
implications [[37]](#ref-37) [[38]](#ref-38).

For this small educational project, I selected the AWS owned key to keep the lab configuration simple and avoid choosing
a different key-management model without a requirement. This keeps encryption at rest enabled, but **does not satisfy**
the particular static-analysis rule requiring `SSEEnabled: true`. I am documenting that distinction rather than claiming
that all security checks passed.

**Validation and current status**

- The previous CloudFormation template validation succeeded before these latest lifecycle/encryption edits.
- The static-analysis finding for `SSEEnabled: true` remains unresolved by design while `SSEEnabled: false` is used.
- The updated template still needs another `aws cloudformation validate-template` check after these edits.
- The Part A(b) stack and DynamoDB table have not yet been deployed.

**References**

AWS documents the lifecycle attributes, DynamoDB encryption-key behaviour and encryption at rest in
references [[35]](#ref-35)–[[38]](#ref-38).

### Iteration 10 — Separate S3 Bucket for Lambda Deployment Artifacts

**Objective**

Prepare an independent, private S3 bucket for storing the packaged Java Lambda application before deployment. The Maven
Shade build produced `target/student-message-board-1.0-SNAPSHOT.jar` (approximately 13.9 MB). No Lambda function or
artifacts bucket has been deployed in this iteration.

**Why a second S3 bucket?**

Part A(a) already uses a private S3 bucket to store website files (`web/index.html`) served through CloudFront. I chose
a separate bucket for Lambda deployment artifacts because JAR files are build outputs, not public website content. This
keeps the two types of objects and their access permissions separate. The website bucket grants CloudFront read access;
the artifact bucket will instead need permissions for uploading the JAR and allowing Lambda deployment to read it.
Separation also makes artifact lifecycle management and lab cleanup easier.

**Implementation**

- Added `infrastructure/lambda-artifacts.yaml` as a separate CloudFormation template for the artifact bucket.
- Reused the security settings already implemented and tested in the Part A(a) S3 bucket: `BlockPublicAccess`,
  `BucketOwnerEnforced` (ACLs disabled), SSE-S3 (`AES256`), and explicit `DeletionPolicy` / `UpdateReplacePolicy`.
- Reused `BucketNamePrefix` with `BucketNamespace: account-regional`, changing the prefix from `atu-l00213593-web` to
  `atu-l00213593-lambda`. This allows AWS to generate an account/Region-scoped bucket name without hardcoding a complete
  name [[6]](#ref-6) [[39]](#ref-39).
- Enabled S3 Versioning for previous deployment artifacts and configured a lifecycle rule to expire noncurrent object
  versions after 30 days, using the same retention approach as the website bucket [[23]](#ref-23) [[24]](#ref-24).
- Added a CloudFormation output for the generated artifact bucket name.

**Static-analysis finding: S3 server access logging**

The template checker recommended adding `LoggingConfiguration` to the bucket. I reviewed this recommendation but did not
enable server access logging at this stage. AWS recommends a separate destination bucket for access logs, with the
appropriate policy granting the logging service permission to deliver records. There is no additional charge solely for
enabling the feature, but delivered log objects incur S3 storage charges [[40]](#ref-40).

For this small, temporary lab bucket, I chose not to add a logging destination and associated permissions at this stage,
keeping the setup simple and avoiding extra stored log objects. This is a documented trade-off, **not** a claim that the
logging check passes or that access logging is unnecessary in production. I can revisit it if stronger auditing is
required.

**Testing and current status**

- The artifact bucket is currently **defined in YAML only**; deployment and bucket-level verification are pending.
- The static-analysis recommendation for `LoggingConfiguration` remains outstanding by design.
- `DeletionPolicy: Delete` will not automatically empty an S3 bucket; stored objects and versions must be removed before
  the bucket can be deleted.
- The artifact bucket's policy and IAM deployment permissions will be prepared before uploading the JAR or deploying
  Lambda.

**Official documentation:** S3 bucket CloudFormation properties [[39]](#ref-39) and server access
logging [[40]](#ref-40).

## 6. Design Decisions

The main technical decisions are recorded in the development iterations above.

The documentation records:

- The selected approach.
- The reason for choosing it.
- Alternative solutions considered.
- Advantages and limitations.
- Relevant AWS documentation.

For example, AWS recommends managing CloudFormation templates using version control
and reviewing changes before deployment [[2]](#ref-2).
Decisions are supported by relevant AWS documentation cited in the References section.

## 7. Testing and Validation

Each development stage is tested and documented before being merged into the main branch.

Test results and issues are documented in the relevant iteration, including CloudFormation validation,
stack status, website delivery over HTTPS and the direct S3 access denial.
AWS recommends validating CloudFormation templates before deploying infrastructure [[2]](#ref-2).

## 8. References

<a id="ref-1"></a>
**[1]** Amazon Web Services (n.d.) *AWS CloudFormation documentation*.
Available at: [https://docs.aws.amazon.com/cloudformation/](https://docs.aws.amazon.com/cloudformation/)
(Accessed: 21 October 2026).

<a id="ref-2"></a>
**[2]** Amazon Web Services (n.d.) *CloudFormation best practices*.
Available at: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html
(Accessed: 21 October 2026).

<a id="ref-3"></a>
**[3]** Amazon Web Services (n.d.)
*Hosting a static website using Amazon S3*.
Available at:
https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html
(Accessed: 21 October 2026).

<a id="ref-4"></a>
**[4]** Amazon Web Services (n.d.) *Controlling ownership of objects and disabling ACLs for your bucket*.
Available at: https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html
(Accessed: 22 October 2026).

<a id="ref-5"></a>
**[5]** Amazon Web Services (n.d.) *Blocking public access to your Amazon S3 storage*.
Available at: https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html
(Accessed: 22 October 2026).

<a id="ref-6"></a>
**[6]** Amazon Web Services (n.d.)
*Namespaces for general purpose buckets*.
Available at:
https://docs.aws.amazon.com/AmazonS3/latest/userguide/gpbucketnamespaces.html
(Accessed: 21 October 2026).

<a id="ref-7"></a>
**[7]** Amazon Web Services (n.d.) *Using server-side encryption with Amazon S3 managed keys (SSE-S3)*.
Available at: https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingServerSideEncryption.html
(Accessed: 22 October 2026).

<a id="ref-8"></a>
**[8]** Amazon Web Services (n.d.)
*Security best practices in IAM*.
Available at:
https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
(Accessed: 22 October 2026).

<a id="ref-9"></a>
**[9]** Amazon Web Services (n.d.)
*Sign in with AWS CLI*.
Available at:
https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sign-in.html
(Accessed: 22 October 2026).

<a id="ref-10"></a>
**[10]** Amazon Web Services (n.d.)
*Control CloudFormation access with AWS Identity
and Access Management*.
Available at:
https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/control-access-with-iam.html
(Accessed: 22 October 2026).

<a id="ref-11"></a>
**[11]** Amazon Web Services (n.d.) *deploy — AWS CLI Command Reference*.
Available at: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/deploy.html
(Accessed: 22 October 2026).

<a id="ref-12"></a>
**[12]** Amazon Web Services (n.d.) *describe-stacks — AWS CLI Command Reference*.
Available at: https://docs.aws.amazon.com/cli/latest/reference/cloudformation/describe-stacks.html
(Accessed: 22 October 2026).

<a id="ref-13"></a>
**[13]** Amazon Web Services (n.d.) *get-public-access-block — AWS CLI Command Reference*.
Available at: https://docs.aws.amazon.com/cli/latest/reference/s3api/get-public-access-block.html
(Accessed: 22 October 2026).

<a id="ref-14"></a>
**[14]** Amazon Web Services (n.d.) *get-bucket-encryption — AWS CLI Command Reference*.
Available at: https://docs.aws.amazon.com/cli/latest/reference/s3api/get-bucket-encryption.html
(Accessed: 22 October 2026).

<a id="ref-15"></a>
**[15]** Amazon Web Services (n.d.) *get-bucket-ownership-controls — AWS CLI Command Reference*.
Available at: https://docs.aws.amazon.com/cli/latest/reference/s3api/get-bucket-ownership-controls.html
(Accessed: 22 October 2026).

<a id="ref-16"></a>
**[16]** Amazon Web Services (n.d.) *get-bucket-tagging — AWS CLI Command Reference*.
Available at: https://docs.aws.amazon.com/cli/latest/reference/s3api/get-bucket-tagging.html
(Accessed: 22 October 2026).

<a id="ref-17"></a>
**[17]** Amazon Web Services (n.d.)
*AWS::CloudFront::OriginAccessControl*.
Available at:
https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-cloudfront-originaccesscontrol.html
(Accessed: 22 October 2026).

<a id="ref-18"></a>
**[18]** Amazon Web Services (n.d.)
*Choosing the price class for a CloudFront distribution*.
Available at:
https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PriceClass.html
(Accessed: 22 October 2026).

<a id="ref-19"></a>
**[19]** Amazon Web Services (n.d.)
*AWS::CloudFront::Distribution S3OriginConfig*.
Available at:
https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-properties-cloudfront-distribution-s3originconfig.html
(Accessed: 22 October 2026).

<a id="ref-20"></a>
**[20]** Amazon Web Services (n.d.) *Use managed cache policies*.
Available at: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html
(Accessed: 22 October 2026).

<a id="ref-21"></a>
**[21]** Amazon Web Services (n.d.)
*Restrict access to an Amazon S3 origin using Origin Access Control (OAC)*.
Available at:
https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html
(Accessed: 22 October 2026).

<a id="ref-22"></a>
**[22]** Amazon Web Services (n.d.)
*AWS::CloudFront::Distribution*.
Available at:
https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-cloudfront-distribution.html
(Accessed: 22 October 2026)

<a id="ref-23"></a>
**[23]** Amazon Web Services (n.d.) *Using versioning in S3 buckets*.
Available at: https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html
(Accessed: 22 October 2026).

<a id="ref-24"></a>
**[24]** Amazon Web Services (n.d.) *Managing the lifecycle of objects*.
Available at: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html
(Accessed: 22 October 2026).

<a id="ref-25"></a>
**[25]** Amazon Web Services (n.d.) *Lambda runtimes*.
Available at: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
(Accessed: 22 October 2026).

<a id="ref-26"></a>
**[26]** Amazon Web Services (n.d.) *Define Lambda function handler in Java*.
Available at: https://docs.aws.amazon.com/lambda/latest/dg/java-handler.html
(Accessed: 22 October 2026).

<a id="ref-27"></a>
**[27]** Amazon Web Services (n.d.) *Set up an Apache Maven project that uses the AWS SDK for Java 2.x*.
Available at: https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/setup-project-maven.html
(Accessed: 22 October 2026).

<a id="ref-28"></a>
**[28]** Amazon Web Services (n.d.) *Deploy Java Lambda functions with .zip or JAR file archives*.
Available at: https://docs.aws.amazon.com/lambda/latest/dg/java-package.html
(Accessed: 22 October 2026).

<a id="ref-29"></a>
**[29]** Apache Software Foundation (n.d.) *Apache Maven Shade Plugin*.
Available at: https://maven.apache.org/plugins/maven-shade-plugin/
(Accessed: 22 October 2026).

<a id="ref-30"></a>
**[30]** Amazon Web Services (n.d.) *Fn::Sub — CloudFormation intrinsic function*.
Available
at: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/intrinsic-function-reference-sub.html
(Accessed: 22 October 2026).

<a id="ref-31"></a>
**[31]** Amazon Web Services (n.d.) *CloudFormation pseudo parameters*.
Available at: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/pseudo-parameter-reference.html
(Accessed: 22 October 2026).

<a id="ref-32"></a>
**[32]** Amazon Web Services (n.d.) *AWS::DynamoDB::Table*.
Available at: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-dynamodb-table.html
(Accessed: 22 October 2026).

<a id="ref-33"></a>
**[33]** Amazon Web Services (n.d.) *AWS::IAM::Role*.
Available at: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-iam-role.html
(Accessed: 22 October 2026).

<a id="ref-34"></a>
**[34]** Amazon Web Services (n.d.) *Defining Lambda function permissions with an execution role*.
Available at: https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html
(Accessed: 22 October 2026).

<a id="ref-35"></a>
**[35]** Amazon Web Services (n.d.) *DeletionPolicy attribute*.
Available at: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-attribute-deletionpolicy.html
(Accessed: 22 October 2026).

<a id="ref-36"></a>
**[36]** Amazon Web Services (n.d.) *UpdateReplacePolicy attribute*.
Available
at: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-attribute-updatereplacepolicy.html
(Accessed: 22 October 2026).

<a id="ref-37"></a>
**[37]** Amazon Web Services (n.d.) *AWS::DynamoDB::Table SSESpecification*.
Available
at: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-properties-dynamodb-table-ssespecification.html
(Accessed: 22 October 2026).

<a id="ref-38"></a>
**[38]** Amazon Web Services (n.d.) *DynamoDB encryption at rest usage notes*.
Available at: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/encryption.usagenotes.html
(Accessed: 22 October 2026).

<a id="ref-39"></a>
**[39]** Amazon Web Services (n.d.) *AWS::S3::Bucket — AWS CloudFormation Template Reference*.
Available at: https://docs.aws.amazon.com/AWSCloudFormation/latest/TemplateReference/aws-resource-s3-bucket.html
(Accessed: 22 October 2026).

<a id="ref-40"></a>
**[40]** Amazon Web Services (n.d.) *Enabling Amazon S3 server access logging*.
Available at: https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html
(Accessed: 22 October 2026).