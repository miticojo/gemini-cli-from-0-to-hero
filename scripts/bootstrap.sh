#!/usr/bin/env bash
# Bootstrap Workshop Pulse — works on Google Cloud Shell and local macOS/Linux.
# Idempotent: safe to re-run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ---------- detect environment ------------------------------------------------
IN_CLOUD_SHELL="${CLOUD_SHELL:-false}"
if [[ "$IN_CLOUD_SHELL" == "true" ]]; then
  ENV_TAG="cloudshell"
else
  ENV_TAG="local"
fi
echo "▶ Bootstrap environment: ${ENV_TAG}"

# ---------- helpers -----------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }
log()  { printf "  • %s\n" "$*"; }
ok()   { printf "  ✓ %s\n" "$*"; }
warn() { printf "  ! %s\n" "$*"; }

# ---------- 1. gcloud project + ADC ------------------------------------------
echo "▶ Step 1/6 — gcloud auth + project"
if ! have gcloud; then
  warn "gcloud not found. On Cloud Shell this never happens; install Cloud SDK."
  exit 1
fi

PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
if [[ -z "${PROJECT_ID:-}" || "$PROJECT_ID" == "(unset)" ]]; then
  warn "No GCP project set. Run: gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi
ok "Project: ${PROJECT_ID}"

if [[ "$IN_CLOUD_SHELL" != "true" ]]; then
  if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
    warn "ADC missing. Running: gcloud auth application-default login"
    gcloud auth application-default login --quiet
  fi
fi
ok "Application Default Credentials available"

# ---------- 2. enable Vertex AI API ------------------------------------------
echo "▶ Step 2/6 — enable required APIs (idempotent)"
APIS=(
  aiplatform.googleapis.com
  cloudresourcemanager.googleapis.com
  iam.googleapis.com
  cloudbuild.googleapis.com
  run.googleapis.com
  cloudfunctions.googleapis.com
  firebase.googleapis.com
  firestore.googleapis.com
)
gcloud services enable "${APIS[@]}" --project="$PROJECT_ID" --quiet || warn "API enable partial (check billing)"
ok "APIs enabled"

# ---------- 3. install gemini CLI --------------------------------------------
echo "▶ Step 3/6 — gemini CLI"
if ! have gemini; then
  log "Installing @google/gemini-cli globally"
  npm install -g @google/gemini-cli
fi
ok "gemini $(gemini --version)"

# ---------- 4. install agents-cli + skills -----------------------------------
echo "▶ Step 4/6 — agents-cli + ADK skills"
if ! have uvx; then
  log "Installing uv (provides uvx)"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
  else
    pip install --user uv
  fi
  export PATH="$HOME/.local/bin:$PATH"
fi
uvx google-agents-cli setup --quiet || uvx google-agents-cli setup
ok "agents-cli installed; ADK skills available in ~/.agents/skills/"

# ---------- 5. firebase CLI --------------------------------------------------
echo "▶ Step 5 — firebase CLI"
if ! have firebase; then
  log "Installing firebase-tools globally"
  npm install -g firebase-tools
fi
ok "firebase $(firebase --version)"

# ---------- 5b. conductor extension -----------------------------------------
echo "▶ Step 5b — conductor extension (Gemini CLI)"
if [[ ! -d "${HOME}/.gemini/extensions/conductor" ]]; then
  log "Installing conductor extension..."
  gemini extensions install https://github.com/gemini-cli-extensions/conductor \
    --consent --skip-settings >/dev/null 2>&1 \
    && ok "conductor installed" \
    || warn "conductor install failed (re-run manually if needed)"
else
  ok "conductor already installed"
fi

# ---------- 6. python venv + agent deps (only if scaffolded) ----------------
if [[ -f "$ROOT/insight-agent/pyproject.toml" ]]; then
  echo "▶ Step 6 — insight-agent Python deps"
  cd "$ROOT/insight-agent"
  if [[ ! -d ".venv" ]]; then
    uv venv --python 3.12 .venv
  fi
  # shellcheck disable=SC1091
  source .venv/bin/activate
  uv pip install -e . --quiet
  ok "insight-agent venv ready"
  cd "$ROOT"
else
  log "insight-agent/ not scaffolded yet — skipping (will be created live in slot 6)"
fi

# ---------- 7. frontend deps (only if scaffolded) ---------------------------
if [[ -f "$ROOT/frontend/package.json" ]]; then
  echo "▶ Step 7 — frontend deps"
  (cd "$ROOT/frontend" && npm install --silent) && ok "frontend deps installed" || warn "frontend deps skipped"
else
  log "frontend/ not scaffolded yet — skipping (will be created live in slot 5b)"
fi

# ---------- 8. trust workspace + verify settings ----------------------------
echo "▶ Step 8/8 — trust workspace + Gemini CLI settings"
TRUST_FILE="${HOME}/.gemini/trustedFolders.json"
mkdir -p "${HOME}/.gemini"
python3 - "$ROOT" "$TRUST_FILE" <<'PY'
import json, os, sys
root, tf = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(tf):
    try: data = json.load(open(tf))
    except Exception: data = {}
data[root] = "TRUST_FOLDER"
json.dump(data, open(tf, "w"), indent=2)
print(f"  ✓ workspace trusted: {root}")
PY

# ensure workspace .gemini/settings.json exists with vertex-ai auth
if [[ ! -f .gemini/settings.json ]]; then
  cat > .gemini/settings.json <<JSON
{
  "security": { "auth": { "selectedType": "vertex-ai" } },
  "general":  { "model": "${GEMINI_MODEL:-gemini-3.1-pro-preview}" }
}
JSON
  ok "wrote .gemini/settings.json (vertex-ai)"
else
  ok ".gemini/settings.json already present"
fi

# ---------- 9. shell env hint ------------------------------------------------
cat > .gemini/env.sh <<EOF
# Source this file before running gemini in this workspace:
#   source .gemini/env.sh
export GOOGLE_CLOUD_PROJECT=${PROJECT_ID}
export GOOGLE_CLOUD_LOCATION=${GOOGLE_CLOUD_LOCATION:-global}
export GOOGLE_GENAI_USE_VERTEXAI=true
export GEMINI_MODEL=${GEMINI_MODEL:-gemini-3.1-pro-preview}
EOF
ok "wrote .gemini/env.sh — source it before running gemini"

# ---------- summary ----------------------------------------------------------
cat <<EOF

────────────────────────────────────────────────────────────────────────────
✅ Bootstrap complete (${ENV_TAG})

   Project:  ${PROJECT_ID}
   Model:    ${GEMINI_MODEL:-gemini-3.1-pro-preview} (Vertex AI)
   Region:   ${GOOGLE_CLOUD_LOCATION:-global}

Next steps:
   1.  cp .env.example .env  &&  edit values
   2.  source .gemini/env.sh         (set Vertex AI env vars for gemini)
   3.  Start the agent:   make agent-dev      (port 8080)
   4.  Start the frontend: make frontend-dev  (port 8081 on Cloud Shell, 5173 local)
   5.  Open Gemini CLI:    gemini             (loads GEMINI.md + agents + skills)
────────────────────────────────────────────────────────────────────────────
EOF
