variable "aws_acm_certificate_domain" {
  type        = string
  description = "domain name to find ssl certificate"
}

// variable "aws_availability_zones" {
//   type        = list(string)
//   description = "List of availability zones"
// }

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "aws_route53_zone_name" {
  type        = string
  description = "name to find aws route53 zone, e.g. mentorpal.info."
}

variable "google_client_id" {
  type        = string
  description = "google client id for google auth (https://developers.google.com/identity/one-tap/web/guides/get-google-api-clientid)"
}

variable "secret_api_key" {
  type        = string
  description = "used to permit services to have superuser powers"
  default     = "set-me"
}

variable "secret_jwt_key" {
  type        = string
  description = "used to encrypt jwt tokens"
  default     = "set-me"
}

variable "secret_mongo_uri" {
  type        = string
  description = "fully qualified mongo uri (includes user and password) for connections to a mongodb instance backend (presumably external, e.g. mongodb.com)"
}

variable "site_domain_name" {
  type        = string
  description = "the public domain name for this site, e.g. dev.mentorpal.org"
}

variable "static_site_alias" {
  type          = string
  description   = "alias for static site that will serve video etc. By default, generates one based on site_domain_name"
  default       = ""
}

variable "static_cors_allowed_origins" {
  type          = list(string)
  description   = "list of cors allowed origins for static"
  default       = []
}

variable "vpc_cidr_block" {
  type        = string
  description = "cidr for the vpc, generally can leave the default unless there is conflict"
  default     = "172.16.0.0/16"
 }
