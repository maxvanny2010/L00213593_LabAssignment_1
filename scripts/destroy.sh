#!/usr/bin/env bash
# shellcheck disable=SC2016
# Guarded cleanup of the seven ATU CloudFormation Lab stacks in one AWS account/Region.
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

stack_status() {
  local name="$1" output
  if output="$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$name" \
      --query 'Stacks[0].StackStatus' --output text 2>&1)"; then
    printf '%s' "$output"
  elif [[ "$output" == *ValidationError* && "$output" == *'does not exist'* ]]; then
    printf 'ABSENT'
  else
    die "Unable to inspect stack $name: $output"
  fi
}

# Check the two tags assigned by scripts/deploy.sh; do not delete unrelated named stacks.
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

assert_bucket() {
  local bucket="$1" service="$2" location
  [[ "$bucket" == "atu-l00213593-${service}-${ACCOUNT}-${REGION}-"* ]] \
    || die "Unexpected S3 bucket name: $bucket"
  location="$(aws s3api get-bucket-location --bucket "$bucket" --query LocationConstraint --output text)" \
    || die "Cannot inspect S3 bucket $bucket"
  [[ "$location" == "$REGION" || ( "$REGION" == eu-west-1 && "$location" == None ) ]] \
    || die "Bucket $bucket is in a different region ($location)."
}

# For failed CloudFormation creations, Outputs may not exist. Fall back to actual
# stack resources, and permit no bucket only when the stack creation failed.
bucket_for_stack() {
  local stack="$1" key="$2" status="$3" bucket
  bucket="$(aws cloudformation describe-stacks --region "$REGION" --stack-name "$stack" \
      --query "Stacks[0].Outputs[?OutputKey=='${key}'].OutputValue | [0]" --output text)" \
    || die "Cannot inspect outputs of $stack"
  if [[ -z "$bucket" || "$bucket" == None ]]; then
    bucket="$(aws cloudformation describe-stack-resources --region "$REGION" --stack-name "$stack" \
        --query 'StackResources[?ResourceType==`AWS::S3::Bucket`].PhysicalResourceId | [0]' --output text)" \
      || die "Cannot inspect resources of $stack"
  fi
  if [[ -z "$bucket" || "$bucket" == None ]]; then
    case "$status" in
      ROLLBACK_COMPLETE|ROLLBACK_FAILED|REVIEW_IN_PROGRESS|CREATE_FAILED)
        log "No S3 bucket was created in failed stack $stack; proceeding to stack deletion" >&2
        return 0 ;;
      *) die "No bucket output/resource found in $stack ($status). Refusing unsafe cleanup." ;;
    esac
  fi
  printf '%s' "$bucket"
}

# An S3 bucket deleted during rollback can still appear in CloudFormation resources.
# Only an explicit 404/NoSuchBucket is treated as absent (not AccessDenied).
bucket_exists() {
  local bucket="$1" result
  if result="$(aws s3api head-bucket --bucket "$bucket" --region "$REGION" 2>&1)"; then
    return 0
  fi
  if [[ "$result" == *'(404)'* || "$result" == *NoSuchBucket* || "$result" == *'Not Found'* ]]; then
    return 1
  fi
  die "Cannot verify bucket $bucket: $result"
}

empty_bucket() {
  local bucket="$1" kind="$2" batch response tmp
  assert_bucket "$bucket" "$kind"
  log "Emptying $kind bucket $bucket (all object versions and delete markers)"
  local batches=0
  while :; do
    ((batches += 1))
    ((batches <= 1000)) || die "S3 cleanup exceeded 1000 batches for $bucket; stopping."
    # AWS CLI paginates all versions. Delete at most 1000 per request.
    batch="$(aws s3api list-object-versions --bucket "$bucket" --region "$REGION" --output json | python3 -c '
import json,sys
v=json.load(sys.stdin)
items=[{"Key":x["Key"],"VersionId":x["VersionId"]} for x in v.get("Versions",[])+v.get("DeleteMarkers",[])]
print(json.dumps({"Objects":items[:1000],"Quiet":True}) if items else "")')" \
      || die "Failed to enumerate object versions in $bucket"
    [[ -n "$batch" ]] || break
    tmp="$(mktemp)" || die 'Cannot create temporary file'
    printf '%s\n' "$batch" > "$tmp"
    if ! response="$(aws s3api delete-objects --bucket "$bucket" --region "$REGION" --delete "file://$tmp" --output json)"; then
      rm -f "$tmp"
      die "S3 delete-objects failed for $bucket"
    fi
    rm -f "$tmp"
    # A successful AWS CLI exit code does not imply every item was deleted.
    if ! printf '%s' "$response" | python3 -c '
import json,sys
reply=json.load(sys.stdin)
errors=reply.get("Errors",[])
if errors:
    print("S3 per-object deletion errors:", file=sys.stderr)
    for e in errors[:10]:
        print("  {}: {}".format(e.get("Key", "?"), e.get("Code", "?")), file=sys.stderr)
    sys.exit(1)
'; then
      die "S3 failed to delete one or more versions from $bucket; stopping instead of retrying indefinitely"
    fi
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

# Reverse dependency order: remove importers before stacks exporting resources.
delete_stack ATU-EC2-Instance
delete_stack ATU-EC2-IAM
delete_stack ATU-EC2-SecurityGroup
delete_stack ATU-EC2-Network
delete_stack ATU-Three-Tier

if [[ "$(stack_status ATU-Lambda-Artifacts)" != ABSENT ]]; then
  status="$(stack_status ATU-Lambda-Artifacts)"
  bucket="$(bucket_for_stack ATU-Lambda-Artifacts LambdaArtifactsBucketName "$status")"
  if [[ -n "$bucket" ]]; then
    if bucket_exists "$bucket"; then empty_bucket "$bucket" lambda; else log "S3 bucket $bucket already absent"; fi
  fi
fi
delete_stack ATU-Lambda-Artifacts

if [[ "$(stack_status ATU-Static-Website)" != ABSENT ]]; then
  status="$(stack_status ATU-Static-Website)"
  bucket="$(bucket_for_stack ATU-Static-Website WebsiteBucketName "$status")"
  if [[ -n "$bucket" ]]; then
    if bucket_exists "$bucket"; then empty_bucket "$bucket" web; else log "S3 bucket $bucket already absent"; fi
  fi
fi
delete_stack ATU-Static-Website

log 'Verifying all named stacks are absent'
for name in "${STACKS[@]}"; do
  [[ "$(stack_status "$name")" == ABSENT ]] || die "Stack still exists: $name"
done
printf '\nSUCCESS: ATU lab stacks deleted in account %s, region %s. Check Billing separately.\n' "$ACCOUNT" "$REGION"
