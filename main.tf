terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source              = "./modules/networking"
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
}

module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.networking.vpc_id
}

module "compute" {
  source               = "./modules/compute"
  project_name         = var.project_name
  instance_type        = var.instance_type
  ami_id               = var.ami_id
  key_name             = var.key_name
  public_subnet_id     = module.networking.public_subnet_id
  private_subnet_id    = module.networking.private_subnet_id
  frontend_sg_id       = module.security.frontend_sg_id
  backend_sg_id        = module.security.backend_sg_id
  data_sg_id           = module.security.data_sg_id
  iam_instance_profile = var.iam_instance_profile
}
