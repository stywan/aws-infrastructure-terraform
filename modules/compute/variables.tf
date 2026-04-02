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

variable "public_subnet_id" {
  description = "ID de la subred pública (para Frontend)"
  type        = string
}

variable "private_subnet_id" {
  description = "ID de la subred privada (para Backend y Data)"
  type        = string
}

variable "frontend_sg_id" {
  description = "ID del Security Group del Frontend"
  type        = string
}

variable "backend_sg_id" {
  description = "ID del Security Group del Backend"
  type        = string
}

variable "data_sg_id" {
  description = "ID del Security Group de la capa Data"
  type        = string
}

variable "iam_instance_profile" {
  description = "Nombre del Instance Profile pre-existente en AWS Academy"
  type        = string
  default     = "LabInstanceProfile"
}
