output "service_arn" {
    description = "id/arn for the ecs service"
    value = module.ecs_service_task.service_arn
}