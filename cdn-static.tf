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


# NOTE: certificates for CloudFront CDN can ONLY be in region us-east-1 
data "aws_acm_certificate" "cdn" {
  provider = aws.us-east-1
  domain   = var.aws_acm_certificate_domain
  statuses = ["ISSUED"]
}


###
# STATIC CDN for videos
# the cdn that serves videos from an s3 bucket, e.g. static.mentorpal.org
###
module "cdn_static" {
  source  = "cloudposse/cloudfront-s3-cdn/aws"
  version = "0.75.0"
  // source               = "git::https://github.com/cloudposse/terraform-aws-cloudfront-s3-cdn?ref=tags/0.74.0"
  // namespace            = "static-${local.namespace}"
  // stage                = var.eb_env_stage
  // name                 = var.eb_env_name
  aliases              = [local.static_alias]
  cors_allowed_origins = local.static_cors_allowed_origins
  dns_alias_enabled    = true
  parent_zone_name     = var.aws_route53_zone_name
  acm_certificate_arn  = data.aws_acm_certificate.cdn.arn
  context              = module.this.context
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