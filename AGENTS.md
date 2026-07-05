# Terraform AWS Bedrock - Agent Instructions

Technical reference for AI assistants working on this repository.

## Prerequisites

- AWS credentials via `aws-vault` profile `terraform-bedrock`
- Nix with flakes enabled (for development shell)

**Important**: Use `--no-session` flag with aws-vault for IAM operations.

## Secrets

Configuration secrets are stored in macOS Keychain under the `aws-vault`
keychain:

| Account          | Service                    | Description              |
|------------------|----------------------------|--------------------------|
| `AWS_ACCOUNT_ID` | `terraform-bedrock-config` | AWS account ID           |
| `AWS_REGION`     | `terraform-bedrock-config` | AWS region               |

Retrieve secrets:

```bash
security find-generic-password -a "AWS_ACCOUNT_ID" \
  -s "terraform-bedrock-config" -w ~/Library/Keychains/aws-vault.keychain-db
```

Add/update secrets:

```bash
security add-generic-password -a "AWS_ACCOUNT_ID" \
  -s "terraform-bedrock-config" -w "<YOUR_ACCOUNT_ID>" -U \
  ~/Library/Keychains/aws-vault.keychain-db
```

## Development

Enter the development shell:

```bash
nix develop
```

## Terraform Commands

Run from the repo root:

```bash
# Plan
aws-vault exec terraform-bedrock --no-session -- terragrunt plan

# Apply
aws-vault exec terraform-bedrock --no-session -- terragrunt apply

# Destroy
aws-vault exec terraform-bedrock --no-session -- terragrunt destroy
```

## Architecture

- **State**: S3 bucket with DynamoDB locking
- **Agent**: Amazon Nova Micro via inference profile
- **IAM**: Least-privilege execution role with confused deputy protection

## Worktree Structure

`main` is checked out directly at the repo root — there is no dedicated
`main/` subfolder. Feature branches are linked worktrees in a sibling
`terraform-aws-bedrock-wt/` directory:

```text
~/git/terraform-aws-bedrock/         # main, checked out directly
~/git/terraform-aws-bedrock-wt/
└── <branch-name>/                   # feature branch worktree
```

Create feature branches:

```bash
cd ~/git/terraform-aws-bedrock
git worktree add ../terraform-aws-bedrock-wt/<branch-name> -b <branch-name>
```
