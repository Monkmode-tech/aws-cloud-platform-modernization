# Security review and known limitations

This is a design/configuration review, not a penetration test or compliance attestation.

| Source issue or risk | Implemented treatment | Remaining validation |
|---|---|---|
| Credential values bundled with coursework configuration | Source credentials excluded; SSO/profile auth; secret guardrail | Review original credentials privately and revoke/rotate if still valid or exposed elsewhere |
| ALB and ECS share a security group | Separate ALB, app, DB, and EFS security groups | Prove direct app/DB access is blocked |
| Data subnets have internet routes | Isolated data route table | Inspect deployed routes and security groups |
| Database password in task environment configuration | Secrets Manager runtime injection; limited DB user | Confirm normal task role cannot retrieve master secret |
| WordPress state diverges between replicas | Shared encrypted EFS and shared authentication salts | Upload/login tests across replicas and replacements |
| Mutable image tag | Digest-pinned official image | Scan image and plugins before live use; a digest is not a clean bill of health |
| HTTP internet entry | Business HTTPS required; lab HTTP explicit and `/32` restricted | Confirm certificate, redirect behavior, and TLS policy |
| Uncontrolled deployment permissions | Exact OIDC subject; service-scoped update; pass only two roles | Verify actual GitHub subject and environment protection rules |
| Scaling/performance claims lack live telemetry | Evidence template; bounded scripts reporting errors | Capture timestamped AWS measurements |

## Production-readiness gaps

1. **Database transport:** storage is encrypted, but this configuration does not enforce or verify TLS for WordPress-to-MariaDB connections. Implement certificate verification with the selected PHP/MySQL client and test `require_secure_transport` before sensitive data use. Do not label the entire data path encrypted.
2. **Application runtime:** the upstream Apache image initializes as root, root filesystem remains writable, and scoped EFS root access is granted. Harden a custom image and test a non-root runtime before stronger isolation claims.
3. **Application security:** no MFA/login hardening plugin, malware scanning, plugin governance, content moderation, or software bill of materials is supplied. Review WAF false positives and application patching.
4. **Monitoring response:** alarms are console-visible; no on-call notification actions, log analytics, ALB access logs, WAF log delivery, or account-wide CloudTrail/GuardDuty organization baseline is provisioned. Establish these before customer operation.
5. **Recovery:** backup configuration is not proof of restoration. Restore database and file backups together to a separate environment and verify content consistency. EFS automatic backups depend on AWS Backup setup and successful jobs; inspect them.
6. **Secret operations:** `wpapp` rotation is manual and untested. Remove/restrict the bootstrap role after initialization if you will not need it. Protect state, raw output metadata, and operator devices.
7. **Deployment:** rollback restores the ECS revision only. Schema migrations and shared file/plugin changes need compatible rollback or restore procedures.
8. **Supply chain:** workflow actions are commit-pinned, but Python packages use bounded version ranges. Create reviewed dependency lock files and run an image/dependency vulnerability scanner before production release.

## Publishing hygiene

Do not publish original ZIPs, raw Terraform state/plans, credential-bearing tfvars, or unreviewed console screenshots. The packaged project intentionally excludes those source bytes. `scripts/check_secrets.py` detects common AWS access-key/private-key patterns and private Terraform files; it is a limited guardrail, not a comprehensive detector. Use GitHub secret scanning where available, and inspect the staged diff before pushing.
