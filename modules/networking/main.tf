# =============================================================================
# Módulo: networking
# Crea la VPC, 6 subredes (pública/backend/data × 2 AZs), Internet Gateway,
# 2 NAT Gateways, Elastic IPs y tablas de ruteo para arquitectura 3 capas
# multi-AZ de Innovatech.
#
# Diagrama de red:
#   10.0.0.0/16 VPC
#   ├── us-east-1a
#   │   ├── 10.0.1.0/24  public-a    → IGW
#   │   ├── 10.0.2.0/24  backend-a   → NAT-a
#   │   └── 10.0.3.0/24  data-a      → NAT-a
#   └── us-east-1b
#       ├── 10.0.4.0/24  public-b    → IGW
#       ├── 10.0.5.0/24  backend-b   → NAT-b
#       └── 10.0.6.0/24  data-b      → NAT-b
# =============================================================================

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# --- Subredes Públicas (Frontend) — una por AZ ---
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-subnet-public-${var.availability_zones[count.index]}"
    Tier    = "public"
    AZ      = var.availability_zones[count.index]
    Project = var.project_name
  }
}

# --- Subredes Privadas Backend — una por AZ ---
resource "aws_subnet" "private_backend" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_backend_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name    = "${var.project_name}-subnet-backend-${var.availability_zones[count.index]}"
    Tier    = "backend"
    AZ      = var.availability_zones[count.index]
    Project = var.project_name
  }
}

# --- Subredes Privadas Data — una por AZ ---
resource "aws_subnet" "private_data" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name    = "${var.project_name}-subnet-data-${var.availability_zones[count.index]}"
    Tier    = "data"
    AZ      = var.availability_zones[count.index]
    Project = var.project_name
  }
}

# --- Internet Gateway (salida pública, compartido por ambas AZs) ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# --- Elastic IPs para NAT Gateways — una por AZ ---
resource "aws_eip" "nat" {
  count  = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip-${var.availability_zones[count.index]}"
    AZ      = var.availability_zones[count.index]
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

# --- NAT Gateways — uno por AZ, en la subred pública de esa AZ ---
resource "aws_nat_gateway" "main" {
  count = length(var.availability_zones)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name    = "${var.project_name}-nat-gw-${var.availability_zones[count.index]}"
    AZ      = var.availability_zones[count.index]
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

# --- Tabla de ruteo Pública (compartida) → Internet Gateway ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-rt-public"
    Project = var.project_name
  }
}

# --- Tablas de ruteo Privadas — una por AZ → NAT de esa AZ ---
# Backend y Data de la misma AZ comparten esta route table
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name    = "${var.project_name}-rt-private-${var.availability_zones[count.index]}"
    AZ      = var.availability_zones[count.index]
    Project = var.project_name
  }
}

# --- Asociaciones: subredes públicas → rt-public ---
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Asociaciones: subredes backend → rt-private de su AZ ---
resource "aws_route_table_association" "private_backend" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private_backend[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --- Asociaciones: subredes data → rt-private de su AZ ---
resource "aws_route_table_association" "private_data" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
