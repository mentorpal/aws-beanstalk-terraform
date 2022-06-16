resource "aws_backup_plan" "backup_plan" {
  name = "${var.name}-backup-plan"
  tags = var.tags

  rule {
    rule_name                = "${var.name}-backup-hourly-rule"
    target_vault_name        = aws_backup_vault.hourly_backup_vault.name
    enable_continuous_backup = true # works for s3 and rds
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

resource "aws_backup_vault" "hourly_backup_vault" {
  name        = "${var.name}-hourly-backups"
  kms_key_arn = aws_kms_key.backup_key.arn
  tags        = var.tags
}

resource "aws_backup_selection" "backup_selection" {
  name         = "${var.name}-backup-selection"
  plan_id      = aws_backup_plan.backup_plan.id
  iam_role_arn = aws_iam_role.backup_role.arn

  resources = var.resources
}
