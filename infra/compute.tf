resource "aws_lb" "main" {
  name                       = var.project
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = aws_subnet.public[*].id
  security_groups            = [aws_security_group.alb.id]
  drop_invalid_header_fields = true
  enable_deletion_protection = local.business && !var.allow_destroy
  lifecycle {
    precondition {
      condition     = (var.certificate_arn != "" && var.domain_name != "") || (!local.business && var.allow_http_lab && var.certificate_arn == "" && var.domain_name == "")
      error_message = "Supply certificate_arn and domain_name together, or explicitly allow HTTP lab mode."
    }
  }
}
resource "aws_lb_target_group" "wordpress" {
  name                 = var.project
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 15
  health_check {
    path                = "/wp-includes/images/blank.gif"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.certificate_arn == "" ? 80 : 443
  protocol          = var.certificate_arn == "" ? "HTTP" : "HTTPS"
  certificate_arn   = var.certificate_arn == "" ? null : var.certificate_arn
  ssl_policy        = var.certificate_arn == "" ? null : "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}
resource "aws_ecs_cluster" "main" { name = var.project }
resource "aws_ecs_task_definition" "wordpress" {
  family                   = var.project
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = local.business ? "512" : "256"
  memory                   = local.business ? "1024" : "512"
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn
  volume {
    name = "wordpress"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.wordpress.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.wordpress.id
        iam             = "ENABLED"
      }
    }
  }
  container_definitions = jsonencode([{
    name         = "wordpress", image = local.image, essential = true
    portMappings = [{ containerPort = 80, protocol = "tcp" }]
    mountPoints  = [{ sourceVolume = "wordpress", containerPath = "/var/www/html/wp-content", readOnly = false }]
    environment = [
      { name = "WORDPRESS_DB_HOST", value = aws_db_instance.main.address },
      { name = "WORDPRESS_DB_NAME", value = "wordpress" },
      { name = "WORDPRESS_CONFIG_EXTRA", value = "define('DISALLOW_FILE_EDIT', true); define('AUTOMATIC_UPDATER_DISABLED', true); if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') { $_SERVER['HTTPS'] = 'on'; }" }
    ]
    secrets = [
      { name = "WORDPRESS_DB_USER", valueFrom = "${aws_secretsmanager_secret.application.arn}:username::" },
      { name = "WORDPRESS_DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.application.arn}:password::" },
      { name = "WORDPRESS_AUTH_KEY", valueFrom = "${aws_secretsmanager_secret.application.arn}:AUTH_KEY::" },
      { name = "WORDPRESS_SECURE_AUTH_KEY", valueFrom = "${aws_secretsmanager_secret.application.arn}:SECURE_AUTH_KEY::" },
      { name = "WORDPRESS_LOGGED_IN_KEY", valueFrom = "${aws_secretsmanager_secret.application.arn}:LOGGED_IN_KEY::" },
      { name = "WORDPRESS_NONCE_KEY", valueFrom = "${aws_secretsmanager_secret.application.arn}:NONCE_KEY::" },
      { name = "WORDPRESS_AUTH_SALT", valueFrom = "${aws_secretsmanager_secret.application.arn}:AUTH_SALT::" },
      { name = "WORDPRESS_SECURE_AUTH_SALT", valueFrom = "${aws_secretsmanager_secret.application.arn}:SECURE_AUTH_SALT::" },
      { name = "WORDPRESS_LOGGED_IN_SALT", valueFrom = "${aws_secretsmanager_secret.application.arn}:LOGGED_IN_SALT::" },
      { name = "WORDPRESS_NONCE_SALT", valueFrom = "${aws_secretsmanager_secret.application.arn}:NONCE_SALT::" }
    ]
    logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = aws_cloudwatch_log_group.app.name, "awslogs-region" = var.region, "awslogs-stream-prefix" = "wordpress" } }
  }])
  lifecycle {
    precondition {
      condition     = can(regex("^docker.io/library/wordpress@sha256:[0-9a-f]{64}$", local.image))
      error_message = "app/image.txt must pin the official WordPress image by sha256 digest."
    }
  }
}
resource "aws_ecs_service" "wordpress" {
  name                               = var.project
  cluster                            = aws_ecs_cluster.main.id
  task_definition                    = aws_ecs_task_definition.wordpress.arn
  desired_count                      = var.application_ready ? local.min_tasks : 0
  launch_type                        = "FARGATE"
  availability_zone_rebalancing      = local.business ? "ENABLED" : "DISABLED"
  platform_version                   = "1.4.0"
  health_check_grace_period_seconds  = 180
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  wait_for_steady_state              = true
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    subnets          = local.private_compute ? aws_subnet.app[*].id : aws_subnet.public[*].id
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = !local.private_compute
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.wordpress.arn
    container_name   = "wordpress"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.web, aws_efs_mount_target.wordpress, aws_efs_file_system_policy.wordpress, aws_iam_role_policy.execution, aws_iam_role_policy.task, aws_route_table_association.app, aws_route_table_association.public]
}
