#!/bin/bash
sudo yum update -y

# INSTALANDO DOCKER
sudo yum install -y docker
sudo service docker start

# Startando e habilitando docker para já iniciar ativo
sudo systemctl enable docker.service

# Instalando docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Instalando Git
sudo yum install -y git

# Instalando o Node
curl -fsSL https://rpm.nodesource.com/setup_14.x | sudo -E bash -
sudo yum install -y nodejs
# Atualizando versao do NPM
sudo npm install -g npm@latest --loglevel=error

# Instalando AWS CLI
  # Pre-requisito (unzip)
  sudo yum install -y unzip

  # AWS CLI (Install)
  sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  sudo unzip awscliv2.zip
  sudo ./aws/install

# Configurando permissão no docker para não ter que ficar usando root
sudo usermod -aG docker ec2-user
newgrp docker
