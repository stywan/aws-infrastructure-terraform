#!/bin/bash
# =============================================================================
# User Data: Data (capa privada)
# - Aplica actualizaciones de seguridad
# - Instala Docker y Git
# - Instala MySQL 8.0 via yum (mysql-server en Amazon Linux 2023)
# - Crea base de datos innovatech_db con tabla y datos de ejemplo
# Log: /var/log/user-data.log
# =============================================================================
set -e
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "============================================"
echo "  Innovatech Chile - Data Tier User Data"
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

# --- 3. Instalar MySQL 8.0 ---
echo "[3/4] Instalando MySQL 8.0..."
yum install -y mysql-server
systemctl start mysqld
systemctl enable mysqld
echo "  -> MySQL instalado y servicio iniciado"

# Esperar a que MySQL esté listo para aceptar conexiones
echo "  -> Esperando que MySQL esté listo..."
for i in {1..30}; do
  if mysqladmin ping --silent 2>/dev/null; then
    echo "  -> MySQL listo después de ${i}s"
    break
  fi
  sleep 1
done

# --- 4. Configurar base de datos ---
echo "[4/4] Configurando base de datos innovatech_db..."

# Amazon Linux 2023 con mysql-server puede arrancar sin contraseña o con temp password
TEMP_PASS=$(grep 'temporary password' /var/log/mysqld.log 2>/dev/null | awk '{print $NF}' | tail -1)

if [ -n "$TEMP_PASS" ]; then
  echo "  -> Contraseña temporal encontrada, cambiando..."
  mysql --connect-expired-password -u root -p"${TEMP_PASS}" << 'SQLEOF'
ALTER USER 'root'@'localhost' IDENTIFIED BY 'InnovatechRoot2024!';
SQLEOF
  ROOT_PASS="InnovatechRoot2024!"
else
  echo "  -> MySQL sin contraseña inicial, configurando..."
  # En algunas versiones de AL2023, mysql arranca sin contraseña
  mysql -u root << 'SQLEOF'
ALTER USER 'root'@'localhost' IDENTIFIED BY 'InnovatechRoot2024!';
SQLEOF
  ROOT_PASS="InnovatechRoot2024!"
fi

# Crear base de datos, usuario de aplicación y tabla inicial
mysql -u root -p"${ROOT_PASS}" << 'SQLEOF'
-- Base de datos principal
CREATE DATABASE IF NOT EXISTS innovatech_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Usuario para la aplicación (acceso desde Backend)
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY 'AppUser2024!';
GRANT ALL PRIVILEGES ON innovatech_db.* TO 'appuser'@'%';
FLUSH PRIVILEGES;

-- Tabla de productos de ejemplo
USE innovatech_db;
CREATE TABLE IF NOT EXISTS products (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  description TEXT,
  price       DECIMAL(10,2) DEFAULT 0.00,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Datos iniciales para verificar conectividad en la presentación
INSERT INTO products (name, description, price) VALUES
  ('Producto Alpha', 'Primer producto de Innovatech Chile', 99.99),
  ('Producto Beta',  'Segundo producto de Innovatech Chile', 149.99),
  ('Producto Gamma', 'Tercer producto de Innovatech Chile', 199.99);

SELECT 'Base de datos innovatech_db configurada correctamente' AS status;
SELECT COUNT(*) AS total_productos FROM products;
SQLEOF

echo "============================================"
echo "  Data Tier listo."
echo "  MySQL 8.0 escuchando en puerto 3306"
echo "  Base de datos: innovatech_db"
echo "  Usuario app: appuser / AppUser2024!"
echo ""
echo "  Verificar desde Backend:"
echo "  mysql -h <DATA_IP> -u appuser -p'AppUser2024!' innovatech_db"
echo "  -> SELECT * FROM products;"
echo ""
echo "  Log completo: /var/log/user-data.log"
echo "============================================"
