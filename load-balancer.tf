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
  listener_https_fixed_response = {
    content_type = "text/plain"
    message_body = "OK"
    status_code  = 200
  }
  context = module.this.context
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


###########################################################################
# NOTE: 
# This load-balancer rule redirects the / path to /chat
# We're doing this for now because we don't have a home page for mentorpal
# When we do get a home page, delete this rule
###########################################################################
resource "aws_lb_listener_rule" "redirect_root_to_chat" {
  listener_arn = module.alb.https_listener_arn
  action {
    type = "redirect"
    redirect {
      path = "/chat"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}
