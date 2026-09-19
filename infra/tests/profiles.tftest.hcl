mock_provider "aws" {
  mock_data "aws_availability_zones" { defaults = { names = ["us-east-1a", "us-east-1b"] } }
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_resource "aws_db_instance" {
    defaults = { master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:master-abc123", secret_status = "active", kms_key_id = "test" }] }
  }
  mock_resource "aws_efs_file_system" { defaults = { arn = "arn:aws:elasticfilesystem:us-east-1:123456789012:file-system/fs-12345678" } }
  mock_resource "aws_efs_access_point" { defaults = { arn = "arn:aws:elasticfilesystem:us-east-1:123456789012:access-point/fsap-12345678" } }
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::123456789012:role/test" } }
  mock_resource "aws_cloudwatch_log_group" { defaults = { arn = "arn:aws:logs:us-east-1:123456789012:log-group:test" } }
  mock_resource "aws_secretsmanager_secret" { defaults = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:application-abc123" } }
}
variables {
  account_id        = "123456789012"
  allowed_ipv4_cidr = "192.0.2.1/32"
}
run "lab_initialization" {
  command = plan
  variables { allow_http_lab = true }
  assert {
    condition     = aws_ecs_service.wordpress.desired_count == 0
    error_message = "Service must remain stopped until database credentials are initialized."
  }
  assert {
    condition     = length(aws_nat_gateway.main) == 0 && !aws_db_instance.main.multi_az
    error_message = "Lab must not create NAT gateways or a Multi-AZ database."
  }
  assert {
    condition     = !aws_db_instance.main.publicly_accessible && aws_db_instance.main.storage_encrypted
    error_message = "The database must remain private and encrypted."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.web.cidr_ipv4 == "192.0.2.1/32"
    error_message = "Lab ingress must be restricted to the workstation."
  }
}
run "business_profile" {
  command = plan
  variables {
    profile            = "business"
    certificate_arn    = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
    domain_name        = "wordpress.example.com"
    application_ready  = true
    bootstrap_complete = true
  }
  assert {
    condition     = aws_ecs_service.wordpress.desired_count == 2 && !one(aws_ecs_service.wordpress.network_configuration).assign_public_ip
    error_message = "Business needs two private application tasks."
  }
  assert {
    condition     = length(aws_nat_gateway.main) == 2 && aws_db_instance.main.multi_az
    error_message = "Business needs a NAT gateway per AZ and Multi-AZ database."
  }
  assert {
    condition     = aws_db_instance.main.backup_retention_period == 7 && aws_db_instance.main.deletion_protection && !aws_db_instance.main.skip_final_snapshot
    error_message = "Business database backup and deletion controls must be enabled."
  }
  assert {
    condition     = aws_appautoscaling_target.ecs[0].min_capacity == 2 && aws_appautoscaling_target.ecs[0].max_capacity == 10
    error_message = "Business scaling must stay bounded from 2 to 10 tasks."
  }
  assert {
    condition     = length(aws_wafv2_web_acl.main) == 1 && aws_lb_listener.web.protocol == "HTTPS"
    error_message = "Business must include WAF and HTTPS."
  }
  assert {
    condition     = one(aws_efs_backup_policy.lab.backup_policy).status == "ENABLED"
    error_message = "Business file backups must be enabled."
  }
}
run "business_rejects_http" {
  command = plan
  variables {
    profile        = "business"
    allow_http_lab = true
  }
  expect_failures = [aws_lb.main]
}
run "rejects_world_open_lab" {
  command = plan
  variables {
    allow_http_lab    = true
    allowed_ipv4_cidr = "0.0.0.0/0"
  }
  expect_failures = [var.allowed_ipv4_cidr]
}
