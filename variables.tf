variable "aws_region" {
  description = "AWS region para desplegar la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en todos los recursos"
  type        = string
  default     = "innovatech"
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Zonas de disponibilidad a usar (2 AZs para alta disponibilidad)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs de subredes públicas (Frontend), uno por AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.4.0/24"]
}

variable "private_backend_subnet_cidrs" {
  description = "CIDRs de subredes privadas (Backend), uno por AZ"
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.5.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDRs de subredes privadas (Data), uno por AZ"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.6.0/24"]
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "ID de la AMI de Amazon Linux 2023 en us-east-1. Obtener con: aws ec2 describe-images --owners amazon --filters 'Name=name,Values=al2023-ami-*-x86_64' --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text"
  type        = string
}

variable "key_name" {
  description = "Nombre del Key Pair EC2 para acceso SSH (opcional si se usa solo SSM)"
  type        = string
  default     = null
}

variable "iam_instance_profile" {
  description = "Nombre del Instance Profile pre-existente en AWS Academy (no se puede crear)"
  type        = string
  default     = "LabInstanceProfile"
}
