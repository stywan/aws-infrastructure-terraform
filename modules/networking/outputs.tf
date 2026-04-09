output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas (Frontend), indexadas por AZ"
  value       = aws_subnet.public[*].id
}

output "private_backend_subnet_ids" {
  description = "IDs de las subredes privadas Backend, indexadas por AZ"
  value       = aws_subnet.private_backend[*].id
}

output "private_data_subnet_ids" {
  description = "IDs de las subredes privadas Data, indexadas por AZ"
  value       = aws_subnet.private_data[*].id
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateways, indexados por AZ"
  value       = aws_nat_gateway.main[*].id
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.main.id
}
