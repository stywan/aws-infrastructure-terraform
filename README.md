# aws-infrastructure-terraform

Implementación de infraestructura en AWS utilizando Terraform bajo principios de Infrastructure as Code (IaC). Arquitectura de tres capas (Frontend, Backend, Data) para la empresa **Innovatech Chile** — migración Lift & Shift a AWS.


---

## Arquitectura

```
Internet
    │
    ▼
[Internet Gateway]
    │
VPC: 10.0.0.0/16
├── Subred Pública (10.0.1.0/24)
│   ├── EC2 Frontend  — Nginx en Docker (puerto 80/443)
│   └── NAT Gateway   — salida a internet para la subred privada
│
└── Subred Privada (10.0.2.0/24)
    ├── EC2 Backend   — Microservicio Python en Docker (puerto 8080)
    └── EC2 Data      — MySQL 8.0 (puerto 3306)
```

**Flujo de acceso:** `Internet → Frontend → Backend → Data`

**Administración:** SSH (Frontend) + AWS Session Manager (las 3 instancias)

---

## Estructura del proyecto

```
├── main.tf                          # Provider AWS + llamadas a módulos
├── variables.tf                     # Variables de entrada
├── outputs.tf                       # IPs, URLs y comandos SSH/SSM
├── terraform.tfvars.example         # Plantilla de configuración (copiar a terraform.tfvars)
└── modules/
    ├── networking/                  # VPC, subredes, IGW, NAT Gateway, route tables
    ├── security/                    # Security Groups por capa
    └── compute/                     # Launch Templates, instancias EC2 y user data scripts
        └── user_data/
            ├── frontend.sh          # Instala Docker + Nginx
            ├── backend.sh           # Instala Docker + microservicio Python
            └── data.sh              # Instala Docker + MySQL 8.0
```

---

## Prerequisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- AWS CLI configurado con credenciales válidas
- Cuenta **AWS Academy (Learner Lab)** activa
- (Opcional) Key Pair creado en la consola EC2 para acceso SSH

---

## Uso

### 1. Configurar variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` y completa al menos el `ami_id`. Para obtener el AMI más reciente de Amazon Linux 2023 en `us-east-1`:

```bash
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query "sort_by(Images,&CreationDate)[-1].ImageId" \
  --output text
```

### 2. Inicializar Terraform

```bash
terraform init
```

### 3. Revisar el plan

```bash
terraform plan
```

Se crearán aproximadamente **20 recursos**. Revisa que todo sea correcto antes de aplicar.

### 4. Desplegar la infraestructura

```bash
terraform apply
```

El proceso tarda entre 3 y 5 minutos. El paso más lento es la creación del NAT Gateway (~2 min).

### 5. Ver outputs

```bash
terraform output
```

Ejemplo de salida:

```
frontend_public_ip  = "54.x.x.x"
web_url             = "http://54.x.x.x"
ssm_frontend        = "aws ssm start-session --target i-xxxxxxxxx --region us-east-1"
ssm_backend         = "aws ssm start-session --target i-xxxxxxxxx --region us-east-1"
ssm_data            = "aws ssm start-session --target i-xxxxxxxxx --region us-east-1"
backend_private_ip  = "10.0.2.x"
data_private_ip     = "10.0.2.x"
```

### 6. Destruir la infraestructura

```bash
terraform destroy
```

**Importante:** ejecutar siempre al finalizar la sesión de AWS Academy para evitar que los recursos sean eliminados abruptamente por el timeout del lab.

---

## Verificar conectividad entre capas

### Frontend accesible desde internet
```bash
curl http://$(terraform output -raw frontend_public_ip)
```

### Conectarse a las instancias via SSM
```bash
# Frontend
aws ssm start-session --target $(terraform output -raw frontend_instance_id) --region us-east-1

# Backend (desde cualquier terminal con credenciales)
aws ssm start-session --target $(terraform output -raw backend_instance_id) --region us-east-1

# Data
aws ssm start-session --target $(terraform output -raw data_instance_id) --region us-east-1
```

### Frontend → Backend (ejecutar dentro del Frontend via SSM)
```bash
curl http://<backend_private_ip>:8080
```

### Backend → Data (ejecutar dentro del Backend via SSM)
```bash
mysql -h <data_private_ip> -u appuser -p'AppUser2024!' innovatech_db -e "SELECT * FROM products;"
```

### Verificar Docker en cualquier instancia
```bash
docker ps
docker logs nginx-frontend    # en Frontend
docker logs backend-service   # en Backend
```

### Verificar logs de user data (si algo falla)
```bash
sudo cat /var/log/user-data.log
```

---

## Variables

| Variable | Default | Descripción |
|---|---|---|
| `aws_region` | `us-east-1` | Región AWS (no cambiar en Academy) |
| `project_name` | `innovatech` | Prefijo para todos los recursos |
| `vpc_cidr` | `10.0.0.0/16` | CIDR de la VPC |
| `public_subnet_cidr` | `10.0.1.0/24` | Subred pública (Frontend) |
| `private_subnet_cidr` | `10.0.2.0/24` | Subred privada (Backend + Data) |
| `availability_zone` | `us-east-1a` | AZ para ambas subredes |
| `instance_type` | `t3.micro` | Tipo de instancia EC2 |
| `ami_id` | *(requerido)* | AMI de Amazon Linux 2023 |
| `key_name` | `null` | Key Pair para SSH (opcional) |
| `iam_instance_profile` | `LabInstanceProfile` | Instance Profile de AWS Academy |

---

## Consideraciones para AWS Academy

1. **Las credenciales expiran cada 4 horas.** Actualiza `~/.aws/credentials` con los valores del panel de Academy antes de cada sesión.

2. **No se pueden crear roles IAM.** El código usa el `LabInstanceProfile` pre-existente mediante un `data source`. No intentes cambiar `iam_instance_profile` a un valor que no exista en tu cuenta.

3. **El estado de Terraform (`terraform.tfstate`) no persiste entre sesiones** si destruyes y recreas los recursos. El archivo `.tfstate` está en `.gitignore` por seguridad — guárdalo localmente entre sesiones si necesitas hacer cambios incrementales.

4. **Destruye los recursos antes de que termine la sesión** del lab. Si la sesión expira con recursos activos, AWS Academy los elimina sin respetar el estado de Terraform, lo que puede dejar el `.tfstate` inconsistente.

5. **El NAT Gateway genera costo.** En AWS Academy el crédito es limitado. Si no necesitas que las instancias privadas accedan a internet (después de la instalación inicial), considera que el NAT Gateway seguirá corriendo mientras el lab esté activo.

6. **SSM tarda 1-3 minutos** en registrar las instancias después de `terraform apply`. Si el comando `aws ssm start-session` falla inmediatamente después del apply, espera un momento y vuelve a intentarlo.

---

## Security Groups (resumen)

| SG | Puerto | Protocolo | Origen |
|---|---|---|---|
| `sg-frontend` | 80 | TCP | `0.0.0.0/0` (internet) |
| `sg-frontend` | 443 | TCP | `0.0.0.0/0` (internet) |
| `sg-frontend` | 22 | TCP | `0.0.0.0/0` (SSH admin) |
| `sg-backend` | 8080 | TCP | `sg-frontend` (solo Frontend) |
| `sg-data` | 3306 | TCP | `sg-backend` (solo Backend) |

---

## Recursos creados por `terraform apply`

| Recurso | Cantidad | Descripción |
|---|---|---|
| `aws_vpc` | 1 | VPC principal |
| `aws_subnet` | 2 | Pública + Privada |
| `aws_internet_gateway` | 1 | Salida a internet |
| `aws_eip` | 1 | IP elástica para NAT |
| `aws_nat_gateway` | 1 | Salida para subred privada |
| `aws_route_table` | 2 | Pública + Privada |
| `aws_route_table_association` | 2 | Asociaciones de subredes |
| `aws_security_group` | 3 | Frontend, Backend, Data |
| `aws_launch_template` | 3 | Frontend, Backend, Data |
| `aws_instance` | 3 | Frontend, Backend, Data |
| **Total** | **20** | |
