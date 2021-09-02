data "aws_availability_zones" "available" {
}

locals {
  # TODO: slice/automate ONLY if not provided (we may need to specify for ECS/FARGATE)
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
}


locals {
  namespace = "${var.eb_env_namespace}-${var.eb_env_stage}-${var.eb_env_name}"
}
###
# Find a certificate for our domain that has status ISSUED
# NOTE that for now, this infra depends on managing certs INSIDE AWS/ACM
###
data "aws_acm_certificate" "default" {
  domain   = var.aws_acm_certificate_domain
  statuses = ["ISSUED"]
}


