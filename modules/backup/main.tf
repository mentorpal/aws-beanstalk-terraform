resource "aws_backup_plan" "backup_plan" {
  name = "${var.name}-backup-plan"
  tags = var.tags

  rule {
    rule_name                = "${var.name}-backup-rule"
    target_vault_name        = aws_backup_vault.continuous_backup_vault.name
    enable_continuous_backup = true # works for s3 and rds
    completion_window        = 300
    # start_window             = 60 default
    lifecycle {
      delete_after = 30 # days
    }
  }
}

resource "aws_kms_key" "backup_key" {
  description             = "backup vault encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_backup_vault" "continuous_backup_vault" {
  name        = "${var.name}-continuous-backups"
  kms_key_arn = aws_kms_key.backup_key.arn
  tags        = var.tags
}

resource "aws_backup_selection" "backup_selection" {
  name         = "${var.name}-backup-selection"
  plan_id      = aws_backup_plan.backup_plan.id
  iam_role_arn = aws_iam_role.backup_role.arn

  resources = var.resources
}

resource "aws_backup_vault_notifications" "failed_alerts" {
  backup_vault_name = aws_backup_vault.continuous_backup_vault.name
  sns_topic_arn     = var.alert_topic_arn
  backup_vault_events = ["BACKUP_JOB_STARTED", "BACKUP_JOB_COMPLETED", "BACKUP_JOB_SUCCESSFUL", "BACKUP_JOB_FAILED"]
  # backup_vault_events = ["BACKUP_JOB_FAILED"]
}
