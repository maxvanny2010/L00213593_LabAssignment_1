# Development History — Iterations 29.1–29.8.8

[← Project README](../README.md) · [References](REFERENCES.md)

### Iteration 29.1 — Multi-stage Dockerfile

**GitHub Pull Request(s):** [PR #26](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/26)

**Objective:** Prepare the Java EC2 application for containerised deployment.

**Implementation:**

- Created a multi-stage Dockerfile using Java 21.
- Configured Maven to build the `ec2-app` module together with its `common` dependency.
- Used a separate Java 21 runtime image for application execution.
- Excluded Maven and application source code from the final runtime image.
- Configured the application to run as a non-root user (`UID 10001`).
- Defined environment variables for the application host, port, AWS Region, and DynamoDB table.
- Exposed application port `8080` in the Docker image metadata.

**Security considerations:**
The multi-stage approach reduces the contents of the final runtime image by excluding build tools and source files.
Running the application as a non-root user follows the Principle of Least Privilege.

Additional runtime restrictions, including Linux capability removal, read-only filesystem, and resource limits, will be
configured during container deployment.

**Verification:**
The Maven application build previously completed successfully using:

```bash
mvn clean verify
```

Docker image build and runtime verification have not yet been performed.

**Result:**
The Dockerfile has been prepared for integration with the GitHub Actions CI pipeline.

### Iteration 29.2 — Amazon ECR Infrastructure

**GitHub Pull Request(s):** [PR #26](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/26)

**Objective:** Provision a secure container registry using AWS CloudFormation.

**Implementation:**

- Created `infrastructure/ec2/ecr.yaml`.
- Provisioned Amazon ECR Repository `atu-ec2-app`.
- Configured immutable Docker image tags to prevent image overwriting.
- Enabled image scanning on push.
- Configured AES256 encryption for stored container images.
- Added an ECR lifecycle policy to retain the latest five images.
- Updated IAM Bootstrap permissions to allow controlled management of the ECR repository.
- Used AWS CloudFormation instead of manual AWS Console configuration.

**Security considerations:**
The ECR repository uses immutable image tags, encryption at rest, and image scanning.
IAM permissions for repository management are restricted to the `atu-ec2-app` repository.
These measures support the principles of Least Privilege and Infrastructure as Code.

**Verification:**

Validated the CloudFormation templates:

```bash
cfn-lint --regions eu-west-1 \
  -t infrastructure/bootstrap/network-deployment-access.yaml \
     infrastructure/ec2/ecr.yaml
```

Both templates passed validation without errors.

Successfully deployed the IAM Bootstrap stack:

```text
Successfully created/updated stack - ATU-EC2-Bootstrap
```

Successfully deployed the ECR stack:

```text
Successfully created/updated stack - ATU-EC2-ECR
```

Verified the ECR repository:

```text
Repository: atu-ec2-app
Region: eu-west-1
Image tag mutability: IMMUTABLE
```

**Result:**
Amazon ECR was successfully provisioned using CloudFormation.
The repository is ready to store Docker images produced by the GitHub Actions pipeline.
Automated image publication and EC2 deployment will be implemented in subsequent iterations.

### Iteration 29.3 — GitHub Actions Docker Build Pipeline

**GitHub Pull Request(s):** [PR #26](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/26)

**Objective:** Introduce automated Java application builds and Docker image creation using GitHub Actions.

**Implementation:**

- Created `.github/workflows/docker-deploy.yml`.
- Configured automatic execution on pushes and pull requests.
- Configured Java 21 using `actions/setup-java@v4`.
- Added Maven build verification using `mvn -B clean verify`.
- Configured Docker Buildx using `docker/setup-buildx-action@v3`.
- Added Docker image creation using `docker/build-push-action@v6`.
- Configured `push: false` to prevent image publication during the initial CI implementation.

**Current limitations:**

- No automated Java unit or integration tests are implemented.
- No Docker vulnerability scanning is configured.
- Docker images are not yet published to Amazon ECR.
- EC2 deployment and automated rollback are not yet implemented.

**Verification:**
The workflow configuration was prepared for GitHub Actions.
Successful execution of the new workflow has not yet been confirmed.

**Result:**
The initial CI pipeline has been implemented to automate Maven and Docker builds.

Future iterations will introduce GitHub OIDC authentication, Amazon ECR image publication, and automated EC2 deployment
through AWS Systems Manager.

### Iteration 29.4 — GitHub Actions OIDC Authentication

**GitHub Pull Request(s):
** [PR #26](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/26), [PR #27](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/27)

**Objective:** Prepare secure authentication between GitHub Actions and AWS without storing permanent AWS credentials.

**Implementation:**

- Created `infrastructure/ec2/github-oidc.yaml`.
- Defined an AWS IAM OIDC Provider for GitHub Actions.
- Defined the IAM Role `ATU-GitHub-Actions-ECR`.
- Restricted role assumption to the `master` branch of the project repository.
- Configured permissions for publishing Docker images to the `atu-ec2-app` ECR repository.
- Applied the Principle of Least Privilege.

**Security considerations:**
GitHub Actions will authenticate using temporary credentials obtained through AWS Security Token Service (STS).
Permanent AWS Access Keys will not be stored in GitHub Secrets.
The IAM trust policy restricts access to the specified GitHub repository and branch.

**Deployment and Verification:**
Both CloudFormation templates were validated using `cfn-lint`.
The initial IAM Bootstrap update failed because the existing Managed Policy exceeded the AWS IAM policy size limit of
6,144 characters.
CloudFormation successfully rolled back the unsuccessful update.
To resolve this issue, permissions were separated into two Managed Policies:

- `NetworkDeploymentPolicy` — existing EC2, networking, SSM and ECR permissions.
- `GitHubOIDCDeploymentPolicy` — permissions for provisioning GitHub OIDC infrastructure.

Both policies are attached to the existing developer IAM group.
After this change, the IAM Bootstrap stack was successfully updated.
The GitHub OIDC infrastructure was deployed using:

```powershell
aws cloudformation deploy `
  --template-file infrastructure/ec2/github-oidc.yaml `
  --stack-name ATU-GitHub-OIDC `
  --capabilities CAPABILITY_NAMED_IAM `
  --region eu-west-1 `
  --profile atu-lab
```

**CloudFormation verification results:**

```text
Stack: ATU-GitHub-OIDC
Status: CREATE_COMPLETE

IAM Role:
arn:aws:iam::897068845214:role/ATU-GitHub-Actions-ECR

OIDC Provider:
arn:aws:iam::897068845214:oidc-provider/token.actions.githubusercontent.com
```

**Security:**

- GitHub Actions authentication uses OIDC federation.
- No permanent AWS Access Keys are required.
- Role assumption is restricted to the project's `master` branch.
- ECR permissions are limited to the `atu-ec2-app` repository.
- A separate IAM Managed Policy is used instead of an inline role policy.

**Result:**
GitHub OIDC infrastructure was successfully provisioned and verified using AWS CloudFormation.
The IAM Role and OIDC Provider are ready for integration with GitHub Actions.
Actual role assumption from GitHub Actions has not yet been tested.

### Iteration 29.5 — Automated Docker Image Publication to Amazon ECR

**GitHub Pull Request(s):
** [PR #26](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/26), [PR #27](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/27)

**Objective:** Build and verify the Java application and Docker image on one GitHub Actions runner,
then publish the verified image to Amazon ECR only for pushes to `master`.

**Implementation:**

- Updated `.github/workflows/docker-deploy.yml` to use a single `build-and-publish` job on `ubuntu-latest`. Its steps
  run sequentially; an unsuccessful Maven build or Docker build prevents the normal publication steps from running.
  GitHub Actions workflow syntax and job steps are documented in [[63]](REFERENCES.md#ref-63).
- Used `actions/checkout@v4` and `actions/setup-java@v4` to prepare the Java 21 Maven build, followed by
  `mvn -B clean verify`.
- Configured Docker Buildx using `docker/setup-buildx-action@v3` [[95]](REFERENCES.md#ref-95).
- Used `docker/build-push-action@v6` to build the project Dockerfile with `load: true`, `push: false`, and the local tag
  `atu-ec2-app:${{ github.sha }}`. The `load` option makes the resulting image available
  to the Docker daemon on the same runner [[94]](REFERENCES.md#ref-94).
- For pushes to `master` only, used `aws-actions/configure-aws-credentials@v4` to assume the existing
  `ATU-GitHub-Actions-ECR` IAM Role using GitHub OIDC. The job requests `id-token: write` to obtain an OIDC token; the
  role's trust policy independently restricts the permitted repository and
  branch [[91]](REFERENCES.md#ref-91) [[92]](REFERENCES.md#ref-92).
- Used `aws-actions/amazon-ecr-login@v2` to authenticate Docker to Amazon ECR [[93]](REFERENCES.md#ref-93).
- Used `docker tag` and `docker push` to publish the **already built local image** to
  `897068845214.dkr.ecr.eu-west-1.amazonaws.com/atu-ec2-app`, using the Git commit SHA as its tag.
  Docker does not rebuild the image for publication.
- Feature branches and pull requests execute Maven verification and Docker
  build but skip AWS authentication, ECR login, nd publication.

**Design decision:**
A single job avoids splitting the build across two GitHub runners and removes the need to transfer build artifacts
between jobs. The project's multi-stage Dockerfile still performs its own Maven build
inside the Docker build; the preceding `mvn clean verify` is a separate validation step.

**Security considerations:**

- AWS authentication uses short-lived credentials through OIDC instead of stored AWS access keys.
- ECR publication is limited to pushes to `master`.
- The IAM Role's ECR permissions are limited to the `atu-ec2-app` repository.
- ECR image tags are immutable; rerunning a publication with an existing Git SHA tag may fail unless handled separately.

**Verification:**
The workflow was updated, but successful GitHub Actions execution, OIDC role assumption
and ECR image publication have **not yet been verified**.
The current Maven verification runs no implemented unit or integration tests.

**Current limitations:**
Automated EC2 deployment, container vulnerability scanning in the workflow,
post-deployment health checks and rollback have not yet been implemented.

**Result:**
The workflow is configured to validate Java and build one local Docker image on
a single runner, and to publish that image to ECR when the workflow is triggered by a push to `master`.

#### GitHub OIDC Authentication Troubleshooting

**Problem:**
The first GitHub Actions execution after merging Pull Request #26 failed during AWS authentication.

```text
Error: Could not assume role with OIDC:
Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**Investigation:**

- Verified the IAM Role Trust Policy.
- Verified the GitHub OIDC Provider and its audience `sts.amazonaws.com`.
- Confirmed that the workflow was triggered by a push to `master`.
- Identified a mismatch between the configured IAM Trust Policy and the GitHub OIDC subject format.

**Solution:**
Updated `infrastructure/ec2/github-oidc.yaml` to use the repository's immutable owner
and repository identifiers in the OIDC subject condition. The IAM Trust Policy remains
restricted to the project's `master` branch. Validated the updated CloudFormation
template using `cfn-lint` and successfully redeployed the `ATU-GitHub-OIDC` stack.

**Verification:**

- [x] CloudFormation lint validation passed.
- [x] GitHub OIDC stack updated successfully.
- [x] GitHub Actions OIDC authentication succeeded.
- [x] Maven build completed successfully.
- [x] Docker image build completed successfully.
- [x] GitHub Actions workflow completed successfully.
- [x] Independent Amazon ECR image verification is passed.

**GitHub Actions Results:**

```text
Workflow: Docker Build and ECR Publish
Branch: master
Commit: 9d0c0478f577557c388106a2328347c3103ebf20
Status: Success
Duration: 1m 23s
```

#### Amazon ECR Verification Permissions

**Problem:**
The first attempt to inspect published Docker images using AWS CLI failed
because the deployment IAM user lacked `ecr:DescribeImages` permission.

**Solution:**
Extended the existing `ManageApplicationECRRepository` statement in
`infrastructure/bootstrap/network-deployment-access.yaml` with `ecr:DescribeImages`.
The permission remains restricted to the `atu-ec2-app` ECR repository.

**Verification:**
CloudFormation deployment completed and the ECR image was independently verified after the permissions update.

**Conclusion:**
The GitHub Actions pipeline successfully authenticated with AWS using OIDC and completed
its build and publication workflow. Independent verification of
the published image in Amazon ECR also succeeded.

### Iteration 29.6.1 — EC2 ECR Access and Container Verification

**GitHub Pull Request(s):** [PR #28](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/28)

**Objective:**
Allow the existing EC2 instance to securely download Docker images from Amazon ECR and verify that the containerised
Java application can access DynamoDB.

**Implementation:**

- Updated `infrastructure/ec2/iam.yaml`.
- Extended the existing `ApplicationManagedPolicy`.
- Added `ecr:GetAuthorizationToken` to allow authentication with Amazon ECR.
- Added `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer` and `ecr:BatchCheckLayerAvailability`.
- Restricted image download permissions to the `atu-ec2-app` ECR repository.
- Preserved the existing DynamoDB and Systems Manager permissions.
- Updated the `ATU-EC2-IAM` CloudFormation stack successfully.

**Deployment and Verification:**
Used AWS Systems Manager Run Command to execute commands on the existing EC2 instance without SSH access.
Verified that AWS CLI and Docker were installed and available.
Authenticated Docker with Amazon ECR using the EC2 Instance Profile credentials.
Successfully downloaded the Docker image:

`897068845214.dkr.ecr.eu-west-1.amazonaws.com/atu-ec2-app:9d0c0478f577557c388106a2328347c3103ebf20`

**Docker Container Security:**
The container was started with the following restrictions:

- Non-root user (`10001:10001`).
- All Linux capabilities removed using `--cap-drop=ALL`.
- Privilege escalation disabled using `--security-opt=no-new-privileges`.
- Read-only root filesystem using `--read-only`.
- Temporary filesystem configured for `/tmp`.
- Memory limit: 256 MB.
- CPU limit: 0.5.
- Process limit: 128.
- Application port bound to `127.0.0.1:8080` on the EC2 host.

**Testing and Validation:**

- [x] CloudFormation IAM stack updated successfully.
- [x] AWS Systems Manager commands completed successfully.
- [x] Amazon ECR authentication succeeded.
- [x] Docker image downloaded successfully.
- [x] Docker container started successfully.
- [x] `GET /health` returned HTTP 200.
- [x] `GET /message` returned HTTP 200.
- [x] DynamoDB returned the previously stored message.
- [x] No inbound Security Group rules were added.

**HTTP Health Check:**

```http
HTTP/1.1 200 OK
```

```json
{
  "service": "ec2-app",
  "status": "UP"
}
```

**DynamoDB Integration Test:**

```http
HTTP/1.1 200 OK
```

```json
{
  "count": 1,
  "messages": [
    {
      "id": "68cc1fcd-a965-45df-a124-05c3c6812fe8",
      "message": "My first DynamoDB message",
      "createdAt": "2026-10-23T21:51:07.150955961Z"
    }
  ]
}
```

**Result:**
The containerized Java application successfully runs on Amazon EC2 and retrieves data from DynamoDB.

The Docker image is downloaded from Amazon ECR using IAM-based authentication without manually configuring permanent AWS
access keys.

**Current Limitations:**

- Docker installation is not yet automated through CloudFormation UserData.
- Container deployment was performed manually using AWS Systems Manager.
- Automatic deployment from GitHub Actions is not yet implemented.
- Automated rollback is not yet configured.

**Next Step:**
Define Docker installation through CloudFormation UserData; the existing container deployment remains a verified manual
SSM operation.

### Iteration 29.6.2 — Docker Setup Defined in EC2 UserData

**GitHub Pull Request(s):** [PR #28](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/28)

**Objective:**

Include Docker installation in the EC2 CloudFormation template so that a newly provisioned Amazon Linux 2023 instance
can configure its container runtime during initialisation.

**Implementation:**

Updated `infrastructure/ec2/instance.yaml` with `UserData` that enables the SSM Agent, installs Docker using `dnf`,
enables and starts the Docker service, and verifies the service with `systemctl` and `docker info`. The configuration
uses `Fn::Base64` and does not require `Fn::Sub`, because no CloudFormation variables are substituted inside the
script [[96]](REFERENCES.md#ref-96) [[97]](REFERENCES.md#ref-97). Amazon Linux 2023 uses `dnf` for package
management [[88]](REFERENCES.md#ref-88).

**Verification and scope:**

- [x] Docker Engine was installed separately on the existing EC2 instance using AWS Systems Manager Run Command (
  Iteration 28).
- [x] The existing Docker service was verified as active and enabled.
- [x] The modified CloudFormation template passed local `cfn-lint` validation.
- [x] The running Docker container was verified through `/health` and `/message` (Iteration 29.6.1).

**Limitation:**

The updated UserData was **not deployed or runtime-tested on a newly created EC2 instance**. The successful installation
on the current instance used SSM, not this UserData script. Accordingly, the CloudFormation template describes the
intended automated setup, but that particular first-boot path has not been independently verified. The existing EC2
stack was not updated to apply this UserData change.

**Design decision:**

Initial instance setup is defined in CloudFormation. Updating the Java application container is a separate operational
activity. Automatic deployment from GitHub Actions to EC2 was deliberately left outside the final scope of this lab.

### Iteration 29.6.3 — Deployment Verification and Scope Conclusion

**GitHub Pull Request(s):** [PR #28](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/28)

**Completed work:**

- Provisioned AWS infrastructure with CloudFormation, including the VPC, subnet, routing, Security Group, EC2, IAM roles
  and Instance Profile.
- Implemented static website delivery through S3 and CloudFront and a three-tier application using API Gateway, Java
  Lambda and DynamoDB.
- Created an ECR repository with CloudFormation and configured GitHub Actions to build the Java application and Docker
  image and publish to ECR from `master` using OIDC.
- Granted the EC2 Instance Profile restricted ECR image-pull permissions through CloudFormation.
- Used SSM Run Command to pull the published Docker image and start the Java application container on EC2 without
  inbound SSH or HTTP access.
- Verified `GET /health` and `GET /message` returned HTTP 200, with the latter retrieving a stored DynamoDB message.

**Final scope decision:**

Automatic container deployment from GitHub Actions using SSM was considered but **not implemented**. The existing
pipeline already builds and publishes Docker images, and manual SSM deployment was sufficient to demonstrate the running
application and AWS infrastructure. This avoids adding deployment orchestration and rollback logic to a lab centred on
CloudFormation.

Temporary SSM deployment permissions that had been added to the GitHub Actions role during development were removed by
updating the `ATU-GitHub-OIDC` stack. The role's remaining ECR publishing policy was verified with
`aws iam list-attached-role-policies`.

**Final verification summary:**

| Verification                                                | Result                         |
|-------------------------------------------------------------|--------------------------------|
| CloudFormation infrastructure and IAM deployment            | Passed                         |
| GitHub Actions Maven/Docker build and ECR publication       | Passed                         |
| ECR image pull to EC2 through SSM                           | Passed                         |
| Docker container startup on EC2                             | Passed                         |
| `GET /health`                                               | HTTP 200                       |
| `GET /message` with DynamoDB data                           | HTTP 200                       |
| Automatic installation by the revised UserData on a new EC2 | Not tested                     |
| Automatic GitHub Actions → SSM deployment                   | Not implemented (out of scope) |

**Conclusion:**

The lab demonstrates CloudFormation-managed AWS infrastructure, IAM access control, containerization, image publication
through a basic CI pipeline, and a working Java application on EC2 connected to DynamoDB. The revised UserData is
included as a reproducible first-boot configuration proposal; automated application deployment and rollback remain
optional future enhancements.

### Iteration 29.7.1 — Simplified EC2 Application Bootstrap Using CloudFormation

**GitHub Pull Request(s):
** [PR #29](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/29), [PR #30](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/30)

**Objective:**
Simplify the EC2 UserData script while retaining automated Docker installation,
container startup and application verification.

**Implementation:**

- Added `DockerImageUri` and `DynamoTableName` CloudFormation parameters.
- Configured Docker image download from a public container registry.
- Removed private ECR authentication from the initial EC2 bootstrap.
- Preserved container security restrictions and resource limits.
- Added HTTP checks for application startup and DynamoDB connectivity.

**Testing and Validation:**

- [x] Updated CloudFormation template passed local `cfn-lint` validation.
- [x] Existing container configuration verified through AWS Systems Manager.
- [x] Simplified UserData tested on a newly provisioned EC2 instance.
- [x] Public Amazon ECR image published and verified (Iteration 29.7.5).

**Final Verification:**
The original GHCR proposal was replaced with Amazon ECR Public. The public image was successfully published by GitHub
Actions, downloaded without registry authentication, and used to bootstrap a newly provisioned EC2 instance. The
automated UserData deployment was verified in Iteration 29.7.6 and repeated in Iteration 29.8.6.

**Reference Implementation:**
I used the official AWS CloudFormation tutorial *Deploy applications on Amazon EC2* as the primary
reference [[98]](REFERENCES.md#ref-98).

The tutorial demonstrates how CloudFormation can configure application software on an EC2 instance during provisioning.
I adapted this approach to install Docker, download a container image and start my Java application using EC2 UserData.

The implementation also follows the official AWS documentation for EC2 UserData [[96]](REFERENCES.md#ref-96),
CloudFormation
`Fn::Sub` [[30]](REFERENCES.md#ref-30), EC2 instance configuration [[97]](REFERENCES.md#ref-97), and Amazon Linux 2023
package
management [[88]](REFERENCES.md#ref-88).

**Design Decision:**
I selected a Bash script embedded in CloudFormation UserData to automate the initial application deployment.
The main focus of this lab is Infrastructure as Code using AWS CloudFormation. Therefore, the implementation does not
include a separate continuous deployment workflow for updating existing EC2 containers after GitHub pushes.

This keeps the deployment process simple while demonstrating automated EC2 provisioning and application initialization.

### Iteration 29.7.2 — IAM Deployment Permissions for Amazon ECR Public

**GitHub Pull Request(s):** [PR #29](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/29)

**Objective:**

Extend the existing CloudFormation-managed IAM configuration to allow
the dedicated development IAM user to deploy and manage a public
Amazon ECR repository.

The public repository will provide a Docker image that can be downloaded
without AWS authentication, supporting reproducible deployment of the
Java application in another AWS account.

**Reference Implementation:**

I used the official AWS CloudFormation documentation for
`AWS::IAM::ManagedPolicy` as the primary reference [[99]](REFERENCES.md#ref-99).

I also referred to the AWS documentation for Amazon ECR Public IAM
permissions, including supported actions and repository ARN formats
[[100]](REFERENCES.md#ref-100).

**Implementation:**

Updated `infrastructure/bootstrap/network-deployment-access.yaml`.

Added a separate CloudFormation resource named `PublicECRDeploymentPolicy`
using `AWS::IAM::ManagedPolicy`.

The policy is attached to the existing
`ATU-DevOps-Lab-Developers` IAM group.

The policy contains three permission groups:

1. `ManagePublicECRStack` — allows CloudFormation operations on the
   `ATU-EC2-ECR-Public` stack in `us-east-1`.

2. `ManagePublicECRChangeSets` — allows creating, reviewing and
   executing CloudFormation Change Sets for the public ECR deployment.

3. `ManagePublicECRRepository` — allows creating, describing,
   updating and deleting the `atu-ec2-app` public repository.

**My Modifications:**

- Reused the existing IAM developer group.
- Created a separate managed policy instead of extending the existing
  network deployment policy.
- Restricted CloudFormation stack permissions to the dedicated public
  ECR stack in `us-east-1`.
- Restricted ECR Public repository operations to `atu-ec2-app`.
- Preserved the existing private ECR permissions.
- Kept IAM permissions managed through CloudFormation.

**Design Decision:**

I selected a separate IAM managed policy to maintain a clear separation
between EC2 infrastructure permissions and public container registry
deployment permissions.

This approach also avoids further increasing the size of the existing
network deployment policy, which previously encountered the IAM
managed policy size limit.

Amazon ECR Public uses `ecr-public` IAM actions and repository ARNs
without a Region component [[100]](REFERENCES.md#ref-100).

The public repository will be managed through the `us-east-1` Region,
while the Java application EC2 instance remains in `eu-west-1`.

**Testing and Validation:**

- [x] Updated CloudFormation IAM template.
- [x] Added separate IAM managed policy for ECR Public.
- [x] Restricted permissions to the project repository and stack.
- [x] Local `cfn-lint` validation passed without errors.
- [x] `git diff --check` passed.
- [x] Updated IAM Bootstrap stack deployed to AWS.
- [x] Public ECR repository deployed and verified.

**Final Status:**
The IAM Bootstrap stack was deployed successfully, and the Amazon ECR Public repository was created and verified. GitHub
Actions publication permissions were added and verified in Iterations 29.7.3–29.7.5.

**References:**

- AWS CloudFormation managed policy documentation [[99]](REFERENCES.md#ref-99).
- Amazon ECR Public IAM authorization reference [[100]](REFERENCES.md#ref-100).

### Iteration 29.7.3 — GitHub Actions IAM Permissions for Amazon ECR Public

**GitHub Pull Request(s):** [PR #29](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/29)

**Objective:**
Extend the existing GitHub Actions IAM role to support publishing Docker images
to Amazon ECR Public without creating a new IAM role or changing the existing
OIDC authentication configuration.

The public Docker image will be used for reproducible deployment of the Java
application through AWS CloudFormation.

**Reference Implementation:**

I used the official Amazon ECR Public documentation for Docker image
publication [[101]](REFERENCES.md#ref-101) and registry authentication [[102]](REFERENCES.md#ref-102).

AWS requires `ecr-public:GetAuthorizationToken` and
`sts:GetServiceBearerToken` permissions for ECR Public authentication.

The Docker image publication process also requires permissions to upload
image layers and register image manifests.

**Implementation:**

Updated `infrastructure/ec2/github-oidc.yaml`.

Added a new `AWS::IAM::ManagedPolicy` resource named
`GitHubECRPublicPushPolicy`.

The policy is attached to the existing `GitHubActionsRole`.

The policy contains two permission groups:

1. `ECRPublicAuthentication` — allows GitHub Actions to obtain
   temporary authentication credentials for Amazon ECR Public.

2. `PushPublicApplicationImages` — allows GitHub Actions to upload
   Docker image layers and publish images to the `atu-ec2-app`
   public repository.

The existing private ECR policy remains unchanged.

**My Modifications:**

- Reused the existing `ATU-GitHub-Actions-ECR` IAM role.
- Preserved the existing GitHub OIDC provider and trust policy.
- Added a separate IAM managed policy for ECR Public.
- Restricted image publication permissions to the project repository.
- Preserved the existing private ECR publishing permissions.
- Used CloudFormation to define the new IAM permissions.

**Design Decision:**

I decided to extend the existing GitHub Actions role instead of creating
another IAM role.

This avoids duplicating the OIDC configuration and preserves the existing
authentication mechanism based on temporary AWS credentials.

A separate managed policy keeps public and private ECR permissions
independent and easier to review.

The public ECR authentication process uses the `us-east-1` Region,
while the EC2 application remains deployed in `eu-west-1`
[[102]](REFERENCES.md#ref-102).

**Testing and Validation:**

- [x] Added the `GitHubECRPublicPushPolicy` resource.
- [x] Reused the existing GitHub Actions IAM role.
- [x] Preserved the private ECR publishing policy.
- [x] Local `cfn-lint` validation passed without errors.
- [x] `git diff --check` passed.
- [x] Updated IAM policy deployed through CloudFormation.
- [x] GitHub Actions authentication to ECR Public verified.
- [x] Docker image publication to ECR Public verified.

**Final Status:**
The updated IAM policy was deployed successfully. GitHub Actions authenticated using OIDC and published the application
image to Amazon ECR Public. The published image and an unauthenticated Docker pull were verified in Iterations
29.7.4–29.7.5.

**References:**

- Amazon ECR Public image publication documentation [[101]](REFERENCES.md#ref-101).
- Amazon ECR Public registry authentication documentation [[102]](REFERENCES.md#ref-102).

**Troubleshooting — Amazon ECR Public CloudFormation Deployment**

**Problem:**

The initial deployment of the `ATU-EC2-ECR-Public` CloudFormation stack
failed because the development IAM user did not have all the permissions
required to create and inspect CloudFormation Change Sets and the
public ECR repository.

**Reference Implementation:**

I used the official AWS documentation *Control CloudFormation access
with AWS Identity and Access Management* to review the permissions
required for CloudFormation stack operations [[103]](REFERENCES.md#ref-103).

I also consulted the AWS Service Authorization Reference for Amazon
ECR Public to identify the permissions required for managing
repository resources and tags [[100]](REFERENCES.md#ref-100).

For troubleshooting the failed deployment, I used the official
CloudFormation documentation *View CloudFormation stack events*
[[104]](REFERENCES.md#ref-104).

**Investigation:**

The first deployment attempt failed with an `AccessDenied` error
for `cloudformation:CreateChangeSet`.

I reviewed the IAM policy and found that Change Set permissions
had been granted for Change Set resources but not all required
permissions had been granted on the CloudFormation stack ARN.

AWS documents the use of IAM policies to control CloudFormation
actions and access to specific resources [[103]](REFERENCES.md#ref-103).

Further investigation identified missing permissions for:

- `cloudformation:CreateChangeSet`
- `cloudformation:ListChangeSets`
- `cloudformation:DescribeChangeSet`
- `cloudformation:ExecuteChangeSet`
- `cloudformation:DeleteChangeSet`

I extended the existing `ManagePublicECRStack` statement to allow
these operations on the `ATU-EC2-ECR-Public` stack.

The separate `ManagePublicECRChangeSets` statement was preserved.

**Amazon ECR Public Tagging Error:**

After correcting the CloudFormation permissions, I successfully
created and executed a Change Set.

The Change Set contained one resource:

`AWS::ECR::PublicRepository`

CloudFormation initially reported `CREATE_COMPLETE` for
`PublicApplicationRepository`.

However, the stack subsequently entered `ROLLBACK_IN_PROGRESS`
because the development IAM user lacked:

`ecr-public:ListTagsForResource`

AWS identifies this operation as the permission required to
retrieve tags associated with an ECR Public resource
[[100]](REFERENCES.md#ref-100).

**Root Cause:**

The initial IAM policy allowed repository creation and tagging
but did not include permission to retrieve resource tags.

CloudFormation required this additional read operation while
processing the repository resource.

The missing permission caused the deployment to fail even though
the repository had initially been created successfully.

**Solution:**

I updated `PublicECRDeploymentPolicy` in:

`infrastructure/bootstrap/network-deployment-access.yaml`

The following permission was added to the
`ManagePublicECRRepository` statement:

`ecr-public:ListTagsForResource`

I then validated the updated CloudFormation template using
`cfn-lint` and redeployed the `ATU-EC2-Bootstrap` stack.

The IAM Bootstrap stack successfully reached `UPDATE_COMPLETE`.

**CloudFormation Recovery:**

I inspected the CloudFormation stack events to identify the
failure reason.

AWS documents the use of stack events and the
`ResourceStatusReason` field for investigating failed
resource operations [[104]](REFERENCES.md#ref-104).

The failed stack reached `ROLLBACK_COMPLETE`.

According to AWS documentation, a stack in this state cannot
be updated and must be deleted before it can be recreated
[[104]](REFERENCES.md#ref-104).

I deleted the failed `ATU-EC2-ECR-Public` stack and repeated
the deployment after correcting the IAM permissions.

**Deployment Result:**

The Amazon ECR Public repository was successfully created.

Repository name:

`atu-ec2-app`

Repository URI:

`public.ecr.aws/e1c9y1q6/atu-ec2-app`

The repository is intended to provide a publicly accessible
Docker image for reproducible EC2 application deployment.

Docker image publication will be configured in the next iteration.

**Lessons Learned:**

- IAM permissions for CloudFormation must cover the required
  stack operations and Change Set operations [[103]](REFERENCES.md#ref-103).

- CloudFormation may require additional AWS service permissions
  beyond the initial resource creation operation [[103]](REFERENCES.md#ref-103).

- Amazon ECR Public provides separate IAM actions for creating,
  tagging and reading repository tags [[100]](REFERENCES.md#ref-100).

- CloudFormation stack events and status reasons are important
  for diagnosing deployment failures [[104]](REFERENCES.md#ref-104).

- A successful resource creation event does not necessarily
  mean that the complete CloudFormation stack deployment
  will succeed.

- Infrastructure permissions should be tested through actual
  CloudFormation deployments, not only template validation.

### Iteration 29.7.4 — Automated Docker Image Publication to Amazon ECR Public

**GitHub Pull Request(s):** [PR #29](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/29)

**Objective:**

Extend the existing GitHub Actions CI pipeline to publish the
containerised Java application to Amazon ECR Public.

The public Docker image will allow the application to be deployed
in another AWS account without requiring access to my private
Amazon ECR repository.

**Reference Implementation:**

I used the official AWS tutorial *Pushing an image to a public
repository in Amazon ECR Public* as the primary reference
[[101]](REFERENCES.md#ref-101).

The tutorial explains Docker authentication, image tagging
and publication to Amazon ECR Public.

I also referred to the official ECR Public authentication
documentation [[102]](REFERENCES.md#ref-102).

GitHub Actions documentation was used to configure reusable
workflow environment variables and the Git commit SHA
[[105]](REFERENCES.md#ref-105).

**Implementation:**

Updated `.github/workflows/docker-deploy.yml`.

The existing workflow builds the Java application using Maven
and creates a Docker image using Docker Buildx.

I extended the workflow with two additional steps:

1. `Login to Amazon ECR Public` — authenticates Docker using
   temporary AWS credentials obtained through GitHub OIDC.

2. `Tag and push Docker image to ECR Public` — tags the
   previously built Docker image and publishes it to
   the public repository.

The public repository URI is:

`public.ecr.aws/e1c9y1q6/atu-ec2-app`

**My Modifications:**

- Reused the existing GitHub Actions workflow.
- Preserved the Maven verification and Docker build steps.
- Preserved publication to the existing private Amazon ECR.
- Added authentication to Amazon ECR Public.
- Used the existing GitHub OIDC IAM role.
- Configured public ECR authentication through `us-east-1`.
- Added reusable environment variables for the image name,
  registry and public registry alias.
- Used the Git commit SHA as the Docker image tag.
- Reused the previously built Docker image without rebuilding it.
- Restricted image publication to pushes to the `master` branch.

**Design Decision:**

I decided to publish the same Docker image to both private
and public Amazon ECR repositories during the transition.

The private repository preserves the existing deployment
workflow, while the public repository makes the application
image accessible without additional AWS account permissions.

The image is built once and then tagged and pushed to
the two registries.

I selected the Git commit SHA as the image tag to identify
the source revision used to build each image.

This supports traceability between Git history, GitHub Actions
executions and published Docker images.

The public registry authentication uses the AWS CLI command
`ecr-public get-login-password` with the `us-east-1` Region,
as documented by AWS [[102]](REFERENCES.md#ref-102).

**Testing and Validation:**

- [x] Existing GitHub Actions workflow inspected.
- [x] Added Amazon ECR Public authentication step.
- [x] Added Docker image tagging and publication step.
- [x] Preserved the existing private ECR publication.
- [x] Reused the existing GitHub OIDC authentication mechanism.
- [x] Added reusable workflow environment variables.
- [x] `git diff --check` passed.
- [x] Updated workflow executed successfully on `master`.
- [x] GitHub Actions authentication to ECR Public verified.
- [x] Docker image publication to ECR Public verified.
- [x] Public Docker image downloaded without authentication.
- [x] CloudFormation EC2 deployment tested using the public image.

**Final Verification:**

After Pull Request #29 was merged into `master`, GitHub Actions successfully published the image to Amazon ECR Public.
The repository image tag and digest were verified, and an unauthenticated Docker pull succeeded (Iteration 29.7.5). The
same public image was subsequently used in a successful fresh EC2 deployment (Iterations 29.7.6 and 29.8.6).

**References:**

- Amazon ECR Public image publication [[101]](REFERENCES.md#ref-101).
- Amazon ECR Public authentication [[102]](REFERENCES.md#ref-102).
- GitHub Actions environment variables [[105]](REFERENCES.md#ref-105).

**Troubleshooting — CloudFormation Validation Region:**

The GitHub Actions CI pipeline initially failed with the following error:

`E3006: Resource type 'AWS::ECR::PublicRepository' does not exist in 'eu-west-1'.`

The failure occurred because the CI pipeline attempted to validate
the Amazon ECR Public CloudFormation template in `eu-west-1`.

Amazon ECR Public resources are managed through the `us-east-1`
AWS Region [[102]](REFERENCES.md#ref-102).

**Solution:**

I updated the CloudFormation validation workflow to validate:

- Standard infrastructure templates in `eu-west-1`.
- The Amazon ECR Public template separately in `us-east-1`.

**Validation:**

- [x] `cfn-lint --regions us-east-1 -t infrastructure/ec2/ecr-public.yaml` passed.
- [x] `git diff --check` passed.
- [x] Updated GitHub Actions CloudFormation validation passed.

This ensures that regional resource availability is correctly
considered during infrastructure validation.

### Iteration 29.7.5 — Verification of Amazon ECR Public Image Publication

**GitHub Pull Request(s):** [PR #29](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/29)

**Objective:**

Verify that GitHub Actions successfully publishes the Java application
Docker image to Amazon ECR Public and that the image can be downloaded
without AWS authentication.

**Reference Implementation:**

I used the official AWS documentation *Pulling an image from the
Amazon ECR Public Gallery* to verify unauthenticated Docker image
downloads [[106]](REFERENCES.md#ref-106).

I also consulted the AWS Service Authorization Reference for Amazon
ECR Public to identify the IAM permission required to inspect
published Docker images [[100]](REFERENCES.md#ref-100).

**Implementation:**

After merging Pull Request #29 into `master`, the GitHub Actions
workflow published the application Docker image to Amazon ECR Public.

Repository:

`public.ecr.aws/e1c9y1q6/atu-ec2-app`

Git commit SHA:

`fc4b4b71c4c1a131b6be47e4e48534ad37f7e921`

Image digest:

`sha256:048835a709824114f3c6380a30f7d8f9b78d636d45bd173b0746db67ab0d5730`

**Troubleshooting — Missing IAM Permission:**

The initial image verification attempt failed with:

`AccessDeniedException: ecr-public:DescribeImages`

The development IAM user did not have permission to retrieve
metadata about images stored in the public repository.

According to the AWS Service Authorization Reference,
`ecr-public:DescribeImages` grants permission to retrieve
image metadata, including tags and image digests [[100]](REFERENCES.md#ref-100).

I added this permission to the existing
`ManagePublicECRRepository` statement in:

`infrastructure/bootstrap/network-deployment-access.yaml`

After validating the template using `cfn-lint`, I redeployed
the `ATU-EC2-Bootstrap` CloudFormation stack.

The deployment completed successfully.

**Image Verification:**

I used the AWS CLI command `ecr-public describe-images` to
retrieve the image tag and digest.

The command returned the Git commit SHA tag and image digest,
confirming that the image was present in the public repository.

**Unauthenticated Docker Pull:**

To verify public accessibility, I removed the Docker registry
credentials using:

`docker logout public.ecr.aws`

I then downloaded the published image using:

`docker pull public.ecr.aws/e1c9y1q6/atu-ec2-app:fc4b4b71c4c1a131b6be47e4e48534ad37f7e921`

Docker successfully downloaded all image layers.

The downloaded image digest matched the digest reported by
Amazon ECR Public.

AWS documents that public images can be downloaded without
authentication and recommends `docker logout public.ecr.aws`
when verifying unauthenticated pulls [[106]](REFERENCES.md#ref-106).

**Testing and Validation:**

- [x] Pull Request #29 merged into `master`.
- [x] GitHub Actions published the Docker image to ECR Public.
- [x] Added the missing `ecr-public:DescribeImages` IAM permission.
- [x] CloudFormation template validation passed.
- [x] IAM Bootstrap stack updated successfully.
- [x] Published image SHA tag verified.
- [x] Published image digest verified.
- [x] Docker registry credentials removed.
- [x] Docker image downloaded without authentication.
- [x] Downloaded image digest matched the published digest.
- [x] Automated deployment on a newly provisioned EC2 instance verified.

**Conclusion:**

Amazon ECR Public image publication and unauthenticated image
retrieval were successfully verified.

The published Docker image can be retrieved without granting
the consuming AWS account access to the original private ECR.

The next stage is to configure the EC2 CloudFormation template
to use the verified public image and test automated application
deployment through EC2 UserData.

### Iteration 29.7.6 — Reproducible EC2 Deployment Using CloudFormation UserData

**GitHub Pull Request(s):** [PR #30](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/30)

**Objective:**

Verify that the Java application can be deployed automatically on a
new Amazon EC2 instance using AWS CloudFormation UserData, without
manually installing Docker or deploying the application through SSM.

**Reference Implementation:**

I followed the official AWS documentation *Run commands when you launch
an EC2 instance with user data input* to configure and verify
first-launch automation [[107]](REFERENCES.md#ref-107).

I also used the AWS documentation for Systems Manager Run Command
to inspect the deployment results remotely [[108]](REFERENCES.md#ref-108).

The application Docker image was retrieved from Amazon ECR Public,
which supports unauthenticated image downloads [[106]](REFERENCES.md#ref-106).

**Implementation:**

I recreated the existing `ATU-EC2-Instance` CloudFormation stack
using the updated template:

`infrastructure/ec2/instance.yaml`

The previous EC2 instance was replaced with a newly provisioned
Amazon Linux 2023 instance.

New EC2 instance ID:

`i-0d455a3e1dc4eea7b`

Instance type:

`t3.micro`

The CloudFormation UserData script automatically:

1. Enabled the AWS Systems Manager Agent.
2. Installed Docker using `dnf`.
3. Enabled and started the Docker service.
4. Downloaded the Java application image from Amazon ECR Public.
5. Started the application container with restricted privileges.
6. Configured the DynamoDB table name and AWS Region.
7. Verified the `/health` and `/message` application endpoints.

The Docker image used was:

`public.ecr.aws/e1c9y1q6/atu-ec2-app:fc4b4b71c4c1a131b6be47e4e48534ad37f7e921`

**My Modifications:**

- Reused the existing CloudFormation network infrastructure.
- Reused the existing EC2 IAM Instance Profile.
- Reused the existing DynamoDB table.
- Used the public ECR image instead of requiring private ECR authentication.
- Automated Docker installation and container startup through UserData.
- Configured Docker to restart the container unless explicitly stopped.
- Preserved container security restrictions, including a non-root user,
  dropped Linux capabilities and a read-only root filesystem.
- Added application startup verification to the UserData script.
- Verified the deployment remotely through AWS Systems Manager.

**Testing and Validation:**

- [x] CloudFormation template validated using `cfn-lint`.
- [x] Existing EC2 CloudFormation stack recreated successfully.
- [x] New EC2 instance provisioned using Amazon Linux 2023.
- [x] AWS Systems Manager Agent reported `Online`.
- [x] Docker automatically installed and started.
- [x] Docker service reported `active`.
- [x] Public ECR Docker image downloaded successfully.
- [x] Docker image digest matched the published ECR Public digest.
- [x] Java application container started automatically.
- [x] Docker container reported `Up 5 minutes`.
- [x] GET `/health` returned HTTP 200.
- [x] GET `/message` returned HTTP 200.
- [x] DynamoDB returned one existing application message.
- [x] Cloud-init completed successfully.
- [x] AWS Systems Manager Run Command completed successfully.
- [x] No manual application installation or Docker deployment was required.

**Deployment Evidence:**
CloudFormation stack:

`ATU-EC2-Instance`

CloudFormation status:

`CREATE_COMPLETE`

Docker service:

`active`

Application container:

`atu-ec2-app`

Health endpoint response:

`{"service":"ec2-app","status":"UP"}`

Message endpoint:
Returned HTTP 200 with one message retrieved from DynamoDB.
Cloud-init completion:

`Cloud-init v. 22.2.2 finished at Wed, 28 Oct 2026 11:19:46 +0000.`

**Troubleshooting:**
The initial AWS Systems Manager verification command failed because
PowerShell incorrectly interpreted the JSON parameter containing
multiple shell commands.

I resolved this by generating a JSON parameter file using
PowerShell `ConvertTo-Json` and passing the file to the AWS CLI
using the `file://` syntax.

The subsequent Systems Manager Run Command completed successfully.

The cloud-init output also contained two temporary HTTP connection
errors while the Java application was starting.

The UserData startup verification loop retried the health endpoint,
and the third attempt succeeded.

Both application endpoints subsequently returned HTTP 200.

AWS recommends checking `/var/log/cloud-init-output.log` to diagnose
the execution of EC2 UserData scripts [[107]](REFERENCES.md#ref-107).

**Conclusion:**

The Java application was successfully deployed on a newly provisioned
Amazon EC2 instance using CloudFormation UserData.

Docker installation, public image retrieval, container startup and
application health verification completed automatically.

This confirms that the EC2 application deployment can be reproduced
without manual server configuration in the tested AWS environment.

The deployment still depends on the supporting CloudFormation
infrastructure, including the network, IAM Instance Profile and
DynamoDB table.

### Iteration 29.8.3 — Removing Hardcoded API Gateway Integration ID

**GitHub Pull Request(s):** [PR #31](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/31) *(planned; link
becomes active when PR #31 is created)*

**Objective:**
Remove the account-specific API Gateway Integration ID from the
CloudFormation template to improve cross-account reproducibility.

**Reference Implementation:**
I used the official AWS CloudFormation documentation for
`AWS::ApiGatewayV2::Integration` and `AWS::ApiGatewayV2::Route`
to replace the hardcoded Integration ID with a CloudFormation-managed
resource [[109]](REFERENCES.md#ref-109) [[110]](REFERENCES.md#ref-110).

**Implementation:**
The original `POST /message` route referenced a fixed API Gateway
Integration ID:

`integrations/zv9cjno`

This identifier was created in my AWS account and would not be
valid in another AWS account.

I added an `AWS::ApiGatewayV2::Integration` resource named
`MessagePostIntegration`.

The `MessagePostRoute` resource now uses:

`Target: !Sub 'integrations/${MessagePostIntegration}'`

CloudFormation automatically resolves the integration identifier
using the reference to the new resource [[109]](REFERENCES.md#ref-109).

**Testing and Validation:**

- [x] Removed the hardcoded API Gateway Integration ID.
- [x] Added the CloudFormation-managed `MessagePostIntegration`.
- [x] Updated `MessagePostRoute` to reference the new Integration.
- [x] CloudFormation lint validation passed.
- [x] `git diff --check` passed.
- [x] CloudFormation Change Set created successfully.
- [x] Change Set contained only the expected resource changes.
- [x] Existing API Gateway route updated without replacement.
- [x] CloudFormation stack reached `UPDATE_COMPLETE`.
- [x] `GET /message` continued to return DynamoDB data.
- [x] `POST /message` confirmed to use the new Integration.
- [x] `POST /message` retained `AWS_IAM` authorization.
- [ ] Authenticated `POST /message` request verified.

**Conclusion:**
The account-specific API Gateway Integration ID was removed
from the CloudFormation template.

The POST route now references an Integration created and managed
by CloudFormation, improving infrastructure reproducibility.

The GET endpoint remains operational, while authenticated POST
execution requires separate verification.

### Iteration 29.8.4 — Removing Account-Specific IAM User Dependency

**GitHub Pull Request(s):** [PR #31](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/31) *(planned; link
becomes active when PR #31 is created)*

**Objective:**
Remove the dependency on a manually created IAM user from the
three-tier CloudFormation template to improve cross-account
infrastructure reproducibility.

**Reference Implementation:**
I used the official AWS CloudFormation documentation for
`AWS::IAM::Policy` to review how inline IAM policies are attached
to users, groups and roles [[111]](REFERENCES.md#ref-111).

I also referred to the API Gateway documentation for IAM
authorization to ensure that removing the client policy would
not disable authentication for the POST endpoint
[[112]](REFERENCES.md#ref-112).

**Implementation:**
The original `three-tier.yaml` contained an IAM policy resource
named `MessagePostClientPolicy`.

This policy granted `execute-api:Invoke` permission for
`POST /message` directly to the existing IAM user
`atu-devops-lab`.

Since this user was manually created in my AWS account,
the CloudFormation template depended on an account-specific
IAM identity.

I removed the entire `MessagePostClientPolicy` resource
from the template.
The API Gateway route retained:

`AuthorizationType: AWS_IAM`

Therefore, authenticated POST requests still require an IAM
principal with the appropriate `execute-api:Invoke` permission
[[112]](REFERENCES.md#ref-112).

**Testing and Validation:**

- [x] Removed the account-specific `MessagePostClientPolicy`.
- [x] Preserved `AWS_IAM` authorization for `POST /message`.
- [x] CloudFormation lint validation passed.
- [x] `git diff --check` passed.
- [x] CloudFormation Change Set created successfully.
- [x] Change Set contained only one resource removal.
- [x] No Lambda, DynamoDB or API Gateway replacement was required.
- [x] CloudFormation stack reached `UPDATE_COMPLETE`.
- [x] GET `/message` verified after IAM policy removal.
- [ ] Authenticated POST `/message` verified after IAM policy removal.

**Conclusion:**
The three-tier CloudFormation template no longer requires
the account-specific IAM user `atu-devops-lab`.
The POST endpoint remains protected by AWS IAM authorization.
Permission to invoke POST requests must be granted separately
to the IAM principal used by an API client.

### Iteration 29.8.5 — Parameterising API Gateway CORS Origin

**GitHub Pull Request(s):** [PR #31](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/31) *(planned; link
becomes active when PR #31 is created)*

**Objective:**
Remove the hardcoded CloudFront domain from the API Gateway CORS
configuration to support deployment in another AWS account.

**Reference Implementation:**
I used the official AWS CloudFormation documentation for
`AWS::ApiGatewayV2::Api` to configure CORS using a CloudFormation
parameter [[113]](REFERENCES.md#ref-113).

**Implementation:**
Added the `AllowedCorsOrigin` parameter to `three-tier.yaml`.
Replaced the hardcoded CloudFront URL in `CorsConfiguration.AllowOrigins`
with `!Ref AllowedCorsOrigin`.

The existing CloudFront domain was retained as the default value
to preserve the current application configuration.

**Testing and Validation:**

- [x] Added the `AllowedCorsOrigin` parameter.
- [x] Replaced the hardcoded CORS origin with a parameter reference.
- [x] `cfn-lint` validation passed.
- [x] `git diff --check` passed.
- [x] CloudFormation Change Set creation attempted.
- [x] Confirmed that CloudFormation detected no resource changes.
- [x] Updated parameterized template deployed successfully.
- [ ] CORS verified with a different CloudFront domain.

**Conclusion:**
The API Gateway CORS origin is now configurable through a
CloudFormation parameter in the local template.

The attempted update produced no resource changes because the
resolved CORS value was unchanged.

The parameterised template was subsequently deployed during Iteration 29.8.6, when the `ATU-Three-Tier` stack was
updated to export the DynamoDB table name. A separate CORS test using a different CloudFront origin remains outstanding.

### Iteration 29.8.6 — Removing Hardcoded DynamoDB Table Name from EC2

**GitHub Pull Request(s):** [PR #31](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/31) *(planned; link
becomes active when PR #31 is created)*

**Objective:**

Remove the hardcoded DynamoDB table name from the EC2 CloudFormation template and configure automatic retrieval of the
table name through CloudFormation cross-stack references.

**Reference Implementation:**

I used the official AWS documentation *Get exported outputs from a deployed CloudFormation stack* to configure `Export`
and `Fn::ImportValue` [[114]](REFERENCES.md#ref-114).

I also consulted the AWS CloudFormation documentation for `Fn::Sub` to pass the imported table name into the EC2
UserData script [[115]](REFERENCES.md#ref-115).

**Implementation:**

The original EC2 template contained a hardcoded DynamoDB table name:

`ATU-Three-Tier-messages`

This created a dependency on the name of the CloudFormation stack used to provision the DynamoDB table.

I added an `Export` to the `MessagesTableName` output in `infrastructure/three-tier.yaml`:

`ATU-Three-Tier-MessagesTableName`

I removed the `DynamoTableName` parameter from `infrastructure/ec2/instance.yaml`.

The EC2 UserData configuration now uses `Fn::Sub` with a variable mapping to retrieve the DynamoDB table name through
`Fn::ImportValue`.

The imported value is passed to the Java application through the `TABLE_NAME` environment variable.

**Deployment and Verification:**

I updated the `ATU-Three-Tier` CloudFormation stack and verified that the DynamoDB table name was exported successfully.

The exported value was:

`ATU-Three-Tier-messages`

I then deleted and recreated the existing `ATU-EC2-Instance` CloudFormation stack using the updated template.

New EC2 instance:

`i-0442df0132f2e9394`

The new instance automatically installed Docker, downloaded the application image from Amazon ECR Public and started the
Java application.

AWS Systems Manager Run Command was used to verify the deployment.

**Testing and Validation:**

- [x] DynamoDB table name exported through CloudFormation.
- [x] DynamoDB Export verified using AWS CLI.
- [x] Removed the hardcoded `DynamoTableName` parameter.
- [x] Configured `Fn::ImportValue` inside `Fn::Sub`.
- [x] CloudFormation lint validation passed.
- [x] Existing EC2 CloudFormation stack recreated successfully.
- [x] Docker Engine started automatically.
- [x] Docker container started successfully.
- [x] GET `/health` returned HTTP 200.
- [x] GET `/message` returned HTTP 200.
- [x] DynamoDB returned one existing message.
- [x] Cloud-init completed successfully.
- [x] AWS Systems Manager Run Command completed successfully.

**Troubleshooting:**
During template validation, `git diff --check` detected trailing whitespace in the modified UserData section.The
whitespace was removed before deployment.

The initial CloudFormation Change Set reported conditional EC2 replacement because the `UserData` property had changed.

Since the objective was to verify deployment on a clean instance, I deleted and recreated the existing EC2 stack rather
than updating the running instance.

During startup, the health verification loop initially received connection reset errors while the Java application was
starting.

The subsequent retry succeeded, and both application endpoints returned HTTP 200.

**Conclusion:**
The EC2 application no longer depends on a hardcoded DynamoDB table name.
CloudFormation automatically retrieves the DynamoDB table name from the three-tier infrastructure stack.

The successful deployment confirms that the Java application can be provisioned automatically using the exported
DynamoDB table name.
The deployment requires the exporting CloudFormation stack to exist in the same AWS account and Region before the EC2
stack is created.

### Iteration 29.8.7 — Removing Hardcoded EC2 Instance IDs from IAM Policies

**GitHub Pull Request(s):** [PR #31](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/31) *(planned; link
becomes active when PR #31 is created)*

**Objective:**
Remove hardcoded EC2 Instance IDs from the IAM Bootstrap CloudFormation template to improve cross-account
reproducibility.

Configure tag-based IAM permissions so that newly provisioned EC2 instances can be managed without updating the IAM
policy after each deployment.

**Reference Implementation:**
I used the official AWS documentation *EC2: Start or stop instances based on tags* to configure resource-level
permissions using the `aws:ResourceTag` condition key [[116]](REFERENCES.md#ref-116).

I also consulted the AWS Systems Manager documentation *Setting up Run Command* to restrict command execution to tagged
EC2 instances [[117]](REFERENCES.md#ref-117).

**Implementation:**
Updated `infrastructure/bootstrap/network-deployment-access.yaml`.
The original IAM policy contained two hardcoded EC2 Instance IDs:

- `i-050f1033713bc9105`
- `i-0a86cb75e6b6d65b4`

These identifiers referred to previous EC2 instances and became invalid after the infrastructure was recreated.

I updated two IAM policy statements:

1. `ControlApplicationInstanceState`
2. `SendSSMCommandToApplicationInstance`

Both statements now reference EC2 instances through a wildcard ARN:
`arn:${AWS::Partition}:ec2:${AWS::Region}:${AWS::AccountId}:instance/*`
Access is restricted using the following condition:
`aws:ResourceTag/Project: ATU-CloudFormation-Lab`
The first statement controls `ec2:StartInstances` and `ec2:StopInstances`.
The second statement controls `ssm:SendCommand` for the project EC2 instances.
The existing permissions for the AWS-managed `AWS-RunShellScript` document and SSM command result retrieval were
preserved.

**Design Decision:**
I selected tag-based IAM permissions instead of referencing individual EC2 Instance IDs.
CloudFormation generates a new Instance ID whenever an EC2 instance is recreated.

Using the project tag allows IAM permissions to remain applicable across subsequent deployments without modifying the
IAM policy.
The permissions remain restricted to EC2 instances in the configured AWS account and Region that have the required
project tag.

**Deployment and Verification:**
I validated the updated CloudFormation template and deployed it to the existing IAM Bootstrap stack.
CloudFormation stack:

`ATU-EC2-Bootstrap`

Deployment result:

`UPDATE_COMPLETE`

I then authenticated using the dedicated IAM user profile `atu-lab` and executed an AWS Systems Manager Run Command on
the newly provisioned EC2 instance.

EC2 Instance ID:

`i-0442df0132f2e9394`

SSM Command ID:

`030e2755-b3df-4b72-87e3-8d0fbb0a077f`

The command executed:

- `whoami`
- `systemctl is-active docker`

**Actual Result:**

~~~text
Status: Success

Output:
root
active

Errors: ""
~~~

This confirmed that the updated IAM permissions allowed the development IAM user to execute SSM commands on the new EC2
instance.

**Testing and Validation:**

- [x] Removed the hardcoded EC2 Instance IDs.
- [x] Configured wildcard EC2 resource ARNs.
- [x] Added project tag conditions to the IAM policy statements.
- [x] Preserved the existing SSM document permissions.
- [x] Local `cfn-lint` validation passed.
- [x] `git diff --check` passed.
- [x] IAM Bootstrap stack updated successfully.
- [x] CloudFormation stack reached `UPDATE_COMPLETE`.
- [x] SSM Run Command submitted using the `atu-lab` profile.
- [x] SSM command completed with `Success`.
- [x] Docker service returned `active`.
- [x] SSM command completed without errors.
- [x] No EC2 replacement was required.

**Limitations:**
The IAM policy still depends on the existing developer IAM group, which will be reviewed separately as part of
cross-account reproducibility.

The successful SSM test confirms access to an instance with the required project tag. A negative test against an
instance without the tag has not been performed.

EC2 start and stop permissions were not independently tested during this iteration.

**Conclusion:**
The IAM Bootstrap configuration no longer depends on hardcoded EC2 Instance IDs.

Tag-based permissions allow the development IAM user to manage newly provisioned project instances without updating the
IAM policy after each EC2 replacement.

The successful SSM test confirms that the updated permissions work with the current EC2 instance.
This improves infrastructure reproducibility while preserving project-specific IAM access restrictions.

### Iteration 29.8.8 — Removing Dependency on an Existing IAM Group

**GitHub Pull Request(s):** [PR #31](https://github.com/maxvanny2010/L00213593_LabAssignment_1/pull/31) *(planned; link
becomes active when PR #31 is created)*

**Objective:**

Remove the requirement for a pre-existing IAM developer group when deploying the IAM Bootstrap infrastructure in another
AWS account.

**Reference Implementation:**

I used the official AWS CloudFormation documentation for resource conditions and conditional expressions to implement
optional IAM group creation [[118]](REFERENCES.md#ref-118).

I also consulted the CloudFormation documentation for `AWS::IAM::Group` and
`Fn::If` [[119]](REFERENCES.md#ref-119) [[120]](REFERENCES.md#ref-120).

**Implementation:**

Updated `infrastructure/bootstrap/network-deployment-access.yaml`.

Added the `UseExistingDeveloperGroup` parameter with two supported values:

- `true` — reuse an existing IAM group.
- `false` — create a new IAM group using CloudFormation.

Added the `CreateDeveloperGroup` condition and the `DeveloperGroup` resource using `AWS::IAM::Group`.

Updated three IAM Managed Policies to use conditional group references:

- `NetworkDeploymentPolicy`
- `GitHubOIDCDeploymentPolicy`
- `PublicECRDeploymentPolicy`

When `UseExistingDeveloperGroup=false`, CloudFormation creates the IAM group and attaches all three managed policies.

When `UseExistingDeveloperGroup=true`, the template references the existing group.

**Testing and Validation:**

Created a temporary CloudFormation stack using the updated template:

`ATU-Bootstrap-Repro-Test`

Deployment parameters:

- `UseExistingDeveloperGroup=false`
- `DeveloperGroupName=ATU-Lab-Repro-Test-20261028`

**Actual Results:**

- [x] Local `cfn-lint` validation passed.
- [x] `git diff --check` passed.
- [x] Temporary CloudFormation stack created successfully.
- [x] Stack reached `CREATE_COMPLETE`.
- [x] New IAM group created through CloudFormation.
- [x] All three IAM Managed Policies created.
- [x] All three policies attached to the new IAM group.
- [x] Test group contained no IAM users.
- [x] Temporary CloudFormation stack deleted successfully.
- [x] Stack deletion completed successfully.
- [x] IAM group removal confirmed through `NoSuchEntity`.
- [x] Existing production lab infrastructure remained unchanged.

**Design Decision:**
I selected conditional resource creation to support both existing and newly provisioned IAM groups.This avoids requiring
manual group creation before deploying the IAM Bootstrap template.

The existing IAM group is preserved in the original AWS account, while a new group can be provisioned automatically in
another account.

**Limitations:**
The test was performed in the existing AWS account using a separate temporary CloudFormation stack.

It confirms that the IAM group and its managed policies can be created and removed automatically.It does not yet
demonstrate complete infrastructure deployment in a different AWS account.

IAM user creation and group membership are not automated by this template.

**Conclusion:**
The IAM Bootstrap template successfully supports automatic IAM group creation.A temporary CloudFormation deployment
confirmed that all three managed policies were attached to the newly created group.

The temporary infrastructure was subsequently removed through CloudFormation. The dependency on a manually created IAM
group has been eliminated for the new-group deployment scenario.
