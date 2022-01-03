locals {
  cluster_name    = "${var.creator}-eks-example"
  cluster_version = "1.21"
}

data "aws_vpc" "selected" {
  cidr_block = "10.20.0.0/16"
}

data "aws_subnet_ids" "selected" {
  vpc_id = data.aws_vpc.selected.id
}

data "aws_security_group" "selected" {
  tags = {
    "Name" = "${var.creator}-eks-example-node-sg"
  }
}
data "aws_lb_target_group" "selected" {
  name = "eks-example-tg"
}
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "15.1.0"
  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version
  subnets         = data.aws_subnet_ids.selected.ids
  vpc_id          = data.aws_vpc.selected.id
  node_groups = {
    ng-1 = {
      instance_types          = ["t3.small"]
      desired_capacity        = 3
      max_capacity            = 5
      min_capacity            = 3
      launch_template_id      = aws_launch_template.launch_template.id
      launch_template_version = aws_launch_template.launch_template.latest_version
      iam_role_arn            = module.iam_assumable_role.iam_role_arn
    }
  }
  write_kubeconfig = false

}

resource "aws_launch_template" "launch_template" {
  name = "${var.creator}-eks-example-template"
  network_interfaces {
    security_groups = [
      module.eks.cluster_primary_security_group_id,
      data.aws_security_group.selected.id
    ]
  }
}

module "iam_assumable_role" {
  source                = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version               = "~> 4.0"
  create_role           = true
  role_requires_mfa     = false
  role_name             = "eks-node-role"
  trusted_role_actions  = ["sts:AssumeRole"]
  trusted_role_services = ["ec2.amazonaws.com"]
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    module.eks_node_policy.arn,

  ]
  number_of_custom_role_policy_arns = 4
}

module "eks_node_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 4.0"

  name        = "${var.creator}-eks_node_policy"
  path        = "/"
  description = "eks example policy"
  policy      = file("./policy/eks_node_policy.json")
}

module "alb_ingress_controller_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 4.0"

  name        = "${var.creator}-AWSLoadBalancerControllerIAMPolicy"
  path        = "/"
  description = "eks example policy"
  policy      = file("./policy/AWSLoadBalancerController.json")
}

resource "aws_iam_openid_connect_provider" "oidc_provider" {
  url             = module.eks.cluster_oidc_issuer_url
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  client_id_list = [
    "sts.amazonaws.com"
  ]
}

data "aws_iam_policy_document" "alb_ingress_controller" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]
    principals {
      type        = "Federated"
      identifiers = ["${aws_iam_openid_connect_provider.oidc_provider.arn}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.oidc_provider.url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

resource "aws_iam_role" "alb_ingress_controller" {
  name               = "${var.creator}-alb-ingress-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_ingress_controller.json
}

resource "aws_iam_role_policy_attachment" "alb_ingress_controller" {
  role       = aws_iam_role.alb_ingress_controller.id
  policy_arn = module.alb_ingress_controller_policy.arn
}
