#!/bin/bash
# =============================================================================
# User Data: Backend (capa privada)
# - Aplica actualizaciones de seguridad
# - Instala Docker y Git
# - Construye y lanza microservicio Python en Docker en puerto 8080
# Log: /var/log/user-data.log
# =============================================================================
set -e
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "============================================"
echo "  Innovatech Chile - Backend User Data"
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

# --- 3. Crear microservicio Python ---
echo "[3/4] Creando microservicio Python..."
mkdir -p /opt/backend

cat > /opt/backend/app.py << 'PYTHON'
"""
Microservicio simple - Innovatech Backend
Capa Backend de la arquitectura 3 capas ISY1101 EP1
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import datetime

class BackendHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        response = {
            "service": "Innovatech Backend",
            "tier": "backend",
            "status": "healthy",
            "version": "1.0.0",
            "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
            "path": self.path
        }
        self.wfile.write(json.dumps(response, indent=2).encode())

    def log_message(self, format, *args):
        print(f"[{datetime.datetime.now()}] {self.address_string()} - {format % args}")

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8080), BackendHandler)
    print("Innovatech Backend corriendo en puerto 8080")
    server.serve_forever()
PYTHON

cat > /opt/backend/Dockerfile << 'DOCKERFILE'
FROM python:3.11-alpine
WORKDIR /app
COPY app.py .
EXPOSE 8080
CMD ["python", "-u", "app.py"]
DOCKERFILE

# --- 4. Construir imagen y lanzar contenedor ---
echo "[4/4] Construyendo imagen Docker y lanzando microservicio..."
cd /opt/backend
docker build -t innovatech-backend:1.0.0 .
docker run -d \
  --name backend-service \
  --restart unless-stopped \
  -p 8080:8080 \
  innovatech-backend:1.0.0

echo "============================================"
echo "  Backend listo. Microservicio en :8080"
echo "  Verificar: curl http://localhost:8080"
echo "  Log completo: /var/log/user-data.log"
echo "============================================"
