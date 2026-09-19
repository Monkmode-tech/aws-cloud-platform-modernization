# Evidence and claim boundaries

## Supplied source material

| Source | What it contributes | Evidence classification |
|---|---|---|
| `configuration files and scripts.zip` | Original WordPress Terraform and ALB recovery scripts | Source implementation; contained credentials, so not redistributed |
| `Unit4_AWS_DR_README.md` and `AWS Disaster Recovery Lab Report.pdf` | Original outage/restoration procedure; report describes about 42 seconds average recovery | Historical self-reported observation, restricted to ALB target deregistration/restoration |
| `lab screenshots.zip` | Original console/application evidence | Supplied but not republished; privacy review required |
| `tetteh_caleb_aws_scaling_design_analysis_lab.zip` | Scaling policy design, scripts, and analysis | Reports explicitly label scaling results simulated |
| `tetteh_caleb_capstone_cloud_blueprint.zip` | Integrated architecture, cost model, operational notes | Mixed source design and simulated validation; not current implementation proof |
| `tetteh_caleb_aws_diagram_lab.zip` | Architecture documentation and diagrams | Source design; contains proposed controls beyond the baseline |
| `Cloud Security Sustainability Assessment.pdf` | Layered security, governance, and roadmap | Proposed enterprise design |
| `AWS Security Best Practices Lab and Report.pdf` | Security review framework | Analysis; some control descriptions require code/deployment verification |
| `Unit 3 Assignment Course Project Cloud Blueprint Part 1 - Cloud Cost Sustainability.pdf` | Cost management framework | Planning assumptions; not this stack's bill |

The new repository consolidates concepts and rewrites the implementation. It does not repackage credential-bearing source files or present generated artifacts as prior deployed work. It preserves the coursework attribution without claiming a real client engagement.

## New implementation status

- Terraform and Python local checks: see `docs/local-validation.md`.
- AWS apply: pending.
- Bootstrap success, WordPress login/media validation: pending.
- Live load/scaling results: pending.
- Task replacement results: pending.
- Business-profile restore, Multi-AZ failover, regional DR: pending/not implemented as applicable.
- Actual AWS cost: pending.

## Collect and publish

Scripts write private raw JSON to `evidence/raw/`, which is ignored by Git. After testing, create a sanitized report using `validation-template.md`. Include UTC timestamps, commit SHA, profile, region, workload definition, request counts, duration, failures, latency percentiles, and screenshots proving actual task counts. Do not copy simulated values into observed fields. Remove account IDs, secret ARNs/values, browser session details, and unnecessary resource identifiers from public screenshots.

For recovery, report the precise failure injected. A task restart does not establish RPO. To claim data preservation, compare known posts/media before and after; to claim database recovery, restore an actual backup and verify its contents.
