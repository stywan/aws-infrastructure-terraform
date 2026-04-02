variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en los Security Groups"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crearán los Security Groups"
  type        = string
}
