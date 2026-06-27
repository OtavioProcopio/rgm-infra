# RGM Infraestrutura & Deploy Orchestrator

Este repositório gerencia a orquestração de containers, configurações de proxy reverso e fluxos de deploy do ecossistema RGM.

---

## 🚀 Como Executar em Produção (Em Segundos)

Para colocar toda a stack no ar em produção, você **não precisa compilar código ou ter Node/Java instalados localmente**. O ambiente de produção consome as imagens Docker pré-construídas no **GitHub Container Registry (GHCR)**.

### Passo a Passo:

1.  **Clone este repositório** na máquina servidor/local:
    ```bash
    git clone git@github.com:OtavioProcopio/rgm-infra.git
    cd rgm-infra
    ```

2.  **Execute o setup automatizado**:
    ```bash
    make setup
    ```
    *Isso criará o `.env` a partir do template e gerará automaticamente uma chave `JWT_SECRET` forte e segura para você.*
    *(Se preferir, você pode editar o `.env` para ajustar o usuário/senha do PostgreSQL/MinIO).*

3.  **Inicie toda a stack**:
    ```bash
    make prod-up
    ```

> [!NOTE]
> **Notas importantes para Windows (WSL) & Redes:**
> - **WSL Integration**: Garanta que o Docker Desktop está configurado para usar o WSL2 backend com integração ativada para a sua distribuição de Linux/WSL.
> - **Conflito de Porta 80**: Em ambientes Windows, o serviço de IIS ou outros proxies nativos podem ocupar a porta `80`. Certifique-se de que a porta está livre para que o Nginx do frontend possa subir, ou altere a porta mapeada em `docker-compose.prod.yml`.
> - **Acesso à Rede**: Por padrão, o sistema estará disponível em `http://localhost` (ou no IP de rede da máquina/WSL para computadores conectados na mesma rede).

A stack iniciará os seguintes serviços:
*   `db` (PostgreSQL 16)
*   `minio` (Armazenamento compatível com S3)
*   `minio-init` (Script temporário para criar o bucket público automaticamente)
*   `backend` (API REST Java/Spring Boot)
*   `frontend` (React + Nginx servindo o build estático e fazendo proxy das rotas `/api/*` diretamente para o backend).

---

## 🛠️ Desenvolvimento Local

Para desenvolvimento local, você pode rodar em duas modalidades a depender do seu fluxo:

### 1. Stack Completa em Docker (Recomendado para Testes E2E)
Sobe toda a infraestrutura mais as aplicações com sincronização de volumes e hot-reload automáticos:
```bash
make up
```
*   **Vite Frontend**: [http://localhost:5173](http://localhost:5173)
*   **Spring Backend**: [http://localhost:8080](http://localhost:8080)
*   **Swagger Docs**: [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html)
*   **MinIO Console**: [http://localhost:9001](http://localhost:9001)

### 2. Apenas Infraestrutura (Recomendado para Codificação Ativa)
Se você quer rodar o backend no VS Code/IntelliJ e o frontend nativo em sua máquina física para ter o melhor desempenho:
```bash
make infra-up
```
Isso iniciará apenas o PostgreSQL (na porta `5434`) e o MinIO (na porta `9000`/`9001`).

---

## 🎛️ Comandos Utilitários (Makefile)

O projeto possui comandos mapeados no `Makefile` para facilitar a administração dos containers:

| Comando | Descrição |
|---------|-----------|
| `make help` | Lista todos os comandos disponíveis e URLs. |
| `make setup` | Cria o arquivo `.env` a partir do template. |
| `make up` / `make down` | Inicia/para a stack de desenvolvimento. |
| `make infra-up` / `make infra-down` | Inicia/para apenas banco e S3 para dev nativo. |
| `make prod-up` / `make prod-down` | Inicia/para a stack de produção (GHCR images). |
| `make logs` | Exibe os logs de todos os containers ativos em tempo real. |
| `make reset` | Limpa volumes, recria o banco de dados e reinicia os containers (PERDE DADOS). |
| `make test-e2e` | Executa os testes Cypress completos de forma headless. |

---

## 🔒 Segurança em Produção

O frontend possui um arquivo `nginx.conf` integrado que serve os arquivos estáticos e atua como proxy reverso para `/api/` redirecionando para `http://backend:8080/api/`. 
Isso elimina a necessidade de expor a porta do backend (`8080`) publicamente e resolve problemas de **CORS** nativamente em produção.
