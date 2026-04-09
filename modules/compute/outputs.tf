output "frontend_instance_ids" {
  description = "IDs de las instancias Frontend (para SSM Session Manager)"
  value       = aws_instance.frontend[*].id
}

output "frontend_public_ips" {
  description = "IPs públicas de las instancias Frontend"
  value       = aws_instance.frontend[*].public_ip
}

output "frontend_public_dns" {
  description = "DNS públicos de las instancias Frontend"
  value       = aws_instance.frontend[*].public_dns
}

output "backend_instance_ids" {
  description = "IDs de las instancias Backend (para SSM Session Manager)"
  value       = aws_instance.backend[*].id
}

output "backend_private_ips" {
  description = "IPs privadas de las instancias Backend"
  value       = aws_instance.backend[*].private_ip
}

output "data_instance_ids" {
  description = "IDs de las instancias Data (para SSM Session Manager)"
  value       = aws_instance.data[*].id
}

output "data_private_ips" {
  description = "IPs privadas de las instancias Data"
  value       = aws_instance.data[*].private_ip
}
