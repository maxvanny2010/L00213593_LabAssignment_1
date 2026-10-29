# Manual AWS Deployment Guide

This guide describes how to deploy the ATU CloudFormation Lab **from a clean AWS environment**, step by step, without running the automation script. The equivalent automated procedure is `bash scripts/deploy.sh` from the repository root.

> **Costs and scope:** These commands create S3, CloudFront, Lambda, API Gateway, DynamoDB, VPC, IAM, and EC2 resources and may incur AWS charges. The repository's public Docker image is reused; an ECR repository, GitHub OIDC role, and optional IAM bootstrap stack are **not** created. Use an AWS identity with sufficient permissions; root credentials are not required or recommended.

## 1. Requirements

Run commands in **Bash** (for example Git Bash, WSL, Linux, macOS, or AWS CloudShell). PowerShell syntax differs. You need:

- AWS CLI v2 authenticated to the **target** AWS account, with sufficient CloudFormation, IAM, S3, CloudFront, Lambda, API Gateway, DynamoDB, EC2, and SSM permissions;
- Bash, Java 21, Maven, and `curl`;
- the cloned repository and network access to Maven dependencies and the public Docker registry.

AWS CloudShell supplies AWS CLI credentials for the signed-in identity, but verify that Java 21 and Maven are installed before choosing CloudShell. The deployment region below is `eu-west-1`.

```bash
git clone https://github.com/maxvanny2010/L00213593_LabAssignment_1.git
cd L00213593_LabAssignment_1

aws --version
java -version
mvn -version
curl --version
aws sts get-caller-identity
```

Check that the displayed account is the one in which you intend to create resources. If you use a named AWS CLI profile, select it before proceeding: `export AWS_PROFILE=your-profile-name`.

## 2. Set the deployment region and check for existing stacks

```bash
export AWS_DEFAULT_REGION=eu-west-1

for stack in ATU-Static-Website ATU-Lambda-Artifacts ATU-Three-Tier \
             ATU-EC2-Network ATU-EC2-SecurityGroup ATU-EC2-IAM ATU-EC2-Instance; do
  if aws cloudformation describe-stacks --stack-name "$stack" >/dev/null 2>&1; then
    echo "Existing stack: $stack — do not continue with a fresh deployment"
    exit 1
  fi
done
```

These steps assume the stack names and exported outputs are unused in the target account/region. Do not use them to modify an existing lab deployment.

## 3. Create the static website infrastructure

```bash
aws cloudformation deploy \
  --template-file infrastructure/static-website.yaml \
  --stack-name ATU-Static-Website

WEBSITE_BUCKET="$(aws cloudformation describe-stacks \
  --stack-name ATU-Static-Website \
  --query "Stacks[0].Outputs[?OutputKey=='WebsiteBucketName'].OutputValue | [0]" \
  --output text)"
WEBSITE_URL="$(aws cloudformation describe-stacks \
  --stack-name ATU-Static-Website \
  --query "Stacks[0].Outputs[?OutputKey=='WebsiteURL'].OutputValue | [0]" \
  --output text)"
printf 'Bucket: %s\nWebsite: %s\n' "$WEBSITE_BUCKET" "$WEBSITE_URL"
```

The site is served through CloudFront using a private S3 origin. It is uploaded after the new API URL is known.

## 4. Deploy the Lambda artefact bucket and upload the Java JAR

```bash
aws cloudformation deploy \
  --template-file infrastructure/lambda-artifacts.yaml \
  --stack-name ATU-Lambda-Artifacts

ARTIFACT_BUCKET="$(aws cloudformation list-exports \
  --query "Exports[?Name=='ATU-Lambda-ArtifactsBucketName'].Value | [0]" \
  --output text)"

mvn -B -pl lambda-app -am clean package

ARTIFACT_VERSION="$(aws s3api put-object \
  --bucket "$ARTIFACT_BUCKET" \
  --key lambda/student-message-board-1.0-SNAPSHOT.jar \
  --body lambda-app/target/lambda-app-1.0-SNAPSHOT.jar \
  --query VersionId --output text)"
printf 'Lambda JAR version: %s\n' "$ARTIFACT_VERSION"
```

The S3 bucket has versioning enabled. `ARTIFACT_VERSION` is passed to the three-tier stack so Lambda uses this exact JAR version.

## 5. Deploy API Gateway, Java Lambda and DynamoDB

```bash
aws cloudformation deploy \
  --template-file infrastructure/three-tier.yaml \
  --stack-name ATU-Three-Tier \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    "LambdaArtifactVersion=$ARTIFACT_VERSION" \
    "AllowedCorsOrigin=$WEBSITE_URL"

API_URL="$(aws cloudformation describe-stacks \
  --stack-name ATU-Three-Tier \
  --query "Stacks[0].Outputs[?OutputKey=='MessageApiEndpoint'].OutputValue | [0]" \
  --output text)"
printf 'API: %s\n' "$API_URL"

curl --fail --silent --show-error "$API_URL"
```

`AllowedCorsOrigin` must match the CloudFront origin created **in this account**, rather than an address from another deployment. A newly created DynamoDB table may be empty; a successful GET can return valid JSON without any stored messages. `POST /message` is protected by AWS IAM and is not required for the public website read-only check.

## 6. Deploy the EC2 network, security group, IAM and application instance

Run these in order because the templates use CloudFormation exports and imports:

```bash
aws cloudformation deploy \
  --template-file infrastructure/ec2/network.yaml \
  --stack-name ATU-EC2-Network

aws cloudformation deploy \
  --template-file infrastructure/ec2/security-groups.yaml \
  --stack-name ATU-EC2-SecurityGroup

aws cloudformation deploy \
  --template-file infrastructure/ec2/iam.yaml \
  --stack-name ATU-EC2-IAM \
  --capabilities CAPABILITY_IAM

aws cloudformation deploy \
  --template-file infrastructure/ec2/instance.yaml \
  --stack-name ATU-EC2-Instance

INSTANCE_ID="$(aws cloudformation describe-stacks \
  --stack-name ATU-EC2-Instance \
  --query "Stacks[0].Outputs[?OutputKey=='InstanceId'].OutputValue | [0]" \
  --output text)"
printf 'EC2: %s\n' "$INSTANCE_ID"
```

The EC2 template uses Amazon Linux 2023 UserData to install Docker and start the already-published image `public.ecr.aws/e1c9y1q6/atu-ec2-app:fc4b4b71c4c1a131b6be47e4e48534ad37f7e921`. No SSH port needs to be opened: verification is performed using AWS Systems Manager (SSM).

## 7. Publish the website with the new API URL

Generate a deployment-specific browser configuration in a temporary file instead of editing the tracked local `web/js/config.js`:

```bash
CONFIG_FILE="$(mktemp)"
printf 'window.APP_CONFIG = { API_URL: "%s" };\n' "$API_URL" > "$CONFIG_FILE"

aws s3 cp web/index.html "s3://${WEBSITE_BUCKET}/index.html" \
  --content-type text/html
aws s3 cp web/js/message.js "s3://${WEBSITE_BUCKET}/js/message.js" \
  --content-type application/javascript
aws s3 cp "$CONFIG_FILE" "s3://${WEBSITE_BUCKET}/js/config.js" \
  --content-type application/javascript --cache-control 'no-cache'
rm -f "$CONFIG_FILE"
```

`web/index.html` loads `js/config.js` before `js/message.js`. CloudFront may take a short time to propagate a new distribution and content. Open `$WEBSITE_URL` in a browser and verify that it fetches the API without a CORS error.

## 8. Verify EC2 Docker and application through SSM

SSM registration can finish before EC2 UserData, Docker installation and Java startup. **Wait until the instance reports `Online`, and retry the application check if necessary.**

```bash
aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
  --query 'InstanceInformationList[0].PingStatus' --output text
```

When the result is `Online`, send a check command:

```bash
COMMAND_ID="$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript \
  --parameters '{"commands":["set -eu","systemctl is-active docker","docker ps --format {{.Names}} | grep -Fx atu-ec2-app","curl -fsS http://127.0.0.1:8080/health","curl -fsS http://127.0.0.1:8080/message"]}' \
  --query 'Command.CommandId' --output text)"

aws ssm wait command-executed \
  --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID"

aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
  --query '{Status:Status,Output:StandardOutputContent,Errors:StandardErrorContent}' \
  --output json
```

If the check fails while the instance is booting, inspect the command output and retry after allowing more time for UserData. Check both `/health` and `/message` for HTTP success. A fresh database may contain no message records.

## 9. Summary and automated alternative

```bash
printf 'Website: %s\nAPI: %s\nEC2: %s\n' "$WEBSITE_URL" "$API_URL" "$INSTANCE_ID"
```

For a **one-command automated deployment**, from a clean environment with the same prerequisites, run:

```bash
bash scripts/deploy.sh
```

The script checks the AWS account, requests explicit confirmation, deploys the same CloudFormation stacks in dependency order, builds and uploads the Lambda artefact, generates the JavaScript configuration, publishes the site, and checks the services over HTTP and SSM.

**Important:** The manual process and deployment script are designed for fresh deployments; neither should be used as an unreviewed update procedure for existing stacks. The automated deployment has been tested successfully in a second Region using a separate IAM user in the same AWS account; deployment in a wholly separate account remains untested.

## 10. Cleanup

AWS resources may continue to incur charges after testing. Delete the stacks in **reverse dependency order**, taking care to empty S3 buckets first, including object versions and deletion markers where versioning is enabled. Do not delete shared or unrelated resources. For automated cleanup, set `AWS_REGION` explicitly and run `bash scripts/destroy.sh` with an appropriately authorised non-root AWS CLI identity. Inspect the target account, Region and stack names and enter the displayed confirmation phrase. The script checks project stack ownership tags before deleting. It has been exercised successfully in `eu-west-2` in the project account; its updated cross-account safeguards have not yet been exercised in another account.
