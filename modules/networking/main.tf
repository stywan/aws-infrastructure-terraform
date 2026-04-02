# =============================================================================
# Módulo: networking
# Crea la VPC, subredes pública/privada, Internet Gateway, NAT Gateway,
# Elastic IP y tablas de ruteo para la arquitectura 3 capas de Innovatech.
# =============================================================================

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Requerido para AWS Session Manager
  enable_dns_support   = true  # Requerido para AWS Session Manager

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# --- Subred Pública (Frontend) ---
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-subnet-public"
    Tier    = "public"
    Project = var.project_name
  }
}

# --- Subred Privada (Backend + Data) ---
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name    = "${var.project_name}-subnet-private"
    Tier    = "private"
    Project = var.project_name
  }
}

# --- Internet Gateway (salida pública para Frontend) ---
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# --- Elastic IP para el NAT Gateway ---
resource "aws_eip" "nat" {
  domain = "vpc"  # Sintaxis moderna (reemplaza vpc = true)

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

# --- NAT Gateway (en subred pública, para que Backend/Data accedan a internet) ---
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name    = "${var.project_name}-nat-gw"
    Project = var.project_name
  }

  # El NAT Gateway necesita el IGW activo antes de crearse
  depends_on = [aws_internet_gateway.main]
}

# --- Tabla de ruteo: Pública → Internet Gateway ---
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

# --- Tabla de ruteo: Privada → NAT Gateway ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-rt-private"
    Project = var.project_name
  }
}

# --- Asociaciones de tablas de ruteo ---
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
