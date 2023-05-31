variable "aws_acm_certificate_domain" {
  type        = string
  description = "domain name to find ssl certificate"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "aws_route53_zone_name" {
  type        = string
  description = "name to find aws route53 zone, e.g. mentorpal.org."
}

variable "eb_env_name" {
  type        = string
  description = "Solution name, e.g. 'app' or 'cluster'"
  default     = "mentorpal"
}

variable "eb_env_namespace" {
  type        = string
  description = "Namespace, which could be your organization name, e.g. 'eg' or 'cp'"
}

variable "eb_env_tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags (e.g. `map('BusinessUnit`,`XYZ`)"
}

variable "site_domain_name" {
  type        = string
  description = "the public domain name for this site, e.g. dev.mentorpal.org"
}

variable "static_site_alias" {
  type        = string
  description = "alias for static site that will serve video etc. By default, generates one based on site_domain_name"
  default     = ""
}

variable "static_cors_allowed_origins" {
  type        = list(string)
  description = "list of cors allowed origins for static"
  default     = []
}


variable "enable_cdn_firewall_logging" {
  type        = bool
  default     = false
  description = "enable cdn firewall logging (s3 bucket for storage, and a kinesis stream for delivery)"
}

variable "enable_api_firewall_logging" {
  type        = bool
  default     = false
  description = "enable api firewall logging (s3 bucket for storage, and a kinesis stream for delivery)"
}

variable "enable_content_backup" {
  type        = bool
  description = "if true configures aws backup service to continuously backup uploads"
  default     = true
}

variable "enable_alarms" {
  type        = bool
  description = "Not used atm, reserved for future alerts"
  default     = false
}

variable "alert_topic_arn" {
  type        = string
  description = "sns topic arn used for alerts"
  default     = ""
}

variable "secret_header_name" {
  type        = string
  default     = ""
}

variable "secret_header_value" {
  type        = string
  default     = ""
}

variable "allowed_origin" {
  type        = string
  default     = ""
}
