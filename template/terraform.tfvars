# must be in AWS certificate manager:
aws_acm_certificate_domain = "mentorpal.info"

# e.g. us-east-1
aws_region = "us-east-1"

# usualy name as `aws_acm_certificate_domain` with . at the end
aws_route53_zone_name = "mentorpal.info"

# namespace to prefix all things your app
eb_env_namespace = "mentorpal"
eb_env_name      = "mentorpal"
# name of stage, e.g 'test' or 'dev' or 'prod'
eb_env_stage = "qa"

site_domain_name = "qa.mentorpal.info"
static_cors_allowed_origins = ["mentorpal.info", "*.mentorpal.info"]

enable_api_firewall_logging = true
enable_cdn_firewall_logging = false
