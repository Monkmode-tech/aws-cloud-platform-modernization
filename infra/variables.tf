variable "region" {
  type    = string
  default = "us-east-1"
}
variable "account_id" {
  type        = string
  description = "Expected AWS account. Prevents accidental deployment to a different account."
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Use your 12-digit AWS account ID."
  }
}
variable "project" {
  type    = string
  default = "caleb-wp-lab"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project))
    error_message = "Use 3-20 lowercase letters, digits, and hyphens, starting with a letter."
  }
}
variable "allowed_ipv4_cidr" {
  type        = string
  description = "Your workstation public IPv4 address as a /32. Default internet-wide ingress is prohibited."
  validation {
    condition     = can(cidrnetmask(var.allowed_ipv4_cidr)) && can(regex("/32$", var.allowed_ipv4_cidr))
    error_message = "Set a single workstation IPv4 address ending in /32."
  }
}
variable "certificate_arn" {
  type        = string
  default     = ""
  description = "Existing ACM certificate in the deployment region. Use its matching DNS name for HTTPS."
}
variable "domain_name" {
  type        = string
  default     = ""
  description = "DNS name covered by the certificate; create its CNAME/alias after apply."
}
variable "allow_http_lab" {
  type        = bool
  default     = false
  description = "Explicit opt-in for short-lived HTTP-only testing with dummy data."
}
variable "db_instance_class" {
  type    = string
  default = null
}
variable "enable_scaling" {
  type        = bool
  default     = false
  description = "Enable only after one task has initialized and WordPress setup is complete."
}
variable "scaling_cpu_target" {
  type    = number
  default = 60
  validation {
    condition     = var.scaling_cpu_target >= 10 && var.scaling_cpu_target <= 80
    error_message = "Use a CPU target from 10 to 80 percent."
  }
}
variable "budget_email" {
  type        = string
  default     = ""
  description = "Optional email for AWS Budget notifications."
}
variable "monthly_budget_usd" {
  type    = number
  default = 5
  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "Budget must be positive. A budget alert is not a spending cap."
  }
}

variable "profile" {
  type    = string
  default = "lab"
  validation {
    condition     = contains(["lab", "business"], var.profile)
    error_message = "Choose lab or business."
  }
}
variable "application_ready" {
  type        = bool
  default     = false
  description = "Set true after bootstrap_db.py has provisioned the limited database user."
}
variable "bootstrap_complete" {
  type        = bool
  default     = false
  description = "Set true after WordPress installation before scaling to multiple tasks."
  validation {
    condition     = !var.bootstrap_complete || var.application_ready
    error_message = "bootstrap_complete requires application_ready=true."
  }
}
variable "allow_destroy" {
  type        = bool
  default     = false
  description = "Explicitly disable business deletion protections before a planned teardown."
}
