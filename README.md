# aws-infrastructure-terraform

Implementación de infraestructura en AWS utilizando Terraform bajo principios de Infrastructure as Code (IaC). Arquitectura de tres capas (Frontend, Backend, Data) en **dos zonas de disponibilidad (Multi-AZ)** para la empresa **Innovatech Chile** — migración Lift & Shift a AWS.

---

## Arquitectura

```
Internet
    │
    ▼
[Internet Gateway]
    │
VPC: 10.0.0.0/16
├── us-east-1a
│   ├── Subred Pública   (10.0.1.0/24)  → EC2 Frontend-1 (EIP: estática) + NAT Gateway-A
│   ├── Subred Backend   (10.0.2.0/24)  → EC2 Backend-1  (IP privada)
│   └── Subred Data      (10.0.3.0/24)  → EC2 Data-1     (IP privada)
│
└── us-east-1b
    ├── Subred Pública   (10.0.4.0/24)  → EC2 Frontend-2 (EIP: estática) + NAT Gateway-B
    ├── Subred Backend   (10.0.5.0/24)  → EC2 Backend-2  (IP privada)
    └── Subred Data      (10.0.6.0/24)  → EC2 Data-2     (IP privada)
```

**Flujo de acceso:** `Internet → Frontend → Backend → Data`

**IPs estáticas (Elastic IPs):** asignadas a las instancias Frontend — no cambian al reiniciar.

**Administración:** AWS Session Manager (las 6 instancias) + SSH opcional (solo Frontend)

---

## Estructura del proyecto

```
├── main.tf                          # Provider AWS + llamadas a módulos
├── variables.tf                     # Variables de entrada (Multi-AZ)
├── outputs.tf                       # IPs, URLs y comandos SSH/SSM
├── terraform.tfvars                 # Valores reales (local, NO se sube al repo)
├── terraform.tfvars.example         # Plantilla de configuración
└── modules/
    ├── networking/                  # VPC, 6 subredes, IGW, 2 NAT Gateways, route tables
    ├── security/                    # Security Groups por capa (compartidos entre AZs)
    └── compute/                     # Launch Templates, EC2 instances, Elastic IPs
        └── user_data/
            ├── frontend.sh          # Instala Docker + Nginx
            ├── backend.sh           # Instala Docker + microservicio Python
            └── data.sh              # Instala Docker + MySQL 8.0 en contenedor
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

Edita `terraform.tfvars` y completa al menos el `ami_id`. Para obtener el AMI más reciente de Amazon Linux 2023 **estándar** (con SSM Agent incluido) en `us-east-1`:

```bash
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
  --query "sort_by(Images,&CreationDate)[-1].ImageId" \
  --output text \
  --region us-east-1
```

> **Importante:** usar el filtro `al2023-ami-2023.*` (con fecha) y NO `al2023-ami-*` para evitar la versión minimal que no incluye SSM Agent preinstalado.

### 2. Inicializar Terraform

```bash
terraform init
```

### 3. Revisar el plan

```bash
terraform plan
```

Se crearán aproximadamente **36 recursos**. Revisa que todo sea correcto antes de aplicar.

### 4. Desplegar la infraestructura

```bash
terraform apply
```

El proceso tarda entre 5 y 8 minutos. El paso más lento es la creación de los 2 NAT Gateways (~2 min cada uno, en paralelo).

### 5. Ver outputs

```bash
terraform output
```

Ejemplo de salida:

```
frontend_public_ips  = ["44.216.157.73", "54.236.68.218"]
web_urls             = ["http://44.216.157.73", "http://54.236.68.218"]
backend_private_ips  = ["10.0.2.135", "10.0.5.210"]
data_private_ips     = ["10.0.3.157", "10.0.6.89"]
ssm_commands = {
  frontend = ["aws ssm start-session --target i-xxx --region us-east-1", ...]
  backend  = ["aws ssm start-session --target i-xxx --region us-east-1", ...]
  data     = ["aws ssm start-session --target i-xxx --region us-east-1", ...]
}
```

### 6. Destruir la infraestructura

```bash
terraform destroy
```

**Importante:** ejecutar siempre al finalizar la sesión de AWS Academy para evitar que los recursos sean eliminados abruptamente por el timeout del lab, lo que puede dejar el `.tfstate` inconsistente.

---

## Sincronización del estado Terraform

### Caso 1: Reiniciaste el lab y los recursos siguen activos

Las credenciales expiran pero los recursos permanecen. Solo actualiza las credenciales y sincroniza el estado:

```bash
# 1. Actualizar ~/.aws/credentials con las nuevas credenciales del lab
# 2. Sincronizar el estado local con AWS (sin crear ni destruir nada)
terraform apply -refresh-only
# 3. Confirmar con "yes" — solo actualiza el tfstate, no toca la infraestructura
```

### Caso 2: El lab expiró y AWS eliminó los recursos

El `.tfstate` tiene IDs de recursos que ya no existen:

```bash
# 1. Borrar el estado viejo
rm terraform.tfstate terraform.tfstate.backup
# 2. Actualizar ami_id en terraform.tfvars (puede haber cambiado)
# 3. Desplegar desde cero
terraform init
terraform apply
```

### Caso 3: Hay cambios en el repo que afectan recursos existentes

Después de un `git pull`, Terraform puede detectar diferencias entre el código nuevo y la infraestructura actual:

```bash
# Ver qué cambiaría
terraform plan
# Si los cambios son esperados, aplicar
terraform apply
```

---

## Verificar conectividad entre capas

### Frontend accesible desde internet

```bash
# Verificar ambos frontends
curl http://44.216.157.73
curl http://54.236.68.218
```

### Conectarse a las instancias via SSM

```bash
# Ver los comandos exactos desde los outputs
terraform output ssm_commands

# Ejemplo Frontend-1
aws ssm start-session --target i-03736d2c588dd1fed --region us-east-1

# Ejemplo Backend-1
aws ssm start-session --target i-0edea2fcf45956bee --region us-east-1
```

### Frontend → Backend (ejecutar dentro del Frontend via SSM)

```bash
# Backend-1 (AZ-A)
curl http://10.0.2.135:8080
# Backend-2 (AZ-B)
curl http://10.0.5.210:8080
```

### Backend → Data (ejecutar dentro del Backend via SSM)

```bash
# Data-1 (AZ-A)
mysql -h 10.0.3.157 -u appuser -p'AppUser2024!' innovatech_db -e "SELECT * FROM products;"
# Data-2 (AZ-B)
mysql -h 10.0.6.89 -u appuser -p'AppUser2024!' innovatech_db -e "SELECT * FROM products;"
```

### Verificar Docker en cualquier instancia

```bash
docker ps
docker logs nginx-frontend    # en Frontend
docker logs backend-service   # en Backend
docker logs mysql-data        # en Data
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
| `availability_zones` | `["us-east-1a","us-east-1b"]` | Las 2 AZs a usar |
| `public_subnet_cidrs` | `["10.0.1.0/24","10.0.4.0/24"]` | Subredes públicas (Frontend) |
| `private_backend_subnet_cidrs` | `["10.0.2.0/24","10.0.5.0/24"]` | Subredes privadas Backend |
| `private_data_subnet_cidrs` | `["10.0.3.0/24","10.0.6.0/24"]` | Subredes privadas Data |
| `instance_type` | `t3.micro` | Tipo de instancia EC2 |
| `ami_id` | *(requerido)* | AMI de Amazon Linux 2023 estándar |
| `key_name` | `null` | Key Pair para SSH (opcional) |
| `iam_instance_profile` | `LabInstanceProfile` | Instance Profile de AWS Academy |

---

## Consideraciones para AWS Academy

1. **Las credenciales expiran cada 4 horas.** Actualiza `~/.aws/credentials` con los valores del panel de Academy antes de cada sesión.

2. **No se pueden crear roles IAM.** El código usa el `LabInstanceProfile` pre-existente. No cambies este valor.

3. **El estado de Terraform (`terraform.tfstate`) no debe subirse al repo.** Está en `.gitignore`. Guárdalo localmente entre sesiones.

4. **Destruye los recursos antes de que termine la sesión.** Si la sesión expira con recursos activos, AWS Academy los elimina sin respetar el estado de Terraform, dejando el `.tfstate` inconsistente. Ver sección de Sincronización.

5. **Los 2 NAT Gateways generan costo doble.** En AWS Academy el crédito es limitado. Considera esto si el lab va a estar activo por muchas horas.

6. **SSM tarda 1-3 minutos** en registrar las instancias después del `terraform apply`. Si falla inmediatamente después, espera y reintenta.

7. **Las Elastic IPs del Frontend son estáticas** — no cambian aunque reinicies el lab o las instancias.

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
| `aws_subnet` | 6 | 2 públicas + 2 backend + 2 data |
| `aws_internet_gateway` | 1 | Salida a internet |
| `aws_eip` (NAT) | 2 | IPs elásticas para NAT Gateways |
| `aws_eip` (Frontend) | 2 | IPs elásticas estáticas para Frontend |
| `aws_eip_association` | 2 | Asociación EIP ↔ Frontend |
| `aws_nat_gateway` | 2 | Uno por AZ |
| `aws_route_table` | 3 | 1 pública + 2 privadas (una por AZ) |
| `aws_route_table_association` | 6 | Asociaciones de subredes |
| `aws_security_group` | 3 | Frontend, Backend, Data |
| `aws_launch_template` | 6 | 2 Frontend + 2 Backend + 2 Data |
| `aws_instance` | 6 | 2 Frontend + 2 Backend + 2 Data |
| **Total** | **~36** | |
