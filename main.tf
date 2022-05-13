provider "aws" {
  region = var.aws_region
}

# to work with CLOUDFRONT firewall region must be us-east-1
provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "aws_elastic_beanstalk_hosted_zone" "current" {}

data "aws_elastic_beanstalk_solution_stack" "multi_docker" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux (.*) Multi-container Docker (.*)$"
}

###
# Find a certificate for our domain that has status ISSUED
# NOTE that for now, this infra depends on managing certs INSIDE AWS/ACM
###
data "aws_acm_certificate" "localregion" {
  domain   = var.aws_acm_certificate_domain
  statuses = ["ISSUED"]
}

data "aws_acm_certificate" "cdn" {
  provider = aws.us-east-1
  domain   = var.aws_acm_certificate_domain
  statuses = ["ISSUED"]
}

locals {
  namespace = "${var.eb_env_namespace}-${var.eb_env_stage}-${var.eb_env_name}"
  alb_url   = "eb-${var.aws_region}-${var.eb_env_stage}.${var.aws_acm_certificate_domain}"
}

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=tags/0.25.0"
  namespace  = var.eb_env_namespace
  stage      = var.eb_env_stage
  name       = var.eb_env_name
  attributes = var.eb_env_attributes
  tags       = var.eb_env_tags
  delimiter  = var.eb_env_delimiter
  cidr_block = var.vpc_cidr_block
}

module "subnets" {
  source               = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.39.3"
  availability_zones   = var.aws_availability_zones
  namespace            = var.eb_env_namespace
  stage                = var.eb_env_stage
  name                 = var.eb_env_name
  attributes           = var.eb_env_attributes
  tags                 = var.eb_env_tags
  delimiter            = var.eb_env_delimiter
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = true
  nat_instance_enabled = false
}

module "elastic_beanstalk_application" {
  source      = "git::https://github.com/cloudposse/terraform-aws-elastic-beanstalk-application.git?ref=tags/0.11.0"
  namespace   = var.eb_env_namespace
  stage       = var.eb_env_stage
  name        = var.eb_env_name
  attributes  = var.eb_env_attributes
  tags        = var.eb_env_tags
  delimiter   = var.eb_env_delimiter
  description = var.eb_env_description
}

###
# all infra for transcribing mentor videos with py-transcribe-aws module
# (IAM, s3 bucket, keys, policies, etc)
###
module "transcribe_aws" {
  source               = "git::https://github.com/ICTLearningSciences/py-transcribe-aws.git?ref=tags/1.4.0"
  transcribe_namespace = local.namespace
}

resource "aws_ssm_parameter" "transcribe_access_key" {
  name        = "/${var.eb_env_name}/${var.eb_env_stage}/transcribe/access_key"
  description = "transcribe access key id"
  type        = "SecureString"
  value       = module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_AWS_ACCESS_KEY_ID
}

resource "aws_ssm_parameter" "transcribe_secret_key" {
  name        = "/${var.eb_env_name}/${var.eb_env_stage}/transcribe/secret_key"
  description = "transcribe secret access key"
  type        = "SecureString"
  value       = module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_AWS_SECRET_ACCESS_KEY
}

resource "aws_ssm_parameter" "transcribe_s3_bucket" {
  name        = "/${var.eb_env_name}/${var.eb_env_stage}/transcribe/s3_bucket"
  description = "transcribe s3 bucket source"
  type        = "SecureString"
  value       = module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_AWS_S3_BUCKET_SOURCE
}

locals {
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
      "*.${var.site_domain_name}"
    ]
  )
}

###
# the cdn that serves videos from an s3 bucket, e.g. static.mentorpal.org
###

module "cdn_static" {
  source               = "git::https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn?ref=tags/0.74.0"
  namespace            = "static-${var.eb_env_namespace}"
  stage                = var.eb_env_stage
  name                 = var.eb_env_name
  aliases              = [local.static_alias]
  cors_allowed_origins = local.static_cors_allowed_origins
  dns_alias_enabled    = true
  parent_zone_name     = var.aws_route53_zone_name
  acm_certificate_arn  = data.aws_acm_certificate.cdn.arn
  # bugfix: required for video playback after upload
  forward_query_string    = true
  query_string_cache_keys = ["v"]
}

# export s3 arn so serverless can pick it up to configure iam policies
resource "aws_ssm_parameter" "cdn_static_param" {
  name        = "/${var.eb_env_name}/${var.eb_env_stage}/s3_static_arn"
  description = "S3 static bucket ARN"
  type        = "SecureString"
  value       = module.cdn_static.s3_bucket_arn
}


###
# the main elastic beanstalk env for this app
###
module "elastic_beanstalk_environment" {
  source                             = "git::https://github.com/cloudposse/terraform-aws-elastic-beanstalk-environment.git?ref=tags/0.40.0"
  namespace                          = var.eb_env_namespace
  stage                              = var.eb_env_stage
  name                               = var.eb_env_name
  attributes                         = var.eb_env_attributes
  tags                               = var.eb_env_tags
  delimiter                          = var.eb_env_delimiter
  description                        = var.eb_env_description
  region                             = var.aws_region
  availability_zone_selector         = var.eb_env_availability_zone_selector
  wait_for_ready_timeout             = var.eb_env_wait_for_ready_timeout
  elastic_beanstalk_application_name = module.elastic_beanstalk_application.elastic_beanstalk_application_name
  environment_type                   = var.eb_env_environment_type
  loadbalancer_type                  = var.eb_env_loadbalancer_type
  loadbalancer_ssl_policy            = var.eb_env_loadbalancer_ssl_policy
  loadbalancer_certificate_arn       = data.aws_acm_certificate.localregion.arn

  elb_scheme    = var.eb_env_elb_scheme
  tier          = "WebServer"
  version_label = var.eb_env_version_label
  force_destroy = var.eb_env_log_bucket_force_destroy

  enable_stream_logs                   = var.eb_env_enable_stream_logs
  logs_delete_on_terminate             = var.eb_env_logs_delete_on_terminate
  logs_retention_in_days               = var.eb_env_logs_retention_in_days
  health_streaming_enabled             = var.eb_env_health_streaming_enabled
  health_streaming_delete_on_terminate = var.eb_env_health_streaming_delete_on_terminate
  health_streaming_retention_in_days   = var.eb_env_health_streaming_retention_in_days

  instance_type    = var.eb_env_instance_type
  root_volume_size = var.eb_env_root_volume_size
  root_volume_type = var.eb_env_root_volume_type

  autoscale_min             = var.eb_env_autoscale_min
  autoscale_max             = var.eb_env_autoscale_max
  autoscale_measure_name    = var.eb_env_autoscale_measure_name
  autoscale_statistic       = var.eb_env_autoscale_statistic
  autoscale_unit            = var.eb_env_autoscale_unit
  autoscale_lower_bound     = var.eb_env_autoscale_lower_bound
  autoscale_lower_increment = var.eb_env_autoscale_lower_increment
  autoscale_upper_bound     = var.eb_env_autoscale_upper_bound
  autoscale_upper_increment = var.eb_env_autoscale_upper_increment

  vpc_id               = module.vpc.vpc_id
  loadbalancer_subnets = module.subnets.public_subnet_ids
  application_subnets  = module.subnets.private_subnet_ids
  allowed_security_groups = [
    module.vpc.vpc_default_security_group_id,
    module.efs.security_group_id
  ]
  # NOTE: will only work for direct ssh
  # if keypair exists and application_subnets above is public subnet
  keypair = var.eb_env_keypair

  rolling_update_enabled  = var.eb_env_rolling_update_enabled
  rolling_update_type     = var.eb_env_rolling_update_type
  updating_min_in_service = var.eb_env_updating_min_in_service
  updating_max_batch      = var.eb_env_updating_max_batch

  healthcheck_url     = var.eb_env_healthcheck_url
  application_port    = var.eb_env_application_port
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.multi_docker.name
  additional_settings = var.eb_env_additional_settings
  env_vars = merge(
    var.eb_env_env_vars,
    {
      API_SECRET                       = var.secret_api_key,
      GOOGLE_CLIENT_ID                 = var.google_client_id,
      JWT_SECRET                       = var.secret_jwt_key,
      MONGO_URI                        = var.secret_mongo_uri,
      STATIC_AWS_ACCESS_KEY_ID         = aws_iam_access_key.static_upload_policy_access_key.id,
      STATIC_AWS_SECRET_ACCESS_KEY     = aws_iam_access_key.static_upload_policy_access_key.secret,
      STATIC_AWS_REGION                = var.aws_region,
      STATIC_AWS_S3_BUCKET             = module.cdn_static.s3_bucket
      STATIC_URL_BASE                  = "https://${local.static_alias}"
      TRANSCRIBE_MODULE_PATH           = module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_MODULE_PATH,
      TRANSCRIBE_AWS_ACCESS_KEY_ID     = module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_AWS_ACCESS_KEY_ID,
      TRANSCRIBE_AWS_REGION            = var.aws_region,
      TRANSCRIBE_AWS_SECRET_ACCESS_KEY = module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_AWS_SECRET_ACCESS_KEY,
      TRANSCRIBE_AWS_S3_BUCKET_SOURCE  = module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_AWS_S3_BUCKET_SOURCE,
    }
  )

  extended_ec2_policy_document = data.aws_iam_policy_document.minimal_s3_permissions.json
  prefer_legacy_ssm_policy     = false
}


data "aws_route53_zone" "main" {
  name = var.aws_route53_zone_name
}

# create dns record of type "A"
resource "aws_route53_record" "site_domain_name" {
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = local.alb_url
  type            = "A"
  allow_overwrite = true
  alias {
    name                   = module.elastic_beanstalk_environment.endpoint
    zone_id                = data.aws_elastic_beanstalk_hosted_zone.current.id
    evaluate_target_health = true
  }
}

resource "aws_ssm_parameter" "alb_url_param" {
  name        = "/${var.eb_env_name}/${var.eb_env_stage}/alb_url"
  description = "Load Balancer url"
  type        = "String"
  # value       = module.elastic_beanstalk_environment.endpoint
  value = local.alb_url
}


#####
# Firewall
# 
#####

module "firewall" {
  source           = "./modules/waf"
  aws_region       = var.aws_region
  environment      = var.eb_env_stage
  rate_limit       = 1000
  tags             = var.eb_env_tags
}

######
# CloudFront distro in front of Beanstalk
#

# the default policy does not include query strings as cache keys
resource "aws_cloudfront_cache_policy" "cdn_beanstalk_cache" {
  name        = "${local.namespace}-cdn-cache-policy"
  default_ttl = 300 # 5min
  min_ttl     = 0
  max_ttl     = 86400 # 1 day

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

resource "aws_cloudfront_origin_request_policy" "cdn_beanstalk_origin_policy" {
  name = "${local.namespace}-cdn-origin-policy"

  cookies_config {
    cookie_behavior = "all"
  }
  headers_config {
    header_behavior = "allViewer"
  }
  query_strings_config {
    query_string_behavior = "all"
  }
}

module "cdn_beanstalk" {
  source               = "git::https://github.com/cloudposse/terraform-aws-cloudfront-cdn.git?ref=tags/0.24.1"
  acm_certificate_arn  = data.aws_acm_certificate.localregion.arn
  aliases              = [var.site_domain_name]
  allowed_methods      = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
  cache_policy_id      = resource.aws_cloudfront_cache_policy.cdn_beanstalk_cache.id
  compress             = true
  cached_methods       = ["GET", "HEAD"]
  forward_query_string = true
  forward_cookies      = "none"
  is_ipv6_enabled      = true
  # logging config, disable because we have from the service itself
  logging_enabled                 = false
  log_expiration_days             = 30
  name                            = var.eb_env_name
  namespace                       = var.eb_env_namespace
  environment                     = var.aws_region
  # origin_domain_name              = module.elastic_beanstalk_environment.endpoint
  origin_domain_name              = local.alb_url
  origin_protocol_policy          = "https-only"
  origin_request_policy_id        = resource.aws_cloudfront_origin_request_policy.cdn_beanstalk_origin_policy.id
  origin_ssl_protocols            = ["TLSv1.2"]
  parent_zone_name                = var.aws_route53_zone_name
  price_class                     = "PriceClass_All"
  stage                           = var.eb_env_stage
  viewer_protocol_policy          = "https-only"
  viewer_minimum_protocol_version = "TLSv1.2_2019"
  web_acl_id                      = module.firewall.wafv2_webacl_arn
}


data "aws_lb_listener" "http_listener" {
  load_balancer_arn = module.elastic_beanstalk_environment.load_balancers[0]
  port              = 80
}

data "aws_iam_policy_document" "minimal_s3_permissions" {
  statement {
    sid = "AllowS3OperationsOnElasticBeanstalkBuckets"
    actions = [
      "s3:ListAllMyBuckets",
      "s3:GetBucketLocation"
    ]
    resources = ["*"]
  }
}

###
# Shared network file system that will store trained models, etc.
# Using a network file system allows separate processes 
# to read/write a common set of files 
# (e.g. training writes models read by classifier api)
###
module "efs" {
  source    = "git::https://github.com/cloudposse/terraform-aws-efs.git?ref=tags/0.30.1"
  namespace = var.eb_env_namespace
  stage     = var.eb_env_stage
  name      = var.eb_env_name
  region    = var.aws_region
  vpc_id    = module.vpc.vpc_id
  subnets   = module.subnets.private_subnet_ids
  security_groups = [
    module.vpc.vpc_default_security_group_id,
    module.elastic_beanstalk_environment.security_group_id
  ]
}

######
# Cloudwatch alarms
# - https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-cloudwatch-metrics.html
######

resource "aws_cloudwatch_metric_alarm" "unhealthy_host_count" {
  count                     = var.enable_alarms ? 1 : 0
  alarm_description         = "ALB unhealthy host count (>= 1)."
  alarm_name                = "${local.namespace}-alb-unhealthy-host-count"
  namespace                 = "AWS/ApplicationELB"
  metric_name               = "UnHealthyHostCount"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  period                    = 300
  statistic                 = "Average"
  unit                      = "Count"
  threshold                 = 1
  treat_missing_data        = "notBreaching"
  actions_enabled           = true
  alarm_actions             = ["${var.alert_topic_arn}"]
  ok_actions                = ["${var.alert_topic_arn}"]
  insufficient_data_actions = []
  dimensions = {
    # alarm requires ARN suffix: "arn:aws:elasticloadbalancing:<region>:<account>:loadbalancer/<suffix>"
    LoadBalancer = regex(".+loadbalancer/(.*)$", module.elastic_beanstalk_environment.load_balancers[0])[0]
    # get the target group arn suffix, this is ugly, but couldn't find another way:
    TargetGroup = regex(".+:(targetgroup/.*)$", data.aws_lb_listener.http_listener.default_action[0].target_group_arn)[0]
  }
}

# LCU is defined on 4 dimensions and takes the highest one among them:
# - 25 new connections per second.
# - 3,000 active connections per minute.
# - 1 GB per hour for EC2 targets
# - 1,000 rule evaluations per second
resource "aws_cloudwatch_metric_alarm" "consumed_lcus" {
  count                     = var.enable_alarms ? 1 : 0
  alarm_description         = "ALB capacity units above the threshold (>= 1)."
  alarm_name                = "${local.namespace}-alb-consumed-lcus"
  namespace                 = "AWS/ApplicationELB"
  metric_name               = "ConsumedLCUs"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  period                    = 300
  unit                      = "Count"
  statistic                 = "Average"
  threshold                 = 1
  treat_missing_data        = "notBreaching"
  actions_enabled           = true
  alarm_actions             = ["${var.alert_topic_arn}"]
  ok_actions                = ["${var.alert_topic_arn}"]
  insufficient_data_actions = []
  dimensions = {
    LoadBalancer = regex(".+loadbalancer/(.*)$", module.elastic_beanstalk_environment.load_balancers[0])[0]
  }
}

resource "aws_cloudwatch_metric_alarm" "httpcode_target_5xx_count" {
  count                     = var.enable_alarms ? 1 : 0
  alarm_description         = "Beanstalk HTTP 5xx errors exceeded threshold (>= 1)."
  alarm_name                = "${local.namespace}-metric-alb-httpcode-5xx-count"
  namespace                 = "AWS/ApplicationELB"
  metric_name               = "HTTPCode_Target_5XX_Count"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  period                    = 300
  statistic                 = "Sum"
  unit                      = "Count"
  threshold                 = 1
  treat_missing_data        = "notBreaching"
  actions_enabled           = true
  alarm_actions             = ["${var.alert_topic_arn}"]
  ok_actions                = ["${var.alert_topic_arn}"]
  insufficient_data_actions = []
  dimensions = {
    LoadBalancer = regex(".+loadbalancer/(.*)$", module.elastic_beanstalk_environment.load_balancers[0])[0]
  }
}

resource "aws_cloudwatch_metric_alarm" "httpcode_elb_5xx_count" {
  count                     = var.enable_alarms ? 1 : 0
  alarm_description         = "Application load balancer httpcode 5xx count>(>= 1)."
  alarm_name                = "${local.namespace}-metric-alb-elb-httpcode-5xx-count"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  namespace                 = "AWS/ApplicationELB"
  metric_name               = "HTTPCode_ELB_5XX_Count"
  period                    = 300
  statistic                 = "Sum"
  unit                      = "Count"
  threshold                 = 1
  actions_enabled           = true
  treat_missing_data        = "notBreaching"
  alarm_actions             = ["${var.alert_topic_arn}"]
  ok_actions                = ["${var.alert_topic_arn}"]
  insufficient_data_actions = []
  dimensions = {
    LoadBalancer = regex(".+loadbalancer/(.*)$", module.elastic_beanstalk_environment.load_balancers[0])[0]
  }
}

resource "aws_cloudwatch_metric_alarm" "target_response_time" {
  count = var.enable_alarms ? 1 : 0

  alarm_name                = "${local.namespace}-alb-target-response-time"
  alarm_description         = "ALB target response time."
  metric_name               = "TargetResponseTime"
  namespace                 = "AWS/ApplicationELB"
  statistic                 = "Maximum"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  period                    = 300
  threshold                 = 10 # in seconds
  treat_missing_data        = "notBreaching"
  alarm_actions             = ["${var.alert_topic_arn}"]
  ok_actions                = []
  insufficient_data_actions = []
  dimensions = {
    LoadBalancer = regex(".+loadbalancer/(.*)$", module.elastic_beanstalk_environment.load_balancers[0])[0]
  }
}

resource "aws_cloudwatch_metric_alarm" "response_time_p90" {
  count = var.enable_alarms ? 1 : 0

  alarm_name                = "${local.namespace}-alb-P90-target-response-time"
  alarm_description         = "P90 ALB target response time (fastest response among top 10% slowest responses)."
  metric_name               = "TargetResponseTime"
  namespace                 = "AWS/ApplicationELB"
  extended_statistic        = "p90"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  period                    = 3600
  threshold                 = 5 # in seconds
  treat_missing_data        = "notBreaching"
  alarm_actions             = ["${var.alert_topic_arn}"]
  ok_actions                = []
  insufficient_data_actions = []
  dimensions = {
    LoadBalancer = regex(".+loadbalancer/(.*)$", module.elastic_beanstalk_environment.load_balancers[0])[0]
  }
}

######
# IAM, policies, access key, etc. for CDN upload
######

locals {
  static_upload_policy_name = "${local.namespace}-static-policy"
  static_upload_user_name   = "${local.namespace}-static-user"
}

data "aws_iam_policy_document" "static_upload_policy" {
  statement {
    sid = "1"
    actions = [
      "s3:*",
    ]
    resources = [
      "${module.cdn_static.s3_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_policy" "static_upload_policy" {
  name   = local.static_upload_policy_name
  path   = "/"
  policy = data.aws_iam_policy_document.static_upload_policy.json
}

resource "aws_iam_user" "static_upload_user" {
  name = local.static_upload_user_name
}

resource "aws_iam_user_policy_attachment" "static_upload_policy_attachment" {
  user       = aws_iam_user.static_upload_user.name
  policy_arn = aws_iam_policy.static_upload_policy.arn
}

resource "aws_iam_access_key" "static_upload_policy_access_key" {
  user = aws_iam_user.static_upload_user.name
}

# SSM parameter store access:

data "aws_iam_policy_document" "read_parameter_store_doc" {
  statement {
    actions   = ["ssm:GetParameters", "ssm:GetParameter", "ssm:GetParameterHistory", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.eb_env_name}/*"]
  }
}
resource "aws_iam_policy" "ssm_read_access" {
  name   = "${local.namespace}-ssm-read-policy"
  policy = data.aws_iam_policy_document.read_parameter_store_doc.json
}

resource "aws_iam_user_policy_attachment" "ssm_access_by_user" {
  user       = aws_iam_user.static_upload_user.name
  policy_arn = aws_iam_policy.ssm_read_access.arn
}
