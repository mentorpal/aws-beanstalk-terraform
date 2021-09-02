####################
# ECS Microservices
####################


# ECS Cluster (needed even if using FARGATE launch type)

resource "aws_ecs_cluster" "default" {
  name = module.this.id
  tags = module.this.tags
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_service_discovery_private_dns_namespace" "microservice" {
  name        = "microservice"
  description = "a private DNS namespace. All microservices will register themselves with names in this namespace for intercommunication among microservices, e.g. training.microservice => graphql.microservice"
  vpc         = module.vpc.vpc_id
}


module "ecs_service_admin_client" {
  source             = "./ecs-service"
  alb_security_group = module.vpc.vpc_default_security_group_id
  container_cpu      = 512
  container_memory   = 1024
  container_name     = "mentor_admin"
  container_image    = "mentorpal/mentor-admin:4.3.0-alpha.7"
  ecs_cluster_arn    = aws_ecs_cluster.default.arn
  ecs_load_balancers = [
    {
      container_name   = "mentor_admin"
      container_port   = 80
      elb_name         = ""
      target_group_arn = aws_alb_target_group.admin.arn
    }
  ]
  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc.vpc_default_security_group_id]
  // subnet_ids         = module.subnets.public_subnet_ids
  subnet_ids         = module.subnets.private_subnet_ids

  context = module.this.context
}


resource "aws_alb_target_group" "admin" {
  name_prefix = "admin"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    path = "/admin"
  }
}

resource "aws_alb_listener_rule" "admin" {
  listener_arn = module.alb.https_listener_arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.admin.arn
  }

  condition {
    path_pattern {
      values = ["/admin", "/admin/*"]
    }
  }
}
