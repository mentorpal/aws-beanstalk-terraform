
module "container_definition" {
  source                   = "cloudposse/ecs-container-definition/aws"
  version                  = "0.58.1"
  container_name           = var.container_name
  container_image          = var.container_image
  container_cpu            = var.container_cpu
  container_memory         = var.container_memory
  readonly_root_filesystem = true
  port_mappings = [
    {
      containerPort = var.container_port,
      hostPort      = var.container_port,
      protocol      = "tcp"
    }
  ]
}

module "ecs_service_task" {
  source                             = "cloudposse/ecs-alb-service-task/aws"
  version                            = "0.56.0"
  context                            = module.this.context
  alb_security_group                 = var.alb_security_group
  assign_public_ip                   = var.assign_public_ip
  container_definition_json          = module.container_definition.json_map_encoded_list
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  desired_count                      = var.desired_count
  ecs_cluster_arn                    = var.ecs_cluster_arn
  ecs_load_balancers                 = var.ecs_load_balancers
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  ignore_changes_task_definition     = var.ignore_changes_task_definition
  launch_type                        = "FARGATE"
  vpc_id                             = var.vpc_id
  security_group_ids                 = var.security_group_ids
  subnet_ids                         = var.subnet_ids
  task_cpu                           = var.task_cpu
  task_memory                        = var.task_memory
  use_alb_security_group             = var.use_alb_security_group
}