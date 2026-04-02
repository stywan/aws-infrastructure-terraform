output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.networking.vpc_id
}

output "frontend_public_ip" {
  description = "IP pública de la instancia Frontend"
  value       = module.compute.frontend_public_ip
}

output "frontend_public_dns" {
  description = "DNS público de la instancia Frontend"
  value       = module.compute.frontend_public_dns
}

output "backend_private_ip" {
  description = "IP privada de la instancia Backend (solo accesible desde Frontend)"
  value       = module.compute.backend_private_ip
}

output "data_private_ip" {
  description = "IP privada de la instancia Data (solo accesible desde Backend)"
  value       = module.compute.data_private_ip
}

output "web_url" {
  description = "URL para acceder al servidor web Frontend"
  value       = "http://${module.compute.frontend_public_ip}"
}

output "ssh_frontend" {
  description = "Comando SSH para conectarse al Frontend"
  value       = var.key_name != null ? "ssh -i ${var.key_name}.pem ec2-user@${module.compute.frontend_public_ip}" : "Sin key pair configurado - usa SSM Session Manager"
}

output "ssm_frontend" {
  description = "Comando AWS CLI para conectarse al Frontend via SSM"
  value       = "aws ssm start-session --target ${module.compute.frontend_instance_id} --region ${var.aws_region}"
}

output "ssm_backend" {
  description = "Comando AWS CLI para conectarse al Backend via SSM"
  value       = "aws ssm start-session --target ${module.compute.backend_instance_id} --region ${var.aws_region}"
}

output "ssm_data" {
  description = "Comando AWS CLI para conectarse a la capa Data via SSM"
  value       = "aws ssm start-session --target ${module.compute.data_instance_id} --region ${var.aws_region}"
}

output "conectividad_test" {
  description = "Comandos para verificar conectividad entre capas"
  value = {
    desde_frontend_a_backend = "curl http://${module.compute.backend_private_ip}:8080"
    desde_backend_a_data     = "mysql -h ${module.compute.data_private_ip} -u appuser -p'AppUser2024!' innovatech_db -e 'SELECT * FROM products;'"
  }
}
