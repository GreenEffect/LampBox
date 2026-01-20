# Makefile for Docker LAMP Stack
# Alternative to lamp.sh for those who prefer make commands

.PHONY: help init check start stop restart status logs shell mysql rebuild clean ssl info start-proxy

# Load environment variables
include .env
export

# Default target
.DEFAULT_GOAL := help

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

##@ General

help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(BLUE)Usage:$(NC)\n  make $(GREEN)<target>$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Setup

init: ## Initialize the project (create .env, directories, etc.)
	@echo "$(GREEN)Initializing Docker LAMP stack...$(NC)"
	@./init.sh

check: ## Check system requirements
	@echo "$(GREEN)Checking system requirements...$(NC)"
	@./check-system.sh

##@ Docker Operations

start: ## Start the stack (direct port mode)
	@echo "$(GREEN)Starting Docker LAMP stack...$(NC)"
	@docker compose up -d
	@echo "$(GREEN)✓ Stack started$(NC)"
	@echo "$(BLUE)Access your site at: http://localhost:$(HTTP_PORT)$(NC)"

start-proxy: ssl ## Start the stack with reverse proxy (domain mode)
	@echo "$(GREEN)Starting Docker LAMP stack with reverse proxy...$(NC)"
	@docker compose --profile proxy up -d
	@echo "$(GREEN)✓ Stack started with reverse proxy$(NC)"
	@echo "$(BLUE)Access your site at: https://$(PROJECT_DOMAIN)$(NC)"

stop: ## Stop the stack
	@echo "$(YELLOW)Stopping Docker LAMP stack...$(NC)"
	@docker compose --profile proxy down
	@echo "$(GREEN)✓ Stack stopped$(NC)"

restart: stop start ## Restart the stack

status: ## Show container status
	@echo "$(BLUE)Container Status:$(NC)"
	@docker compose ps

logs: ## Show logs (use 'make logs SERVICE=webserver' for specific service)
	@docker compose logs -f $(SERVICE)

##@ Container Access

shell: ## Open bash shell in webserver container
	@echo "$(GREEN)Opening bash shell in webserver...$(NC)"
	@docker compose exec webserver bash

mysql: ## Open MySQL shell
	@echo "$(GREEN)Opening MySQL shell...$(NC)"
	@docker compose exec database mysql -u root -p$(MYSQL_ROOT_PASSWORD)

##@ Maintenance

rebuild: ## Rebuild all containers from scratch
	@echo "$(YELLOW)Rebuilding Docker LAMP stack...$(NC)"
	@docker compose --profile proxy down
	@docker compose build --no-cache
	@echo "$(GREEN)✓ Rebuild complete$(NC)"
	@make start

clean: ## Remove all containers, networks, and volumes (⚠️  destructive!)
	@echo "$(YELLOW)⚠️  WARNING: This will remove all data!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose --profile proxy down -v; \
		echo "$(GREEN)✓ All containers, networks, and volumes removed$(NC)"; \
	else \
		echo "$(YELLOW)Clean cancelled$(NC)"; \
	fi

##@ SSL

ssl: ## Generate SSL certificates
	@echo "$(GREEN)Generating SSL certificates...$(NC)"
	@./generate-ssl-certs.sh

##@ Information

info: ## Show connection information
	@echo ""
	@echo "$(BLUE)===================================================================$(NC)"
	@echo "$(BLUE)Connection Information$(NC)"
	@echo "$(BLUE)===================================================================$(NC)"
	@echo ""
	@echo "$(GREEN)Project:$(NC) $(COMPOSE_PROJECT_NAME)"
	@echo "$(GREEN)PHP Version:$(NC) $(PHPVERSION)"
	@echo "$(GREEN)Database:$(NC) $(DATABASE)"
	@echo ""
	@if [ "$(USE_REVERSE_PROXY)" = "true" ]; then \
		echo "$(GREEN)Website:$(NC) https://$(PROJECT_DOMAIN)"; \
		echo "$(GREEN)phpMyAdmin:$(NC) https://$(PROJECT_DOMAIN)/$(COMPOSE_PROJECT_NAME)-mysql"; \
	else \
		echo "$(GREEN)Website (HTTP):$(NC) http://localhost:$(HTTP_PORT)"; \
		echo "$(GREEN)Website (HTTPS):$(NC) https://localhost:$(HTTPS_PORT)"; \
		echo "$(GREEN)phpMyAdmin:$(NC) http://localhost:$(HTTP_PORT)/$(COMPOSE_PROJECT_NAME)-mysql"; \
	fi
	@if [ -n "$(MYSQL_PORT)" ]; then \
		echo "$(GREEN)MySQL:$(NC) localhost:$(MYSQL_PORT)"; \
	fi
	@echo ""
	@echo "$(BLUE)Database Credentials:$(NC)"
	@echo "  Host: $(COMPOSE_PROJECT_NAME)-database"
	@echo "  Root Password: $(MYSQL_ROOT_PASSWORD)"
	@echo "  Database: $(MYSQL_DATABASE)"
	@echo "  User: $(MYSQL_USER)"
	@echo "  Password: $(MYSQL_PASSWORD)"
	@echo ""

##@ Development

watch: ## Watch logs in real-time
	@docker compose logs -f

exec: ## Execute command in webserver (use: make exec CMD="ls -la")
	@docker compose exec webserver $(CMD)

composer: ## Run composer command (use: make composer CMD="install")
	@docker compose exec webserver composer $(CMD)

php: ## Run PHP command (use: make php CMD="artisan migrate")
	@docker compose exec webserver php $(CMD)

##@ Database

db-backup: ## Backup database to backups/$(date).sql
	@echo "$(GREEN)Backing up database...$(NC)"
	@mkdir -p backups
	@docker compose exec -T database mysqldump -u root -p$(MYSQL_ROOT_PASSWORD) --all-databases > backups/backup-$$(date +%Y%m%d-%H%M%S).sql
	@echo "$(GREEN)✓ Database backed up to backups/backup-$$(date +%Y%m%d-%H%M%S).sql$(NC)"

db-restore: ## Restore database from backup (use: make db-restore FILE=backups/backup.sql)
	@if [ -z "$(FILE)" ]; then \
		echo "$(YELLOW)Usage: make db-restore FILE=backups/backup.sql$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Restoring database from $(FILE)...$(NC)"
	@docker compose exec -T database mysql -u root -p$(MYSQL_ROOT_PASSWORD) < $(FILE)
	@echo "$(GREEN)✓ Database restored$(NC)"
