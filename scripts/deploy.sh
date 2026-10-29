#!/usr/bin/env bash
# ATU CloudFormation Lab — fresh-account deployment (Bash).
# Requires authenticated AWS CLI identity with CloudFormation, IAM, S3,
# CloudFront, API Gateway, Lambda, DynamoDB, EC2 and SSM permissions.
set -Eeuo pipefail

REGION="${AWS_REGION:-eu-west-1}"
IMAGE='public.ecr.aws/e1c9y1q6/atu-ec2-app:fc4b4b71c4c1a131b6be47e4e48534ad37f7e921'
ARTIFACT_KEY='lambda/student-message-board-1.0-SNAPSHOT.jar'
SEED_DEMO=0
case "${1:-}" in
  "") ;;
  --seed-demo) SEED_DEMO=1 ;;
  *) printf "Usage: %s [--seed-demo]\n" "$0" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo "Usage: $0 [--seed-demo]" >&2; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
trap 'printf "\nFAILED at line %s: %s\nExisting AWS resources are NOT automatically deleted.\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

for cmd in aws mvn java curl; do command -v "$cmd" >/dev/null || die "Missing dependency: $cmd"; done
for f in infrastructure/static-website.yaml infrastructure/lambda-artifacts.yaml infrastructure/three-tier.yaml infrastructure/ec2/network.yaml infrastructure/ec2/security-groups.yaml infrastructure/ec2/iam.yaml infrastructure/ec2/instance.yaml web/index.html web/js/message.js; do
  [[ -f "$f" ]] || die "Required file not found: $f"
done

export AWS_DEFAULT_REGION="$REGION"
log 'Checking AWS identity'
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
[[ "$ACCOUNT" =~ ^[0-9]{12}$ ]] || die 'Invalid AWS Account ID'
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output table
printf 'This deploys new AWS resources in account %s (%s) and can incur charges.\n' "$ACCOUNT" "$REGION"
printf 'Type DEPLOY to proceed: '
read -r approval
[[ "$approval" == DEPLOY ]] || die 'Cancelled'

# Deliberately refuse to modify existing stacks. This script is for CLEAN deployments.
STACKS=(ATU-Static-Website ATU-Lambda-Artifacts ATU-Three-Tier ATU-EC2-Network ATU-EC2-SecurityGroup ATU-EC2-IAM ATU-EC2-Instance)
for stack in "${STACKS[@]}"; do
  if aws cloudformation describe-stacks --stack-name "$stack" --query 'Stacks[0].StackStatus' --output text >/dev/null 2>&1; then
    die "Stack already exists: $stack. This script is for a fresh deployment only."
  fi
done

stack_output() {
  local stack="$1" key="$2" result
  result="$(aws cloudformation describe-stacks --stack-name "$stack" --query "Stacks[0].Outputs[?OutputKey=='${key}'].OutputValue | [0]" --output text)"
  [[ -n "$result" && "$result" != None ]] || die "Missing output $key in $stack"
  printf '%s' "$result"
}

deploy() {
  local template="$1" stack="$2"; shift 2
  log "Deploying $stack"
  aws cloudformation deploy --template-file "$template" --stack-name "$stack" --region "$REGION" \
    --tags Project=ATU-CloudFormation-Lab ManagedBy=CloudFormation "$@"
}

# 1. Static site first: its generated CloudFront origin is required by API CORS.
deploy infrastructure/static-website.yaml ATU-Static-Website
WEBSITE_BUCKET="$(stack_output ATU-Static-Website WebsiteBucketName)"
WEBSITE_URL="$(stack_output ATU-Static-Website WebsiteURL)"

# 2. Build Java Lambda, upload immutable S3 object version.
deploy infrastructure/lambda-artifacts.yaml ATU-Lambda-Artifacts
# The artifacts stack exports its generated bucket name for cross-stack use.
ARTIFACT_BUCKET="$(aws cloudformation list-exports \
  --query "Exports[?Name=='ATU-Lambda-ArtifactsBucketName'].Value | [0]" --output text)"
[[ -n "$ARTIFACT_BUCKET" && "$ARTIFACT_BUCKET" != None ]] || die 'Missing CloudFormation export ATU-Lambda-ArtifactsBucketName'
log 'Building Java Lambda package'
mvn -B -pl lambda-app -am clean package
JAR="lambda-app/target/lambda-app-1.0-SNAPSHOT.jar"
[[ -s "$JAR" ]] || die "Lambda JAR not found: $JAR"
log 'Uploading versioned Lambda JAR'
VERSION="$(aws s3api put-object --bucket "$ARTIFACT_BUCKET" --key "$ARTIFACT_KEY" --body "$JAR" --query VersionId --output text)"
[[ -n "$VERSION" && "$VERSION" != None ]] || die 'Lambda artifact S3 VersionId missing (bucket versioning required)'

# 3. Lambda/API/DynamoDB. Explicit CORS origin uses the new CloudFront domain.
deploy infrastructure/three-tier.yaml ATU-Three-Tier \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides "LambdaArtifactVersion=$VERSION" "AllowedCorsOrigin=$WEBSITE_URL"
API_URL="$(stack_output ATU-Three-Tier MessageApiEndpoint)"

# 4. EC2 prerequisites: network -> security group -> instance profile -> instance.
deploy infrastructure/ec2/network.yaml ATU-EC2-Network
deploy infrastructure/ec2/security-groups.yaml ATU-EC2-SecurityGroup
deploy infrastructure/ec2/iam.yaml ATU-EC2-IAM --capabilities CAPABILITY_IAM
deploy infrastructure/ec2/instance.yaml ATU-EC2-Instance
INSTANCE_ID="$(stack_output ATU-EC2-Instance InstanceId)"

# 5. Generate environment-specific browser config without editing tracked source.
log 'Publishing static website and environment-specific JavaScript'
TEMP_CONFIG="$(mktemp)"
trap 'rm -f "${TEMP_CONFIG:-}"' EXIT
printf 'window.APP_CONFIG = { API_URL: "%s" };\n' "$API_URL" > "$TEMP_CONFIG"
aws s3 cp web/index.html "s3://${WEBSITE_BUCKET}/index.html" --content-type text/html --region "$REGION"
aws s3 cp web/js/message.js "s3://${WEBSITE_BUCKET}/js/message.js" --content-type application/javascript --region "$REGION"
aws s3 cp "$TEMP_CONFIG" "s3://${WEBSITE_BUCKET}/js/config.js" --content-type application/javascript --cache-control 'no-cache' --region "$REGION"

# 6. The API response is independently checked. A freshly booted EC2 may need time for SSM.
log 'Verifying API Gateway -> Lambda -> DynamoDB'
curl --fail --silent --show-error "$API_URL" >/dev/null
if (( SEED_DEMO )); then
  log 'Seeding one demonstration message into DynamoDB'
  TABLE_NAME="$(stack_output ATU-Three-Tier MessagesTableName)"
  DEMO_ID="atu-demo-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  DEMO_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Avoid shell JSON escaping and preserve the existing id/message/createdAt schema.
  SEED_ITEM="$(mktemp)"
  trap 'rm -f "${TEMP_CONFIG:-}" "${SEED_ITEM:-}"' EXIT
  printf '{"id":{"S":"%s"},"message":{"S":"CloudFormation deployment successful!"},"createdAt":{"S":"%s"}}\n' "$DEMO_ID" "$DEMO_DATE" > "$SEED_ITEM"
  aws dynamodb put-item --region "$REGION" --table-name "$TABLE_NAME" --item "file://$SEED_ITEM"
  aws dynamodb get-item --region "$REGION" --table-name "$TABLE_NAME" \
    --key "{\"id\":{\"S\":\"$DEMO_ID\"}}" --consistent-read \
    --query 'Item.id.S' --output text | grep -Fx "$DEMO_ID" >/dev/null \
    || die 'DynamoDB demo message could not be read back'
  # DynamoDB Scan is eventually consistent: retry briefly until it appears via the public API.
  found=0
  for _ in {1..12}; do
    if curl --fail --silent --show-error "$API_URL" | grep -Fq "$DEMO_ID"; then found=1; break; fi
    sleep 2
  done
  [[ "$found" == 1 ]] || die 'Demo record saved but not visible through API GET'
  log "Demo message verified via API: $DEMO_ID"
fi
log 'Waiting for EC2 to register with SSM (up to 10 minutes)'
ready=0
for _ in {1..40}; do
  status="$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$INSTANCE_ID" \
    --query 'InstanceInformationList[0].PingStatus' --output text || true)"
  if [[ "$status" == Online ]]; then ready=1; break; fi
  sleep 15
done
[[ "$ready" == 1 ]] || die "EC2 $INSTANCE_ID did not register as SSM Online"

log 'Waiting for Docker and Java application readiness over SSM (up to ~10 minutes)'
app_ready=0
for attempt in {1..24}; do
  log "Application readiness check $attempt/24"
  COMMAND_ID="$(aws ssm send-command --instance-ids "$INSTANCE_ID" --document-name AWS-RunShellScript \
    --parameters '{"commands":["set -eu","systemctl is-active docker","docker ps --format {{.Names}} | grep -Fx atu-ec2-app","curl -fsS http://127.0.0.1:8080/health","curl -fsS http://127.0.0.1:8080/message"]}' \
    --query 'Command.CommandId' --output text)"
  status='Pending'
  for _ in {1..5}; do
    status="$(aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --query Status --output text 2>/dev/null || true)"
    case "$status" in
      Success|Failed|Cancelled|TimedOut|Cancelling) break ;;
    esac
    sleep 5
  done
  if [[ "$status" == Success ]]; then
    app_ready=1
    aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --query StandardOutputContent --output text
    break
  fi
  if (( attempt == 24 )); then
    aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --output json || true
    break
  fi
  sleep 5
done
[[ "$app_ready" == 1 ]] || die "EC2 $INSTANCE_ID: Docker/Java application did not become ready"

printf '\nDEPLOYMENT SUCCESSFUL\nAccount: %s\nRegion: %s\nWebsite: %s\nAPI: %s\nEC2: %s\nImage: %s\n' \
  "$ACCOUNT" "$REGION" "$WEBSITE_URL" "$API_URL" "$INSTANCE_ID" "$IMAGE"
printf 'Remember to delete lab resources when finished to avoid charges.\n'
