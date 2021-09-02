
########################################
# Application Load Balancer
########################################


data "aws_route53_zone" "main" {
  name = var.aws_route53_zone_name
}


module "alb" {
  source                                  = "cloudposse/alb/aws"
  version                                 = "0.35.3"
  alb_access_logs_s3_bucket_force_destroy = true
  vpc_id                                  = module.vpc.vpc_id
  ip_address_type                         = "ipv4"
  subnet_ids                              = module.subnets.public_subnet_ids
  security_group_ids                      = [module.vpc.vpc_default_security_group_id]
  http_redirect                           = true
  https_enabled                           = true
  http_ingress_cidr_blocks                = ["0.0.0.0/0"]
  https_ingress_cidr_blocks               = ["0.0.0.0/0"]
  certificate_arn                         = data.aws_acm_certificate.default.arn
  // health_check_interval                   = 60
  // # need to finish the 'status' service and then change the health_check_path to '/status'
  // health_check_path = "/admin"
  listener_https_fixed_response = {
    content_type = "text/plain"
    message_body = "OK"
    status_code  = 200
  }
  context = module.this.context
}


output "main_zone_id" {
  description = "test this"
  value       = data.aws_route53_zone.main.zone_id
}


output "site_domain_name" {
  description = "test this"
  value       = var.site_domain_name
}

output "alb_dns_name" {
  description = "test this"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "test this"
  value       = module.alb.alb_zone_id
}

# create dns record of type "A"
resource "aws_route53_record" "site_domain_name" {
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = var.site_domain_name
  type            = "A"
  allow_overwrite = true
  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}