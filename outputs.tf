output "efs_file_system_id" {
  description = "id for the efs file system (use to mount from beanstalk)"
  value       = module.efs.id
}
