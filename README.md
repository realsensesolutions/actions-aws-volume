# GitHub Action for AWS EFS Volume

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Description

This GitHub Action manages an AWS Elastic File System (EFS) volume using Terraform. It can work with both default VPC and custom private networks, and always creates EFS-specific security groups for proper NFS access.

## Features

- Manages EFS volumes using Terraform for proper state tracking
- Works with default VPC or custom private networks (via network actions)
- Always creates EFS-specific security groups with proper NFS rules
- Creates mount targets in appropriate subnets (private when available, default otherwise)
- Creates an access point for the EFS
- Returns ARNs and IDs as outputs for use in other steps

## Inputs

| Name                | Description                                   | Required | Default |
| ------------------- | --------------------------------------------- | -------- | ------- |
| action              | Desired outcome: apply, plan or destroy       | false    | apply   |
| name                | EFS volume name - will be used as the Name tag| true     | ""      |

## Outputs

| Name            | Description                                       |
| --------------- | ------------------------------------------------- |
| efs_arn         | ARN of the EFS file system                        |
| efs_id          | ID of the EFS file system                         |
| mount_targets   | List of EFS mount target IDs in default subnets   |
| access_point_arn| ARN of the EFS access point                       |

## Sample Usage

### Basic Usage
```yaml
jobs:
  deploy:
    permissions:
      id-token: write
    runs-on: ubuntu-latest
    steps:
      - name: Check out repo
        uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: us-east-1
          role-to-assume: ${{ secrets.ROLE_ARN }}
          role-session-name: ${{ github.actor }}
      - uses: alonch/actions-aws-backend-setup@main
        id: backend
        with:
          instance: demo
      - name: Provision EFS volume
        uses: alonch/actions-aws-volume@main
        id: efs
        with:
          name: my-database
      - name: Use EFS with Lambda function
        run: |
          echo "EFS ID: ${{ steps.efs.outputs.efs_id }}"
          echo "EFS ARN: ${{ steps.efs.outputs.efs_arn }}"
          echo "EFS Access Point ARN: ${{ steps.efs.outputs.access_point_arn }}"
```

### Integrating with Lambda

When using this EFS volume with Lambda, you'll need to:

1. Configure your Lambda function to run in the VPC with access to the EFS mount targets
2. Configure the Lambda to use the EFS access point
3. Ensure your Lambda function has permission to access EFS

Example Lambda configuration in Terraform:

```hcl
resource "aws_lambda_function" "example" {
  # Standard Lambda configuration

  vpc_config {
    subnet_ids         = [subnet_ids_from_default_vpc]
    security_group_ids = [your_security_group_with_efs_access]
  }

  file_system_config {
    arn              = "${access_point_arn}"
    local_mount_path = "/mnt/data"
  }
}
```