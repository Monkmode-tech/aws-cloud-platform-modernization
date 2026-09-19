terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
  default_tags {
    tags = { Project = var.project, Environment = "portfolio-lab", ManagedBy = "Terraform", Owner = "Caleb-Tetteh" }
  }
}
data "aws_availability_zones" "available" { state = "available" }
data "aws_caller_identity" "current" {}
locals {
  azs   = slice(data.aws_availability_zones.available.names, 0, 2)
  image = trimspace(file("${path.module}/../app/image.txt"))
}

locals {
  business        = var.profile == "business"
  private_compute = local.business
  min_tasks       = local.business && var.bootstrap_complete ? 2 : 1
  max_tasks       = local.business ? 10 : 2
  scaling         = var.bootstrap_complete && (var.enable_scaling || local.business)
}
