resource "aws_cloudwatch_log_group" "app" {
  name              = "/portfolio/${var.project}"
  retention_in_days = local.business ? 30 : 7
}
resource "aws_appautoscaling_target" "ecs" {
  count              = local.scaling ? 1 : 0
  max_capacity       = local.max_tasks
  min_capacity       = local.min_tasks
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.wordpress.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
resource "aws_appautoscaling_policy" "cpu" {
  count              = local.scaling ? 1 : 0
  name               = "${var.project}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace
  target_tracking_scaling_policy_configuration {
    target_value       = var.scaling_cpu_target
    scale_in_cooldown  = 180
    scale_out_cooldown = 60
    predefined_metric_specification { predefined_metric_type = "ECSServiceAverageCPUUtilization" }
  }
}
resource "aws_cloudwatch_metric_alarm" "unhealthy" {
  alarm_name          = "${var.project}-unhealthy-target"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix, TargetGroup = aws_lb_target_group.wordpress.arn_suffix }
  alarm_description   = "Console-only lab alarm; configure notification actions before operational use."
}
resource "aws_cloudwatch_metric_alarm" "errors" {
  alarm_name          = "${var.project}-target-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  dimensions          = { LoadBalancer = aws_lb.main.arn_suffix, TargetGroup = aws_lb_target_group.wordpress.arn_suffix }
}
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = var.project
  dashboard_body = jsonencode({ widgets = [{ type = "metric", x = 0, y = 0, width = 12, height = 6, properties = { title = "WordPress CPU and memory", region = var.region, period = 60, stat = "Average", metrics = [["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.wordpress.name], ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.wordpress.name]] } }, { type = "metric", x = 12, y = 0, width = 12, height = 6, properties = { title = "ALB request count", region = var.region, period = 60, stat = "Sum", metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, "TargetGroup", aws_lb_target_group.wordpress.arn_suffix]] } }] })
}
resource "aws_budgets_budget" "lab" {
  count        = var.budget_email == "" ? 0 : 1
  name         = "${var.project}-account-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }
}
