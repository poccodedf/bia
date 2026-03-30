# Guia de Deploy - EC2 Instance i-0977cdff42c104d9c

## Informações da Instância
- **Instance ID:** i-0977cdff42c104d9c
- **IP Público:** 100.31.242.214
- **Porta da Aplicação:** 3001
- **URL de Acesso:** http://100.31.242.214:3001

---

## Pré-requisitos

### 1. Security Group
Certifique-se que o Security Group da instância permite:
- **Porta 3001** (TCP) - Inbound de 0.0.0.0/0 (ou seu IP específico)
- **Porta 22** (SSH) - Para acesso à instância
- **Porta 5433** (opcional) - Se precisar acessar o PostgreSQL externamente

### 2. Chave SSH
Você precisa da chave privada (.pem) associada à instância para conectar via SSH.

---

## Opção 1: Deploy Automatizado (Recomendado)

### Passo 1: Conectar à instância EC2
```bash
ssh -i "sua-chave.pem" ec2-user@100.31.242.214
# ou
ssh -i "sua-chave.pem" ubuntu@100.31.242.214
```

### Passo 2: Copiar script de deploy
No seu computador local, copie o script para a EC2:
```bash
scp -i "sua-chave.pem" deploy-ec2.sh ec2-user@100.31.242.214:/home/ec2-user/
```

### Passo 3: Executar deploy
Na instância EC2:
```bash
chmod +x deploy-ec2.sh
./deploy-ec2.sh
```

---

## Opção 2: Deploy Manual

### Passo 1: Conectar à EC2
```bash
ssh -i "sua-chave.pem" ec2-user@100.31.242.214
```

### Passo 2: Instalar dependências
```bash
# Atualizar sistema
sudo yum update -y

# Instalar Git
sudo yum install -y git

# Instalar Docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Instalar Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Relogar para aplicar permissões do Docker
exit
# Conectar novamente via SSH
```

### Passo 3: Clonar repositório
```bash
sudo mkdir -p /opt/bia
sudo chown $USER:$USER /opt/bia
cd /opt/bia
git clone https://github.com/henrylle/bia.git .
```

### Passo 4: Configurar variáveis de ambiente (opcional)
```bash
# Criar arquivo .env se necessário
cat > .env << EOF
PORT=8080
DB_HOST=database
DB_PORT=5432
DB_USER=postgres
DB_PWD=postgres
VERSAO_API=4.2.0
EOF
```

### Passo 5: Iniciar aplicação
```bash
# Usar compose.prod.yml ou compose.yml
docker-compose -f compose.prod.yml up -d --build

# Ou usar o compose.yml padrão
docker-compose up -d --build
```

### Passo 6: Executar migrations
```bash
docker-compose exec server npx sequelize db:migrate
```

### Passo 7: Verificar status
```bash
docker-compose ps
docker-compose logs -f server
```

---

## Opção 3: Deploy com Imagem Docker Pré-construída

Se você já tem a imagem no ECR ou Docker Hub:

```bash
# Login no ECR (se aplicável)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Pull da imagem
docker pull <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/bia:latest

# Executar containers
docker network create bia-network

docker run -d \
  --name database \
  --network bia-network \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=bia \
  -v postgres-data:/var/lib/postgresql/data \
  postgres:17.1

docker run -d \
  --name bia \
  --network bia-network \
  -p 3001:8080 \
  -e DB_HOST=database \
  -e DB_PORT=5432 \
  -e DB_USER=postgres \
  -e DB_PWD=postgres \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/bia:latest
```

---

## Verificação e Testes

### 1. Verificar se a aplicação está rodando
```bash
curl http://localhost:8080/api/versao
# Deve retornar: {"versao":"4.2.0"}
```

### 2. Testar do seu computador local
```bash
curl http://100.31.242.214:3001/api/versao
```

### 3. Acessar no navegador
Abra: **http://100.31.242.214:3001**

---

## Comandos Úteis

### Ver logs
```bash
docker-compose logs -f
docker-compose logs -f server
docker-compose logs -f database
```

### Reiniciar aplicação
```bash
docker-compose restart
docker-compose restart server
```

### Parar aplicação
```bash
docker-compose down
```

### Atualizar aplicação
```bash
cd /opt/bia
git pull
docker-compose down
docker-compose up -d --build
docker-compose exec server npx sequelize db:migrate
```

### Verificar uso de recursos
```bash
docker stats
htop
free -h
df -h
```

---

## Troubleshooting

### Porta 3001 não acessível
1. Verificar Security Group no AWS Console
2. Verificar firewall da instância:
```bash
sudo iptables -L -n
sudo firewall-cmd --list-all  # Se usar firewalld
```

### Container não inicia
```bash
docker-compose logs server
docker inspect bia
```

### Banco de dados não conecta
```bash
docker-compose logs database
docker-compose exec database psql -U postgres -d bia -c "\dt"
```

### Limpar tudo e recomeçar
```bash
docker-compose down -v
docker system prune -a
# Depois refazer o deploy
```

---

## Configuração de Security Group (AWS Console)

1. Acesse EC2 → Instances → i-0977cdff42c104d9c
2. Clique na aba "Security"
3. Clique no Security Group
4. Adicione regra Inbound:
   - **Type:** Custom TCP
   - **Port:** 3001
   - **Source:** 0.0.0.0/0 (ou seu IP específico)
   - **Description:** BIA Application

---

## Monitoramento

### CloudWatch Logs (se configurado)
```bash
# Instalar CloudWatch Agent
sudo yum install -y amazon-cloudwatch-agent
```

### Logs locais
```bash
# Logs do Docker
sudo journalctl -u docker -f

# Logs da aplicação
docker-compose logs -f --tail=100
```

---

## Backup do Banco de Dados

```bash
# Backup
docker-compose exec database pg_dump -U postgres bia > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore
docker-compose exec -T database psql -U postgres bia < backup_20260321_120000.sql
```

---

## Próximos Passos (Produção)

1. **Configurar HTTPS** com certificado SSL (Let's Encrypt ou ACM)
2. **Usar RDS** ao invés de PostgreSQL em container
3. **Configurar ALB** para balanceamento de carga
4. **Implementar CI/CD** com CodePipeline
5. **Configurar CloudWatch** para monitoramento
6. **Usar Secrets Manager** para credenciais
7. **Configurar Auto Scaling** para alta disponibilidade

---

**Aplicação disponível em:** http://100.31.242.214:3001
