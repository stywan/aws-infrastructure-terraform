output "frontend_instance_id" {
  description = "ID de la instancia Frontend (para SSM Session Manager)"
  value       = aws_instance.frontend.id
}

output "frontend_public_ip" {
  description = "IP pública de la instancia Frontend"
  value       = aws_instance.frontend.public_ip
}

output "frontend_public_dns" {
  description = "DNS público de la instancia Frontend"
  value       = aws_instance.frontend.public_dns
}

output "backend_instance_id" {
  description = "ID de la instancia Backend (para SSM Session Manager)"
  value       = aws_instance.backend.id
}

output "backend_private_ip" {
  description = "IP privada de la instancia Backend"
  value       = aws_instance.backend.private_ip
}

output "data_instance_id" {
  description = "ID de la instancia Data (para SSM Session Manager)"
  value       = aws_instance.data.id
}

output "data_private_ip" {
  description = "IP privada de la instancia Data"
  value       = aws_instance.data.private_ip
}
