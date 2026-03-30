#!/bin/bash
# Script de deploy para EC2 i-0977cdff42c104d9c
# IP: 100.31.242.214 - Porta: 3001

set -e

echo "=== Deploy BIA para EC2 ==="

# 1. Atualizar sistema
echo "Atualizando sistema..."
sudo yum update -y || sudo apt-get update -y

# 2. Instalar Git
if ! command -v git &> /dev/null; then
    echo "Instalando Git..."
    sudo yum install -y git || sudo apt-get install -y git
fi

# 3. Instalar Docker
if ! command -v docker &> /dev/null; then
    echo "Instalando Docker..."
    sudo yum install -y docker || sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -aG docker $USER
    echo "Docker instalado. Você pode precisar relogar para usar sem sudo."
fi

# 4. Instalar Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "Instalando Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# 5. Criar diretório da aplicação
echo "Configurando diretório da aplicação..."
sudo mkdir -p /opt/bia
sudo chown $USER:$USER /opt/bia
cd /opt/bia

# 6. Clonar ou atualizar repositório
if [ -d ".git" ]; then
    echo "Atualizando repositório..."
    git pull origin main || git pull origin master
else
    echo "Clonando repositório..."
    git clone https://github.com/henrylle/bia.git .
fi

# 7. Parar containers existentes
echo "Parando containers existentes..."
sudo docker-compose down 2>/dev/null || true

# 8. Construir e iniciar aplicação
echo "Construindo e iniciando aplicação..."
sudo docker-compose -f docker-compose.yml up -d --build

# 9. Aguardar containers iniciarem
echo "Aguardando containers iniciarem..."
sleep 15

# 10. Executar migrations
echo "Executando migrations..."
sudo docker-compose exec -T server npx sequelize db:migrate || echo "Aviso: Migrations podem ter falhado"

# 11. Verificar status
echo ""
echo "Status dos containers:"
sudo docker-compose ps

echo ""
echo "=== Deploy concluído! ==="
echo "Aplicação disponível em: http://100.31.242.214:3001"
echo ""
echo "Comandos úteis:"
echo "  Ver logs: sudo docker-compose logs -f"
echo "  Parar: sudo docker-compose down"
echo "  Reiniciar: sudo docker-compose restart"
echo "  Status: sudo docker-compose ps"
