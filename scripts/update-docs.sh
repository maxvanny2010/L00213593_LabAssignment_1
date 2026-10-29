#!/usr/bin/env bash
# Run from the repository root after copying scripts into scripts/.
set -euo pipefail
[[ -f README.md && -f docs/DESIGN_AND_TESTING.md ]] || { echo 'Run in repository root.' >&2; exit 1; }
python3 - <<'PY'
from pathlib import Path
readme=Path('README.md')
s=readme.read_text()
heading='### Demonstration Data and Cleanup'
block='''### Demonstration Data and Cleanup

For a clean AWS Region, `bash scripts/deploy.sh` deploys the infrastructure without adding sample data. To populate one demonstration record in DynamoDB and verify that it appears through the public GET endpoint, use:

```bash
bash scripts/deploy.sh --seed-demo
```

After deployment, open the CloudFront website and click **Load Messages**. The demonstration message is `CloudFormation deployment successful!`. The optional seed is written using the deploying IAM identity (`dynamodb:PutItem` required); the public POST endpoint remains IAM-protected. The seed option cannot be used on an already deployed stack because `deploy.sh` intentionally refuses existing project stacks.

**Destroying the London test environment:** The provided `scripts/destroy.sh` is deliberately restricted to AWS account `897068845214` and Region `eu-west-2`. After confirming the AWS identity, run:

```bash
export AWS_PROFILE=atu-test
export AWS_REGION=eu-west-2
bash scripts/destroy.sh
```

Type `DELETE-ATU-eu-west-2` only after checking the displayed account, Region and stack names. This irreversibly deletes the seven named lab stacks and data stored in their two S3 buckets and DynamoDB table. The Ireland (`eu-west-1`) deployment is not touched. For a different AWS account, review and adapt the safety guards before using the cleanup script. AWS charges may continue for other unrelated resources.
'''
if heading not in s:
    marker='## Project Files'
    if marker in s: s=s.replace(marker,block+'\n'+marker,1)
    else: s+='\n'+block
# Remove stale statement if present; the reproduced test was in same account, separate region and IAM user.
s=s.replace('**Verification status:** Bash syntax, ShellCheck and CloudFormation template linting passed locally. A complete deployment from scratch in a different AWS account has **not yet been verified**. Delete test resources when finished to avoid ongoing charges; see the manual guide for cleanup considerations.',
'''**Verification status:** On 28 October 2026, the complete automated deployment succeeded in a second Region (`eu-west-2`) under an independent IAM user in the same AWS account. Seven stacks reached `CREATE_COMPLETE`; Java build, API GET, SSM Docker/Java checks, and website loading passed. A deployment in a completely separate AWS account has not been verified. See [Testing](docs/DESIGN_AND_TESTING.md) for details.''')
s=s.replace('The deployment region is **`eu-west-1`**.', 'Set `AWS_REGION` for the target deployment (default: **`eu-west-1`**).')
s=s.replace('scripts/deploy.sh             Automated clean-account deployment','scripts/deploy.sh             Automated clean-region deployment (optional demo seed)\nscripts/destroy.sh            Guarded cleanup of eu-west-2 test stacks')
readme.write_text(s)

doc=Path('docs/DESIGN_AND_TESTING.md'); d=doc.read_text()
note='''
**Additional message-board functional check:** A demonstration item with the fields `id`, `message` and `createdAt` was inserted into the new `eu-west-2` DynamoDB table using authenticated AWS CLI `PutItem`. The public GET endpoint returned the record, and the CloudFront page displayed `CloudFormation deployment successful!` after selecting **Load Messages**. This checks the write → read → browser display path. The optional `--seed-demo` deployment argument automates this check in future clean deployments. The `scripts/destroy.sh` helper was added for guarded cleanup of the test Region; its execution must be verified separately.
'''
if '**Additional message-board functional check:**' not in d:
    d += '\n'+note
doc.write_text(d)
print('README.md and docs/DESIGN_AND_TESTING.md updated')
PY
