provider "aws" {
  region = var.aws_region
}

module "mentorpal_beanstalk_deployment" {
  source                      = "./.."
  aws_acm_certificate_domain  = var.aws_acm_certificate_domain
  aws_region                  = var.aws_region
  aws_route53_zone_name       = var.aws_route53_zone_name
  eb_env_namespace            = var.eb_env_namespace
  site_domain_name            = var.site_domain_name
  static_cors_allowed_origins = var.static_cors_allowed_origins
  enable_api_firewall_logging = var.enable_api_firewall_logging
  enable_cdn_firewall_logging = var.enable_cdn_firewall_logging
  enable_content_backup       = true
  alert_topic_arn             = module.notify_slack.this_slack_topic_arn
}

module "notify_slack" {
  source  = "terraform-aws-modules/notify-slack/aws"
  version = "~> 4.0"

  sns_topic_name = "slack-alerts-${var.eb_env_namespace}"

  lambda_function_name = "notify-slack-${var.eb_env_namespace}"

  slack_webhook_url = var.cloudwatch_slack_webhook
  slack_channel     = "ls-alerts-prod"
  slack_username    = "uscictlsalerts"
}

resource "aws_ssm_parameter" "sns_alert_topic_arn" {
  name        = "/${var.eb_env_name}/shared/sns_alert_topic_arn"
  description = "Slack alert topic"
  type        = "String"
  value       = module.notify_slack.this_slack_topic_arn
}
