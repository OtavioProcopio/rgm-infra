.PHONY: help setup up down logs logs-backend logs-frontend ps \
        infra-up infra-down \
        test-backend test-frontend check-frontend \
        build-prod prod-up prod-down prod-logs \
        reset reset-prod status

COMPOSE_DEV   := docker compose -f docker-compose.dev.yml --env-file .env
COMPOSE_INFRA := docker compose -f docker-compose.infra.yml --env-file .env
COMPOSE_PROD  := docker compose -f docker-compose.prod.yml --env-file .env

# Cria .env a partir do exemplo se não existir
.env:
	@cp .env.example .env
	@echo "⚠  .env criado a partir de .env.example — revise antes de subir em produção."

help: ## Mostrar todos os comandos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  URLs (dev):"
	@echo "    Backend  → http://localhost:8080"
	@echo "    Swagger  → http://localhost:8080/swagger-ui.html"
	@echo "    Frontend → http://localhost:5173"
	@echo "    MinIO    → http://localhost:9001"

# ── Configuração ─────────────────────────────────────────────

setup: .env ## Configuração inicial (cria .env se não existir)
	@echo "Setup concluído. Execute 'make up' ou 'make infra-up'."

# ── Dev completo (containers) ────────────────────────────────

up: .env ## Subir stack completa de dev (backend + frontend + infra)
	$(COMPOSE_DEV) up -d
	@echo ""
	@echo "Stack de desenvolvimento ativa:"
	@echo "  Backend  → http://localhost:8080"
	@echo "  Swagger  → http://localhost:8080/swagger-ui.html"
	@echo "  Frontend → http://localhost:5173"
	@echo "  MinIO    → http://localhost:9001"
	@echo ""
	@echo "Acompanhe os logs: make logs"

down: ## Parar stack de dev
	$(COMPOSE_DEV) down

logs: ## Seguir todos os logs
	$(COMPOSE_DEV) logs -f

logs-backend: ## Seguir logs do backend
	$(COMPOSE_DEV) logs -f backend

logs-frontend: ## Seguir logs do frontend
	$(COMPOSE_DEV) logs -f frontend

ps: ## Listar containers e status
	$(COMPOSE_DEV) ps

# ── Dev leve (só infra — backend/frontend rodam no host) ─────

infra-up: .env ## Subir só PostgreSQL + MinIO (backend/frontend nativos)
	$(COMPOSE_INFRA) up -d
	@echo "Infra ativa:"
	@echo "  PostgreSQL → localhost:$${POSTGRES_PORT:-5434}"
	@echo "  MinIO API  → localhost:9000"
	@echo "  MinIO UI   → localhost:9001"

infra-down: ## Parar infra (PostgreSQL + MinIO)
	$(COMPOSE_INFRA) down

# ── Testes ───────────────────────────────────────────────────

test-backend: ## Rodar testes do backend (unitários + integração)
	$(COMPOSE_DEV) exec backend ./mvnw test -Dtest='!FlywayMigrationTest' -q

test-backend-all: ## Rodar TODOS os testes do backend (requer Docker-in-Docker)
	$(COMPOSE_DEV) exec backend ./mvnw test -q

test-frontend: ## Rodar testes do frontend
	$(COMPOSE_DEV) exec frontend npm run test:run

check-frontend: ## Lint + typecheck + testes + build do frontend
	$(COMPOSE_DEV) exec frontend npm run check

# ── Produção ─────────────────────────────────────────────────

build-prod: .env ## Build das imagens de produção (backend + frontend)
	$(COMPOSE_PROD) build

prod-up: .env ## Subir stack de produção
	$(COMPOSE_PROD) up -d

prod-down: ## Parar stack de produção
	$(COMPOSE_PROD) down

prod-logs: ## Seguir logs de produção
	$(COMPOSE_PROD) logs -f

# ── Limpeza ───────────────────────────────────────────────────

reset: ## Destruir volumes dev e recriar containers (PERDE DADOS)
	$(COMPOSE_DEV) down -v
	$(COMPOSE_DEV) up -d

reset-infra: ## Destruir volumes de infra e recriar (PERDE DADOS)
	$(COMPOSE_INFRA) down -v
	$(COMPOSE_INFRA) up -d

reset-prod: ## Destruir volumes de produção e recriar (PERDE DADOS)
	$(COMPOSE_PROD) down -v
	$(COMPOSE_PROD) up -d

status: ## Status geral da stack ativa
	@echo "=== Dev Stack ==="
	@$(COMPOSE_DEV) ps 2>/dev/null || echo "  Stack dev não está rodando"
	@echo ""
	@echo "=== Infra Stack ==="
	@$(COMPOSE_INFRA) ps 2>/dev/null || echo "  Stack infra não está rodando"
