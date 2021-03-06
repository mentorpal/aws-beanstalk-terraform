provider "aws" {
  region  = var.aws_region
}

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=tags/0.21.1"
  namespace  = var.eb_env_namespace
  stage      = var.eb_env_stage
  name       = var.eb_env_name
  attributes = var.eb_env_attributes
  tags       = var.eb_env_tags
  delimiter  = var.eb_env_delimiter
  cidr_block = var.vpc_cidr_block
}

module "subnets" {
  source               = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.39.0"
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

data "aws_elastic_beanstalk_hosted_zone" "current" {}

data "aws_elastic_beanstalk_solution_stack" "multi_docker" {
  most_recent = true
  name_regex = "^64bit Amazon Linux (.*) Multi-container Docker (.*)$"
}

locals {
  namespace = "${var.eb_env_namespace}-${var.eb_env_stage}-${var.eb_env_name}"
}

###
# all infra for transcribing mentor videos with py-transcribe-aws module
# (IAM, s3 bucket, keys, policies, etc)
###
module "transcribe_aws" {
    source                  = "git::https://github.com/ICTLearningSciences/py-transcribe-aws.git?ref=tags/1.4.0"
    transcribe_namespace    = local.namespace
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
  source = "git::https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn?ref=tags/0.69.0"
  namespace               = "static-${var.eb_env_namespace}"
  stage                   = var.eb_env_stage
  name                    = var.eb_env_name
  aliases                 = [local.static_alias]
  cors_allowed_origins    = local.static_cors_allowed_origins
  dns_alias_enabled = true
  parent_zone_name  = var.aws_route53_zone_name
  acm_certificate_arn = data.aws_acm_certificate.issued.arn
}


###
# the main elastic beanstalk env for this app
###
module "elastic_beanstalk_environment" {
  source                     = "git::https://github.com/cloudposse/terraform-aws-elastic-beanstalk-environment.git?ref=tags/0.39.1"
  namespace                  = var.eb_env_namespace
  stage                      = var.eb_env_stage
  name                       = var.eb_env_name
  attributes                 = var.eb_env_attributes
  tags                       = var.eb_env_tags
  delimiter                  = var.eb_env_delimiter
  description                = var.eb_env_description
  region                     = var.aws_region
  availability_zone_selector = var.eb_env_availability_zone_selector
  # NOTE: We would prefer for the DNS name 
  # of module.elastic_beanstalk_environment
  # to be staticly set via inputs,
  # but have been running into other/different problems
  # trying to get that to work 
  # (for one thing, permissions error anytime try to set
  # elastic_beanstalk_environment.dns_zone_id)
  # dns_zone_id                = data.aws_elastic_beanstalk_hosted_zone.current.id
  # dns_zone_id                = var.dns_zone_id
  wait_for_ready_timeout             = var.eb_env_wait_for_ready_timeout
  elastic_beanstalk_application_name = module.elastic_beanstalk_application.elastic_beanstalk_application_name
  environment_type                   = var.eb_env_environment_type
  loadbalancer_type                  = var.eb_env_loadbalancer_type
  loadbalancer_certificate_arn       = data.aws_acm_certificate.issued.arn
  loadbalancer_ssl_policy            = var.eb_env_loadbalancer_ssl_policy
  elb_scheme                         = var.eb_env_elb_scheme
  tier                               = "WebServer"
  version_label                      = var.eb_env_version_label
  force_destroy                      = var.eb_env_log_bucket_force_destroy

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

  vpc_id                  = module.vpc.vpc_id
  loadbalancer_subnets    = module.subnets.public_subnet_ids
  application_subnets     = module.subnets.private_subnet_ids
  allowed_security_groups = [
    module.vpc.vpc_default_security_group_id,
    module.efs.security_group_id
  ]
  # NOTE: will only work for direct ssh
  # if keypair exists and application_subnets above is public subnet
  keypair                 = var.eb_env_keypair    

  rolling_update_enabled  = var.eb_env_rolling_update_enabled
  rolling_update_type     = var.eb_env_rolling_update_type
  updating_min_in_service = var.eb_env_updating_min_in_service
  updating_max_batch      = var.eb_env_updating_max_batch

  healthcheck_url  = var.eb_env_healthcheck_url
  application_port = var.eb_env_application_port
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.multi_docker.name
  additional_settings = var.eb_env_additional_settings
  env_vars            = merge(
                          var.eb_env_env_vars,
                          {
                            API_SECRET=var.secret_api_key,
                            GOOGLE_CLIENT_ID=var.google_client_id,
                            JWT_SECRET=var.secret_jwt_key,
                            MONGO_URI=var.secret_mongo_uri,
                            TRANSCRIBE_MODULE_PATH=module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_MODULE_PATH,
                            TRANSCRIBE_AWS_ACCESS_KEY_ID=module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_AWS_ACCESS_KEY_ID,
                            TRANSCRIBE_AWS_REGION=var.aws_region,
                            TRANSCRIBE_AWS_SECRET_ACCESS_KEY=module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_AWS_SECRET_ACCESS_KEY,
                            TRANSCRIBE_AWS_S3_BUCKET_SOURCE=module.transcribe_aws.transcribe_env_vars.TRANSCRIBE_AWS_S3_BUCKET_SOURCE,
                            STATIC_AWS_ACCESS_KEY_ID        = aws_iam_access_key.static_upload_policy_access_key.id,
                            STATIC_AWS_SECRET_ACCESS_KEY    = aws_iam_access_key.static_upload_policy_access_key.secret,
                            STATIC_AWS_REGION               = var.aws_region,
                            STATIC_AWS_S3_BUCKET            = module.cdn_static.s3_bucket
                            STATIC_URL_BASE                        = "https://${local.static_alias}"
                          }
                        )

  extended_ec2_policy_document = data.aws_iam_policy_document.minimal_s3_permissions.json
  prefer_legacy_ssm_policy     = false
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
# Find a certificate for our domain that has status ISSUED
# NOTE that for now, this infra depends on managing certs INSIDE AWS/ACM
###
data "aws_acm_certificate" "issued" {
  domain   = var.aws_acm_certificate_domain
  statuses = ["ISSUED"]
}

data "aws_route53_zone" "main" {
  name = var.aws_route53_zone_name
}

# create dns record of type "A"
resource "aws_route53_record" "site_domain_name" {
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = var.site_domain_name
  type            = "A"
  allow_overwrite = true
  alias {
    name                   = module.elastic_beanstalk_environment.endpoint
    zone_id                = data.aws_elastic_beanstalk_hosted_zone.current.id
    evaluate_target_health = true
  }
}

###
# Shared network file system that will store trained models, etc.
# Using a network file system allows separate processes 
# to read/write a common set of files 
# (e.g. training writes models read by classifier api)
###
module "efs" {
  source             = "git::https://github.com/cloudposse/terraform-aws-efs.git?ref=tags/0.30.0"
  namespace          = var.eb_env_namespace
  stage              = var.eb_env_stage
  name               = var.eb_env_name
  region             = var.aws_region
  vpc_id             = module.vpc.vpc_id
  subnets            = module.subnets.private_subnet_ids
  security_groups    = [
    module.vpc.vpc_default_security_group_id,
    module.elastic_beanstalk_environment.security_group_id
  ]
}

# find the HTTP load-balancer listener, so we can redirect to HTTPS
data "aws_lb_listener" "http_listener" {
  load_balancer_arn = module.elastic_beanstalk_environment.load_balancers[0]
  port              = 80
}

# set the HTTP -> HTTPS redirect rule for any request matching site domain
resource "aws_lb_listener_rule" "redirect_http_to_https" {
  listener_arn = data.aws_lb_listener.http_listener.arn
  action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
  condition {
    host_header {
      values = [var.site_domain_name]
    }
  }
}



######
# IAM, policies, access key, etc. for CDN upload
######

locals {
  static_upload_policy_name = "${local.namespace}-static-policy"
  static_upload_user_name = "${local.namespace}-static-user"
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
