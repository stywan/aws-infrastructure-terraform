variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los recursos de red"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC (ej: 10.0.0.0/16)"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block de la subred pública"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block de la subred privada"
  type        = string
}

variable "availability_zone" {
  description = "Zona de disponibilidad para ambas subredes"
  type        = string
}
