.PHONY: help setup up down logs logs-backend logs-frontend ps \
        infra-up infra-down \
        test-all test-e2e test-e2e-spec test-backend test-backend-all test-frontend check-frontend \
        monitoring-up monitoring-down \
        build-prod prod-up prod-down prod-logs \
        reset reset-infra reset-prod status

COMPOSE_DEV        := docker compose -f docker-compose.dev.yml --env-file .env
COMPOSE_INFRA      := docker compose -f docker-compose.infra.yml --env-file .env
COMPOSE_PROD       := docker compose -f docker-compose.prod.yml --env-file .env
COMPOSE_MONITORING := docker compose -f docker-compose.dev.yml --env-file .env --profile monitoring

# Cria .env a partir do exemplo se não existir
.env:
	@cp .env.example .env
	@if grep -q "^JWT_SECRET=$$" .env; then \
		SECRET=$$(openssl rand -hex 32 2>/dev/null || od -An -N32 -tx1 /dev/urandom | tr -d ' \n' | head -c 64 || echo "development_jwt_secret_fallback_key_32_chars"); \
		sed -i "s/^JWT_SECRET=.*/JWT_SECRET=$$SECRET/" .env; \
		echo "🔑 JWT_SECRET gerado automaticamente com sucesso!"; \
	fi
	@echo "⚠  .env criado a partir de .env.example — revise antes de subir em produção."

help: ## Mostrar todos os comandos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  URLs (dev):"
	@echo "    Backend   → http://localhost:8080"
	@echo "    Swagger   → http://localhost:8080/swagger-ui.html"
	@echo "    Frontend  → http://localhost:5173"
	@echo "    MinIO     → http://localhost:9001"
	@echo "    Prometheus→ http://localhost:9090  (make monitoring-up)"
	@echo "    Grafana   → http://localhost:3000  (make monitoring-up)"

# ── Configuração ─────────────────────────────────────────────

setup: .env ## Configuração inicial (cria .env se não existir)
	@echo "Setup concluído. Execute 'make up' para iniciar o ambiente de dev."

# ── Dev completo (containers) ────────────────────────────────

up: .env ## Subir stack completa de dev (backend + frontend + infra)
	$(COMPOSE_DEV) up -d
	@echo ""
	@echo "Stack de desenvolvimento ativa:"
	@echo "  Backend   → http://localhost:8080"
	@echo "  Swagger   → http://localhost:8080/swagger-ui.html"
	@echo "  Frontend  → http://localhost:5173"
	@echo "  MinIO UI  → http://localhost:9001"
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

# ── Dev leve (só infra) ──────────────────────────────────────

infra-up: .env ## Subir só PostgreSQL + MinIO (backend/frontend nativos no host)
	$(COMPOSE_INFRA) up -d
	@echo "Infra ativa:"
	@echo "  PostgreSQL → localhost:$${POSTGRES_PORT:-5434}"
	@echo "  MinIO API  → localhost:9000"
	@echo "  MinIO UI   → localhost:9001"

infra-down: ## Parar infra (PostgreSQL + MinIO)
	$(COMPOSE_INFRA) down

# ── Testes ───────────────────────────────────────────────────

test-all: test-backend test-frontend test-e2e ## Rodar todas as suítes (backend + frontend + E2E)

test-e2e: ## Rodar testes E2E Playwright (requer: make up)
	$(COMPOSE_DEV) --profile e2e run --rm playwright

test-e2e-spec: ## Rodar spec específico: make test-e2e-spec SPEC=kanban
	$(COMPOSE_DEV) --profile e2e run --rm playwright \
	  sh -c "npm install --prefer-offline && npx playwright install chromium && npx playwright test e2e/$(SPEC).spec.ts"

test-backend: ## Rodar testes do backend (unitários + integração)
	$(COMPOSE_DEV) exec backend ./mvnw test -Dtest='!FlywayMigrationTest' -q

test-backend-all: ## Rodar TODOS os testes do backend (requer Docker-in-Docker)
	$(COMPOSE_DEV) exec backend ./mvnw test -q

test-frontend: ## Rodar testes unitários do frontend (Vitest)
	$(COMPOSE_DEV) exec frontend npm run test:run

check-frontend: ## Lint + typecheck + testes + build do frontend
	$(COMPOSE_DEV) exec frontend npm run check

# ── Monitoramento (Prometheus + Grafana) ─────────────────────

monitoring-up: .env ## Subir Prometheus + Grafana (requer stack dev rodando)
	$(COMPOSE_MONITORING) up -d prometheus grafana
	@echo ""
	@echo "Monitoramento ativo:"
	@echo "  Prometheus → http://localhost:9090"
	@echo "  Grafana    → http://localhost:3000  (admin / $${GRAFANA_PASSWORD:-admin})"

monitoring-down: ## Parar Prometheus + Grafana
	$(COMPOSE_MONITORING) stop prometheus grafana

# ── Produção ─────────────────────────────────────────────────

build-prod: .env ## Build das imagens de produção (backend + frontend)
	$(COMPOSE_PROD) build

prod-up: .env ## Subir stack de produção (usa imagens do GHCR)
	$(COMPOSE_PROD) up -d
	@echo ""
	@echo "Stack de produção ativa:"
	@echo "  Frontend  → http://localhost"
	@echo "  MinIO UI  → http://localhost:9001"

prod-down: ## Parar stack de produção
	$(COMPOSE_PROD) down

prod-logs: ## Seguir logs de produção
	$(COMPOSE_PROD) logs -f

# ── Limpeza ───────────────────────────────────────────────────

reset: ## Destruir volumes dev e recriar containers (PERDE DADOS DEV)
	$(COMPOSE_DEV) down -v
	$(COMPOSE_DEV) up -d

reset-infra: ## Destruir volumes de infra e recriar (PERDE DADOS INFRA)
	$(COMPOSE_INFRA) down -v
	$(COMPOSE_INFRA) up -d

reset-prod: ## Destruir volumes de produção e recriar (PERDE DADOS PROD)
	$(COMPOSE_PROD) down -v
	$(COMPOSE_PROD) up -d

status: ## Status geral de todas as stacks
	@echo "=== Dev Stack ==="
	@$(COMPOSE_DEV) ps 2>/dev/null || echo "  não está rodando"
	@echo ""
	@echo "=== Infra Stack ==="
	@$(COMPOSE_INFRA) ps 2>/dev/null || echo "  não está rodando"
