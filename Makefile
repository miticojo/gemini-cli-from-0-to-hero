# Workshop Pulse — convenience Makefile
# Designed to run identically on macOS, Linux, and Google Cloud Shell.

ROOT := $(shell pwd)
AGENT_DIR := insight-agent
FRONTEND_DIR := frontend
PYTHON ?= python3

# Cloud Shell uses 8081 for the second web preview port.
FRONTEND_PORT := $(shell [ "$$CLOUD_SHELL" = "true" ] && echo 8081 || echo 5173)
AGENT_PORT := 8080

.PHONY: help bootstrap scaffold-frontend scaffold-agent firebase-config agent-dev agent-test frontend-dev frontend-build clean preview-info expose publish gcloud-status gcloud-list gemini-test

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
	@echo "Publish:"
	@echo "  expose             [Cloud Shell] Get public preview URLs + patch frontend/.env"
	@echo "  publish            [Local] firebase deploy --only hosting (permanent URL)"
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
	  cd $(FRONTEND_DIR) && \
	  npm install && \
	  npm install firebase react-router-dom recharts qrcode && \
	  npm install -D @types/qrcode && \
	  for f in tsconfig.app.json tsconfig.json; do \
	    if [ -f "$$f" ]; then \
	      sed -i.bak -E \
	        -e 's/"noUnusedLocals" *: *true/"noUnusedLocals": false/' \
	        -e 's/"noUnusedParameters" *: *true/"noUnusedParameters": false/' \
	        -e 's/"verbatimModuleSyntax" *: *true/"verbatimModuleSyntax": false/' \
	        -e 's/"erasableSyntaxOnly" *: *true/"erasableSyntaxOnly": false/' \
	        "$$f" && \
	      rm -f "$$f.bak" && \
	      echo "relaxed tsconfig at frontend/$$f"; \
	    fi; \
	  done; \
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

expose:
	@if [ "$$CLOUD_SHELL" = "true" ]; then \
	  agent_url=$$(cloudshell get-web-host-url --port=$(AGENT_PORT) 2>/dev/null); \
	  fe_url=$$(cloudshell get-web-host-url --port=$(FRONTEND_PORT) 2>/dev/null); \
	  if [ -z "$$agent_url" ] || [ -z "$$fe_url" ]; then \
	    echo "✗ cloudshell get-web-host-url failed."; \
	    echo "  Use the 'Web Preview' button in the toolbar manually."; \
	    exit 1; \
	  fi; \
	  if [ -f $(FRONTEND_DIR)/.env ]; then \
	    sed -i.bak "s|^VITE_AGENT_ENDPOINT=.*|VITE_AGENT_ENDPOINT=$$agent_url|" $(FRONTEND_DIR)/.env && \
	    rm -f $(FRONTEND_DIR)/.env.bak; \
	    echo "✓ patched $(FRONTEND_DIR)/.env: VITE_AGENT_ENDPOINT=$$agent_url"; \
	  else \
	    echo "! $(FRONTEND_DIR)/.env missing — run 'make scaffold-frontend' first"; \
	  fi; \
	  echo ""; \
	  echo "  agent (8080):    $$agent_url"; \
	  echo "  frontend (8081): $$fe_url"; \
	  echo ""; \
	  echo "  → restart 'make frontend-dev' so vite picks up the new env"; \
	  echo "  → audience scans QR rendered on $$fe_url/admin (qrcode points to $$fe_url/p/<workshopId>)"; \
	else \
	  echo "Not running in Cloud Shell. Options for exposing local servers:"; \
	  echo ""; \
	  echo "  Cloudflare Tunnel (free, no signup):"; \
	  echo "    cloudflared tunnel --url http://localhost:$(AGENT_PORT)    # agent (tab 1)"; \
	  echo "    cloudflared tunnel --url http://localhost:$(FRONTEND_PORT) # frontend (tab 2)"; \
	  echo "    Then update VITE_AGENT_ENDPOINT in $(FRONTEND_DIR)/.env to the agent tunnel URL."; \
	  echo ""; \
	  echo "  Firebase Hosting (permanent URL, frontend only):"; \
	  echo "    make publish     # builds and deploys frontend to <project>.web.app"; \
	  echo "    Pair with cloudflared for the agent endpoint."; \
	fi

publish: frontend-build
	@if ! firebase login:list 2>&1 | grep -q "Logged in as"; then \
	  echo "✗ firebase CLI not logged in."; \
	  echo "  Run: firebase login"; \
	  exit 1; \
	fi
	@if [ ! -f firebase.json ]; then \
	  echo "writing firebase.json (hosting points to $(FRONTEND_DIR)/dist)..."; \
	  printf '%s\n' \
	    '{' \
	    '  "hosting": {' \
	    '    "public": "$(FRONTEND_DIR)/dist",' \
	    '    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],' \
	    '    "rewrites": [{ "source": "**", "destination": "/index.html" }]' \
	    '  }' \
	    '}' > firebase.json; \
	fi
	@if [ ! -f .firebaserc ]; then \
	  proj=$$(gcloud config get-value project 2>/dev/null); \
	  if [ -z "$$proj" ] || [ "$$proj" = "(unset)" ]; then \
	    echo "✗ no default GCP project. Run: gcloud config set project <id>"; exit 1; \
	  fi; \
	  printf '{"projects":{"default":"%s"}}\n' "$$proj" > .firebaserc; \
	  echo "wrote .firebaserc → project $$proj"; \
	fi
	firebase deploy --only hosting
	@proj=$$(python3 -c "import json; print(json.load(open('.firebaserc'))['projects']['default'])"); \
	  echo ""; \
	  echo "  Public URL:  https://$$proj.web.app"; \
	  echo "  Audience can scan QR rendered at https://$$proj.web.app/admin"

clean:
	rm -rf $(AGENT_DIR)/.venv
	rm -rf $(FRONTEND_DIR)/node_modules $(FRONTEND_DIR)/dist
	rm -rf functions/node_modules
