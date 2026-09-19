# Company workload readiness

The business profile is a concrete deployable reference configuration, not a validated production service. A customer count alone is insufficient to size infrastructure: active concurrency, page mix, cache hit rate, plugins, media volume, database writes, geography, and peak traffic all matter.

## Candidate acceptance targets — proposed, not achieved

| Area | Initial target for discussion | Required evidence |
|---|---|---|
| HTTP performance | p95 under 1 second at the agreed representative peak | Sustained authenticated/unauthenticated load test with error rate and DB telemetry |
| Request errors | Less than 1% errors during the agreed test window | Raw request logs including failures |
| App resilience | Serve requests during one-task replacement with two tasks | Controlled business staging drill and timestamped availability probes |
| Data recovery | Agree RTO/RPO with the business before testing | Restore DB and EFS to a separate stack; compare synthetic records/media |
| Security | No public app/DB ingress; approved TLS paths | Network checks, transport verification, IAM review, image/plugin scan |
| Spending | Business-approved monthly baseline and peak estimate | Region-specific calculator export plus observed test-session bill |

Do not place these targets on a resume as achieved outcomes.

## Launch sequence

1. Validate the inexpensive lab, including bootstrap, login/media behavior, deployment rollback, and full cleanup.
2. Resolve the security/operations gaps in `security-review.md`, particularly database TLS, image/plugin review, alarm routing, and restore testing.
3. Deploy a temporary business staging stack with synthetic content and the same security topology intended for customers.
4. Increase load in measured steps. Capture CPU/memory, DB connections/latency, latency percentiles, error rate, and task count. Stop when errors or saturation exceed agreed limits.
5. Tune database size, caching/CDN strategy, task resources, and scaling signals based on evidence. Scaling the web tier does not guarantee database scalability.
6. Run restore and failure drills in staging. Assign an operations owner and test the incident runbook.
7. Approve a launch capacity envelope, change process, budget, and recovery objectives based on the results.

CloudFront, application/object caching, ECR image mirroring, ALB request-based scaling, and multi-region recovery are possible next steps. Select them based on measured needs; they are not deployed by this version.
