resource "aws_db_subnet_group" "main" {
  name       = var.project
  subnet_ids = aws_subnet.data[*].id
}
resource "aws_db_instance" "main" {
  identifier                  = var.project
  engine                      = "mariadb"
  engine_version              = "10.11"
  instance_class              = coalesce(var.db_instance_class, local.business ? "db.t4g.small" : "db.t4g.micro")
  allocated_storage           = 20
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = "wordpress"
  username                    = "wpadmin"
  manage_master_user_password = true
  db_subnet_group_name        = aws_db_subnet_group.main.name
  vpc_security_group_ids      = [aws_security_group.db.id]
  publicly_accessible         = false
  multi_az                    = local.business
  backup_retention_period     = local.business ? 7 : 1
  auto_minor_version_upgrade  = true
  deletion_protection         = local.business && !var.allow_destroy
  skip_final_snapshot         = !local.business
  final_snapshot_identifier   = local.business ? "${var.project}-final" : null
  delete_automated_backups    = true
  apply_immediately           = !local.business
}
resource "aws_efs_file_system" "wordpress" {
  creation_token  = var.project
  encrypted       = true
  throughput_mode = "bursting"
  tags            = { Name = var.project }
}
resource "aws_efs_backup_policy" "lab" {
  file_system_id = aws_efs_file_system.wordpress.id
  backup_policy { status = local.business ? "ENABLED" : "DISABLED" }
}
resource "aws_efs_access_point" "wordpress" {
  file_system_id = aws_efs_file_system.wordpress.id
  root_directory {
    path = "/wordpress"
    creation_info {
      owner_uid   = 0
      owner_gid   = 0
      permissions = "0755"
    }
  }
}
resource "aws_efs_mount_target" "wordpress" {
  count           = 2
  file_system_id  = aws_efs_file_system.wordpress.id
  subnet_id       = aws_subnet.data[count.index].id
  security_groups = [aws_security_group.efs.id]
}
resource "aws_efs_file_system_policy" "wordpress" {
  file_system_id = aws_efs_file_system.wordpress.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "DenyInsecureTransport", Effect = "Deny", Principal = "*", Action = "elasticfilesystem:*", Resource = aws_efs_file_system.wordpress.arn, Condition = { Bool = { "aws:SecureTransport" = "false" } } },
      { Sid = "AllowApplication", Effect = "Allow", Principal = { AWS = aws_iam_role.task.arn }, Action = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite", "elasticfilesystem:ClientRootAccess"], Resource = aws_efs_file_system.wordpress.arn, Condition = { StringEquals = { "elasticfilesystem:AccessPointArn" = aws_efs_access_point.wordpress.arn }, Bool = { "elasticfilesystem:AccessedViaMountTarget" = "true" } } }
    ]
  })
}

resource "aws_secretsmanager_secret" "application" {
  name_prefix             = "${var.project}-application-"
  description             = "Limited WordPress database user; value initialized outside Terraform"
  recovery_window_in_days = local.business ? 7 : 0
}
