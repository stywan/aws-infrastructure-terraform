# =============================================================================
# Módulo: security
# Define los Security Groups para cada capa de la arquitectura.
# Principio de mínimo privilegio: cada capa solo acepta tráfico del origen
# estrictamente necesario.
#
# Flujo de acceso:
#   Internet → Frontend (80/443/22)
#   Frontend → Backend  (8080)
#   Backend  → Data     (3306)
# =============================================================================

# --- Security Group: Frontend (capa pública) ---
resource "aws_security_group" "frontend" {
  name        = "${var.project_name}-sg-frontend"
  description = "SG Frontend: HTTP/HTTPS desde internet, SSH para administracion"
  vpc_id      = var.vpc_id

  # HTTP desde internet (servidor web Nginx)
  ingress {
    description = "HTTP desde internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS desde internet
  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH para administración directa
  ingress {
    description = "SSH administracion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Todo el tráfico de salida permitido (Docker pulls, yum updates, SSM)
  egress {
    description = "Salida total permitida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-frontend"
    Tier    = "frontend"
    Project = var.project_name
  }
}

# --- Security Group: Backend (capa privada) ---
resource "aws_security_group" "backend" {
  name        = "${var.project_name}-sg-backend"
  description = "SG Backend: microservicio 8080 solo desde Frontend"
  vpc_id      = var.vpc_id

  # Microservicio solo accesible desde el SG del Frontend
  ingress {
    description     = "Microservicio desde Frontend"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  # Todo el tráfico de salida permitido (Docker pulls via NAT, SSM via NAT)
  egress {
    description = "Salida total permitida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-backend"
    Tier    = "backend"
    Project = var.project_name
  }
}

# --- Security Group: Data (capa privada) ---
resource "aws_security_group" "data" {
  name        = "${var.project_name}-sg-data"
  description = "SG Data: MySQL 3306 solo desde Backend"
  vpc_id      = var.vpc_id

  # MySQL solo accesible desde el SG del Backend
  ingress {
    description     = "MySQL desde Backend"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  # Todo el tráfico de salida permitido (yum updates via NAT, SSM via NAT)
  egress {
    description = "Salida total permitida"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-data"
    Tier    = "data"
    Project = var.project_name
  }
}
