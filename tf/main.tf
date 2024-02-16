################################################################################
# Terraform Init
################################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.37.0"
    }
  }
  required_version = "~> 1.7.1"
}


################################################################################
# AWS AUTH
################################################################################
provider "aws" {
  region = var.region
  default_tags {
    tags = local.tags
  }
}

################################################################################
# Locals
################################################################################
data "aws_availability_zones" "available" {}

locals {
  name   = "k8s-sandbox"

  vpc_cidr = "10.0.0.0/16"

  master_node_name = "k8s-master"
  worker_node_name = "k8s-worker"
  ssh_key_name     = "k8s-ssh-key"

  net_a = "${var.region}a"
  net_b = "${var.region}b"
  azs   = ["${var.region}a", "${var.region}b"]

  user_data = <<-EOT
    #!/bin/bash
    echo "Hello Terraform!"
  EOT

  ami_id = "ami-0ab1a82de7ca5889c"

  tags = {
    Terraform   = "true"
    Environment = "sandbox"
    Project     = "k8s-sandbox"
  }
}

################################################################################
# EC2
################################################################################

# State management
locals {
  ec2_k8s_master_state = "stopped"
  ec2_k8s_worker_state = "stopped"
}
resource "aws_ec2_instance_state" "ec2_k8s_master_state" {
  instance_id = module.ec2_k8s_master.id
  state       = local.ec2_k8s_master_state
}

resource "aws_ec2_instance_state" "ec2_k8s_worker_state" {
  instance_id = module.ec2_k8s_worker.id
  state       = local.ec2_k8s_worker_state
}


# EC2 settings
module "ec2_k8s_master" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.1.0"

  name = local.master_node_name
  ami  = local.ami_id

  instance_type          = "t2.large"
  key_name               = local.ssh_key_name
  monitoring             = false
  vpc_security_group_ids = [module.security_group.security_group_id]
  subnet_id              = element(module.vpc.public_subnets, 0)
  #  associate_public_ip_address = false
  availability_zone = local.net_a

  root_block_device = [
    {
      volume_type = "gp3"
      volume_size = 20
    }
  ]
}

#### EBS attached to EC2
##resource "aws_volume_attachment" "k8s_master" {
##  device_name = "/dev/sda1"
##  volume_id   = aws_ebs_volume.k8s_master.id
##  instance_id = module.ec2_k8s_master.id
##}

# EIP attached to EC2
resource "aws_eip_association" "eip_assoc_k8s_master" {
  instance_id   = module.ec2_k8s_master.id
  allocation_id = aws_eip.k8s_master_eip.id
  depends_on    = [aws_eip.k8s_master_eip]
}

module "ec2_k8s_worker" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.1.0"

  name = local.worker_node_name
  ami  = local.ami_id

  instance_type          = "t2.large"
  key_name               = local.ssh_key_name
  monitoring             = false
  vpc_security_group_ids = [module.security_group.security_group_id]
  subnet_id              = element(module.vpc.public_subnets, 1)
  #  associate_public_ip_address = false
  availability_zone = local.net_b

  root_block_device = [
    {
      volume_type = "gp3"
      volume_size = 20
    }
  ]
}

##resource "aws_volume_attachment" "k8s_worker" {
##  device_name = "/dev/sda1"
##  volume_id   = aws_ebs_volume.k8s_worker.id
##  instance_id = module.ec2_k8s_worker.id
##}
##

# EIP attached to EC2
resource "aws_eip_association" "eip_assoc_worker_eip" {
  instance_id   = module.ec2_k8s_worker.id
  allocation_id = aws_eip.k8s_worker_eip.id
  depends_on    = [aws_eip.k8s_worker_eip]
}

################################################################################
# Supporting Resources
################################################################################

# VPC
# ------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr

  azs = local.azs
  # 10.0.0.0/28 [10.0.0.0 - 10.0.0.15], 10.0.0.16/28 [10.0.0.16 - 10.0.0.31]
  public_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 4)]
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.1.0"

  name        = "${local.name}-sq"
  description = "K8S Sandbox"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = [local.vpc_cidr]
  #    ingress_rules       = ["all-all"]
  ingress_with_cidr_blocks = [
    {
      rule = "all-all"
    },
    {
      rule        = "all-all"
      cidr_blocks = "80.151.43.175/32"
    }
  ]
  egress_rules = ["all-all"]

  tags = local.tags
}

# SSH Key
# ------------------------------------------------------------------
resource "aws_key_pair" "k8s_ssh_key" {
  public_key = length(var.k8s_ssh_key) > 0 ? var.k8s_ssh_key : file(var.k8s_ssh_key_path)
  key_name   = local.ssh_key_name
}

# EIP
# ------------------------------------------------------------------
resource "aws_eip" "k8s_master_eip" {
  domain = "vpc"
}

resource "aws_eip" "k8s_worker_eip" {
  domain = "vpc"
}


## EBS
## ------------------------------------------------------------------
#resource "aws_ebs_volume" "k8s_master" {
#  availability_zone = local.net_a
#  size              = 20
#  type              = "gp3"
#
#}
#
#resource "aws_ebs_volume" "k8s_worker" {
#  availability_zone = local.net_b
#  size              = 20
#  type              = "gp3"
#}
