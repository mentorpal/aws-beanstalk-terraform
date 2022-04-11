variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "environment" {
  type = string
}
variable "top_level_domain" {
  type    = string
  default = "mentorpal.org"
}

variable "tags" {
  type = map(string)
}

variable "rate_limit" {
  type    = number
  default = 100 # minimum
}
