.DEFAULT_GOAL := help
SHELL := /bin/sh

# rootless Podman reports Host.Security.Rootless; rootless Docker lists "rootless" in SecurityOptions
IS_ROOTLESS := $(shell { docker info --format '{{.Host.Security.Rootless}}'; docker info --format '{{json .SecurityOptions}}'; } 2>/dev/null | grep -Eqi '^true$$|rootless' && echo yes)
export CONTAINER_USER := $(if $(IS_ROOTLESS),0:0,$(shell id -u):$(shell id -g))

NODE_IMAGE := docker.io/library/node:26.13-trixie-slim
PNPM_VERSION := 12.16.1
COMPOSE := docker compose
RUN := $(COMPOSE) run --rm app

.PHONY: help build lockfile install up down dev logs shell pnpm \
        typecheck lint lint-fix fmt fmt-check test test-e2e \
        db-generate db-generate-custom db-migrate check clean

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build the app image
	$(COMPOSE) build app

lockfile: ## Create/refresh pnpm-lock.yaml (first run, before build)
	docker run --rm -v "$(CURDIR)":/app -w /app --user "$(CONTAINER_USER)" -e HOME=/tmp $(NODE_IMAGE) \
	  npx --yes pnpm@$(PNPM_VERSION) install --lockfile-only --store-dir /tmp/pnpm-store

install: ## Install deps into ./node_modules (inside the container)
	$(COMPOSE) run --rm --no-deps --user root app chown -R $(CONTAINER_USER) /pnpm-store
	$(COMPOSE) run --rm --no-deps app pnpm install --frozen-lockfile

up: ## Start db and app in background
	$(COMPOSE) up -d --wait

down: ## Stop containers
	$(COMPOSE) down

dev: ## Run app in foreground (watch mode, :3000)
	$(COMPOSE) up app

logs: ## Follow app logs
	$(COMPOSE) logs -f app

shell: ## Open a shell in the app container
	$(RUN) sh

pnpm: ## Run any pnpm command: make pnpm ARGS="add zod"
	$(RUN) pnpm $(ARGS)

typecheck: ## tsc --noEmit
	$(RUN) pnpm typecheck

lint: ## oxlint (type-aware, deny warnings)
	$(RUN) pnpm lint

lint-fix: ## oxlint --fix
	$(RUN) pnpm lint:fix

fmt: ## Format with oxfmt
	$(RUN) pnpm fmt

fmt-check: ## Check formatting
	$(RUN) pnpm fmt:check

test: ## Unit tests
	$(RUN) pnpm test

test-e2e: ## E2E tests (real Postgres)
	$(RUN) pnpm test:e2e

db-generate: ## Generate a migration from schema changes
	$(RUN) pnpm db:generate

db-generate-custom: ## Empty SQL migration: make db-generate-custom NAME=<migration_name>
	@test -n "$(NAME)" || (echo "NAME is required" && exit 1)
	$(RUN) pnpm db:generate:custom $(NAME)

db-migrate: ## Apply migrations to the dev database
	$(RUN) pnpm db:migrate

check: ## fmt-check, typecheck, lint, unit, e2e
	$(RUN) pnpm check

clean: ## Remove containers, volumes and build output
	$(COMPOSE) down -v --remove-orphans
	rm -rf dist coverage
