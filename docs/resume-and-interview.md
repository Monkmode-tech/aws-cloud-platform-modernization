# Resume and interview positioning

## Project title

**AWS Cloud Platform Modernization | Terraform, ECS Fargate, RDS, EFS, GitHub Actions**

Independent portfolio project adapted from UMGC CLCS 645 — Cloud Infrastructure Planning and Design.

## Before personally validating the new implementation

Use these only after reviewing the code and being able to explain it:

- Designed a Terraform-based AWS WordPress reference architecture with economical lab and multi-AZ business profiles, separating load balancing, application networking, and data access.
- Developed security controls using Secrets Manager, scoped IAM roles, restricted database credentials, encrypted shared storage, HTTPS, and AWS WAF configuration.
- Built GitHub Actions validation and OIDC deployment workflows, plus scripts for bounded load testing and ECS task-recovery evidence collection.

Do not claim production operation, customer scale, measured latency improvements, cost savings, or disaster recovery objectives based only on this code package. If you have not run GitHub Actions yet, describe its configuration rather than a successful pipeline execution.

## After live validation

Replace placeholders with actual evidence before using:

- Provisioned and validated a containerized WordPress environment using Terraform, ECS Fargate, ALB, RDS, and EFS; achieved **[measured throughput]** at **[p95 latency]** with **[error rate]** under **[defined workload]**.
- Verified application scaling from **[observed count]** to **[observed count]** and task replacement in **[measured seconds]**, preserving **[tested synthetic posts/media]**.
- Implemented OIDC-authenticated image delivery with **[verified rollback behavior]** and documented an observed test-session cost of **[actual amount]**.

## Interview discussion

1. Why a public-task lab and private-task business profile? Explain cost versus network isolation and why the company target keeps per-AZ NAT.
2. Why EFS? Explain immutable WordPress core versus shared media/plugins, and shared authentication salts across tasks.
3. Why separate DB bootstrap? Explain database-scoped privileges and why normal app tasks cannot retrieve the master secret.
4. What did you actually test? Distinguish original ALB recovery, simulated scaling, new local checks, and new live evidence.
5. What fails first as traffic grows? Discuss DB contention, plugin behavior, memory, CPU credits, and cache hit rate.
6. What prevents production approval today? Discuss database TLS, restores, image/plugin review, alarm routing, and representative capacity testing.

AI assistance was used to refactor and document this package. Review, execute, and explain each claimed capability yourself; your strongest interview evidence is your own measured validation and engineering decisions.
