
resource "aws_wafv2_web_acl" "main" {
  count = local.business ? 1 : 0
  name  = var.project
  scope = "REGIONAL"
  default_action {
    allow {}
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = var.project
    sampled_requests_enabled   = false
  }
  rule {
    name     = "CommonRules"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-common"
      sampled_requests_enabled   = false
    }
  }
  rule {
    name     = "IPRateLimit"
    priority = 2
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project}-rate"
      sampled_requests_enabled   = false
    }
  }
}
resource "aws_wafv2_web_acl_association" "main" {
  count        = local.business ? 1 : 0
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main[0].arn
}
