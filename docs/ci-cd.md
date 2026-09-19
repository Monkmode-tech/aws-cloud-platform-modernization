# CI/CD setup

## Continuous integration

Every push and pull request runs Terraform formatting, init/validate, mocked configuration tests, Python guardrail tests, and the basic secret scan. It uses no AWS credentials. Commit `infra/.terraform.lock.hcl`; provider integrity is verified by Terraform. External GitHub Actions are pinned to commit SHAs and Dependabot proposes updates.

## Continuous delivery scope

`deploy.yml` is a **manual** rollout of the digest committed in `app/image.txt` to an existing initialized ECS service. It does not create infrastructure or handle database migrations. It runs CI first, requires `main`, uses the `aws-deploy` environment, and authenticates with OIDC. ECS circuit-breaker rollback is enabled; the Python script also detects fallback to the previous revision and requests rollback on failure.

## Configure the deployment role

1. Create or reuse the GitHub OIDC identity provider in your AWS account, with issuer `https://token.actions.githubusercontent.com` and audience `sts.amazonaws.com`.
2. Create a GitHub environment named `aws-deploy`. Restrict deployment branches to `main` and configure required reviewers if your repository plan supports them.
3. Determine the **exact OIDC subject** your repository emits. GitHub documents subject formats that can include immutable owner/repository IDs for newly created repositories. Do not assume the old name-only format or broaden trust with a wildcard if it fails.
4. Generate policies using your actual subject:

```bash
python scripts/make_oidc_policy.py --subject 'repo:OWNER/REPOSITORY:environment:aws-deploy'
```

The subject above is an example; repositories using immutable IDs require the corresponding `OWNER@ID/REPOSITORY@ID` form. Verify your format against GitHub's official documentation.

5. Review the two generated JSON files under `evidence/raw/`. With an authorized IAM operator, create the role and its inline policy:

```bash
aws iam create-role --role-name caleb-wp-github-deploy --assume-role-policy-document file://evidence/raw/oidc-trust.json
aws iam put-role-policy --role-name caleb-wp-github-deploy --policy-name DeployExistingWordPressService --policy-document file://evidence/raw/deploy-policy.json
```

Role name is an example. If it already exists, review its policies rather than overwriting unrelated permissions. `ecs:RegisterTaskDefinition` uses wildcard resource scope; the deployment can pass only the application's existing execution/task roles and update only its service. The role cannot provision infrastructure or read secret values directly. Treat permission to deploy code under those roles as privileged.

## GitHub environment variables

Populate these under the `aws-deploy` environment. Use Terraform outputs; none are passwords.

| Variable | Terraform output / value |
|---|---|
| `AWS_REGION` | `region` |
| `AWS_ACCOUNT_ID` | `account_id` |
| `AWS_DEPLOY_ROLE_ARN` | ARN of the role created above |
| `ECS_CLUSTER` | `cluster` |
| `ECS_SERVICE` | `service` |
| `TASK_FAMILY` | `task_family` |
| `EXECUTION_ROLE_ARN` | `execution_role_arn` |
| `TASK_ROLE_ARN` | `task_role_arn` |

Use a PR to update `app/image.txt`, inspect the image, merge after checks, and manually dispatch the workflow. The service must already be initialized. Verify login, content, media, and HTTP behavior afterward. GitHub-hosted runners are not added to the lab `/32` allowlist; post-deployment HTTP verification runs from your workstation.

Terraform still owns the base task definition. After a CD rollout, its next apply may create a new equivalent revision using the same committed digest and reconcile the service. Review that plan; avoid concurrent CD and Terraform applies. Do not reverse `image.txt` unless you intend an image rollback.

## State protection

Start locally for the single-operator lab. For collaboration, create a private encrypted S3 state bucket with versioning, public access blocking, HTTPS-only bucket policy, and appropriately scoped read/write/lock permissions. Copy `infra/backend.tf.example` to `infra/backend.tf`, edit the bucket name, and run `terraform -chdir=infra init -migrate-state`. The example uses S3 lockfiles (`use_lockfile=true`). Do not publish the backend's account-specific configuration or state.

The CD workflow does not access Terraform state, so remote state is not required merely to demonstrate OIDC application delivery.

Sources: [GitHub OIDC with AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws), [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3).
