output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.networking.vpc_id
}

# --- Subredes ---
output "public_subnet_ids" {
  description = "IDs de las subredes públicas (Frontend) por AZ"
  value       = module.networking.public_subnet_ids
}

output "private_backend_subnet_ids" {
  description = "IDs de las subredes privadas Backend por AZ"
  value       = module.networking.private_backend_subnet_ids
}

output "private_data_subnet_ids" {
  description = "IDs de las subredes privadas Data por AZ"
  value       = module.networking.private_data_subnet_ids
}

# --- Frontend ---
output "frontend_public_ips" {
  description = "IPs públicas de las instancias Frontend"
  value       = module.compute.frontend_public_ips
}

output "frontend_public_dns" {
  description = "DNS públicos de las instancias Frontend"
  value       = module.compute.frontend_public_dns
}

output "frontend_instance_ids" {
  description = "IDs de las instancias Frontend (para SSM)"
  value       = module.compute.frontend_instance_ids
}

# --- Backend ---
output "backend_private_ips" {
  description = "IPs privadas de las instancias Backend"
  value       = module.compute.backend_private_ips
}

output "backend_instance_ids" {
  description = "IDs de las instancias Backend (para SSM)"
  value       = module.compute.backend_instance_ids
}

# --- Data ---
output "data_private_ips" {
  description = "IPs privadas de las instancias Data"
  value       = module.compute.data_private_ips
}

output "data_instance_ids" {
  description = "IDs de las instancias Data (para SSM)"
  value       = module.compute.data_instance_ids
}

# --- URLs de acceso ---
output "web_urls" {
  description = "URLs para acceder a los servidores Frontend"
  value       = [for ip in module.compute.frontend_public_ips : "http://${ip}"]
}

# --- Comandos SSM ---
output "ssm_commands" {
  description = "Comandos para conectarse via SSM Session Manager"
  value = {
    frontend = [for id in module.compute.frontend_instance_ids : "aws ssm start-session --target ${id} --region ${var.aws_region}"]
    backend  = [for id in module.compute.backend_instance_ids : "aws ssm start-session --target ${id} --region ${var.aws_region}"]
    data     = [for id in module.compute.data_instance_ids : "aws ssm start-session --target ${id} --region ${var.aws_region}"]
  }
}
