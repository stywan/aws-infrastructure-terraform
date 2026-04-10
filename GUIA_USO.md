# Guía de uso — Infraestructura Innovatech Chile en AWS

Esta guía explica paso a paso cómo desplegar, usar y destruir la infraestructura desde cero, incluyendo el workflow de cada sesión de AWS Academy y cómo manejar los casos frecuentes de desincronización de estado.

---

## Índice

1. [Prerequisitos (instalar una sola vez)](#1-prerequisitos-instalar-una-sola-vez)
2. [Configuración inicial del proyecto (primera vez)](#2-configuración-inicial-del-proyecto-primera-vez)
3. [Iniciar sesión en AWS Academy](#3-iniciar-sesión-en-aws-academy)
4. [Desplegar la infraestructura](#4-desplegar-la-infraestructura)
5. [Verificar que todo funciona](#5-verificar-que-todo-funciona)
6. [Conectarse a las instancias](#6-conectarse-a-las-instancias)
7. [Workflow de sesiones siguientes](#7-workflow-de-sesiones-siguientes)
8. [Sincronización del estado Terraform](#8-sincronización-del-estado-terraform)
9. [Destruir la infraestructura](#9-destruir-la-infraestructura)
10. [Solución de problemas](#10-solución-de-problemas)

---

## 1. Prerequisitos (instalar una sola vez)

### Terraform

```bash
# macOS (con Homebrew)
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Verificar instalación
terraform -version
# Debe mostrar: Terraform v1.5.0 o superior
```

> En Windows: descargar el instalador desde https://developer.hashicorp.com/terraform/install

### AWS CLI

```bash
# macOS
brew install awscli

# Verificar instalación
aws --version
# Debe mostrar: aws-cli/2.x.x
```

> En Windows: descargar desde https://aws.amazon.com/cli/

### Plugin de Session Manager (para conectarse via SSM)

```bash
# macOS
brew install --cask session-manager-plugin

# Verificar instalación
session-manager-plugin --version
```

> En Windows: descargar desde https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

### Crear la carpeta de credenciales AWS (si no existe)

```bash
# macOS/Linux
mkdir -p ~/.aws

# Windows (PowerShell)
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.aws"
```

---

## 2. Configuración inicial del proyecto (primera vez)

### Clonar el repositorio

```bash
git clone <url-del-repo>
cd aws-infrastructure-terraform
git checkout feature/pipeline
```

### Crear el archivo de variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

> `terraform.tfvars` está en `.gitignore` — es un archivo **local**, nunca se sube al repo.

### Obtener el AMI ID de Amazon Linux 2023

Con las credenciales de AWS Academy ya configuradas (ver sección 3), ejecuta:

```bash
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
  --query "sort_by(Images,&CreationDate)[-1].ImageId" \
  --output text \
  --region us-east-1
```

> **Importante:** usar `al2023-ami-2023.*` (con fecha) y NO `al2023-ami-*` para evitar la versión minimal que no incluye SSM Agent.

Copia el resultado y pégalo en `terraform.tfvars`:

```hcl
ami_id = "ami-0abcdef1234567890"
```

### (Opcional) Configurar Key Pair para SSH

Si quieres acceso SSH además de SSM:

1. Ve a **EC2 Console → Key Pairs → Create key pair**
2. Nombre: `vockey`, tipo RSA, formato `.pem`
3. Descarga el `.pem` y guárdalo en `~/.ssh/`
4. Dale permisos correctos:
   ```bash
   chmod 400 ~/.ssh/vockey.pem
   ```
5. Descomenta en `terraform.tfvars`:
   ```hcl
   key_name = "vockey"
   ```

> Sin key pair, SSM Session Manager funciona perfectamente para las 6 instancias.

### Inicializar Terraform (solo la primera vez o al cambiar providers)

```bash
terraform init
```

---

## 3. Iniciar sesión en AWS Academy

**Este paso es obligatorio al inicio de cada sesión** porque las credenciales expiran cada 4 horas.

1. Ingresa a **AWS Academy → Learner Lab**
2. Haz clic en **Start Lab** y espera que el círculo se ponga verde
3. Haz clic en **AWS Details** → **AWS CLI**
4. Copia el bloque de credenciales:
   ```
   [default]
   aws_access_key_id=ASIA...
   aws_secret_access_key=...
   aws_session_token=...
   ```
5. Pégalo en `~/.aws/credentials`:
   ```bash
   # macOS/Linux
   nano ~/.aws/credentials

   # Windows
   notepad "$env:USERPROFILE\.aws\credentials"
   ```

### Verificar que las credenciales funcionan

```bash
aws sts get-caller-identity
```

Debe mostrar tu Account ID y el rol `LabRole`. Si ves error de autenticación, repite el paso anterior.

---

## 4. Desplegar la infraestructura

### Ver qué se va a crear

```bash
terraform plan
```

Debes ver **~36 recursos a crear**. Revisa que no haya errores.

### Aplicar

```bash
terraform apply
```

Escribe `yes` cuando lo pida.

**Tiempos aproximados:**

| Recurso | Tiempo |
|---|---|
| VPC, subredes, SGs | ~30 segundos |
| 2 NAT Gateways (en paralelo) | ~2-3 minutos |
| EC2 instances + EIPs | ~1-2 minutos |
| **Total** | **~5-8 minutos** |

### Ver los outputs al finalizar

```bash
terraform output
```

Guarda estos valores — los necesitarás para conectarte:

```
frontend_public_ips = ["44.x.x.x", "54.x.x.x"]
web_urls            = ["http://44.x.x.x", "http://54.x.x.x"]
backend_private_ips = ["10.0.2.x", "10.0.5.x"]
data_private_ips    = ["10.0.3.x", "10.0.6.x"]
ssm_commands = {
  frontend = ["aws ssm start-session --target i-xxx ...", ...]
  backend  = ["aws ssm start-session --target i-xxx ...", ...]
  data     = ["aws ssm start-session --target i-xxx ...", ...]
}
```

> El `terraform.tfstate` se guarda localmente. **No lo borres** entre sesiones — es el mapa que Terraform usa para saber qué recursos ya existen en AWS.

---

## 5. Verificar que todo funciona

Espera **3-5 minutos** después del `terraform apply` para que los scripts de user data terminen.

### Frontend accesible desde internet

```bash
# Abrir en el navegador o con curl (usar las IPs del output)
curl http://44.x.x.x
# Debe mostrar el HTML de la página Innovatech Chile
```

### Microservicio Backend respondiendo

Desde SSM en el Backend (ver sección 6):
```bash
curl http://localhost:8080
# Respuesta esperada: {"service": "Innovatech Backend", "status": "healthy", ...}
```

### Frontend puede llegar al Backend

Desde SSM en el Frontend:
```bash
curl http://<backend_private_ip>:8080
```

### Backend puede llegar a la base de datos

Desde SSM en el Backend:
```bash
mysql -h <data_private_ip> -u appuser -p'AppUser2024!' innovatech_db \
  -e "SELECT * FROM products;"
# Debe mostrar 3 filas de productos
```

### Verificar Docker en cada instancia

```bash
docker ps
# Frontend: contenedor nginx-frontend
# Backend:  contenedor backend-service
# Data:     contenedor mysql-data
```

---

## 6. Conectarse a las instancias

### Via AWS Session Manager (recomendado)

```bash
# Ver los comandos exactos desde los outputs
terraform output ssm_commands

# Conectarse (ejemplo Frontend-1)
aws ssm start-session --target i-0abc123def456 --region us-east-1
```

> SSM tarda **1-3 minutos** en registrar las instancias después del apply. Si falla, espera y reintenta.

Una vez dentro, cambiar a ec2-user:
```bash
sudo su - ec2-user
```

### Via SSH (solo Frontend, requiere key pair)

```bash
ssh -i ~/.ssh/vockey.pem ec2-user@<frontend_public_ip>
```

### Ver logs de instalación

```bash
sudo cat /var/log/user-data.log
```

---

## 7. Workflow de sesiones siguientes

Las credenciales de AWS Academy duran **4 horas**. Al iniciar una nueva sesión:

```bash
# 1. Actualizar credenciales (ver sección 3)
nano ~/.aws/credentials

# 2. Verificar que funcionan
aws sts get-caller-identity

# 3. Sincronizar el estado Terraform con AWS (sin cambiar nada)
terraform apply -refresh-only
# → escribir "yes" para actualizar el tfstate local

# 4. Ver el estado actual
terraform output
```

---

## 8. Sincronización del estado Terraform

Este es uno de los temas más importantes al trabajar con AWS Academy. El archivo `.tfstate` es el registro local de Terraform sobre qué recursos existen en AWS. Puede desincronizarse en varios escenarios.

---

### Caso A: Reiniciaste el lab — los recursos siguen activos

Las credenciales expiran pero los recursos permanecen en AWS. Terraform puede detectar diferencias menores (IPs dinámicas reasignadas, etc.).

```bash
# 1. Actualizar credenciales en ~/.aws/credentials

# 2. Sincronizar sin tocar infraestructura
terraform apply -refresh-only

# 3. Cuando pregunte "Would you like to update the Terraform state?"
#    escribir "yes" — solo actualiza el tfstate local, NO modifica AWS

# 4. Verificar que todo está en orden
terraform plan
# Debe mostrar: No changes o cambios mínimos esperados
```

---

### Caso B: El lab expiró y AWS eliminó todos los recursos

El `.tfstate` tiene IDs de recursos que ya no existen en AWS.

```bash
# 1. Eliminar el estado viejo
rm terraform.tfstate terraform.tfstate.backup

# 2. Actualizar el ami_id en terraform.tfvars con el nuevo AMI
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
  --query "sort_by(Images,&CreationDate)[-1].ImageId" \
  --output text \
  --region us-east-1

# 3. Desplegar desde cero
terraform init   # solo si es necesario
terraform apply
```

---

### Caso C: Hay cambios en el repo que modifican recursos existentes

Después de un `git pull`, Terraform puede detectar diferencias entre el código nuevo y la infraestructura que está corriendo.

```bash
# 1. Traer los últimos cambios del repo
git pull origin feature/pipeline

# 2. Ver exactamente qué cambiaría
terraform plan
# Revisar el output:
#   ~ update in-place  → instancia se actualiza sin recrearse
#   -/+ destroy/create → instancia se recrea (ojo: pierde datos)

# 3. Si los cambios son esperados, aplicar
terraform apply
```

> Si el plan muestra `-/+` en instancias Data, significa que MySQL se recreará y perderá los datos de la sesión. Para un entorno de lab esto es aceptable.

---

### Caso D: PC nuevo — no tengo el tfstate

Si perdiste el `.tfstate` pero los recursos siguen activos en AWS:

```bash
# Opción 1 (recomendada): destruir los recursos desde la consola AWS manualmente
# y luego hacer terraform apply desde cero

# Opción 2: sincronizar con terraform import (avanzado, recurso por recurso)
# No recomendado para el lab — mejor destruir y recrear
```

---

## 9. Destruir la infraestructura

**Hacer siempre antes de cerrar el lab** para evitar inconsistencias en el `.tfstate`.

```bash
terraform destroy
```

Escribe `yes` cuando lo pida. Tarda ~3-5 minutos.

Verifica que se eliminó todo:
```bash
terraform show
# Debe mostrar: No state.
```

---

## 10. Solución de problemas

### Error: `ExpiredTokenException` o `InvalidClientTokenId`

**Causa:** Credenciales de AWS Academy expiradas.

**Solución:** Actualizar `~/.aws/credentials` con las nuevas credenciales del panel de Academy (sección 3).

---

### Error: `NoRegion` al correr comandos AWS CLI

**Causa:** No se especificó la región.

**Solución:** Agregar `--region us-east-1` al comando, o configurar la región por defecto:
```bash
aws configure set region us-east-1
```

---

### SSM no conecta después del apply

**Causa:** El agente SSM todavía está arrancando (normal los primeros 1-3 minutos).

**Solución:** Esperar y reintentar. Para verificar cuáles instancias ya están registradas:
```bash
aws ssm describe-instance-information \
  --region us-east-1 \
  --query "InstanceInformationList[*].{ID:InstanceId,Status:PingStatus}" \
  --output table
# Esperar a que todas aparezcan como "Online"
```

---

### El Frontend no carga en el navegador

**Causa 1:** Los scripts de user data todavía están corriendo (Docker pull puede tardar).

**Solución:** Esperar 3-5 minutos y recargar.

**Causa 2:** El script de user data falló.

**Solución:** Conectarse via SSM y revisar:
```bash
sudo cat /var/log/user-data.log
```

---

### MySQL no responde desde el Backend

**Causa:** El contenedor Docker de MySQL en la instancia Data todavía está iniciando.

**Solución:** Conectarse a la instancia Data via SSM y verificar:
```bash
sudo cat /var/log/user-data.log   # ver si completó
docker ps                          # ver si el contenedor mysql-data está corriendo
docker logs mysql-data             # ver logs de MySQL
```

---

### `terraform apply` falla con `ResourceAlreadyExists`

**Causa:** El lab anterior expiró con recursos activos y el `.tfstate` quedó desincronizado.

**Solución:**
```bash
# Intentar destruir primero
terraform destroy

# Si falla, borrar el tfstate y desplegar desde cero
rm terraform.tfstate terraform.tfstate.backup
terraform apply
```

---

### `terraform plan` muestra muchos cambios inesperados después de un `git pull`

**Causa:** Alguien del equipo modificó scripts de user data u otros archivos en el repo.

**Solución:** Revisar el plan con cuidado:
```bash
terraform plan
# Los cambios ~ (update in-place) son seguros
# Los cambios -/+ (destroy+create) recrean la instancia
```

Si no quieres aplicar los cambios ahora, simplemente no hagas `terraform apply`.

---

### Error: `data.aws_iam_instance_profile.lab: no matching IAM instance profile`

**Causa:** El `LabInstanceProfile` no existe en esta cuenta de AWS Academy.

**Solución:**
```bash
aws iam list-instance-profiles --query "InstanceProfiles[].InstanceProfileName"
```

Actualizar en `terraform.tfvars`:
```hcl
iam_instance_profile = "<nombre-exacto>"
```
