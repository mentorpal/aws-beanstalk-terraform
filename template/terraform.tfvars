# must be in AWS certificate manager:
aws_acm_certificate_domain = "mentorpal.org"

# e.g. us-east-1
aws_region = "us-east-1"

# usualy name as `aws_acm_certificate_domain` with . at the end
aws_route53_zone_name = "mentorpal.org"

# namespace to prefix all things your app
eb_env_namespace = "mentorpal"
eb_env_name      = "mentorpal"

site_domain_name = "mentorpal.org"
static_cors_allowed_origins = ["mentorpal.org", "*.mentorpal.org"]

enable_api_firewall_logging = true
enable_cdn_firewall_logging = false
