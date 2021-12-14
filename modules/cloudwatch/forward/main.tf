###
# all infra for shipping cloudwatch logs to an http endpoint (new relic).
# https://docs.newrelic.com/docs/logs/forward-logs/stream-logs-using-kinesis-data-firehose/
###

# resource "random_string" "suffix" {
#   length  = 5
#   special = false
#   upper   = false
# }

locals {
  # defined in beanstalk-app
  log_groups = toset([
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/admin-stdout.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/chat-stdout.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/classifier-stdout.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/graphql-stdout.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/home-stdout.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/nginx-access.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/nginx-error.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/nginx-stdout.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/redis-stdout.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/training-stdout.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/upload-api-stdout.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/containers/upload-worker-stdout.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/environment-health.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/var/log/docker-events.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/var/log/eb-activity.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/var/log/eb-ecs-mgr.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/var/log/ecs/ecs-agent.log",
    "/aws/elasticbeanstalk/${var.eb_log_group_prefix}/var/log/ecs/ecs-init.log",
  ])
}

resource "aws_s3_bucket" "bucket" {
  bucket = "firehose-cw-failed-${var.name}"
  acl    = "private"

  lifecycle_rule {
    enabled = true

    expiration {
      days = 30
    }
  }
}

resource "aws_kinesis_firehose_delivery_stream" "logs_stream" {
  name        = "kinesis-cw-logs-${var.name}"
  destination = "http_endpoint"

  s3_configuration {
    role_arn           = aws_iam_role.firehose.arn
    bucket_arn         = aws_s3_bucket.bucket.arn
    buffer_size        = 10
    buffer_interval    = 400
    compression_format = "GZIP"
  }

  http_endpoint_configuration {
    url                = var.ingest_url
    name               = var.name
    access_key         = var.api_key
    buffering_size     = 15
    buffering_interval = 600
    role_arn           = aws_iam_role.firehose.arn
    s3_backup_mode     = "FailedDataOnly"

    request_configuration {
      content_encoding = "GZIP"
    }
  }
}

# need a role that grants kinesis required permissions
# https://registry.terraform.io/providers/hashicorp"/aws/latest/docs/resources/kinesis_firehose_delivery_stream#role_arn",
resource "aws_iam_role" "firehose" {
  name = "${var.name}-firehose-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  inline_policy {
    name = "policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject"
          ],
          "Resource" : [
            "${aws_s3_bucket.bucket.arn}",
            "${aws_s3_bucket.bucket.arn}/*"
          ]
        }
      ]
    })
  }
}

resource "aws_iam_role" "subscription" {
  name = "${var.name}-cw-subscription"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "logs.ap-northeast-1.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "to_kinesis" {
  role = aws_iam_role.subscription.name

  policy = jsonencode({
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : ["firehose:*"],
        "Resource" : ["${aws_kinesis_firehose_delivery_stream.logs_stream.arn}"]
      }
    ]
  })
}

# these are created by eb but to make sure tf apply does not fail:
resource "aws_cloudwatch_log_group" "cw_log_groups" {
  for_each          = local.log_groups
  name              = each.key
  retention_in_days = 30
}

# https://github.com/beta-yumatsud/terraform-practice/blob/6536a7f5edfd23f54cbe07da6e8a5317af5d6b76/log.tf
resource "aws_cloudwatch_log_subscription_filter" "cw_subscriptions" {
  for_each = local.log_groups

  name            = "${each.key}-${var.name}-kinesis-filter"
  role_arn        = aws_iam_role.subscription.arn
  log_group_name  = each.key
  filter_pattern  = "[]"
  destination_arn = aws_kinesis_firehose_delivery_stream.logs_stream.arn
  depends_on      = [aws_iam_role_policy.to_kinesis]
}
