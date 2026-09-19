output "project" { value = var.project }
output "region" { value = var.region }
output "account_id" { value = data.aws_caller_identity.current.account_id }
output "url" { value = var.certificate_arn == "" ? "http://${aws_lb.main.dns_name}" : "https://${var.domain_name}" }
output "alb_dns_name" { value = aws_lb.main.dns_name }
output "cluster" { value = aws_ecs_cluster.main.name }
output "service" { value = aws_ecs_service.wordpress.name }
output "service_arn" { value = aws_ecs_service.wordpress.id }
output "task_family" { value = aws_ecs_task_definition.wordpress.family }
output "execution_role_arn" { value = aws_iam_role.execution.arn }
output "task_role_arn" { value = aws_iam_role.task.arn }
output "target_group_arn" { value = aws_lb_target_group.wordpress.arn }
output "log_group" { value = aws_cloudwatch_log_group.app.name }
output "scaling_enabled" { value = local.scaling }

output "profile" { value = var.profile }
output "application_secret_arn" { value = aws_secretsmanager_secret.application.arn }
output "master_secret_arn" { value = aws_db_instance.main.master_user_secret[0].secret_arn }
output "bootstrap_execution_role_arn" { value = aws_iam_role.bootstrap.arn }
output "task_definition_arn" { value = aws_ecs_task_definition.wordpress.arn }
output "subnet_ids" { value = local.private_compute ? aws_subnet.app[*].id : aws_subnet.public[*].id }
output "app_security_group_id" { value = aws_security_group.app.id }
output "assign_public_ip" { value = !local.private_compute }
output "db_host" { value = aws_db_instance.main.address }
