# Technical references

Reviewed 2026-09-19. Provider/API behavior must be rechecked when dependencies are upgraded.

- [Amazon ECS with EFS](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/efs-volumes.html): shared persistent storage, IAM access points, and Fargate platform requirements.
- [RDS-managed master credentials](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-secrets-manager.html): master password generation and managed rotation. This is distinct from the separately initialized application account.
- [Terraform and Secrets Manager](https://docs.aws.amazon.com/prescriptive-guidance/latest/secure-sensitive-data-secrets-manager-terraform/using-secrets-manager-and-terraform.html): secret handling and state protection.
- [GitHub OIDC for AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws): trust audience/subject, environment restrictions, and repository subject formats.
- [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3): encryption, remote state permissions, and lockfiles.
- [AWS provider DB resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance): database Terraform settings.
- [Official WordPress image source](https://github.com/docker-library/wordpress): initialization, runtime environment configuration, and image packaging.

The architecture choices and project-specific trade-offs are engineering decisions based on these capabilities and the supplied coursework; they are not certifications by these vendors.
