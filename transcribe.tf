###
# TRANSCRIBE INFRA
#
# all infra for transcribing mentor videos with py-transcribe-aws module
# (IAM, s3 bucket, keys, policies, etc)
###
module "transcribe_aws" {
  source               = "git::https://github.com/ICTLearningSciences/py-transcribe-aws.git?ref=tags/1.4.0"
  transcribe_namespace = local.namespace
}