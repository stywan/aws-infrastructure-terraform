#!/bin/bash
# =============================================================================
# User Data: Frontend (capa pública)
# - Aplica actualizaciones de seguridad
# - Instala Docker y Git
# - Lanza Nginx en Docker en puerto 80
# Log: /var/log/user-data.log
# =============================================================================
set -e
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "============================================"
echo "  Innovatech Chile - Frontend User Data"
echo "  $(date)"
echo "============================================"

# --- 1. Actualizaciones de seguridad ---
echo "[1/4] Aplicando actualizaciones del sistema..."
yum update -y
echo "  -> Actualizaciones aplicadas"

# --- 2. Instalar Docker y Git ---
echo "[2/4] Instalando Docker y Git..."
yum install -y docker git
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
echo "  -> Docker $(docker --version) instalado"
echo "  -> Git $(git --version) instalado"

# --- 3. Crear página web personalizada ---
echo "[3/4] Creando contenido web..."
mkdir -p /home/ec2-user/www

cat > /home/ec2-user/www/index.html << 'HTML'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Innovatech Chile - Frontend</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
    h1 { color: #232f3e; }
    .badge { background: #ff9900; color: white; padding: 4px 10px; border-radius: 4px; font-size: 0.9em; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    td, th { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background: #232f3e; color: white; }
  </style>
</head>
<body>
  <h1>Innovatech Chile <span class="badge">Frontend</span></h1>
  <p>Prueba de Concepto (POC) - Migración Lift &amp; Shift a AWS</p>
  <p>ISY1101 - Introducción a Herramientas DevOps</p>
  <table>
    <tr><th>Capa</th><th>Tecnología</th><th>Acceso</th></tr>
    <tr><td>Frontend</td><td>Nginx (Docker)</td><td>Internet → Puerto 80/443</td></tr>
    <tr><td>Backend</td><td>Python Microservicio (Docker)</td><td>Solo desde Frontend → Puerto 8080</td></tr>
    <tr><td>Data</td><td>MySQL 8.0</td><td>Solo desde Backend → Puerto 3306</td></tr>
  </table>
</body>
</html>
HTML

# --- 4. Lanzar Nginx en Docker ---
echo "[4/4] Lanzando contenedor Nginx en puerto 80..."
docker run -d \
  --name nginx-frontend \
  --restart unless-stopped \
  -p 80:80 \
  -v /home/ec2-user/www/index.html:/usr/share/nginx/html/index.html:ro \
  nginx:alpine

echo "============================================"
echo "  Frontend listo. Nginx corriendo en :80"
echo "  Verificar: curl http://localhost"
echo "  Log completo: /var/log/user-data.log"
echo "============================================"
