# Deployment runbook

Use Bash in AWS CloudShell, Linux, macOS, or Windows WSL, and a dedicated sandbox AWS account. Run the setup sections in order. If a command fails, resolve that error before continuing to the next section. The commands below are instructions for you to execute; no AWS deployment was performed when this package was created.

## 1. Prerequisites and cost decision

Use Terraform 1.11.4 or a compatible 1.11+ release, Python 3.11+, AWS CLI v2, and Git. CloudShell provides AWS CLI and console-session credentials, but check the installed Python and Terraform versions against these requirements. Never paste access keys into this repository or chat.

### 1.1 Authenticate: choose the path for your environment

**AWS CloudShell opened from the AWS console**

CloudShell receives credentials from your current console sign-in. An IAM user does not need an SSO profile named `portfolio` to use that session. Clear example profile overrides, then verify the identity:

```bash
unset AWS_PROFILE AWS_DEFAULT_PROFILE
aws sts get-caller-identity
```

The command should return JSON containing `Account`, `Arn`, and `UserId` for the intended sandbox account. If it fails, resolve that failure before continuing. Do not run `aws sso login --profile portfolio` or `export AWS_PROFILE=portfolio` for this CloudShell path.

AWS documents console-session credential forwarding in the [CloudShell CLI guide](https://docs.aws.amazon.com/cloudshell/latest/userguide/working-with-aws-cli.html).

**Local Linux/macOS/Windows WSL with IAM Identity Center (SSO)**

Use this path only when IAM Identity Center is configured and you have its sign-in details. The name `portfolio` is an example credential-profile name, not a profile created automatically by making an IAM user. If the profile does not exist, configure it once:

```bash
aws configure sso --profile portfolio
```

Then authenticate:

```bash
aws sso login --profile portfolio
export AWS_PROFILE=portfolio
aws sts get-caller-identity
```

For another authentication method, use its normal temporary-credential/profile chain. The deployment operator needs permissions to create the resources in `infra/` and IAM roles, pass those roles to ECS, initialize secrets, and run the bootstrap task. The narrow CD role is intentionally insufficient for provisioning. Do not use root credentials. First-time ECS/EFS/RDS/Application Auto Scaling use may require service-linked roles; check IAM errors against the actual denied action.

### 1.2 Obtain the project and enter its directory

For a new setup, clone the repository. If the project folder already exists, the following block enters it without deleting it:

```bash
cd ~
if [ ! -d aws-cloud-platform-modernization ]; then
  git clone https://github.com/Monkmode-tech/aws-cloud-platform-modernization.git
fi
cd aws-cloud-platform-modernization
ls requirements-dev.txt infra/terraform.tfvars.example
```

Both paths must appear in the `ls` output. Your shell should now be in `aws-cloud-platform-modernization`, not just `~`. Run the remaining commands from this repository root.

Preserve existing checkouts, Terraform state, and private backups. Deleting local files does not remove deployed AWS resources. If a deleted checkout previously managed resources, recover its state or identify its remote backend before a new apply; a fresh Git clone does not restore ignored local state or backups. See [Terraform state](https://developer.hashicorp.com/terraform/language/state).

### 1.3 Create the project virtual environment and local configuration

If you activated a virtual environment in your home directory, deactivate it before creating the project environment:

```bash
if type deactivate >/dev/null 2>&1; then
  deactivate
fi
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
if [ ! -f infra/terraform.tfvars ]; then
  cp infra/terraform.tfvars.example infra/terraform.tfvars
fi
```

The copy step preserves an existing `terraform.tfvars`. A pip notice about a newer pip version is informational; a missing requirements file means you have not entered a complete project checkout.

Edit `infra/terraform.tfvars`: set your account ID, region, a unique project name, and your workstation public IPv4 `/32`. Do not put a private LAN address there. `192.0.2.10` is a documentation placeholder. When using CloudShell, use your browser workstation's public IP for this allowlist, not CloudShell's outbound IP.

Choose **lab first** with `profile="lab"`. This Terraform setting chooses the infrastructure configuration; it is separate from the `AWS_PROFILE` environment variable that selects CLI credentials. Review `costs/README.md`, set an account budget notification if desired, and reserve time to destroy resources. Budget notifications are delayed alerts, not hard caps.

For HTTPS, provide an existing validated ACM certificate ARN in the same region and its matching `domain_name`. After apply, create a DNS CNAME/alias to `alb_dns_name`. ACM/DNS provisioning and domain registration are not included. If you have no domain, `allow_http_lab=true` permits a short `/32`-restricted test with disposable credentials and synthetic content only. Restricting the source IP does not encrypt HTTP. The business profile refuses this mode.

## 2. Inspect and create infrastructure with zero application tasks

```bash
terraform -chdir=infra init
terraform -chdir=infra fmt -check -recursive
terraform -chdir=infra validate
terraform -chdir=infra test
terraform -chdir=infra plan -out=lab.tfplan
terraform -chdir=infra apply lab.tfplan
umask 077
terraform -chdir=infra output -json > outputs.json
```

Review the plan before applying. Keep `application_ready=false` and `bootstrap_complete=false`. RDS creation can take several minutes. The app secret container initially has no value, so the service intentionally has no tasks. No web application should be available yet.

Terraform generates resource metadata locally. State and plan files are private. The RDS master password is managed by RDS/Secrets Manager; the application password is generated by the bootstrap script outside Terraform state.

## 3. Initialize limited database credentials

```bash
python scripts/bootstrap_db.py --confirm-project caleb-wp-lab
```

Use your actual project name if different. This script checks the AWS account and service tag, generates a secret if none exists, runs a one-off PHP task in the application's network, and creates `wpapp` with privileges on `wordpress.*` only. It reuses the secret on a retry. The application execution role cannot retrieve the master secret; only the separate bootstrap role can retrieve it. The bootstrap script never prints secret values and deregisters its task definition afterward.

If the script times out, inspect the bootstrap task before retrying and stop it if still running. A failed database bootstrap must be resolved before enabling the service. Run this bootstrap only for a new application with desired count zero, not as a rotation procedure on a running site.

## 4. Start one task and complete WordPress setup

Set `application_ready=true`, keeping `bootstrap_complete=false` and `enable_scaling=false`.

```bash
terraform -chdir=infra plan -out=lab.tfplan
terraform -chdir=infra apply lab.tfplan
terraform -chdir=infra output -json > outputs.json
terraform -chdir=infra output -raw url
```

Finish DNS setup for HTTPS, open the URL, and complete WordPress installation. Use unique credentials. Add a synthetic post and upload a small sample image. Confirm both render correctly. This initializes shared `wp-content` and the database before concurrent replicas are added.

ALB checks a static asset to avoid depending on redirects or the installation wizard. That health check does not establish database health. The live validation script checks the root page, but you must also test login, posting, and media persistence manually.

## 5. Capture evidence and test scaling

```bash
python scripts/validate_live.py --requests 20 --concurrency 2
```

After setup, set `bootstrap_complete=true` and `enable_scaling=true` in the lab profile and apply the reviewed plan. Export `outputs.json` again. Run a bounded load test:

```bash
python scripts/validate_live.py --requests 500 --concurrency 10 --out evidence/raw/load-500.json
```

Observe CloudWatch CPU/memory, desired/running task count, and scaling activities. A short 500-request test may not sustain CPU long enough to trigger scaling. Do not call an unobserved scale event successful. Increase test duration deliberately; use `scaling_cpu_target=10` only as an explicitly labeled demonstration threshold, then return it to 60. Maximum task count is two in lab; a rolling deployment can temporarily run more tasks than the steady-state scaling maximum.

The script performs only read requests, has a 10-second per-request timeout, and caps each invocation at 5,000 requests and 20 concurrent requests. Do not use it against a third-party site. It uses only the endpoint in your local Terraform outputs.

## 6. Run the task recovery drill

```bash
python scripts/recovery_drill.py --confirm-project caleb-wp-lab
```

This intentionally stops one Fargate task and observes ECS replacement. It is restricted to the lab profile, checks the project tag, and refuses an unstable service. It can interrupt the site. The report records task replacement plus stable HTTP response time; it does not measure regional DR, database restoration, or RPO.

Verify the synthetic post and uploaded image again after replacement. Capture screenshots with timestamps, and keep raw JSON private until identifiers and metadata have been reviewed.

## 7. Business-profile demonstration

Use a **separate checkout/state and a unique project name**, such as `caleb-wp-business`, to avoid changing a running lab in place. Repeat initialization with `profile="business"`, valid ACM/DNS, and an appropriate budget. It creates two NAT gateways, private app subnets, Multi-AZ RDS, WAF, and backup protections. After first-task setup, `bootstrap_complete=true` establishes the two-task baseline and scaling up to ten tasks. The default business database class is `db.t4g.small`; choose a different class only after sizing or testing.

A company workload needs representative reads/writes, authentication, caching behavior, and sustained/burst traffic tests. Do not infer capacity from the configured maximum. The business profile is a starting point for validation, not approval for real customer data.

## 8. Teardown and verify

For **lab**, review the destroy plan, then destroy:

```bash
terraform -chdir=infra plan -destroy -out=destroy.tfplan
terraform -chdir=infra apply destroy.tfplan
terraform -chdir=infra state list
```

This deletes the lab database and filesystem contents. Export anything you intend to keep first. An empty state list confirms no resources remain in that Terraform state, but does not prove the account has no retained or manually created resources.

For **business**, export required data, inventory backups, set `allow_destroy=true`, apply that change, then destroy. A final RDS snapshot is intentionally retained as `<project>-final`; rename that setting before repeated teardown if it already exists. EFS recovery points can outlive the filesystem and continue to incur charges. Decide whether to retain or delete them deliberately in AWS Backup. The application secret has a seven-day recovery window. ACM certificates, DNS records, domains, an optional state bucket, the GitHub OIDC provider/role, and manually created snapshots are outside this stack. Remove unneeded items separately after review.

Confirm in AWS that NAT gateways/EIPs, ALB, ECS tasks, database instances, EFS mount targets/filesystems, and unexpected backup artifacts are gone. Review billing after charges have posted.

## Troubleshooting

- **Image pull or secret retrieval fails:** inspect ECS stopped-task reason, HTTPS egress, NAT routes in business, temporary credentials, and execution role permissions. Docker Hub may impose rate limits; mirror an approved digest to ECR only with matching IAM/image validation changes.
- **ALB unhealthy:** inspect application logs, EFS mounting, bootstrap completion, security groups, and the static asset path. Do not open the task security group to the internet.
- **WAF blocks WordPress admin requests:** inspect rule metrics, reproduce with test content, and add a narrowly justified exclusion; do not disable the whole ACL casually.
- **Secret rotated but existing tasks fail:** ECS injects values at task start. Application credential rotation needs a coordinated DB/secret update and rolling deployment. The master secret is independently managed by RDS.
- **Scale-in or desired-count drift:** Terraform owns the configured baseline while Application Auto Scaling changes live desired count. A later apply may return the service to the baseline before scaling reacts. Inspect the plan and use a maintenance window for business changes.
