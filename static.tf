
// variable "static_namespace" {
//   type          = string
//   description   = "used to prefix resource names"
// }

variable "static_s3_bucket_name" {
  type          = string
  description   = "bucket where static content is uploaded for cloudfront"
  default       = ""
}

variable "static_site_alias" {
  type          = string
  description   = "bucket where static content is uploaded for cloudfront"
  default       = ""
}

locals {
  static_s3_bucket_name = var.static_s3_bucket_name != "" ? var.static_s3_bucket_name : "${local.namespace}-static"
  static_site_alias = (
    var.static_site_alias != "" 
    ? var.static_site_alias
    : length(split(".", var.site_domain_name)) > 2 
    ? "video-${var.site_domain_name}"
    : "video.${var.site_domain_name}"
  )
  s3_origin_id = "${local.namespace}-static-s3-origin-id"
}

resource "aws_s3_bucket" "static" {
  bucket          = local.static_s3_bucket_name
  acl             = "private"
  force_destroy   = true
}

resource "aws_cloudfront_origin_access_identity" "static" {
  comment = "user for s3 bucket"
}

data "aws_iam_policy_document" "static" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.static.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id
  policy = data.aws_iam_policy_document.static.json
}

// data "aws_arn" "static_iam" {
//   arn = aws_cloudfront_origin_access_identity.static.iam_arn
// }


// resource "aws_iam_user_policy_attachment" "static_policy_attachment" {
//   user       = aws_cloudfront_origin_access_identity.static.iam_arn
//   policy_arn = aws_s3_bucket_policy.static.arn
// }


resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.static.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "serves static video content"
  default_root_object = "index.html"

  // logging_config {
  //   include_cookies = false
  //   bucket          = "mylogs.s3.amazonaws.com"
  //   prefix          = "myprefix"
  // }

  aliases = [local.static_site_alias]
  restrictions {
    geo_restriction {
      restriction_type= "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/videos/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    // compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  // ordered_cache_behavior {
  //   path_pattern     = "/content/*"
  //   allowed_methods  = ["GET", "HEAD", "OPTIONS"]
  //   cached_methods   = ["GET", "HEAD"]
  //   target_origin_id = local.s3_origin_id

  //   forwarded_values {
  //     query_string = false

  //     cookies {
  //       forward = "none"
  //     }
  //   }

  //   min_ttl                = 0
  //   default_ttl            = 3600
  //   max_ttl                = 86400
  //   compress               = true
  //   viewer_protocol_policy = "redirect-to-https"
  // }

  // price_class = "PriceClass_200"

  // restrictions {
  //   geo_restriction {
  //     restriction_type = "whitelist"
  //     locations        = ["US", "CA", "GB", "DE"]
  //   }
  // }

  // tags = {
  //   Environment = "production"
  // }

  viewer_certificate {
    // cloudfront_default_certificate = true
    acm_certificate_arn = data.aws_acm_certificate.issued.arn
    ssl_support_method = "sni-only"
  }
}

