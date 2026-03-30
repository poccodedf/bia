# Checklist de Publicação — BIA na AWS

> Atualizado em: 29/03/2026  
> Conta AWS: `395120012447` | Região: `us-east-1`  
> Aplicação: https://bia.uira.com.br

## Infraestrutura identificada

| Recurso | Valor |
|---|---|
| EC2 | `bia-dev` — `i-0977cdff42c104d9c` — IP: `100.31.242.214` |
| Security Group | `bia-alb-sg` — `sg-03f8e153b1b17a0cf` |
| VPC | `vpc-0570a35b2c53a3eb5` |
| Subnet | `subnet-02c4e497903f0f6df` (us-east-1a) |
| ECR | `395120012447.dkr.ecr.us-east-1.amazonaws.com/bia` |
| ALB | `bia-dev-alb` |
| Target Group | `bia-alb-sg` |
| Certificado ACM | `794c923a-d826-44d8-9117-3a93b4aa8b1a` |
| Hosted Zone | `uira.com.br` |

---

## 1. ECR — Publicar imagem Docker

- [ ] Autenticar Docker no ECR
  ```bash
  aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin 395120012447.dkr.ecr.us-east-1.amazonaws.com
  ```
- [ ] Verificar/criar repositório `bia`
  ```bash
  aws ecr describe-repositories --repository-names bia --region us-east-1
  # Se não existir:
  aws ecr create-repository --repository-name bia --region us-east-1
  ```
- [ ] Build e push da imagem
  ```bash
  docker build -t bia:latest .
  docker tag bia:latest 395120012447.dkr.ecr.us-east-1.amazonaws.com/bia:latest
  docker push 395120012447.dkr.ecr.us-east-1.amazonaws.com/bia:latest
  ```

---

## 2. EC2 bia-dev — Rodar Docker Compose

- [ ] Conectar na instância via SSH
  ```bash
  ssh -i bia-dev-key-pair.pem ec2-user@100.31.242.214
  ```
- [ ] Verificar Docker e Docker Compose instalados
  ```bash
  docker --version && docker compose version
  ```
- [ ] Clonar/atualizar repositório
  ```bash
  git clone https://github.com/henrylle/bia.git && cd bia
  # ou: git pull origin main
  ```
- [ ] Subir os containers
  ```bash
  docker compose up --build -d
  ```
- [ ] Rodar migrations
  ```bash
  docker compose exec server bash -c 'npx sequelize db:migrate'
  ```
- [ ] Verificar aplicação respondendo na porta 8080
  ```bash
  curl http://localhost:8080/api/versao
  ```

---

## 3. ECS — Cluster e Serviço

- [ ] Confirmar cluster ECS `bia-cluster` existe
  ```bash
  aws ecs list-clusters --region us-east-1
  ```
- [ ] Verificar serviço `bia-service` ativo
  ```bash
  aws ecs describe-services --cluster bia-cluster --services bia-service --region us-east-1
  ```
- [ ] Forçar novo deploy com imagem atualizada
  ```bash
  aws ecs update-service --cluster bia-cluster --service bia-service \
    --force-new-deployment --region us-east-1
  ```
- [ ] Aguardar tasks ficarem `RUNNING`
  ```bash
  aws ecs wait services-stable --cluster bia-cluster --services bia-service --region us-east-1
  ```

---

## 4. ALB bia-dev-alb — Listeners e Rules

- [ ] Verificar ALB `bia-dev-alb` com status `active`
  ```bash
  aws elbv2 describe-load-balancers --names bia-dev-alb --region us-east-1
  ```
- [ ] Listener porta **80** → redirect para HTTPS 443
  ```bash
  aws elbv2 describe-listeners --load-balancer-arn <ALB_ARN> --region us-east-1
  ```
- [ ] Listener porta **443** → forward para target group `bia-alb-sg`
- [ ] Certificado ACM `794c923a-d826-44d8-9117-3a93b4aa8b1a` associado ao listener 443
  ```bash
  aws elbv2 describe-listener-certificates --listener-arn <LISTENER_443_ARN> --region us-east-1
  ```
- [ ] Rule default do listener 443 aponta para o target group

---

## 5. Target Group bia-alb-sg

- [ ] Verificar configuração do target group
  ```bash
  aws elbv2 describe-target-groups --names bia-alb-sg --region us-east-1
  ```
  - Protocol: `HTTP` | Port: `8080` | Target type: `instance`
- [ ] Health check configurado
  - Path: `/api/versao` | Healthy threshold: 2 | Interval: 30s
- [ ] Instância `i-0977cdff42c104d9c` registrada e com status `healthy`
  ```bash
  aws elbv2 describe-target-health --target-group-arn <TG_ARN> --region us-east-1
  ```
- [ ] Security Group `sg-03f8e153b1b17a0cf` permite tráfego do ALB na porta 8080

---

## 6. Certificado ACM

- [ ] Verificar status do certificado (deve ser `ISSUED`)
  ```bash
  aws acm describe-certificate \
    --certificate-arn arn:aws:acm:us-east-1:395120012447:certificate/794c923a-d826-44d8-9117-3a93b4aa8b1a \
    --region us-east-1
  ```
- [ ] Domínio `bia.uira.com.br` coberto pelo certificado
- [ ] Se `PENDING_VALIDATION`: completar validação DNS no Route53

---

## 7. Route53 — Hosted Zone uira.com.br

- [ ] Localizar Hosted Zone de `uira.com.br`
  ```bash
  aws route53 list-hosted-zones-by-name --dns-name uira.com.br
  ```
- [ ] Registro `bia.uira.com.br` tipo **A (Alias)** apontando para o ALB ou CloudFront
  ```bash
  aws route53 list-resource-record-sets --hosted-zone-id <ZONE_ID> \
    --query "ResourceRecordSets[?Name=='bia.uira.com.br.']"
  ```
- [ ] Se não existir, criar registro A Alias apontando para o domínio CloudFront
  - Evaluate Target Health: `true`

---

## 8. CloudFront — CDN

- [ ] Criar distribuição CloudFront
  - Origin: DNS do ALB `bia-dev-alb` (HTTPS, porta 443)
  - Viewer Protocol Policy: `Redirect HTTP to HTTPS`
  - Allowed Methods: `GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE`
- [ ] Cache behaviors configurados
  - `/api/*` → Cache Policy: `CachingDisabled` (conteúdo dinâmico)
  - `/assets/*`, `*.js`, `*.css` → Cache Policy: `CachingOptimized`
- [ ] Certificado ACM `794c923a-d826-44d8-9117-3a93b4aa8b1a` associado
  > ⚠️ O certificado deve estar na região **us-east-1** (obrigatório para CloudFront)
- [ ] CNAME alternativo: `bia.uira.com.br`
- [ ] Registro Route53 `bia.uira.com.br` atualizado para apontar para o domínio `.cloudfront.net`

---

## 9. CodePipeline — CI/CD automático

> A cada `git push` no repositório, o pipeline executa build, push no ECR e deploy no ECS automaticamente.

### Pré-requisitos
- [ ] Repositório GitHub conectado via **CodeStar Connection** ou **OAuth**
- [ ] Role IAM para CodePipeline com permissões: ECR, ECS, CodeBuild, S3
- [ ] Role IAM para CodeBuild com permissões: ECR push, ECS describe

### Criar pipeline
- [ ] Criar pipeline `bia-pipeline` no CodePipeline
  ```bash
  # Stage 1 — Source
  # Provider: GitHub | Repositório: henrylle/bia | Branch: main
  # Trigger: Push to branch

  # Stage 2 — Build
  # Provider: CodeBuild | Projeto: bia-build
  # buildspec.yml já configurado na raiz do projeto

  # Stage 3 — Deploy
  # Provider: Amazon ECS
  # Cluster: bia-cluster | Service: bia-service
  # Image definitions file: imagedefinitions.json
  ```
- [ ] Verificar `buildspec.yml` com account ID correto (`395120012447`)
  > ⚠️ O buildspec.yml atual usa account `380278406175` — precisa ser atualizado
  ```yaml
  # Linha a corrigir no buildspec.yml:
  - aws ecr get-login-password --region us-east-1 | docker login --username AWS \
      --password-stdin 395120012447.dkr.ecr.us-east-1.amazonaws.com
  - REPOSITORY_URI=395120012447.dkr.ecr.us-east-1.amazonaws.com/bia
  ```
- [ ] Projeto CodeBuild `bia-build` configurado
  ```bash
  aws codebuild create-project \
    --name bia-build \
    --source type=CODEPIPELINE,buildspec=buildspec.yml \
    --artifacts type=CODEPIPELINE \
    --environment type=LINUX_CONTAINER,computeType=BUILD_GENERAL1_SMALL,\
  image=aws/codebuild/standard:7.0,privilegedMode=true \
    --service-role arn:aws:iam::395120012447:role/CodeBuildRole \
    --region us-east-1
  ```
- [ ] Testar pipeline executando manualmente após criação
  ```bash
  aws codepipeline start-pipeline-execution --name bia-pipeline --region us-east-1
  ```
- [ ] Verificar execução do pipeline
  ```bash
  aws codepipeline get-pipeline-state --name bia-pipeline --region us-east-1
  ```

### Fluxo CI/CD
```
git push (main) → CodePipeline
  → Stage Source:  GitHub checkout
  → Stage Build:   CodeBuild → docker build → ECR push (imagedefinitions.json)
  → Stage Deploy:  ECS rolling update com nova imagem
```

---

## 10. Validação Final

- [ ] HTTP redireciona para HTTPS
  ```bash
  curl -I http://bia.uira.com.br
  # Esperado: 301/302 → https://
  ```
- [ ] HTTPS responde com 200
  ```bash
  curl -I https://bia.uira.com.br
  ```
- [ ] API respondendo
  ```bash
  curl https://bia.uira.com.br/api/versao
  # Esperado: {"versao":"4.2.0",...}
  ```
- [ ] CloudFront com cache funcionando
  ```bash
  curl -I https://bia.uira.com.br/assets/index.js
  # Esperado: X-Cache: Hit from cloudfront (2ª requisição)
  ```
- [ ] Pipeline CI/CD: fazer push de teste e verificar deploy automático

---

## Fluxo completo

```
git push → CodePipeline → CodeBuild → ECR
                                         ↓
Usuário → bia.uira.com.br → Route53 → CloudFront → ALB bia-dev-alb (HTTPS/443)
                                                        → Target Group bia-alb-sg
                                                             → EC2 bia-dev :8080
                                                                  → Docker Compose
                                                                       → API + PostgreSQL
```
