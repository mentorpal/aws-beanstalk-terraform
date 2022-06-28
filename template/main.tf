provider "aws" {
  region = var.aws_region
}

module "mentorpal_beanstalk_deployment" {
  source                      = "git::https://github.com/mentorpal/aws-beanstalk-terraform?ref=tags/5.0.1"
  aws_acm_certificate_domain  = var.aws_acm_certificate_domain
  aws_region                  = var.aws_region
  aws_route53_zone_name       = var.aws_route53_zone_name
  eb_env_namespace            = var.eb_env_namespace
  eb_env_stage                = var.eb_env_stage
  site_domain_name            = var.site_domain_name
  static_cors_allowed_origins = var.static_cors_allowed_origins
  enable_api_firewall_logging = var.enable_api_firewall_logging
  enable_cdn_firewall_logging = var.enable_cdn_firewall_logging
  enable_content_backup       = true
  alert_topic_arn             = module.notify_slack.this_slack_topic_arn
}
