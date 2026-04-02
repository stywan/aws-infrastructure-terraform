# Guía de uso — Infraestructura Innovatech Chile en AWS

Esta guía explica paso a paso cómo desplegar, usar y destruir la infraestructura desde cero, incluyendo el workflow de cada sesión de AWS Academy.

---

## Índice

1. [Prerequisitos (instalar una sola vez)](#1-prerequisitos-instalar-una-sola-vez)
2. [Configuración inicial del proyecto (primera vez)](#2-configuración-inicial-del-proyecto-primera-vez)
3. [Iniciar sesión en AWS Academy](#3-iniciar-sesión-en-aws-academy)
4. [Desplegar la infraestructura](#4-desplegar-la-infraestructura)
5. [Verificar que todo funciona](#5-verificar-que-todo-funciona)
6. [Conectarse a las instancias](#6-conectarse-a-las-instancias)
7. [Workflow de sesiones siguientes](#7-workflow-de-sesiones-siguientes)
8. [Destruir la infraestructura](#8-destruir-la-infraestructura)
9. [Solución de problemas](#9-solución-de-problemas)

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

### Plugin de Session Manager (para conectarse via SSM)

```bash
# macOS
brew install --cask session-manager-plugin

# Verificar instalación
session-manager-plugin --version
```

> En Windows: descargar desde https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

---

## 2. Configuración inicial del proyecto (primera vez)

### Clonar el repositorio

```bash
git clone <url-del-repo>
cd aws-infrastructure-terraform
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
  --filters "Name=name,Values=al2023-ami-*-x86_64" "Name=state,Values=available" \
  --query "sort_by(Images,&CreationDate)[-1].ImageId" \
  --output text
  --region us-east-1
```

Copia el resultado (algo como `ami-0abcdef1234567890`) y pégalo en `terraform.tfvars`:

```hcl
ami_id = "ami-0abcdef1234567890"
```

### (Opcional) Configurar Key Pair para SSH

Si quieres acceso SSH además de SSM:

1. Ve a **EC2 Console → Key Pairs → Create key pair**
2. Nombre: `vockey` (o el que prefieras), tipo RSA, formato `.pem`
3. Descarga el archivo `.pem` y guárdalo en `~/.ssh/`
4. Dale permisos correctos:
   ```bash
   chmod 400 ~/.ssh/vockey.pem
   ```
5. Descomenta y completa en `terraform.tfvars`:
   ```hcl
   key_name = "vockey"
   ```

> Sin key pair, puedes usar SSM Session Manager para conectarte a las 3 instancias sin problema.

### Inicializar Terraform (solo la primera vez o al cambiar providers)

```bash
terraform init
```

Verás que descarga el provider de AWS. Solo necesitas hacer esto una vez, a menos que cambies la versión del provider.

---

## 3. Iniciar sesión en AWS Academy

**Este paso es obligatorio al inicio de cada sesión** porque las credenciales de AWS Academy expiran cada 4 horas.

1. Ingresa a **AWS Academy → Learner Lab**
2. Haz clic en **Start Lab** y espera que el círculo se ponga verde
3. Haz clic en **AWS Details** → **AWS CLI**
4. Copia el bloque de credenciales que aparece:
   ```
   [default]
   aws_access_key_id=ASIA...
   aws_secret_access_key=...
   aws_session_token=...
   ```
5. Pégalo reemplazando el contenido de `~/.aws/credentials`:
   ```bash
   # Abrir el archivo de credenciales
   nano ~/.aws/credentials
   # (pegar y guardar con Ctrl+O, Enter, Ctrl+X)
   ```

### Verificar que las credenciales funcionan

```bash
aws sts get-caller-identity
```

Debes ver tu Account ID y el rol `LabRole`. Si ves un error de autenticación, repite el paso anterior.

---

## 4. Desplegar la infraestructura

### Ver qué se va a crear

```bash
terraform plan
```

Debes ver **20 recursos a crear**. Revisa que no haya errores antes de continuar.

### Aplicar

```bash
terraform apply
```

Escribe `yes` cuando lo pida y presiona Enter.

**Tiempos aproximados:**
| Recurso | Tiempo |
|---|---|
| VPC, subredes, SGs | ~30 segundos |
| NAT Gateway | ~2 minutos |
| EC2 instances | ~1 minuto |
| **Total** | **~3-5 minutos** |

### Ver los outputs al finalizar

```bash
terraform output
```

Guarda estos valores — los necesitarás para conectarte y verificar la infraestructura:

```
frontend_public_ip  = "54.x.x.x"
web_url             = "http://54.x.x.x"
ssm_frontend        = "aws ssm start-session --target i-xxxxxxxxx --region us-east-1"
ssm_backend         = "aws ssm start-session --target i-xxxxxxxxx --region us-east-1"
ssm_data            = "aws ssm start-session --target i-xxxxxxxxx --region us-east-1"
backend_private_ip  = "10.0.2.x"
data_private_ip     = "10.0.2.x"
```

> El `terraform.tfstate` se guarda localmente y está en `.gitignore`. **No lo borres** entre sesiones — es el mapa que Terraform usa para saber qué recursos ya existen.

---

## 5. Verificar que todo funciona

Espera 2-3 minutos después del `terraform apply` para que los user data scripts terminen de instalar Docker, MySQL, etc.

### Frontend accesible desde internet

```bash
curl http://$(terraform output -raw frontend_public_ip)
# Debes ver el HTML de la página de Innovatech Chile
```

O abre directamente en el navegador: `http://<frontend_public_ip>`

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
# Misma respuesta JSON del microservicio
```

### Backend puede llegar a la base de datos

Desde SSM en el Backend:
```bash
mysql -h <data_private_ip> -u appuser -p'AppUser2024!' innovatech_db \
  -e "SELECT * FROM products;"
# Debes ver 3 filas de productos
```

### Verificar que Docker está corriendo en cada instancia

```bash
docker ps
# Frontend: debe mostrar el contenedor nginx-frontend
# Backend:  debe mostrar el contenedor backend-service
# Data:     puede no tener contenedores (MySQL se instaló directamente)
```

---

## 6. Conectarse a las instancias

### Via AWS Session Manager (recomendado, no requiere key pair)

```bash
# Copiar el comando exacto desde los outputs de Terraform
terraform output ssm_frontend
terraform output ssm_backend
terraform output ssm_data

# Ejemplo de conexión al Frontend
aws ssm start-session --target i-0abc123def456 --region us-east-1
```

> SSM tarda **1-3 minutos** en registrar las instancias después del `terraform apply`. Si falla, espera un momento y vuelve a intentar.

Una vez dentro de la sesión SSM, cambiar a ec2-user:
```bash
sudo su - ec2-user
```

### Via SSH (solo Frontend, requiere key pair configurado)

```bash
# El output de Terraform te da el comando exacto
terraform output ssh_frontend

# O manualmente:
ssh -i ~/.ssh/vockey.pem ec2-user@<frontend_public_ip>
```

### Ver logs de instalación (si algo no funciona)

```bash
sudo cat /var/log/user-data.log
```

---

## 7. Workflow de sesiones siguientes

Las credenciales de AWS Academy duran **4 horas**. En cada nueva sesión:

```bash
# 1. Actualizar credenciales en ~/.aws/credentials (ver sección 3)

# 2. Verificar que funcionan
aws sts get-caller-identity

# 3. Si destruiste los recursos al cerrar la sesión anterior, volver a desplegar
terraform apply

# 4. Si los recursos siguen activos (misma sesión de lab), solo verificar
terraform output
```

> Si el lab expiró con recursos activos, el `.tfstate` puede quedar desincronizado. En ese caso ejecuta `terraform destroy` (ignorará los errores de recursos que ya no existen) y luego `terraform apply` para empezar limpio.

---

## 8. Destruir la infraestructura

**Hacer siempre antes de cerrar el lab** para evitar que AWS Academy elimine los recursos abruptamente y deje el estado de Terraform inconsistente.

```bash
terraform destroy
```

Escribe `yes` cuando lo pida. Tarda ~2-3 minutos.

Verifica que se eliminaron todos los recursos:
```bash
terraform show
# Debe mostrar: No state. (estado vacío)
```

---

## 9. Solución de problemas

### Error: `ExpiredTokenException` o `InvalidClientTokenId`

**Causa:** Las credenciales de AWS Academy expiraron.

**Solución:** Actualizar `~/.aws/credentials` con las nuevas credenciales del panel de Academy (sección 3).

---

### SSM no conecta después del apply

**Causa:** El agente SSM en la instancia todavía está arrancando (normal los primeros 1-3 minutos).

**Solución:** Esperar 2-3 minutos y volver a intentar. Si sigue fallando después de 5 minutos:

```bash
# Verificar que la instancia tiene el LabInstanceProfile asignado
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=innovatech" \
  --query "Reservations[].Instances[].{ID:InstanceId,Profile:IamInstanceProfile.Arn,State:State.Name}"
```

---

### El Frontend no carga en el navegador

**Causa 1:** Los user data scripts todavía están corriendo (Docker pull de Nginx puede tardar).

**Solución:** Esperar 2-3 minutos y recargar.

**Causa 2:** El script de user data falló.

**Solución:** Conectarse via SSM y revisar el log:
```bash
sudo cat /var/log/user-data.log
# Buscar líneas con "error" o donde se cortó la ejecución
```

---

### MySQL no responde desde el Backend

**Causa:** El script de user data de la instancia Data todavía está ejecutándose o falló.

**Solución:** Conectarse a la instancia Data via SSM y verificar:

```bash
sudo cat /var/log/user-data.log   # ver si completó
sudo systemctl status mysqld       # ver estado de MySQL
sudo journalctl -u mysqld -n 50    # ver logs de MySQL
```

---

### `terraform apply` falla con `ResourceAlreadyExists`

**Causa:** El lab anterior expiró con recursos activos y el `.tfstate` quedó desincronizado.

**Solución:**
```bash
# Intentar destruir primero (ignorará errores de recursos que ya no existen)
terraform destroy

# Si terraform destroy falla, importar el estado existente o limpiar manualmente desde la consola AWS
# Luego volver a aplicar
terraform apply
```

---

### Error: `data.aws_iam_instance_profile.lab: no matching IAM instance profile`

**Causa:** El `LabInstanceProfile` no existe en esta cuenta de AWS Academy.

**Solución:** Verificar el nombre exacto del profile disponible:
```bash
aws iam list-instance-profiles --query "InstanceProfiles[].InstanceProfileName"
```

Actualizar el valor en `terraform.tfvars`:
```hcl
iam_instance_profile = "<nombre-exacto-del-profile>"
```
