# Local validation record

Date: 2026-09-19. No AWS account was accessed and no AWS infrastructure was created.

| Check | Result | Scope |
|---|---|---|
| Terraform 1.11.4 installation | Verified against HashiCorp SHA256 checksum | Tool integrity |
| AWS provider initialization | Provider 6.65.0 installed, HashiCorp signature/checksums verified | Dependency retrieval, not schema validation |
| Terraform formatting | PASS | All Terraform configuration and native test files |
| HCL parsing | PASS | Configuration syntax through python-hcl2 |
| Python guardrail tests | PASS — 12 tests | Deployment identity/image restrictions, recovery safeguards, error statistics, basic secret scan, network/storage/IAM invariants |
| Python syntax compilation | PASS | Supplied scripts and tests |
| Workflow YAML parsing | PASS | Syntax only; GitHub Actions execution pending |
| Basic repository secret guardrail | PASS | Common AWS key/private-key patterns and private Terraform files; not a comprehensive audit |
| Terraform provider validation | BLOCKED | Provider cannot open its required local Unix socket in this execution environment |
| Terraform mocked profile tests | BLOCKED | Same provider startup limitation; none of the four runs is counted as passed |
| Live AWS deployment / application tests | NOT RUN | Requires authenticated account execution |
| Live load, recovery, restore, cost validation | NOT RUN | Requires deployed resources and measured evidence |

Terraform reported `listen unix ... socket: operation not permitted` while starting the AWS provider. No permissions were bypassed. The repository includes the normal validation commands in CI and the runbook so they can run in GitHub Actions or a local environment that supports the provider.

Passing offline checks does not establish deployability, security effectiveness, customer capacity, availability, or production readiness. Resolve any provider/CI failures before `terraform apply`, and collect live evidence using the supplied runbook.
