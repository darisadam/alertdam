# =============================================================================
# PagerDam — Makefile
# =============================================================================

.PHONY: help dev build test lint clean docker docker-down migrate

BINARY_NAME=pagerdam
BACKEND_DIR=./backend
WEB_DIR=./web
MOBILE_DIR=./mobile

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# -----------------------------------------------------------------------------
# Development
# -----------------------------------------------------------------------------
dev: ## Start the full stack locally (Docker Compose)
	docker compose up --build

dev-backend: ## Run the Go backend with hot reload (requires air)
	cd $(BACKEND_DIR) && air

dev-web: ## Start the React web dashboard dev server
	cd $(WEB_DIR) && npm run dev

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------
build: ## Build the Go backend binary
	cd $(BACKEND_DIR) && go build -o bin/$(BINARY_NAME) ./cmd/pagerdam/...

build-web: ## Build the React web dashboard for production
	cd $(WEB_DIR) && npm run build

build-docker: ## Build the Docker image
	docker build -f deploy/docker/Dockerfile -t pagerdam:latest .

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------
test: ## Run all Go tests
	cd $(BACKEND_DIR) && go test ./... -v -race -coverprofile=coverage.out

test-coverage: ## Run tests and open HTML coverage report
	cd $(BACKEND_DIR) && go test ./... -coverprofile=coverage.out && go tool cover -html=coverage.out

# -----------------------------------------------------------------------------
# Code Quality
# -----------------------------------------------------------------------------
lint: ## Run Go linter (requires golangci-lint)
	cd $(BACKEND_DIR) && golangci-lint run ./...

lint-web: ## Run ESLint on the web dashboard
	cd $(WEB_DIR) && npm run lint

fmt: ## Format Go code
	cd $(BACKEND_DIR) && gofmt -s -w .

vet: ## Run go vet
	cd $(BACKEND_DIR) && go vet ./...

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------
migrate-up: ## Run all pending database migrations
	cd $(BACKEND_DIR) && go run ./cmd/pagerdam/... migrate up

migrate-down: ## Roll back the last migration
	cd $(BACKEND_DIR) && go run ./cmd/pagerdam/... migrate down

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------
docker: ## Start the full stack with Docker Compose (detached)
	docker compose up -d --build

docker-down: ## Stop and remove all containers
	docker compose down

docker-logs: ## Tail logs from all containers
	docker compose logs -f

docker-clean: ## Remove all containers, volumes, and images
	docker compose down -v --rmi local

# -----------------------------------------------------------------------------
# Secrets Scanning
# -----------------------------------------------------------------------------
secrets-scan: ## Run Gitleaks to detect secrets (requires gitleaks)
	gitleaks detect --config=.gitleaks.toml --source=. -v

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
setup: ## Install all development dependencies
	@echo "Installing Go tools..."
	go install github.com/air-verse/air@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo "Installing web dependencies..."
	cd $(WEB_DIR) && npm install
	@echo "Done! Run 'make dev' to start."

clean: ## Remove build artifacts
	cd $(BACKEND_DIR) && rm -rf bin/ coverage.out
	cd $(WEB_DIR) && rm -rf dist/ node_modules/
