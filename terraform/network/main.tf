data "aws_availability_zones" "available" {}

module "vpc" {
  source         = "terraform-aws-modules/vpc/aws"
  version        = "~> 3.0.0"
  name           = "${var.creator}-vpc-example"
  cidr           = "10.20.0.0/16"
  azs            = data.aws_availability_zones.available.names
  public_subnets = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  vpc_tags = {
    "createdBy" = var.creator
  }
  public_subnet_tags = {
    "createdBy" = var.creator
  }
}

module "alb_security_group" {
  source       = "terraform-aws-modules/security-group/aws"
  version      = "~> 4.0.0"
  name         = "${var.creator}-eks-example-alb-sg"
  vpc_id       = module.vpc.vpc_id
  egress_rules = ["all-all"]
  ingress_with_cidr_blocks = [
    {
      rule        = "http-80-tcp"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

module "node_security_group" {
  source       = "terraform-aws-modules/security-group/aws"
  version      = "~> 4.0.0"
  name         = "${var.creator}-eks-example-node-sg"
  vpc_id       = module.vpc.vpc_id
  egress_rules = ["all-all"]
  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "all-all"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name = "${var.creator}-eks-example"

  load_balancer_type = "application"

  vpc_id          = module.vpc.vpc_id
  subnets         = module.vpc.public_subnets
  security_groups = [module.alb_security_group.security_group_id]


  target_groups = [
    {
      name             = "eks-example-tg"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "ip"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    createdBy = var.creator
  }
}
