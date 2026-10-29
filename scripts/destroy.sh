#!/usr/bin/env bash
# Destroy ONLY the seven named ATU lab stacks in the selected AWS region.
set -Eeuo pipefail
REGION="${AWS_REGION:-eu-west-1}"
EXPECTED_ACCOUNT='897068845214' # Project account safety guard; change for another account.
STACKS=(ATU-EC2-Instance ATU-EC2-IAM ATU-EC2-SecurityGroup ATU-EC2-Network ATU-Three-Tier ATU-Lambda-Artifacts ATU-Static-Website)
log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
for cmd in aws python3; do command -v "$cmd" >/dev/null || die "Missing dependency: $cmd"; done
[[ $# == 0 ]] || die "Usage: AWS_PROFILE=... AWS_REGION=... bash scripts/destroy.sh"
export AWS_DEFAULT_REGION="$REGION"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
ARN="$(aws sts get-caller-identity --query Arn --output text)"
[[ "$ACCOUNT" == "$EXPECTED_ACCOUNT" ]] || die "Unexpected AWS account $ACCOUNT (expected $EXPECTED_ACCOUNT)."
[[ "$REGION" == eu-west-2 ]] || die "Safety guard: this cleanup is restricted to eu-west-2; got $REGION."
[[ "$ARN" != *:root ]] || die 'Refusing to run with AWS root credentials.'
log "Target account: $ACCOUNT; region: $REGION; identity: $ARN"
for s in "${STACKS[@]}"; do
  aws cloudformation describe-stacks --stack-name "$s" --query 'Stacks[0].[StackName,StackStatus]' --output text 2>/dev/null || true
done
printf '\nDESTRUCTIVE: Delete ONLY the above ATU lab stacks and their data in %s.\n' "$REGION"
printf 'Enter DELETE-ATU-eu-west-2 to proceed: '
read -r answer
[[ "$answer" == DELETE-ATU-eu-west-2 ]] || die 'Cancelled'

exists() { aws cloudformation describe-stacks --stack-name "$1" >/dev/null 2>&1; }
output() {
  aws cloudformation describe-stacks --stack-name "$1" \
    --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue | [0]" --output text
}
delete_stack() {
  local s="$1"
  if ! exists "$s"; then log "Skip $s (absent)"; return 0; fi
  log "Deleting $s"
  aws cloudformation delete-stack --stack-name "$s"
  aws cloudformation wait stack-delete-complete --stack-name "$s" || die "Failed deleting $s. Inspect CloudFormation events."
}
# Include all versions and delete markers; limit each request to 1000 objects.
empty_bucket() {
  local bucket="$1" kind="$2" payload
  [[ -n "$bucket" && "$bucket" != None ]] || die 'Missing bucket output; refusing to continue'
  [[ "$bucket" == atu-l00213593-* ]] || die "Unexpected bucket name: $bucket"
  log "Clearing $kind bucket $bucket"
  aws s3 rm "s3://$bucket" --recursive --region "$REGION" >/dev/null
  while :; do
    payload="$(aws s3api list-object-versions --bucket "$bucket" --region "$REGION" --output json | python3 -c '
import json,sys
j=json.load(sys.stdin)
a=[{"Key":x["Key"],"VersionId":x["VersionId"]} for x in j.get("Versions",[])+j.get("DeleteMarkers",[])]
print(json.dumps({"Objects":a[:1000],"Quiet":True}) if a else "")')"
    [[ -n "$payload" ]] || break
    tmp="$(mktemp)"
    printf '%s\n' "$payload" > "$tmp"
    if ! aws s3api delete-objects --bucket "$bucket" --region "$REGION" --delete "file://$tmp" >/dev/null; then
      rm -f "$tmp"; die "Failed clearing $bucket"
    fi
    rm -f "$tmp"
  done
}

# Delete dependants before producers of CloudFormation exports.
delete_stack ATU-EC2-Instance
delete_stack ATU-EC2-IAM
delete_stack ATU-EC2-SecurityGroup
delete_stack ATU-EC2-Network
delete_stack ATU-Three-Tier
if exists ATU-Lambda-Artifacts; then
  bucket="$(aws cloudformation list-exports --query "Exports[?Name=='ATU-Lambda-ArtifactsBucketName'].Value | [0]" --output text)"
  empty_bucket "$bucket" artifacts
fi
delete_stack ATU-Lambda-Artifacts
if exists ATU-Static-Website; then
  bucket="$(output ATU-Static-Website WebsiteBucketName)"
  empty_bucket "$bucket" website
fi
delete_stack ATU-Static-Website
log 'Checking remaining named stacks'
for s in "${STACKS[@]}"; do
  if exists "$s"; then die "Still exists: $s"; fi
done
printf '\nATU test stacks deleted in %s. Check Billing and any unrelated resources separately.\n' "$REGION"
