variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "name" {
  type        = string
  description = "Project name, e.g. 'v2-mentorpal-new-relic'"
}

variable "eb_log_group_prefix" {
  type        = string
  description = "CW logs are under /aws/elasticbeanstalk/{eb_log_group_prefix}/*, e.g. 'mentorpal-v2-mentorpal'"
}

variable "api_key" {
  type        = string
  description = "http endpoint credentials"
}

variable "ingest_url" {
  type        = string
  description = "HTTP endpoint"
  default     = "https://aws-api.newrelic.com/firehose/v1"
}
