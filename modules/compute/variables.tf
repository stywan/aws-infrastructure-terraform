variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
}

variable "ami_id" {
  description = "ID de la AMI de Amazon Linux 2023"
  type        = string
}

variable "key_name" {
  description = "Nombre del Key Pair EC2 (null si se usa solo SSM)"
  type        = string
  default     = null
}

variable "public_subnet_ids" {
  description = "IDs de las subredes públicas para Frontend, uno por AZ"
  type        = list(string)
}

variable "private_backend_subnet_ids" {
  description = "IDs de las subredes privadas para Backend, uno por AZ"
  type        = list(string)
}

variable "private_data_subnet_ids" {
  description = "IDs de las subredes privadas para Data, uno por AZ"
  type        = list(string)
}

variable "frontend_sg_id" {
  description = "ID del Security Group del Frontend (compartido entre AZs)"
  type        = string
}

variable "backend_sg_id" {
  description = "ID del Security Group del Backend (compartido entre AZs)"
  type        = string
}

variable "data_sg_id" {
  description = "ID del Security Group de la capa Data (compartido entre AZs)"
  type        = string
}

variable "iam_instance_profile" {
  description = "Nombre del Instance Profile pre-existente en AWS Academy"
  type        = string
  default     = "LabInstanceProfile"
}
