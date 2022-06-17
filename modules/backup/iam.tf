resource "aws_iam_role" "backup_role" {
  name               = "${var.name}-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role_policy.json
}

data "aws_iam_policy_document" "backup_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

# https://docs.aws.amazon.com/aws-backup/latest/devguide/iam-service-roles.html#default-service-roles
resource "aws_iam_role_policy_attachment" "backup_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = aws_iam_role.backup_role.name
}

resource "aws_iam_role_policy_attachment" "restore_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role = aws_iam_role.backup_role.name
}

# AWSBackupServiceRolePolicyForBackup doesnt grant S3 access

resource "aws_iam_policy" "s3_backup_policy" {
  description = "AWS Backup S3 backup policy"

  policy = <<EOF
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"S3BucketBackupPermissions",
      "Action":[
        "s3:GetInventoryConfiguration",
        "s3:PutInventoryConfiguration",
        "s3:ListBucketVersions",
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:GetBucketNotification",
        "s3:PutBucketNotification",
        "s3:GetBucketLocation",
        "s3:GetBucketTagging"
      ],
      "Effect":"Allow",
      "Resource":[
        "arn:aws:s3:::*"
      ]
    },
    {
      "Sid":"S3ObjectBackupPermissions",
      "Action":[
        "s3:GetObjectAcl",
        "s3:GetObject",
        "s3:GetObjectVersionTagging",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectTagging",
        "s3:GetObjectVersion"
      ],
      "Effect":"Allow",
      "Resource":[
        "arn:aws:s3:::*/*"
      ]
    },
    {
      "Sid":"S3GlobalPermissions",
      "Action":[
        "s3:ListAllMyBuckets"
      ],
      "Effect":"Allow",
      "Resource":[
        "*"
      ]
    },
    {
      "Sid":"KMSBackupPermissions",
      "Action":[
        "kms:Decrypt",
        "kms:DescribeKey"
      ],
      "Effect":"Allow",
      "Resource":"*",
      "Condition":{
        "StringLike":{
          "kms:ViaService":"s3.*.amazonaws.com"
        }
      }
    },
    {
      "Sid":"EventsPermissions",
      "Action":[
        "events:DescribeRule",
        "events:EnableRule",
        "events:PutRule",
        "events:DeleteRule",
        "events:PutTargets",
        "events:RemoveTargets",
        "events:ListTargetsByRule",
        "events:DisableRule"
      ],
      "Effect":"Allow",
      "Resource":"arn:aws:events:*:*:rule/AwsBackupManagedRule*"
    },
    {
      "Sid":"EventsMetricsGlobalPermissions",
      "Action":[
        "cloudwatch:GetMetricData",
        "events:ListRules"
      ],
      "Effect":"Allow",
      "Resource":"*"
    }
  ]
}
EOF
}


resource "aws_iam_policy" "s3_restore_policy" {
  description = "AWS Backup S3 restore policy"

  policy = <<EOF
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"S3BucketRestorePermissions",
      "Action":[
        "s3:CreateBucket",
        "s3:ListBucketVersions",
        "s3:ListBucket",
        "s3:GetBucketVersioning",
        "s3:GetBucketLocation",
        "s3:PutBucketVersioning"
      ],
      "Effect":"Allow",
      "Resource":[
        "arn:aws:s3:::*"
      ]
    },
    {
      "Sid":"S3ObjectRestorePermissions",
      "Action":[
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:DeleteObject",
        "s3:PutObjectVersionAcl",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectTagging",
        "s3:PutObjectTagging",
        "s3:GetObjectAcl",
        "s3:PutObjectAcl",
        "s3:PutObject",
        "s3:ListMultipartUploadParts"
      ],
      "Effect":"Allow",
      "Resource":[
        "arn:aws:s3:::*/*"
      ]
    },
    {
      "Sid":"S3KMSPermissions",
      "Action":[
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKey"
      ],
      "Effect":"Allow",
      "Resource":"*",
      "Condition":{
        "StringLike":{
          "kms:ViaService":"s3.*.amazonaws.com"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "s3_backup_attachment" {
  policy_arn = aws_iam_policy.s3_backup_policy.arn
  role       = aws_iam_role.backup_role.name
}

resource "aws_iam_role_policy_attachment" "s3_restore_attachment" {
  policy_arn = aws_iam_policy.s3_restore_policy.arn
  role       = aws_iam_role.backup_role.name
}
