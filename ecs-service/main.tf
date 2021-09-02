
locals {
  enabled = module.this.enabled
}

module "container_definition" {
  source                   = "cloudposse/ecs-container-definition/aws"
  version                  = "0.58.1"
  container_name           = var.container_name
  container_image          = var.container_image
  container_cpu            = var.container_cpu
  container_memory         = var.container_memory
  readonly_root_filesystem = false
  port_mappings = [
    {
      containerPort = var.container_port,
      hostPort      = var.container_port,
      protocol      = "tcp"
    }
  ]
}

// module "ecs_service_task" {
//   source                             = "cloudposse/ecs-alb-service-task/aws"
//   version                            = "0.56.0"
//   context                            = module.this.context
//   alb_security_group                 = var.alb_security_group
//   assign_public_ip                   = var.assign_public_ip
//   container_definition_json          = module.container_definition.json_map_encoded_list
//   deployment_maximum_percent         = var.deployment_maximum_percent
//   deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
//   desired_count                      = var.desired_count
//   ecs_cluster_arn                    = var.ecs_cluster_arn
//   ecs_load_balancers                 = var.ecs_load_balancers
//   health_check_grace_period_seconds  = var.health_check_grace_period_seconds
//   ignore_changes_task_definition     = var.ignore_changes_task_definition
//   launch_type                        = "FARGATE"
//   vpc_id                             = var.vpc_id
//   security_group_ids                 = var.security_group_ids
//   subnet_ids                         = var.subnet_ids
//   task_cpu                           = var.task_cpu
//   task_memory                        = var.task_memory
//   use_alb_security_group             = var.use_alb_security_group
// }

resource "aws_ecs_task_definition" "default" {
  count                    = local.enabled ? 1 : 0
  family                   = "${module.this.id}-${var.container_name}"
  container_definitions    = module.container_definition.json_map_encoded_list
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  // execution_role_arn       = length(var.task_exec_role_arn) > 0 ? var.task_exec_role_arn : join("", aws_iam_role.ecs_exec.*.arn)
  // task_role_arn            = length(var.task_role_arn) > 0 ? var.task_role_arn : join("", aws_iam_role.ecs_task.*.arn)

  // dynamic "proxy_configuration" {
  //   for_each = var.proxy_configuration == null ? [] : [var.proxy_configuration]
  //   content {
  //     type           = lookup(proxy_configuration.value, "type", "APPMESH")
  //     container_name = proxy_configuration.value.container_name
  //     properties     = proxy_configuration.value.properties
  //   }
  // }

  // dynamic "placement_constraints" {
  //   for_each = var.task_placement_constraints
  //   content {
  //     type       = placement_constraints.value.type
  //     expression = lookup(placement_constraints.value, "expression", null)
  //   }
  // }

  dynamic "volume" {
    for_each = var.volumes
    content {
      host_path = lookup(volume.value, "host_path", null)
      name      = volume.value.name

      dynamic "docker_volume_configuration" {
        for_each = lookup(volume.value, "docker_volume_configuration", [])
        content {
          autoprovision = lookup(docker_volume_configuration.value, "autoprovision", null)
          driver        = lookup(docker_volume_configuration.value, "driver", null)
          driver_opts   = lookup(docker_volume_configuration.value, "driver_opts", null)
          labels        = lookup(docker_volume_configuration.value, "labels", null)
          scope         = lookup(docker_volume_configuration.value, "scope", null)
        }
      }

      dynamic "efs_volume_configuration" {
        for_each = lookup(volume.value, "efs_volume_configuration", [])
        content {
          file_system_id          = lookup(efs_volume_configuration.value, "file_system_id", null)
          root_directory          = lookup(efs_volume_configuration.value, "root_directory", null)
          transit_encryption      = lookup(efs_volume_configuration.value, "transit_encryption", null)
          transit_encryption_port = lookup(efs_volume_configuration.value, "transit_encryption_port", null)
          dynamic "authorization_config" {
            for_each = lookup(efs_volume_configuration.value, "authorization_config", [])
            content {
              access_point_id = lookup(authorization_config.value, "access_point_id", null)
              iam             = lookup(authorization_config.value, "iam", null)
            }
          }
        }
      }
    }
  }
  tags = module.this.tags
}


resource "aws_ecs_service" "default" {
  count                              = local.enabled ? 1 : 0
  name                               = "${module.this.id}-${var.container_name}"
  task_definition                    = coalesce(var.task_definition, "${join("", aws_ecs_task_definition.default.*.family)}:${join("", aws_ecs_task_definition.default.*.revision)}")
  desired_count                      = var.desired_count
  deployment_maximum_percent         = var.deployment_maximum_percent
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  scheduling_strategy                = "REPLICA"
  enable_ecs_managed_tags            = var.enable_ecs_managed_tags
  // iam_role                           = local.enable_ecs_service_role ? coalesce(var.service_role_arn, join("", aws_iam_role.ecs_service.*.arn)) : null
  // wait_for_steady_state              = var.wait_for_steady_state
  // force_new_deployment               = var.force_new_deployment
  // enable_execute_command             = var.exec_enabled

  // dynamic "capacity_provider_strategy" {
  //   for_each = var.capacity_provider_strategies
  //   content {
  //     capacity_provider = capacity_provider_strategy.value.capacity_provider
  //     weight            = capacity_provider_strategy.value.weight
  //     base              = lookup(capacity_provider_strategy.value, "base", null)
  //   }
  // }

  dynamic "service_registries" {
    for_each = var.service_registries
    content {
      registry_arn   = service_registries.value.registry_arn
      port           = lookup(service_registries.value, "port", null)
      container_name = lookup(service_registries.value, "container_name", null)
      container_port = lookup(service_registries.value, "container_port", null)
    }
  }

  // dynamic "ordered_placement_strategy" {
  //   for_each = var.ordered_placement_strategy
  //   content {
  //     type  = ordered_placement_strategy.value.type
  //     field = lookup(ordered_placement_strategy.value, "field", null)
  //   }
  // }

  // dynamic "placement_constraints" {
  //   for_each = var.service_placement_constraints
  //   content {
  //     type       = placement_constraints.value.type
  //     expression = lookup(placement_constraints.value, "expression", null)
  //   }
  // }

  dynamic "load_balancer" {
    for_each = var.ecs_load_balancers
    content {
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
      elb_name         = lookup(load_balancer.value, "elb_name", null)
      target_group_arn = lookup(load_balancer.value, "target_group_arn", null)
    }
  }

  cluster        = var.ecs_cluster_arn
  propagate_tags = var.propagate_tags
  tags           = var.use_old_arn ? null : module.this.tags

  deployment_controller {
    type = var.deployment_controller_type
  }

  # https://www.terraform.io/docs/providers/aws/r/ecs_service.html#network_configuration
  network_configuration {

    // security_groups  = compact(concat(var.security_group_ids, aws_security_group.ecs_service.*.id))
    security_groups  = var.security_group_ids
    subnets          = var.subnet_ids
    assign_public_ip = false
  }
}












