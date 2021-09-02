####################
# ECS Microservices
####################

module "service_label" {
  source  = "cloudposse/label/null"
  version = "0.24.1"

  attributes = ["service"]

  context = module.this.context
}


# Service
## Security Groups
resource "aws_security_group" "ecs_service" {
  vpc_id      = module.vpc.vpc_id
  name        = "${module.this.id}-ecs-service"
  description = "Allow ALL egress from ECS service"
  tags        = module.service_label.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_all_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = join("", aws_security_group.ecs_service.*.id)
}

resource "aws_security_group_rule" "allow_icmp_ingress" {
  description       = "Enables ping command from anywhere, see https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/security-group-rules-reference.html#sg-rules-ping"
  type              = "ingress"
  from_port         = 8
  to_port           = 0
  protocol          = "icmp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = join("", aws_security_group.ecs_service.*.id)
}


resource "aws_security_group_rule" "alb-ingress-80" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.vpc.vpc_default_security_group_id
  security_group_id        = join("", aws_security_group.ecs_service.*.id)
}

resource "aws_security_group_rule" "alb-ingress-3001" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 3001
  protocol                 = "tcp"
  source_security_group_id = module.vpc.vpc_default_security_group_id
  security_group_id        = join("", aws_security_group.ecs_service.*.id)
}



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

locals {
  security_group_ids = compact(concat([module.vpc.vpc_default_security_group_id], aws_security_group.ecs_service.*.id))
}


module "ecs_service_admin_client" {
  source             = "./ecs-service"
  alb_security_group = module.vpc.vpc_default_security_group_id
  container_cpu      = 512
  container_memory   = 1024
  container_name     = "admin"
  container_image    = "mentorpal/mentor-admin:4.3.0-alpha.7"
  ecs_cluster_arn    = aws_ecs_cluster.default.arn
  ecs_load_balancers = [
    {
      container_name   = "admin"
      container_port   = 80
      target_group_arn = aws_alb_target_group.admin.arn
    }
  ]
  vpc_id             = module.vpc.vpc_id
  security_group_ids = local.security_group_ids
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














module "ecs_service_chat_client" {
  source             = "./ecs-service"
  alb_security_group = module.vpc.vpc_default_security_group_id
  container_cpu      = 512
  container_memory   = 1024
  container_name     = "chat"
  container_image    = "mentorpal/mentor-client:4.2.0"
  ecs_cluster_arn    = aws_ecs_cluster.default.arn
  ecs_load_balancers = [
    {
      container_name   = "chat"
      container_port   = 80
      target_group_arn = aws_alb_target_group.chat.arn
    }
  ]
  vpc_id             = module.vpc.vpc_id
  security_group_ids = local.security_group_ids
  subnet_ids         = module.subnets.private_subnet_ids

  context = module.this.context
}


resource "aws_alb_target_group" "chat" {
  name_prefix = "chat"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    path = "/chat"
  }
}

resource "aws_alb_listener_rule" "chat" {
  listener_arn = module.alb.https_listener_arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.chat.arn
  }

  condition {
    path_pattern {
      values = ["/chat", "/chat/*"]
    }
  }
}











module "ecs_service_graphql" {
  source             = "./ecs-service"
  alb_security_group = module.vpc.vpc_default_security_group_id
  container_cpu      = 512
  container_memory   = 1024
  container_name     = "graphql"
  container_image    = "mentorpal/mentor-graphql:4.2.0"
  ecs_cluster_arn    = aws_ecs_cluster.default.arn
  ecs_load_balancers = [
    {
      container_name   = "graphql"
      container_port   = 3001
      target_group_arn = aws_alb_target_group.graphql.arn
    }
  ]
  container_port = 3001
  task_environment = {
    "API_SECRET" = var.secret_api_key,
    "JWT_SECRET" = var.secret_jwt_key,
    "MONGO_URI"  = var.secret_mongo_uri
  }
  vpc_id             = module.vpc.vpc_id
  security_group_ids = local.security_group_ids
  subnet_ids         = module.subnets.private_subnet_ids

  context = module.this.context
}


resource "aws_alb_target_group" "graphql" {
  name_prefix = "gql"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"
  health_check {
    path = "/graphql"
  }
}

resource "aws_alb_listener_rule" "graphql" {
  listener_arn = module.alb.https_listener_arn
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.graphql.arn
  }

  condition {
    path_pattern {
      values = ["/graphql", "/graphql/*"]
    }
  }
}

