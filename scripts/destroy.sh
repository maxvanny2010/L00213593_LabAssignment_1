#!/usr/bin/env bash
# Guarded cleanup for the seven ATU CloudFormation Lab stacks in a selected AWS account/Region.
set -Eeuo pipefail

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[[ $# -eq 0 ]] || die 'Usage: AWS_PROFILE=your-profile AWS_REGION=eu-west-2 bash scripts/destroy.sh'
[[ -n "${AWS_REGION:-}" ]] || die 'Set AWS_REGION explicitly (e.g. export AWS_REGION=eu-west-2).'
REGION="$AWS_REGION"
[[ "$REGION" =~ ^[a-z]{2}(-gov)?-[a-z]+-[0-9]+$ ]] || die "Invalid AWS Region: $REGION"
export AWS_DEFAULT_REGION="$REGION"

for cmd in aws python3; do command -v "$cmd" >/dev/null || die "Missing dependency: $cmd"; done
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
ARN="$(aws sts get-caller-identity --query Arn --output text)"
[[ "$ACCOUNT" =~ ^[0-9]{12}$ ]] || die 'Invalid AWS account ID.'
[[ "$ARN" != *:root ]] || die 'Refusing to operate using AWS root credentials.'

STACKS=(ATU-EC2-Instance ATU-EC2-IAM ATU-EC2-SecurityGroup ATU-EC2-Network ATU-Three-Tier ATU-Lambda-Artifacts ATU-Static-Website)

# AWS CLI returns a ValidationError for an absent stack; do not mistake permission errors for absence.
stack_status() {
  local name="$1" output
  if output="$(aws cloudformation describe-stacks \
      --region "$REGION" \
      --stack-name "$name" \
      --query 'Stacks[0].StackStatus' \
      --output text 2>&1)"; then
    printf '%s' "$output"
  elif [[ "$output" == *"ValidationError"* &&
          "$output" == *"does not exist"* ]]; then

    printf 'ABSENT'
  else
    die "Unable to inspect stack $name: $output"
  fi
}

stack_output() {
  local name="$1" key="$2" value
  value="$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$name" \
      --query "Stacks[0].Outputs[?OutputKey=='${key}'].OutputValue | [0]" --output text)"
  [[ -n "$value" && "$value" != None ]] || die "Missing $key output in $name"
  printf '%s' "$value"
}

# Require exact ownership tags added by scripts/deploy.sh for every existing stack.
assert_project_stack() {
  local name="$1" project managed
  project="$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$name" \
      --query "Stacks[0].Tags[?Key=='Project'].Value | [0]" --output text)"
  managed="$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$name" \
      --query "Stacks[0].Tags[?Key=='ManagedBy'].Value | [0]" --output text)"
  [[ "$project" == ATU-CloudFormation-Lab && "$managed" == CloudFormation ]] \
    || die "Stack $name is missing expected project ownership tags; refusing deletion."
}

log "AWS identity: $ARN"
log "Target AWS account: $ACCOUNT; Region: $REGION"
found=0
for name in "${STACKS[@]}"; do
  status="$(stack_status "$name")"
  printf '%-24s %s\n' "$name" "$status"
  if [[ "$status" != ABSENT ]]; then
    assert_project_stack "$name"
    found=1
  fi
done
[[ "$found" == 1 ]] || die 'No ATU stacks found. Nothing to delete.'

printf '\nDESTRUCTIVE: This deletes the listed project stacks and their DynamoDB/S3 data.\n'
printf 'Account: %s | Region: %s\n' "$ACCOUNT" "$REGION"
printf 'Type DELETE-%s-%s to confirm: ' "$ACCOUNT" "$REGION"
read -r confirmation
[[ "$confirmation" == "DELETE-${ACCOUNT}-${REGION}" ]] || die 'Cancelled.'

# Explicitly match stack-produced bucket names to the account and region before erasing content.
assert_bucket() {
  local bucket="$1" service="$2"
  [[ "$bucket" == "atu-l00213593-${service}-${ACCOUNT}-${REGION}-"* ]] \
    || die "Unexpected S3 bucket name: $bucket"
  local owner
  owner="$(aws s3api get-bucket-location --bucket "$bucket" --query LocationConstraint --output text)" \
    || die "Cannot inspect S3 bucket $bucket"
  [[ "$owner" == "$REGION" || ( "$REGION" == eu-west-1 && "$owner" == None ) ]] \
    || die "Bucket $bucket is in a different region ($owner)."
}

empty_bucket() {
  local bucket="$1" kind="$2" batch tmp
  assert_bucket "$bucket" "$kind"
  log "Emptying $kind bucket $bucket (all object versions and delete markers)"
  # The AWS CLI paginates list-object-versions automatically.
  while :; do
    batch="$(aws s3api list-object-versions --bucket "$bucket" --region "$REGION" --output json | python3 -c '
import json,sys
v=json.load(sys.stdin)
items=[{"Key":x["Key"],"VersionId":x["VersionId"]} for x in v.get("Versions",[])+v.get("DeleteMarkers",[])]
print(json.dumps({"Objects":items[:1000],"Quiet":True}) if items else "")')"
    [[ -n "$batch" ]] || break
    tmp="$(mktemp)"
    printf '%s\n' "$batch" > "$tmp"
    if ! aws s3api delete-objects --bucket "$bucket" --region "$REGION" --delete "file://$tmp" >/dev/null; then
      rm -f "$tmp"; die "Failed to clear $bucket"
    fi
    rm -f "$tmp"
  done
}

delete_stack() {
  local name="$1" current
  current="$(stack_status "$name")"
  if [[ "$current" == ABSENT ]]; then log "Skipping absent stack: $name"; return 0; fi
  assert_project_stack "$name"
  log "Deleting $name"
  aws cloudformation delete-stack --stack-name "$name" --region "$REGION"
  aws cloudformation wait stack-delete-complete --stack-name "$name" --region "$REGION" \
    || die "Failed deleting $name. Inspect CloudFormation events."
}

# Reverse dependency order: remove importers before the stacks exporting resources.
delete_stack ATU-EC2-Instance
delete_stack ATU-EC2-IAM
delete_stack ATU-EC2-SecurityGroup
delete_stack ATU-EC2-Network
delete_stack ATU-Three-Tier

if [[ "$(stack_status ATU-Lambda-Artifacts)" != ABSENT ]]; then
  empty_bucket "$(stack_output ATU-Lambda-Artifacts LambdaArtifactsBucketName)" lambda
fi
delete_stack ATU-Lambda-Artifacts

if [[ "$(stack_status ATU-Static-Website)" != ABSENT ]]; then
  empty_bucket "$(stack_output ATU-Static-Website WebsiteBucketName)" web
fi
delete_stack ATU-Static-Website

log 'Verifying all named stacks are absent'
for name in "${STACKS[@]}"; do
  [[ "$(stack_status "$name")" == ABSENT ]] || die "Stack still exists: $name"
done
printf '\nSUCCESS: ATU lab stacks deleted in account %s, region %s. Check Billing separately.\n' "$ACCOUNT" "$REGION"
