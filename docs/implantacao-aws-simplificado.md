# Implantação AWS — BIA

> Atualizado em: 30/03/2026
> Conta AWS: `395120012447` | Região: `us-east-1`
> Aplicação: <https://bia.uira.com.br>

---

## Visão Geral

```text
Internet
   │
   ▼
Route 53 (bia.uira.com.br → ALB)
   │
   ▼
ALB bia-dev-alb (HTTPS :443 → :8080)
   │
   ▼
EC2 bia-dev (i-0977cdff42c104d9c — 100.31.242.214)
   ├── Container: server (Node.js :8080)
   ├── Container: nginx  (:3001 → :8080)
   └── Container: database (PostgreSQL 17.1 :5432)

ECR (395120012447.dkr.ecr.us-east-1.amazonaws.com/bia)
  └──► EC2 (pull das imagens via CodePipeline)
```

---

## Recursos AWS Provisionados

| Recurso | Nome / ID / Valor |
| --- | --- |
| EC2 | `bia-dev` — `i-0977cdff42c104d9c` — IP: `100.31.242.214` |
| Security Group | `bia-alb-sg` — `sg-03f8e153b1b17a0cf` |
| VPC | `vpc-0570a35b2c53a3eb5` |
| Subnet | `subnet-02c4e497903f0f6df` (us-east-1a) |
| ECR | `395120012447.dkr.ecr.us-east-1.amazonaws.com/bia` |
| ALB | `bia-dev-alb` |
| Target Group | `bia-alb-sg` — porta `8080` — health check `/api/versao` |
| Certificado ACM | `794c923a-d826-44d8-9117-3a93b4aa8b1a` — `bia.uira.com.br` |
| Hosted Zone | `uira.com.br` |

---

## 1. ECR — Publicar imagem Docker

```bash
# Autenticar Docker no ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  395120012447.dkr.ecr.us-east-1.amazonaws.com

# Build e push da imagem
docker build -t bia:latest .
docker tag bia:latest 395120012447.dkr.ecr.us-east-1.amazonaws.com/bia:latest
docker push 395120012447.dkr.ecr.us-east-1.amazonaws.com/bia:latest
```

---

## 2. EC2 bia-dev — Deploy via Docker Compose

### Conectar na instância

```bash
ssh -i bia-dev-key-pair.pem ec2-user@100.31.242.214
```

### Subir os containers

```bash
cd /opt/bia
git pull origin main
docker compose -f compose.prod.yml up --build -d
```

### Rodar migrations

```bash
docker compose exec server bash -c 'npx sequelize db:migrate'
```

### Verificar aplicação

```bash
curl http://localhost:8080/api/versao
# Esperado: {"versao":"4.2.0"}
```

### Security Group — regras de entrada

| Tipo | Porta | Origem |
| --- | --- | --- |
| SSH | 22 | Seu IP |
| HTTPS | 443 | 0.0.0.0/0 |
| HTTP | 80 | 0.0.0.0/0 (redirect → HTTPS) |
| Custom TCP | 8080 | `bia-alb-sg` (tráfego do ALB) |

---

## 3. ALB bia-dev-alb

| Parâmetro | Valor |
| --- | --- |
| Scheme | Internet-facing |
| Listener 80 | Redirect → HTTPS 443 |
| Listener 443 | Forward → Target Group `bia-alb-sg` |
| Certificado | ACM `794c923a-d826-44d8-9117-3a93b4aa8b1a` |

### Verificar status

```bash
aws elbv2 describe-load-balancers --names bia-dev-alb --region us-east-1
```

---

## 4. Target Group bia-alb-sg

| Parâmetro | Valor |
| --- | --- |
| Target type | instance |
| Protocolo | HTTP |
| Porta | 8080 |
| Health check path | `/api/versao` |
| Healthy threshold | 2 |
| Interval | 30s |

### Verificar saúde da instância

```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --names bia-alb-sg \
    --query 'TargetGroups[0].TargetGroupArn' --output text --region us-east-1) \
  --region us-east-1
```

---

## 5. Certificado ACM

```bash
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:395120012447:certificate/794c923a-d826-44d8-9117-3a93b4aa8b1a \
  --region us-east-1
```

Status esperado: `ISSUED` | Domínio: `bia.uira.com.br`

---

## 6. Route 53

Registro `bia.uira.com.br` — tipo **A (Alias)** apontando para o ALB `bia-dev-alb`.

```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id $(aws route53 list-hosted-zones-by-name \
    --dns-name uira.com.br --query 'HostedZones[0].Id' --output text) \
  --query "ResourceRecordSets[?Name=='bia.uira.com.br.']"
```

---

## 7. Fluxo de Deploy Automatizado (CodePipeline)

A cada `git push` na branch `main`, o pipeline executa automaticamente:

```text
git push main
  → CodePipeline bia-pipeline
      → Stage Source:  GitHub checkout
      → Stage Build:   CodeBuild bia-build
                         → docker build
                         → docker push ECR (bia:latest + bia:COMMIT_HASH)
                         → gera imagedefinitions.json
      → Stage Deploy:  ECS rolling update (cluster bia-cluster / service bia-service)
```

### Disparar deploy manualmente

```bash
aws codepipeline start-pipeline-execution --name bia-pipeline --region us-east-1
```

### Verificar estado do pipeline

```bash
aws codepipeline get-pipeline-state --name bia-pipeline --region us-east-1
```

---

## 8. Validação Final

```bash
# HTTP redireciona para HTTPS
curl -I http://bia.uira.com.br
# Esperado: 301/302 → https://

# HTTPS responde com 200
curl -I https://bia.uira.com.br

# API respondendo
curl https://bia.uira.com.br/api/versao
# Esperado: {"versao":"4.2.0"}
```

---

## Observações

- O banco PostgreSQL roda em container no mesmo host da aplicação (sem RDS). Adequado para o estágio atual de aprendizado.
- Para maior disponibilidade em produção, considere migrar o banco para **RDS** e adicionar **CloudFront** na frente do ALB.
- Secrets Manager não é utilizado neste estágio — as credenciais do banco são passadas via variáveis de ambiente no `compose.prod.yml`.
