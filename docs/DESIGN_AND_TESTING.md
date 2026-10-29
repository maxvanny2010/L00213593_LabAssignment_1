# Design Decisions and Testing Summary

[← Project README](../README.md) · [References](REFERENCES.md)

## 6. Design Decisions

The main technical decisions are recorded in the development iterations above.

The documentation records:

- The selected approach.
- The reason for choosing it.
- Alternative solutions considered.
- Advantages and limitations.
- Relevant AWS documentation.

For example, AWS recommends managing CloudFormation templates using version control
and reviewing changes before deployment [[2]](REFERENCES.md#ref-2).
Decisions are supported by relevant AWS documentation cited in the References section.

## 7. Testing and Validation

Each development stage is tested and documented before being merged into the main branch.

Test results and issues are documented in the relevant iteration, including CloudFormation validation,
stack status, website delivery over HTTPS, direct S3 access denial, and HTTP API/DynamoDB integration tests.
The most recent end-to-end tests returned HTTP 403 for anonymous POST, HTTP 201 for a signed POST, and HTTP 200 for GET
returning the newly created DynamoDB record.
AWS recommends validating CloudFormation templates before deploying infrastructure [[2]](REFERENCES.md#ref-2).

### Part A(b) — Conclusion

The objective of Part A(b) was to design and implement a three-tier architecture using AWS services and Infrastructure
as Code.

I implemented the Web Tier using Amazon S3 and CloudFront, the Application Tier using Amazon API Gateway and Java
Lambda, and the Database Tier using Amazon DynamoDB.

AWS CloudFormation was used to define and manage the infrastructure, including the DynamoDB table, Lambda execution
role, API Gateway configuration and access permissions.

The application was tested successfully. The GET endpoint retrieved messages from DynamoDB, while the POST endpoint
created new messages using AWS IAM authentication. I also connected the static website to the API, allowing messages to
be displayed directly in the browser.

During development, I encountered several IAM permission and deployment issues. Investigating CloudFormation stack
events helped me understand the importance of access control, the least privilege and infrastructure validation.

The final integration test confirmed that all three tiers communicate successfully.

**Result:** Part A(b) has been implemented and tested successfully.

The next development stage will explore an alternative Application Tier using a lightweight Java HTTP server on Amazon
EC2, with networking
and security resources defined through CloudFormation.

### 7.1 Independent Deployment and Reproducibility Test — 28 October 2026

**Objective:** Verify that the complete infrastructure can be deployed automatically in a different AWS Region using a
separate IAM user, without manual configuration of individual AWS resources.

**Test environment:**

- Operating system: Ubuntu 24.04 (WSL2).
- AWS CLI: 2.39.1.
- Java: OpenJDK 21.
- Apache Maven: 3.8.7.
- AWS Region: eu-west-2 (London).
- IAM identity: atu-test-deployer.
- Deployment command: `bash scripts/deploy.sh`.

**Results:**

| Test                                                | Result                                       |
|-----------------------------------------------------|----------------------------------------------|
| AWS IAM authentication                              | PASS                                         |
| Seven CloudFormation stacks                         | PASS — CREATE_COMPLETE                       |
| Java Lambda compilation and packaging               | PASS — BUILD SUCCESS                         |
| Lambda artifact upload to Amazon S3                 | PASS                                         |
| Static website deployment through S3 and CloudFront | PASS                                         |
| API Gateway → Java Lambda → DynamoDB                | PASS                                         |
| Public GET endpoint                                 | PASS — `{"count":0,"messages":[]}`           |
| EC2 registration with AWS Systems Manager           | PASS                                         |
| Automatic Docker installation and container startup | PASS                                         |
| EC2 application health endpoint                     | PASS — `{"status":"UP","service":"ec2-app"}` |
| Complete deployment script                          | PASS — DEPLOYMENT SUCCESSFUL                 |

**Issue identified and resolved:**

The first deployment failed because the CloudFront Origin Access Control (OAC) name conflicted with an existing OAC in
another Region. CloudFront is a global AWS service.

The OAC name was updated to include both the AWS account ID and Region:

`atu-l00213593-oac-${AWS::AccountId}-${AWS::Region}`

After removing the failed test stack and repeating the deployment, all seven CloudFormation stacks reached
`CREATE_COMPLETE`.

**Conclusion:**

The complete infrastructure was successfully deployed in eu-west-2 under a separate IAM identity. The deployment script
automatically provisioned the AWS resources, built and uploaded the Java Lambda package, published the static website,
and verified the API and EC2 application.

The deployed website was also opened successfully in a browser, and the public API returned the expected JSON response
for a new, empty DynamoDB table.

This test demonstrates that the infrastructure can be reproduced in a different AWS Region without manually creating
individual application resources.


**Additional message-board functional check:** A demonstration item with the fields `id`, `message` and `createdAt` was inserted into the new `eu-west-2` DynamoDB table using authenticated AWS CLI `PutItem`. The public GET endpoint returned the record, and the CloudFront page displayed `CloudFormation deployment successful!` after selecting **Load Messages**. This checks the write → read → browser display path. The optional `--seed-demo` deployment argument automates this check in future clean deployments. The `scripts/destroy.sh` helper was added for guarded cleanup of the test Region; its execution must be verified separately.

### Automated Infrastructure Cleanup — 28 October 2026

The `scripts/destroy.sh` script was executed successfully in AWS Region `eu-west-2` using the `atu-test-deployer` IAM identity.

All seven CloudFormation stacks were deleted in reverse dependency order. Both S3 buckets were emptied before deletion.

A subsequent CloudFormation check confirmed that no active `ATU-*` stacks or stacks with `DELETE_FAILED` status remained in the test Region.

**Result:** Automated deployment, functional testing and infrastructure cleanup completed successfully.

### 7.2 Final Automated Deployment and Cleanup Test — 29 October 2026

A second complete deployment was performed in `eu-west-2` using the temporary IAM user `atu-test-deployer-2`.

**Deployment command:**
`bash scripts/deploy.sh --seed-demo`

**Results:**
- All seven CloudFormation stacks deployed successfully.
- Java Lambda, API Gateway and DynamoDB integration passed.
- The optional `--seed-demo` argument inserted a DynamoDB record.
- The demonstration message was retrieved through the API and displayed on the CloudFront website.
- EC2, Docker and the Java application passed readiness checks.
- The deployment finished with `DEPLOYMENT SUCCESSFUL`.

**Cleanup command:**
`bash scripts/destroy.sh`

**Results:**
- The script identified the target AWS account and Region.
- All seven CloudFormation stacks passed project ownership tag checks.
- Account- and Region-specific confirmation was required.
- Stacks were deleted in reverse dependency order.
- Both S3 buckets were emptied, including object versions and delete markers.
- The final script verification confirmed that all seven named stacks were absent.
- The cleanup finished with `SUCCESS`.

**Conclusion:** The complete automated deployment, demonstration data seeding, functional verification and infrastructure cleanup were successfully tested in a second AWS Region. Testing in a separate AWS account remains outstanding.
