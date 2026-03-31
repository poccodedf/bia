# 🤖 BIA — Bootcamp Imersão AWS & IA

> Projeto base para o evento **Imersão AWS & IA**.  
> **Período:** 21/03 e 22/03/2026 (Online e ao Vivo das 9h30 às 17h30)

[>> Página de Inscrição do evento](https://org.imersaoaws.com.br/github/readme)

---

## 📋 Sobre o Projeto

O **BIA** é uma aplicação web fullstack de **gerenciamento de tarefas** (Task Tracker) construída para fins didáticos durante a Imersão AWS. O projeto demonstra como desenvolver, containerizar e implantar uma aplicação completa na AWS usando ECS, RDS, CodePipeline e outros serviços.

### Funcionalidades

- ✅ Criar tarefas (título, data, prioridade)
- ✅ Listar todas as tarefas
- ✅ Marcar/desmarcar tarefa como importante
- ✅ Excluir tarefas
- ✅ Indicador de status da API (online/offline)
- ✅ Tema claro/escuro
- ✅ Painel de debug com logs de requisições

---

## 🛠️ Stack Tecnológica

| Camada             | Tecnologias                                                                    |
| ------------------ | ------------------------------------------------------------------------------ |
| **Front-End**      | React 18, Vite 5, React Router DOM 6, React Icons                              |
| **Back-End**       | Node.js, Express 4, Sequelize 6 (ORM), Morgan (logging)                        |
| **Banco de Dados** | PostgreSQL 17 (local via Docker) / PostgreSQL 16 (AWS RDS)                     |
| **Infraestrutura** | Docker, Docker Compose, AWS ECS, ECR, RDS, ALB, Route 53, ACM, Secrets Manager |
| **CI/CD**          | AWS CodePipeline, CodeBuild (`buildspec.yml`)                                  |
| **Testes**         | Jest                                                                           |

---

## 📁 Estrutura do Projeto

```
bia/
├── api/                        # API REST
│   ├── controllers/            # Lógica de negócio (tarefas, versão)
│   ├── models/                 # Models Sequelize (Tarefas)
│   ├── routes/                 # Definição de rotas Express
│   └── data/                   # Dados estáticos de exemplo
├── client/                     # Front-End React (SPA)
│   ├── src/
│   │   ├── components/         # Componentes React (Header, Tasks, AddTask, etc.)
│   │   ├── contexts/           # Context API (Tema, Logs)
│   │   ├── App.jsx             # Componente raiz
│   │   └── main.jsx            # Entry point React
│   ├── vite.config.js          # Configuração Vite
│   └── package.json
├── config/
│   ├── database.js             # Configuração PostgreSQL (local + AWS Secrets Manager)
│   ├── express.js              # Configuração Express (middlewares, rotas)
│   └── default.json            # Porta padrão (8080)
├── database/
│   └── migrations/             # Migrations Sequelize
├── tests/                      # Testes unitários (Jest)
├── docs/                       # Documentação
│   ├── arquitetura.md          # Documentação arquitetural (diagramas C4)
│   ├── implantacao-aws.md      # Guia completo de implantação AWS
│   └── architecture/           # Diagrama visual HTML da arquitetura AWS
├── server.js                   # Entry point da aplicação
├── Dockerfile                  # Build da imagem Docker
├── compose.yml                 # Docker Compose (app + PostgreSQL)
├── buildspec.yml               # AWS CodeBuild (CI/CD)
└── package.json                # Dependências do back-end
```

---

## 🚀 Como Executar

### Pré-requisitos

- [Node.js](https://nodejs.org/) >= 18
- [Docker](https://www.docker.com/) e Docker Compose
- Git

### Opção 1 — Docker Compose (recomendado)

Sobe a aplicação inteira (API + PostgreSQL) com um único comando:

```bash
# Clonar o repositório
git clone https://github.com/henrylle/bia.git
cd bia

# Subir os containers
docker compose up --build
```

> A aplicação estará disponível em: **http://localhost:3001**  
> A API estará disponível em: **http://localhost:3001/api/tarefas**

#### Rodar as Migrations no container

```bash
docker compose exec server bash -c 'npx sequelize db:migrate'
```

### Opção 2 — Execução Local (sem Docker)

#### 1. Subir o PostgreSQL

Você precisa de uma instância PostgreSQL rodando. Configure as variáveis de ambiente ou use os valores padrão (localhost:5433, user: postgres, password: postgres).

#### 2. Instalar dependências e rodar o Back-End

```bash
# Na raiz do projeto
npm install
npm start
```

> O servidor Express inicia na porta **8080**.

#### 3. Instalar dependências e rodar o Front-End

```bash
# Na pasta client
cd client
npm install
npm run dev
```

> O Vite inicia na porta **3001** com hot reload.

#### 4. Rodar migrations

```bash
npx sequelize db:migrate
```

### Opção 3 — Scripts auxiliares

```bash
# Windows
rodar_app_local_windows.bat

# Linux / macOS
./rodar_app_local_unix.sh
```

---

## 🔌 API Endpoints

| Método   | Rota                                 | Descrição                       |
| -------- | ------------------------------------ | ------------------------------- |
| `GET`    | `/api/tarefas`                       | Lista todas as tarefas          |
| `GET`    | `/api/tarefas/:uuid`                 | Busca uma tarefa pelo UUID      |
| `POST`   | `/api/tarefas`                       | Cria uma nova tarefa            |
| `PUT`    | `/api/tarefas/update_priority/:uuid` | Alterna prioridade (importante) |
| `DELETE` | `/api/tarefas/:uuid`                 | Remove uma tarefa               |
| `GET`    | `/api/versao`                        | Retorna a versão da API         |

### Exemplo de payload (POST /api/tarefas)

```json
{
  "titulo": "Estudar AWS ECS",
  "dia_atividade": "21/03/2026",
  "importante": true
}
```

---

## 🐳 Docker

### Build manual da imagem

```bash
docker build -t bia:latest .
```

O `Dockerfile` executa os seguintes passos:

1. Base `node:22-slim`
2. Instala dependências do back-end (`npm install`)
3. Instala dependências do front-end (`cd client && npm install`)
4. Builda o React com Vite (`cd client && npm run build`)
5. Remove devDependencies do client (prune)
6. Expõe porta **8080** e executa `npm start`

### Docker Compose

O `compose.yml` define dois serviços:

| Serviço    | Container  | Porta     | Detalhes                                                 |
| ---------- | ---------- | --------- | -------------------------------------------------------- |
| `server`   | `bia`      | 3001:8080 | Aplicação Node.js (API + React build)                    |
| `database` | `database` | 5433:5432 | PostgreSQL 17.1 (user: postgres, pwd: postgres, db: bia) |

---

## ⚙️ Variáveis de Ambiente

| Variável         | Padrão                  | Descrição                                        |
| ---------------- | ----------------------- | ------------------------------------------------ |
| `PORT`           | `8080`                  | Porta do servidor Express                        |
| `DB_HOST`        | `127.0.0.1`             | Host do PostgreSQL                               |
| `DB_PORT`        | `5433`                  | Porta do PostgreSQL                              |
| `DB_USER`        | `postgres`              | Usuário do banco                                 |
| `DB_PWD`         | `postgres`              | Senha do banco                                   |
| `DB_SECRET_NAME` | —                       | Nome do secret no AWS Secrets Manager (produção) |
| `DB_REGION`      | —                       | Região AWS do Secrets Manager                    |
| `IS_LOCAL`       | —                       | Se `true`, usa credenciais locais da AWS         |
| `DEBUG_SECRET`   | —                       | Se `true`, imprime secrets no console (debug)    |
| `VERSAO_API`     | `4.2.0`                 | Versão exibida no endpoint `/api/versao`         |
| `VITE_API_URL`   | `http://localhost:8080` | URL da API usada pelo React (build time)         |

---

## 🧪 Testes

```bash
# Executar testes unitários
npm test
```

Utiliza **Jest** para testes unitários na pasta `tests/unit`.

---

## ☁️ Deploy na AWS

O projeto foi desenhado para ser implantado na AWS usando a seguinte arquitetura:

```
Usuários → Route 53 → ALB (HTTPS) → ECS/EC2 → RDS PostgreSQL
                         ↑                        ↑
                   ACM Certificate          Secrets Manager
```

### Documentação completa

- 📐 [Documentação Arquitetural](docs/arquitetura.md) — Diagramas C4, fluxos e análise de componentes
- 🚀 [Guia de Implantação AWS](docs/implantacao-aws.md) — Passo a passo completo com 13 etapas
- 🏗️ [Diagrama Visual AWS](docs/architecture/aws-ecs-diagram.html) — Diagrama interativo HTML

### Deploy rápido (resumo)

```bash
# 1. Login no ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# 2. Build e push
docker build -t bia:latest .
docker tag bia:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/bia:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/bia:latest

# 3. Atualizar ECS Service (force new deployment)
aws ecs update-service --cluster bia-cluster --service bia-service --force-new-deployment
```

### CI/CD automático

O pipeline é configurado via **AWS CodePipeline**:

```
GitHub (push) → CodeBuild (buildspec.yml) → ECR (push imagem) → ECS (rolling update)
```

---

## 📚 Documentação

| Documento                                          | Descrição                                                                                                                                                            |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [docs/arquitetura.md](docs/arquitetura.md)         | Análise arquitetural completa com diagramas C4 (Contexto, Container, Componentes), fluxos de requisição e CI/CD, resumo de decisões e pontos de melhoria             |
| [docs/implantacao-aws.md](docs/implantacao-aws.md) | Guia de implantação com 13 etapas ordenadas: VPC, Security Groups, RDS, Secrets Manager, ECR, Docker, ECS, ACM, ALB, Route 53, ECS Service, CodePipeline, CloudWatch |
| [docs/architecture/](docs/architecture/)           | Diagrama visual HTML interativo da arquitetura ECS + EC2                                                                                                             |

---

## 📄 Licença

ISC

---

> **Desenvolvido para a Imersão AWS & IA 2026** 🚀
