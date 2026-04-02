output "frontend_sg_id" {
  description = "ID del Security Group del Frontend"
  value       = aws_security_group.frontend.id
}

output "backend_sg_id" {
  description = "ID del Security Group del Backend"
  value       = aws_security_group.backend.id
}

output "data_sg_id" {
  description = "ID del Security Group de la capa Data"
  value       = aws_security_group.data.id
}
