# =============================================================================
# Módulo: compute
# Crea Launch Templates y EC2 instances para las 3 capas en 2 AZs.
# Cada AZ tiene: 1 Frontend (subred pública), 1 Backend, 1 Data (subredes privadas).
# Los Security Groups son compartidos entre AZs (recursos VPC-level).
# =============================================================================

# --- Data Source: Instance Profile pre-existente de AWS Academy ---
data "aws_iam_instance_profile" "lab" {
  name = var.iam_instance_profile
}

# =============================================================================
# LAUNCH TEMPLATES FRONTEND (uno por AZ)
# =============================================================================

resource "aws_launch_template" "frontend" {
  count = length(var.public_subnet_ids)

  name_prefix   = "${var.project_name}-lt-frontend-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.frontend_sg_id]
    subnet_id                   = var.public_subnet_ids[count.index]
  }

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  user_data = filebase64("${path.module}/user_data/frontend.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-frontend-${count.index + 1}"
      Tier    = "frontend"
      Project = var.project_name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name    = "${var.project_name}-frontend-vol-${count.index + 1}"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-lt-frontend-${count.index + 1}"
    Project = var.project_name
  }
}

# =============================================================================
# LAUNCH TEMPLATES BACKEND (uno por AZ)
# =============================================================================

resource "aws_launch_template" "backend" {
  count = length(var.private_backend_subnet_ids)

  name_prefix   = "${var.project_name}-lt-backend-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.backend_sg_id]
    subnet_id                   = var.private_backend_subnet_ids[count.index]
  }

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  user_data = filebase64("${path.module}/user_data/backend.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-backend-${count.index + 1}"
      Tier    = "backend"
      Project = var.project_name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name    = "${var.project_name}-backend-vol-${count.index + 1}"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-lt-backend-${count.index + 1}"
    Project = var.project_name
  }
}

# =============================================================================
# LAUNCH TEMPLATES DATA (uno por AZ)
# =============================================================================

resource "aws_launch_template" "data" {
  count = length(var.private_data_subnet_ids)

  name_prefix   = "${var.project_name}-lt-data-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.data_sg_id]
    subnet_id                   = var.private_data_subnet_ids[count.index]
  }

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  user_data = filebase64("${path.module}/user_data/data.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-data-${count.index + 1}"
      Tier    = "data"
      Project = var.project_name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name    = "${var.project_name}-data-vol-${count.index + 1}"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-lt-data-${count.index + 1}"
    Project = var.project_name
  }
}

# =============================================================================
# EC2 INSTANCES
# =============================================================================

resource "aws_instance" "frontend" {
  count = length(var.public_subnet_ids)

  launch_template {
    id      = aws_launch_template.frontend[count.index].id
    version = aws_launch_template.frontend[count.index].latest_version
  }

  tags = {
    Name    = "${var.project_name}-frontend-${count.index + 1}"
    Tier    = "frontend"
    Project = var.project_name
  }
}

resource "aws_instance" "backend" {
  count = length(var.private_backend_subnet_ids)

  launch_template {
    id      = aws_launch_template.backend[count.index].id
    version = aws_launch_template.backend[count.index].latest_version
  }

  tags = {
    Name    = "${var.project_name}-backend-${count.index + 1}"
    Tier    = "backend"
    Project = var.project_name
  }
}

resource "aws_instance" "data" {
  count = length(var.private_data_subnet_ids)

  launch_template {
    id      = aws_launch_template.data[count.index].id
    version = aws_launch_template.data[count.index].latest_version
  }

  tags = {
    Name    = "${var.project_name}-data-${count.index + 1}"
    Tier    = "data"
    Project = var.project_name
  }
}

# =============================================================================
# ELASTIC IPs — una por instancia Frontend
# Proveen IPs públicas estáticas que no cambian al detener/iniciar las instancias
# =============================================================================

resource "aws_eip" "frontend" {
  count    = length(var.public_subnet_ids)
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip-frontend-${count.index + 1}"
    Tier    = "frontend"
    Project = var.project_name
  }
}

resource "aws_eip_association" "frontend" {
  count         = length(var.public_subnet_ids)
  instance_id   = aws_instance.frontend[count.index].id
  allocation_id = aws_eip.frontend[count.index].id
}
