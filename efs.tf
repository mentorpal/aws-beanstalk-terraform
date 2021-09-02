
###
# Shared network file system that will store trained models, etc.
# Using a network file system allows separate processes 
# to read/write a common set of files 
# (e.g. training writes models read by classifier api)
###
module "efs" {
  source = "cloudposse/efs/aws"
  version="0.30.1"
  region  = var.aws_region
  vpc_id  = module.vpc.vpc_id
  subnets = module.subnets.private_subnet_ids
  security_groups = [
    module.vpc.vpc_default_security_group_id
  ]
  context = module.this.context
}


