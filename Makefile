# Workshop Pulse — convenience Makefile
# Designed to run identically on macOS, Linux, and Google Cloud Shell.

ROOT := $(shell pwd)
AGENT_DIR := insight-agent
FRONTEND_DIR := frontend
PYTHON ?= python3

# Cloud Shell uses 8081 for the second web preview port.
FRONTEND_PORT := $(shell [ "$$CLOUD_SHELL" = "true" ] && echo 8081 || echo 5173)
AGENT_PORT := 8080

.PHONY: help bootstrap scaffold-frontend scaffold-agent firebase-config agent-dev agent-test frontend-dev frontend-build clean preview-info gcloud-status gcloud-list gemini-test

help:
	@echo "Setup:"
	@echo "  bootstrap          Install global tooling (gemini, agents-cli, firebase, uv, conductor ext)"
	@echo "  scaffold-frontend  npm create vite + auto-populate frontend/.env via firebase-config"
	@echo "  scaffold-agent     agents-cli create insight-agent (only if missing)"
	@echo "  firebase-config    Auto-populate VITE_FIREBASE_* in frontend/.env"
	@echo ""
	@echo "Run:"
	@echo "  agent-dev          Start ADK insight-agent on :$(AGENT_PORT)"
	@echo "  agent-test         Smoke-test root_agent locally (no server)"
	@echo "  frontend-dev       Start Vite dev server on :$(FRONTEND_PORT)"
	@echo "  frontend-build     Production build of frontend"
	@echo "  preview-info       Print Cloud Shell web-preview URLs"
	@echo ""
	@echo "Ops:"
	@echo "  gcloud-status      Show active gcloud profile / ADC state"
	@echo "  gcloud-list        List all configured gcloud profiles"
	@echo "  gemini-test        Run smoke tests for gemini-cli setup"
	@echo "  clean              Remove venvs, node_modules, build artefacts"

bootstrap:
	bash scripts/bootstrap.sh

scaffold-frontend:
	@if [ -f $(FRONTEND_DIR)/package.json ]; then \
	  echo "frontend/ already scaffolded"; \
	else \
	  npm create vite@latest $(FRONTEND_DIR) -- --template react-ts -y && \
	  cd $(FRONTEND_DIR) && npm install; \
	fi
	@$(MAKE) firebase-config

firebase-config:
	@bash scripts/firebase-config.sh

scaffold-agent:
	@if [ -f $(AGENT_DIR)/pyproject.toml ]; then \
	  echo "$(AGENT_DIR)/ already scaffolded"; \
	else \
	  uvx google-agents-cli create $(AGENT_DIR) --prototype --yes \
	    --skip-checks --region us-central1 --deployment-target none && \
	  cd $(AGENT_DIR) && uv venv --python 3.12 .venv && \
	  . .venv/bin/activate && uv pip install -e . --quiet; \
	fi

agent-dev:
	@if [ ! -f $(AGENT_DIR)/pyproject.toml ]; then \
	  echo "✗ $(AGENT_DIR)/ not scaffolded yet. Run: make scaffold-agent"; exit 1; \
	fi
	cd $(AGENT_DIR) && \
	. .venv/bin/activate && \
	uvicorn app.fast_api_app:app --host 0.0.0.0 --port $(AGENT_PORT) --reload

agent-test:
	cd $(AGENT_DIR) && \
	. .venv/bin/activate && \
	$(PYTHON) -m app.agent

frontend-dev:
	@if [ ! -f $(FRONTEND_DIR)/package.json ]; then \
	  echo "✗ $(FRONTEND_DIR)/ not scaffolded yet. Run: make scaffold-frontend"; exit 1; \
	fi
	cd $(FRONTEND_DIR) && npm run dev -- --host 0.0.0.0 --port $(FRONTEND_PORT)

frontend-build:
	cd $(FRONTEND_DIR) && npm run build

preview-info:
	@echo "Agent     :  port $(AGENT_PORT)"
	@echo "Frontend  :  port $(FRONTEND_PORT)"
	@if [ "$$CLOUD_SHELL" = "true" ]; then \
	  echo ""; \
	  echo "Cloud Shell web preview:"; \
	  echo "  → Click 'Web Preview' in toolbar, choose port $(AGENT_PORT) for the agent"; \
	  echo "  → Or port $(FRONTEND_PORT) for the frontend"; \
	fi

gcloud-status:
	@bash scripts/gcloud-profile.sh status

gcloud-list:
	@bash scripts/gcloud-profile.sh list

gemini-test:
	@bash scripts/gemini-smoke-test.sh

clean:
	rm -rf $(AGENT_DIR)/.venv
	rm -rf $(FRONTEND_DIR)/node_modules $(FRONTEND_DIR)/dist
	rm -rf functions/node_modules
