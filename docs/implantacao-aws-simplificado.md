# Implantação AWS Simplificada — BIA

Arquitetura simples com uma instância EC2 rodando dois containers Docker (app + banco), ECR para versionamento de imagens, Load Balancer e Route 53 para DNS.

---

## Visão Geral

```
Internet
   │
   ▼
Route 53 (bia.uira.com.br → ALB)
   │
   ▼
Application Load Balancer (porta 80)
   │
   ▼
Target Group (porta 3001)
   │
   ▼
EC2 Instance
   ├── Container: app (porta 3001)
   └── Container: postgresql (porta 5432)

ECR ──► EC2 (pull das imagens)
```

---

## 1. ECR — Elastic Container Registry

Repositório para versionar a imagem Docker do app.

### Criar repositório

```bash
aws ecr create-repository \
  --repository-name bia-app \
  --region us-east-1
```

### Autenticar e fazer push da imagem

```bash
# Autenticar no ECR
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build e tag da imagem
docker build -t bia-app .
docker tag bia-app:latest \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/bia-app:latest

# Push
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/bia-app:latest
```

> Substitua `<account-id>` pelo ID da sua conta AWS.

---

## 2. EC2 — Instância com Docker

### Configuração mínima recomendada

| Parâmetro       | Valor sugerido        |
|-----------------|-----------------------|
| Tipo            | `t3.small`            |
| SO              | Amazon Linux 2023     |
| Armazenamento   | 20 GB gp3             |
| Security Group  | Portas 22, 80, 3001   |

### Security Group — regras de entrada

| Tipo  | Porta | Origem         |
|-------|-------|----------------|
| SSH   | 22    | Seu IP         |
| HTTP  | 80    | 0.0.0.0/0      |
| Custom| 3001  | Security Group do ALB |

### Instalar Docker na EC2

```bash
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -aG docker ec2-user

# Instalar docker-compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### IAM Role para EC2 acessar o ECR

Crie uma IAM Role com a policy `AmazonEC2ContainerRegistryReadOnly` e associe à instância EC2.

### docker-compose.yml na EC2

```yaml
version: "3.8"

services:
  db:
    image: postgres:16-alpine
    container_name: bia-db
    restart: always
    environment:
      POSTGRES_USER: bia
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: bia
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - bia-net

  app:
    image: <account-id>.dkr.ecr.us-east-1.amazonaws.com/bia-app:latest
    container_name: bia-app
    restart: always
    ports:
      - "3001:3001"
    environment:
      DATABASE_URL: postgresql://bia:${DB_PASSWORD}@db:5432/bia
      NODE_ENV: production
    depends_on:
      - db
    networks:
      - bia-net

volumes:
  pgdata:

networks:
  bia-net:
```

### Arquivo .env na EC2

```bash
# /home/ec2-user/.env
DB_PASSWORD=senha_segura_aqui
```

### Subir os containers

```bash
# Autenticar no ECR (necessário antes do pull)
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Subir os containers
docker-compose --env-file .env up -d

# Verificar status
docker-compose ps
docker-compose logs -f app
```

---

## 3. Application Load Balancer (ALB)

### Criar o ALB

1. **EC2 → Load Balancers → Create Load Balancer**
2. Selecionar: **Application Load Balancer**
3. Configurações:
   - Nome: `bia-alb`
   - Scheme: `Internet-facing`
   - IP type: `IPv4`
   - Subnets: selecionar ao menos 2 subnets públicas

### Listener

| Protocolo | Porta | Ação          |
|-----------|-------|---------------|
| HTTP      | 80    | Forward → Target Group `bia-tg` |

---

## 4. Target Group

### Criar o Target Group

1. **EC2 → Target Groups → Create target group**
2. Configurações:

| Parâmetro           | Valor         |
|---------------------|---------------|
| Target type         | Instances     |
| Nome                | `bia-tg`      |
| Protocolo           | HTTP          |
| Porta               | **3001**      |
| VPC                 | Mesma da EC2  |

3. **Health Check:**
   - Protocol: HTTP
   - Path: `/health` (ou `/` se não houver rota de health check)
   - Healthy threshold: 2
   - Interval: 30s

4. **Registrar a instância EC2** no target group.

---

## 5. Route 53 — DNS

### Pré-requisito

O domínio `uira.com.br` deve estar configurado no Route 53 (Hosted Zone criada).

### Criar registro DNS

1. **Route 53 → Hosted Zones → uira.com.br → Create Record**
2. Configurações:

| Campo          | Valor                        |
|----------------|------------------------------|
| Record name    | `bia`                        |
| Record type    | `A`                          |
| Alias          | **Sim**                      |
| Alias target   | DNS do ALB (`bia-alb-xxx.us-east-1.elb.amazonaws.com`) |
| Routing policy | Simple                       |

Resultado: `bia.uira.com.br` → ALB → EC2:3001

---

## 6. Fluxo de Deploy (atualizar a aplicação)

```bash
# 1. Na máquina de desenvolvimento — build e push da nova imagem
docker build -t bia-app .
docker tag bia-app:latest \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/bia-app:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/bia-app:latest

# 2. Na EC2 — pull e restart do container
ssh ec2-user@<ec2-ip>
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker-compose pull app
docker-compose up -d --no-deps app
```

---

## 7. Resumo dos Recursos AWS

| Recurso        | Nome/Detalhe                        |
|----------------|-------------------------------------|
| ECR            | `bia-app`                           |
| EC2            | `t3.small`, Amazon Linux 2023       |
| IAM Role       | `ec2-ecr-readonly` (ECR pull)       |
| ALB            | `bia-alb` — porta 80                |
| Target Group   | `bia-tg` — porta 3001               |
| Route 53       | `bia.uira.com.br` → ALB (Alias A)   |

---

## Observações

- O banco PostgreSQL roda no mesmo host da aplicação (sem RDS), adequado para ambiente de desenvolvimento ou uso simples.
- Para produção com maior disponibilidade, considere migrar o banco para o **RDS** e usar **ECS** ou **Elastic Beanstalk** para o app.
- Para HTTPS, adicione um listener na porta 443 no ALB com certificado via **AWS Certificate Manager (ACM)**.
