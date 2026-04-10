#!/bin/bash
# =============================================================================
# User Data: Data (capa privada)
# - Aplica actualizaciones de seguridad
# - Instala Docker y Git
# - Lanza MySQL 8.0 en Docker en puerto 3306
# - Crea base de datos innovatech_db con tabla y datos de ejemplo
# Nota: mysql-server no está en los repos de Amazon Linux 2023; se usa Docker.
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

# --- 3. Lanzar MySQL 8.0 en Docker ---
echo "[3/4] Lanzando MySQL 8.0 en Docker..."
docker run -d \
  --name mysql-data \
  --restart unless-stopped \
  -e MYSQL_ROOT_PASSWORD='InnovatechRoot2024!' \
  -e MYSQL_DATABASE=innovatech_db \
  -e MYSQL_USER=appuser \
  -e MYSQL_PASSWORD='AppUser2024!' \
  -p 3306:3306 \
  mysql:8.0
echo "  -> Contenedor MySQL 8.0 lanzado"

# --- 4. Configurar base de datos ---
echo "[4/4] Configurando base de datos innovatech_db..."
echo "  -> Esperando que MySQL esté listo..."
for i in $(seq 1 60); do
  if docker exec mysql-data mysqladmin ping -u root -p'InnovatechRoot2024!' --silent 2>/dev/null; then
    echo "  -> MySQL listo después de ${i}s"
    break
  fi
  sleep 2
done

docker exec -i mysql-data mysql -u root -p'InnovatechRoot2024!' << 'SQLEOF'
USE innovatech_db;

-- Tabla de productos de ejemplo
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
