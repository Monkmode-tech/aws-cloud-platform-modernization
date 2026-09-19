# Cost planning

No AWS resources were created while building this repository. No claim of free-tier eligibility or exact monthly cost is made.

## Spend in stages

1. **Local checks:** no AWS infrastructure charges.
2. **Short lab session:** provision, initialize, validate, capture evidence, and destroy in one sitting. Keep scaling disabled until needed.
3. **Temporary business demonstration:** only after lab success and an explicit region-specific estimate. Two NAT gateways, Multi-AZ database capacity, WAF, backups, and two baseline tasks create an appreciably larger recurring cost.
4. **Continuous company operation:** size with representative traffic and review actual daily costs, then consider commitments only after demand is understood.

## Quantities for your AWS Pricing Calculator estimate

| Cost component | Lab | Business |
|---|---|---|
| Fargate Linux/x86 baseline after setup | 1 × 0.25 vCPU / 0.5 GiB | 2 × 0.5 vCPU / 1 GiB |
| Fargate scaling maximum | 2 tasks | 10 tasks |
| ALB | 1 + consumed LCUs | 1 + consumed LCUs |
| RDS MariaDB | Single-AZ `db.t4g.micro`, 20 GiB gp3 | Multi-AZ `db.t4g.small`, 20 GiB gp3 |
| NAT gateways | 0 | 2 + processed data |
| Public IPv4 | ALB plus public task IPs | ALB plus NAT EIPs |
| EFS | Stored data and access/transfer usage | Stored data plus backup retention |
| Secrets Manager | Application secret + managed DB secret | Same plus API usage |
| CloudWatch | Logs, dashboard, alarms, metrics usage | Longer log retention and higher traffic |
| WAF | None | 1 ACL, 2 rule entries, inspected requests |
| Other | Egress, backups, optional domain/DNS | Egress, backups, domain/DNS, retained snapshots |

Public IPv4 and load balancers can cost money even at low traffic. Burstable RDS instances can incur CPU credit charges. Deployments temporarily run old and new tasks, so their peak can exceed the steady-state autoscaling limit. Bootstrap tasks also incur a small runtime charge.

Use [AWS Pricing Calculator](https://calculator.aws/) with your region and expected runtime. `session-estimate.json` and `estimate.py` accept **your verified hourly subtotal** plus other charges; they deliberately avoid stale price constants.

```bash
python costs/estimate.py --hours 4 --hourly-subtotal 0.00 --other 0.00
```

Replace zeros with calculator-derived figures. The program does not fetch prices or guarantee the bill. NAT partial hours are billed as full hours; storage, WAF, secrets, backups, and other services use their own billing units. A simple hours-times-subtotal calculation is a planning approximation.

## Budget and cleanup controls

`budget_email` creates an **account-wide** monthly budget alert (other account workloads count toward it). Set `monthly_budget_usd` to a realistic value after estimating. Alerts are not instantaneous and do not stop resources. This project does not rely on an untested automatic shutdown job.

After teardown, inspect retained business RDS snapshots and EFS recovery points, secret recovery windows, unused IPs, DNS/domain charges, and any external state bucket. Keep only data you intentionally need.

Pricing references, reviewed 2026-09-19: [Fargate](https://aws.amazon.com/fargate/pricing/), [ALB](https://aws.amazon.com/elasticloadbalancing/pricing/), [VPC/NAT/IPv4](https://aws.amazon.com/vpc/pricing/), [RDS MariaDB](https://aws.amazon.com/rds/mariadb/pricing/), [WAF](https://aws.amazon.com/waf/pricing/), [EFS](https://aws.amazon.com/efs/pricing/), [Secrets Manager](https://aws.amazon.com/secrets-manager/pricing/).
