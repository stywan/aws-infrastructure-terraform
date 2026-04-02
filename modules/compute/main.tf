# =============================================================================
# Módulo: compute
# Crea Launch Templates y EC2 instances para las 3 capas.
# Usa el LabInstanceProfile pre-existente de AWS Academy (no se puede crear IAM).
# =============================================================================

# --- Data Source: Instance Profile pre-existente de AWS Academy ---
data "aws_iam_instance_profile" "lab" {
  name = var.iam_instance_profile
}

# =============================================================================
# LAUNCH TEMPLATES
# Definen la configuración de lanzamiento para cada capa.
# Visibles en: EC2 Console → Launch Templates
# =============================================================================

# --- Launch Template: Frontend ---
resource "aws_launch_template" "frontend" {
  name_prefix   = "${var.project_name}-lt-frontend-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  key_name = var.key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.frontend_sg_id]
    subnet_id                   = var.public_subnet_id
  }

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  user_data = filebase64("${path.module}/user_data/frontend.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-frontend"
      Tier    = "frontend"
      Project = var.project_name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name    = "${var.project_name}-frontend-vol"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-lt-frontend"
    Project = var.project_name
  }
}

# --- Launch Template: Backend ---
resource "aws_launch_template" "backend" {
  name_prefix   = "${var.project_name}-lt-backend-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  key_name = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.backend_sg_id]
    subnet_id                   = var.private_subnet_id
  }

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  user_data = filebase64("${path.module}/user_data/backend.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-backend"
      Tier    = "backend"
      Project = var.project_name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name    = "${var.project_name}-backend-vol"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-lt-backend"
    Project = var.project_name
  }
}

# --- Launch Template: Data ---
resource "aws_launch_template" "data" {
  name_prefix   = "${var.project_name}-lt-data-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  key_name = var.key_name

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.data_sg_id]
    subnet_id                   = var.private_subnet_id
  }

  iam_instance_profile {
    name = data.aws_iam_instance_profile.lab.name
  }

  user_data = filebase64("${path.module}/user_data/data.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "${var.project_name}-data"
      Tier    = "data"
      Project = var.project_name
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name    = "${var.project_name}-data-vol"
      Project = var.project_name
    }
  }

  tags = {
    Name    = "${var.project_name}-lt-data"
    Project = var.project_name
  }
}

# =============================================================================
# EC2 INSTANCES
# Cada instancia referencia su Launch Template.
# =============================================================================

# --- EC2: Frontend (subred pública, IP pública) ---
resource "aws_instance" "frontend" {
  launch_template {
    id      = aws_launch_template.frontend.id
    version = "$Latest"
  }

  tags = {
    Name    = "${var.project_name}-frontend"
    Tier    = "frontend"
    Project = var.project_name
  }
}

# --- EC2: Backend (subred privada, solo accesible desde Frontend) ---
resource "aws_instance" "backend" {
  launch_template {
    id      = aws_launch_template.backend.id
    version = "$Latest"
  }

  tags = {
    Name    = "${var.project_name}-backend"
    Tier    = "backend"
    Project = var.project_name
  }
}

# --- EC2: Data (subred privada, solo accesible desde Backend) ---
resource "aws_instance" "data" {
  launch_template {
    id      = aws_launch_template.data.id
    version = "$Latest"
  }

  tags = {
    Name    = "${var.project_name}-data"
    Tier    = "data"
    Project = var.project_name
  }
}
