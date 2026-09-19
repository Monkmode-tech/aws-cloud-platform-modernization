locals {
  ecs_trust = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ecs-tasks.amazonaws.com" }, Condition = { StringEquals = { "aws:SourceAccount" = var.account_id }, ArnLike = { "aws:SourceArn" = "arn:aws:ecs:${var.region}:${var.account_id}:*" } } }]
  })
}
resource "aws_iam_role" "execution" {
  name               = "${var.project}-execution"
  assume_role_policy = local.ecs_trust
}
resource "aws_iam_role" "task" {
  name               = "${var.project}-task"
  assume_role_policy = local.ecs_trust
}
resource "aws_iam_role_policy" "execution" {
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.app.arn}:*" },
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = aws_secretsmanager_secret.application.arn }
    ]
  })
}
resource "aws_iam_role_policy" "task" {
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite", "elasticfilesystem:ClientRootAccess"], Resource = aws_efs_file_system.wordpress.arn, Condition = { StringEquals = { "elasticfilesystem:AccessPointArn" = aws_efs_access_point.wordpress.arn } } }]
  })
}

resource "aws_iam_role" "bootstrap" {
  name               = "${var.project}-bootstrap"
  assume_role_policy = local.ecs_trust
}
resource "aws_iam_role_policy" "bootstrap" {
  role = aws_iam_role.bootstrap.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.app.arn}:*" },
      { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = [aws_db_instance.main.master_user_secret[0].secret_arn, aws_secretsmanager_secret.application.arn] }
    ]
  })
}
