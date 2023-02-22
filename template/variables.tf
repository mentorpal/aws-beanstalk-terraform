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

variable "eb_env_namespace" {
  type        = string
  description = "Namespace, which could be your organization name, e.g. 'eg' or 'cp'"
}

variable "eb_env_name" {
  type        = string
  description = "Solution name, e.g. 'app' or 'cluster'"
  default     = "mentorpal"
}

variable "site_domain_name" {
  type        = string
  description = "the public domain name for this site, e.g. mentorpal.org"
}

variable "secret_newrelic_api_key" {
  type        = string
  description = "new relic ingest key"
  default     = ""
}

variable "static_cors_allowed_origins" {
  type        = list(string)
  description = "list of cors allowed origins for static"
  default     = []
}

variable "cloudwatch_slack_webhook" {
  type        = string
  description = "The slack app incoming webhook."
  default     = ""
}

variable "cicd_slack_webhook" {
  type        = string
  description = "The slack app incoming webhook for cicd notifications."
  default     = ""
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
