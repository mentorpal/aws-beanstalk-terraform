provider "aws" {
  region = var.aws_region
}

# some resources must be created in N.Virginia
provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

###
# Find a certificate for our domain that has status ISSUED
# NOTE that for now, this infra depends on managing certs INSIDE AWS/ACM
###
data "aws_acm_certificate" "cdn" {
  provider = aws.us-east-1
  domain   = var.aws_acm_certificate_domain
  statuses = ["ISSUED"]
}

locals {
  namespace = "${var.eb_env_namespace}-${var.eb_env_name}"

  static_alias = (
    var.static_site_alias != ""
    ? var.static_site_alias
    : length(split(".", var.site_domain_name)) > 2
    ? "static-${var.site_domain_name}"
    : "static.${var.site_domain_name}"
  )

  static_cors_allowed_origins = (
    length(var.static_cors_allowed_origins) != 0
    ? var.static_cors_allowed_origins
    : [
      var.site_domain_name,
      "*.${var.site_domain_name}",
      "https://${var.site_domain_name}",
      "https://*.${var.site_domain_name}",
      "https://static.${var.site_domain_name}",
    ]
  )

  static_page_asset_aliases = [var.site_domain_name, "*.${var.site_domain_name}"] # adds support for organizations subdomains
}

###
# the cdn that serves videos from an s3 bucket, e.g. static.mentorpal.org
###

module "cdn_static" {
  source               = "git::https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn?ref=tags/0.74.0"
  namespace            = "static-${var.eb_env_namespace}"
  name                 = var.eb_env_name
  aliases              = [local.static_alias]
  cors_allowed_origins = local.static_cors_allowed_origins
  dns_alias_enabled    = true
  versioning_enabled   = true
  parent_zone_name     = var.aws_route53_zone_name
  acm_certificate_arn  = data.aws_acm_certificate.cdn.arn
  # bugfix: required for video playback after upload
  forward_query_string    = true
  query_string_cache_keys = ["v"]
}

# export s3 arn so serverless can pick it up to configure iam policies
resource "aws_ssm_parameter" "cdn_content_param" {
  name        = "/${var.eb_env_name}/s3_content_arn"
  description = "S3 content (videos, images) bucket ARN"
  type        = "SecureString"
  value       = module.cdn_static.s3_bucket_arn
  tags        = var.eb_env_tags
}

# TODO remove
resource "aws_ssm_parameter" "cdn_content_param_deprecated" {
  name        = "/${var.eb_env_name}/s3_static_arn"
  description = "S3 content (videos, images) bucket ARN"
  type        = "SecureString"
  value       = module.cdn_static.s3_bucket_arn
  tags        = var.eb_env_tags
}

# Cleanup old versions to avoid unnecessary costs.
# Must have bucket versioning enabled for this to work!
resource "aws_s3_bucket_lifecycle_configuration" "content_bucket_version_expire_policy" {
  bucket = module.cdn_static.s3_bucket

  rule {
    id     = "config"
    status = "Enabled"

    filter {
      # all objects
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

module "content_backup" {
  count  = var.enable_content_backup ? 1 : 0
  source = "git::https://github.com/mentorpal/terraform-modules//modules/backup?ref=tags/v1.5.1"
  name   = "${var.eb_env_name}-s3-backup"

  resources = [
    module.cdn_static.s3_bucket_arn
  ]

  enable_notifications = true
  alert_topic_arn      = var.alert_topic_arn

  tags = var.eb_env_tags
}

#####
# Firewall
# 
#####
module "cdn_firewall" {
  source     = "git::https://github.com/mentorpal/terraform-modules//modules/api-waf?ref=tags/v1.6.0"
  name       = "${var.eb_env_name}-cdn"
  scope      = "CLOUDFRONT"
  rate_limit = 1000


  # cloudfront waf must be in N.Virginia
  aws_region = "us-east-1"
  providers = {
    aws = aws.us-east-1
  }

  disable_bot_protection_for_amazon_ips = false
  excluded_bot_rules = [
    "CategorySocialMedia", # slack
    "CategorySearchEngine" # google bot
  ]
  excluded_common_rules = [
    "SizeRestrictions_BODY",  # 8kb is not enough
    "CrossSiteScripting_BODY" # flags legit image upload attempts
  ]
  enable_logging = var.enable_cdn_firewall_logging
  tags           = var.eb_env_tags
}

module "api_firewall" {
  source     = "git::https://github.com/mentorpal/terraform-modules//modules/api-waf?ref=tags/1.6.18"
  name       = "${var.eb_env_name}-api"
  scope      = "REGIONAL"
  rate_limit = 1000
  secret_header_name = var.secret_header_name
  secret_header_value = var.secret_header_value
  allowed_origins = var.allowed_origins
  enable_ip_and_origin_whitelisting = true

  excluded_bot_rules = [
    "CategoryMonitoring"
  ]
  excluded_common_rules = [
    "SizeRestrictions_BODY",  # 8kb is not enough
    "CrossSiteScripting_BODY" # flags legit image upload attempts
  ]
  enable_logging = var.enable_api_firewall_logging
  aws_region     = var.aws_region
  tags           = var.eb_env_tags
}

resource "aws_ssm_parameter" "api_firewall_ssm" {
  name  = "/${var.eb_env_name}/api_firewall_arn"
  type  = "String"
  value = module.api_firewall.wafv2_webacl_arn
  tags  = var.eb_env_tags
}

######
# CloudFront distro in front of s3
#

# the default policy does not include query strings as cache keys
resource "aws_cloudfront_cache_policy" "cdn_s3_cache" {
  name        = "${local.namespace}-cdn-s3-origin-cache-policy"
  min_ttl     = 0
  max_ttl     = 31536000 # 1yr
  default_ttl = 2592000  # 1 month

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_origin_request_policy" "cdn_s3_request" {
  name = "${local.namespace}-cdn-s3-origin-request-policy"

  cookies_config {
    cookie_behavior = "none"
  }
  headers_config {
    header_behavior = "none"
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_function
resource "aws_cloudfront_function" "cf_fn_origin_root" {
  # Note this is not a lambda function, but a CloudFront Function!
  name    = "${local.namespace}-cffn-origin"
  runtime = "cloudfront-js-1.0"
  comment = "Rewrites root s3 bucket requests to index.html for all apps (home, chat, admin)"
  publish = true
  code    = file("${path.module}/scripts/mentorpal-rewrite-default-index-s3-origin.js")
}

# fronts just an s3 bucket with static assets (javascript, css, ...) for frontend apps hosting
module "cdn_static_assets" {
  source                             = "git::https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn.git?ref=tags/0.82.4"
  acm_certificate_arn                = data.aws_acm_certificate.cdn.arn
  aliases                            = local.static_page_asset_aliases
  allowed_methods                    = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
  block_origin_public_access_enabled = true # so only CDN can access it
  # having a default cache policy made the apply fail:
  # cache_policy_id                   = resource.aws_cloudfront_cache_policy.cdn_s3_cache.id
  # origin_request_policy_id          = resource.aws_cloudfront_cache_policy.cdn_s3_request.id
  cached_methods                    = ["GET", "HEAD"]
  cloudfront_access_logging_enabled = false
  compress                          = true

  default_root_object = "/home/index.html"
  dns_alias_enabled   = true
  environment         = var.aws_region

  # cookies are used in graphql right? but seems to work with "none":
  forward_cookies = "none"

  custom_error_response = var.not_found_error_response_path != "" ? [
    {
      error_caching_min_ttl = 10
      error_code = 404
      response_code = 200
      response_page_path = var.not_found_error_response_path
    },
  ] : []

  # from the docs: "Amazon S3 returns this index document when requests are made to the root domain or any of the subfolders"
  # if this is the case then aws_lambda_function.cf_fn_origin_root is not required
  index_document      = "index.html"
  ipv6_enabled        = true
  log_expiration_days = 30
  name                = var.eb_env_name
  namespace           = var.eb_env_namespace

  ordered_cache = [
    {
      target_origin_id                  = "" # default s3 bucket
      path_pattern                      = "*"
      viewer_protocol_policy            = "redirect-to-https"
      min_ttl                           = 0
      default_ttl                       = 2592000  # 1 month
      max_ttl                           = 31536000 # 1yr
      forward_query_string              = false
      forward_cookies                   = "none"
      forward_cookies_whitelisted_names = []

      viewer_protocol_policy      = "redirect-to-https"
      cached_methods              = ["GET", "HEAD"]
      allowed_methods             = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
      compress                    = true
      forward_header_values       = []
      forward_query_string        = false
      cache_policy_id             = resource.aws_cloudfront_cache_policy.cdn_s3_cache.id
      origin_request_policy_id    = resource.aws_cloudfront_origin_request_policy.cdn_s3_request.id
      lambda_function_association = []
      trusted_signers             = []
      trusted_key_groups          = []
      response_headers_policy_id  = ""
      function_association = [{
        # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#function-association
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.cf_fn_origin_root.arn
      }]
    }
  ]

  # comment out to create a new bucket:
  # origin_bucket	= ""
  origin_force_destroy = true
  parent_zone_name     = var.aws_route53_zone_name
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PriceClass.html
  price_class = "PriceClass_100"
  # this are artifacts generated from github code, no need to version them:
  versioning_enabled     = true # test backup
  viewer_protocol_policy = "redirect-to-https"
  web_acl_id             = module.cdn_firewall.wafv2_webacl_arn
}

# export to SSM so cicd can be configured for deployment

# cicd pipeline runs in us-east-1 so its easier to have them too in the same region
resource "aws_ssm_parameter" "cdn_id" {
  name     = "/${var.eb_env_name}/CLOUDFRONT_DISTRIBUTION_ID"
  type     = "String"
  value    = module.cdn_static_assets.cf_id
  provider = aws.us-east-1
  tags     = var.eb_env_tags
}

resource "aws_ssm_parameter" "cdn_s3_websites_arn" {
  name        = "/${var.eb_env_name}/s3-websites/ARN"
  description = "Bucket that stores frontend apps"
  type        = "String"
  value       = module.cdn_static_assets.s3_bucket_arn
  provider    = aws.us-east-1
  tags        = var.eb_env_tags
}

resource "aws_ssm_parameter" "cdn_s3_websites_name" {
  name        = "/${var.eb_env_name}/s3-websites/NAME"
  description = "Bucket that stores frontend apps"
  type        = "String"
  value       = module.cdn_static_assets.s3_bucket
  provider    = aws.us-east-1
  tags        = var.eb_env_tags
}
