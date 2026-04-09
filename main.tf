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
  source                       = "./modules/networking"
  project_name                 = var.project_name
  vpc_cidr                     = var.vpc_cidr
  availability_zones           = var.availability_zones
  public_subnet_cidrs          = var.public_subnet_cidrs
  private_backend_subnet_cidrs = var.private_backend_subnet_cidrs
  private_data_subnet_cidrs    = var.private_data_subnet_cidrs
}

module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.networking.vpc_id
}

module "compute" {
  source                     = "./modules/compute"
  project_name               = var.project_name
  instance_type              = var.instance_type
  ami_id                     = var.ami_id
  key_name                   = var.key_name
  public_subnet_ids          = module.networking.public_subnet_ids
  private_backend_subnet_ids = module.networking.private_backend_subnet_ids
  private_data_subnet_ids    = module.networking.private_data_subnet_ids
  frontend_sg_id             = module.security.frontend_sg_id
  backend_sg_id              = module.security.backend_sg_id
  data_sg_id                 = module.security.data_sg_id
  iam_instance_profile       = var.iam_instance_profile
}
