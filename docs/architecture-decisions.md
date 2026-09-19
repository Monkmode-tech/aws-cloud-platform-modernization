# Architecture decisions

## ADR-001: Keep WordPress; focus the project on cloud operations

WordPress connects the original Terraform, recovery evidence, and scaling coursework. It provides a real application with database state, file state, sessions, plugins, and deployment hazards. The fictional business serves public content and customer information pages; no payment processing or regulated-data compliance is claimed.

## ADR-002: Separate economical verification from the business target

A business target uses a public ALB, private application subnets, isolated data subnets, two Availability Zones, per-AZ NAT, and Multi-AZ RDS. The lab accepts public task IPs to avoid persistent NAT charges; its security group accepts HTTP only from the ALB security group. A publicly addressed task is not an acceptable substitute for the intended private business topology.

Two tasks and ECS AZ rebalancing support distribution across AZs. This is not evidence that an AZ failure has been tested. RDS Multi-AZ provides standby availability, not read scaling or a substitute for recovery testing. The single region remains a shared failure boundary.

## ADR-003: Separate application and data access

The ALB can reach app port 80; the app can reach MariaDB port 3306 and EFS port 2049. The database and EFS have no internet ingress. App HTTPS egress supports registry pulls and AWS APIs; this is broader than an allowlisted production egress design. HTTPS terminates at ALB; backend HTTP and unverified database transport are recorded residual risks.

## ADR-004: Persist content, keep core tied to the image

EFS stores only `wp-content`. WordPress core is reconstructed from the pinned image for each task. Shared secret values keep WordPress authentication keys/salts consistent across replicas. EFS is encrypted at rest, uses TLS in transit, and is restricted by the access point, task role, and mount-target security group. The official container's initialization requires write/chown behavior, so scoped EFS ClientRootAccess remains a documented exception. A custom non-root image and immutable plugin delivery would reduce this surface.

## ADR-005: No application use of the RDS master account

RDS creates/manages its master password. An explicit one-off bootstrap task uses it to create the restricted `wpapp` account. The normal application's execution role retrieves only the application secret. Secret values are neither Terraform inputs nor outputs. The task role is separate from the execution role and grants filesystem access only.

Master-secret rotation does not rotate `wpapp`. Application secret rotation must be designed and tested as a separate operation; changing a secret alone does not update an already-running container.

## ADR-006: Bounded scaling and evidence before capacity claims

The business service starts at two tasks and is bounded at ten; CPU target tracking defaults to 60%. Fargate tasks use 0.5 vCPU/1 GiB in business and 0.25 vCPU/0.5 GiB in lab. Small tasks and burstable databases are initial hypotheses. CPU scaling cannot resolve database contention, poor plugins, external API bottlenecks, or memory pressure. Measure p95 latency, error rate, throughput, memory, DB connections, and CPU credit use before choosing a customer capacity target.

## ADR-007: Controlled delivery instead of unattended infrastructure changes

CI validates Terraform syntax/schema, mocked profile behavior, script guardrails, and basic secret hygiene without AWS access. CD is manually dispatched from `main`, after CI, through an exact-subject OIDC trust and protected GitHub environment. It updates only an existing service using approved task/execution roles. Infrastructure remains reviewable through Terraform plans and local authenticated applies.

A successful ECS waiter means scheduling/health convergence, not business correctness. The script checks that the requested revision is active because a circuit-breaker rollback can otherwise look stable. Workstation HTTP and content checks follow deployment.

## ADR-008: Single-region availability now; regional recovery as an extension

Historical evidence covers ALB target deregistration and restoration. New scripts cover task replacement. Neither is a database restore or regional failover exercise. The regional extension would require off-region copies of DB and file backups, DNS strategy, secrets/key access, a recovery-region stack, restore orchestration, and measured recovery objectives. It is documented future work, not an implemented feature.
