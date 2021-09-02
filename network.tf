
module "vpc" {
  source     = "cloudposse/vpc/aws"
  version    = "0.25.0"
  namespace  = var.eb_env_namespace
  stage      = var.eb_env_stage
  name       = var.eb_env_name
  attributes = var.eb_env_attributes
  tags       = var.eb_env_tags
  delimiter  = var.eb_env_delimiter
  cidr_block = var.vpc_cidr_block
}

module "subnets" {
  source               = "cloudposse/dynamic-subnets/aws"
  version              = "0.39.4"
  availability_zones   = local.availability_zones
  namespace            = var.eb_env_namespace
  stage                = var.eb_env_stage
  name                 = var.eb_env_name
  attributes           = var.eb_env_attributes
  tags                 = var.eb_env_tags
  delimiter            = var.eb_env_delimiter
  vpc_id               = module.vpc.vpc_id
  igw_id               = module.vpc.igw_id
  cidr_block           = module.vpc.vpc_cidr_block
  nat_gateway_enabled  = true
  nat_instance_enabled = false
}