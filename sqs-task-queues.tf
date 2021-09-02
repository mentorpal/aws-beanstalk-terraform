
##############################
# All things SQS / Task Queue
##############################

locals {
  sqs_shared_policy_name = "${local.namespace}-sqs-shared-policy"
}

###################################################
# Policy for persmissions all queue users need
###################################################

data "aws_iam_policy_document" "sqs_shared_policy" {
  statement {
    sid = "1"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueues"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "sqs_shared_policy" {
  name   = local.sqs_shared_policy_name
  path   = "/"
  policy = data.aws_iam_policy_document.sqs_shared_policy.json
}


###################################################
# Task queue for UPLOADS
###################################################

locals {
  upload_queue_name        = "${local.namespace}-uploads.fifo"
  upload_queue_policy_name = "${local.namespace}-uploads-policy"
  upload_queue_user_name   = "${local.namespace}-uploads-user"
}

resource "aws_sqs_queue" "upload_queue" {
  name       = local.upload_queue_name
  # A FIFO queue in sqs guarantees "exactly once" delivery
  # A non fifo queue would be "at least once" delivery.
  # Fifo is slightly more expensive and doesn't have infinite scaling, 
  # but seems better for our current uses (starting upload and training jobs)
  fifo_queue = true
}

data "aws_iam_policy_document" "upload_queue_policy" {
  statement {
    sid = "1"
    actions = [
      "sqs:DeleteMessage", "sqs:ReceiveMessage", "sqs:SendMessage",
    ]
    resources = [
      aws_sqs_queue.upload_queue.arn
    ]
  }
}

resource "aws_iam_policy" "upload_queue_policy" {
  name   = local.upload_queue_policy_name
  path   = "/"
  policy = data.aws_iam_policy_document.upload_queue_policy.json
}

resource "aws_iam_user" "upload_queue_user" {
  name = local.upload_queue_user_name
}

resource "aws_iam_user_policy_attachment" "upload_queue_policy_attachment" {
  user       = aws_iam_user.upload_queue_user.name
  policy_arn = aws_iam_policy.upload_queue_policy.arn
}

resource "aws_iam_user_policy_attachment" "upload_queue_sqs_shared_policy_attachment" {
  user       = aws_iam_user.upload_queue_user.name
  policy_arn = aws_iam_policy.sqs_shared_policy.arn
}

resource "aws_iam_access_key" "upload_queue_user_access_key" {
  user = aws_iam_user.upload_queue_user.name
}



###################################################
# Task queue for CLASSIFIER (training)
###################################################

locals {
  classifier_queue_name        = "${local.namespace}-classifier.fifo"
  classifier_queue_policy_name = "${local.namespace}-classifier-policy"
  classifier_queue_user_name   = "${local.namespace}-classifier-user"
}

resource "aws_sqs_queue" "classifier_queue" {
  name       = local.classifier_queue_name
  # A FIFO queue in sqs guarantees "exactly once" delivery
  # A non fifo queue would be "at least once" delivery.
  # Fifo is slightly more expensive and doesn't have infinite scaling, 
  # but seems better for our current uses (starting upload and training jobs)
  fifo_queue = true
}

data "aws_iam_policy_document" "classifier_queue_policy" {
  statement {
    sid = "1"
    actions = [
      "sqs:DeleteMessage", "sqs:ReceiveMessage", "sqs:SendMessage",
    ]
    resources = [
      aws_sqs_queue.classifier_queue.arn
    ]
  }
}

resource "aws_iam_policy" "classifier_queue_policy" {
  name   = local.classifier_queue_policy_name
  path   = "/"
  policy = data.aws_iam_policy_document.classifier_queue_policy.json
}

resource "aws_iam_user" "classifier_queue_user" {
  name = local.classifier_queue_user_name
}

resource "aws_iam_user_policy_attachment" "classifier_queue_policy_attachment" {
  user       = aws_iam_user.classifier_queue_user.name
  policy_arn = aws_iam_policy.classifier_queue_policy.arn
}

resource "aws_iam_user_policy_attachment" "classifier_queue_sqs_shared_policy_attachment" {
  user       = aws_iam_user.classifier_queue_user.name
  policy_arn = aws_iam_policy.sqs_shared_policy.arn
}

resource "aws_iam_access_key" "classifier_queue_user_access_key" {
  user = aws_iam_user.classifier_queue_user.name
}

