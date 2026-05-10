#!/usr/bin/env bash
# Auto-populate frontend/.env with VITE_FIREBASE_* keys.
#
# Idempotent. Safe to re-run. Skips work if frontend/.env already has
# all four keys filled (so subsequent runs in the same Cloud Shell are
# instant).
#
# Pre-conditions:
#   - `firebase` CLI installed and logged in
#   - frontend/ directory exists (call after `make scaffold-frontend`)
#   - $GOOGLE_CLOUD_PROJECT set (or gcloud project configured)
#
# Strategy:
#   1. Resolve project id (env > gcloud).
#   2. Ensure Firebase project exists (firebase projects:list).
#   3. Ensure a Web app exists; create one named "workshop-pulse" if not.
#   4. firebase apps:sdkconfig WEB --json -> parse -> write to .env.
#   5. Append/update VITE_FIREBASE_* lines without touching other keys.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT}/frontend/.env"

log()  { printf "  • %s\n" "$*"; }
ok()   { printf "  ✓ %s\n" "$*"; }
warn() { printf "  ! %s\n" "$*" >&2; }
die()  { printf "  ✗ %s\n" "$*" >&2; exit 1; }

# Bail early if frontend/ does not exist yet (workshop slot 5 not started).
if [[ ! -d "${ROOT}/frontend" ]]; then
  warn "frontend/ does not exist yet. Run 'make scaffold-frontend' first."
  exit 0
fi

# Skip if already populated (idempotency).
if [[ -f "$ENV_FILE" ]]; then
  if grep -q '^VITE_FIREBASE_API_KEY=.\+' "$ENV_FILE" \
     && grep -q '^VITE_FIREBASE_AUTH_DOMAIN=.\+' "$ENV_FILE" \
     && grep -q '^VITE_FIREBASE_PROJECT_ID=.\+' "$ENV_FILE" \
     && grep -q '^VITE_FIREBASE_APP_ID=.\+' "$ENV_FILE"; then
    ok "frontend/.env already has all VITE_FIREBASE_* keys; skipping."
    exit 0
  fi
fi

# Resolve project id.
PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
[[ -n "${PROJECT_ID:-}" && "$PROJECT_ID" != "(unset)" ]] \
  || die "no GCP project resolved. Run: gcloud config set project <id>"
log "project: ${PROJECT_ID}"

command -v firebase >/dev/null 2>&1 \
  || die "firebase CLI not installed. Run: npm install -g firebase-tools"

# Helper: write a stub .env so the frontend dev server can boot. Real values
# can be filled later by re-running this script (after `firebase login` etc.).
write_stub_env() {
  local reason="$1"
  warn "writing stub frontend/.env (${reason})"
  warn "after fixing the issue, re-run: make firebase-config"
  cat > "$ENV_FILE" <<EOF
# STUB: populated by firebase-config.sh fallback (${reason}).
# Replace these with real Firebase config: \`firebase apps:sdkconfig WEB --json\`.
VITE_FIREBASE_API_KEY=AIzaSy-stub-key-replace-me
VITE_FIREBASE_AUTH_DOMAIN=${PROJECT_ID}.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=${PROJECT_ID}
VITE_FIREBASE_APP_ID=1:000000000000:web:0000000000000000000000
VITE_AGENT_ENDPOINT=http://localhost:8080
EOF
  exit 0
}

# Check firebase CLI auth state.
if ! firebase login:list 2>&1 | grep -q "Logged in as"; then
  write_stub_env "firebase CLI not logged in — run \`firebase login\` then re-try"
fi

# Ensure Firebase is enabled on the project.
if ! firebase projects:list --json 2>/dev/null \
       | python3 -c "import sys,json; d=json.load(sys.stdin); ids=[p['projectId'] for p in d.get('result',[])]; sys.exit(0 if '${PROJECT_ID}' in ids else 1)"
then
  warn "project ${PROJECT_ID} is not registered with Firebase yet."
  log "registering Firebase on the project (firebase projects:addfirebase)..."
  if ! firebase projects:addfirebase "$PROJECT_ID" 2>&1; then
    write_stub_env "could not register Firebase on ${PROJECT_ID} (auth/billing/permissions)"
  fi
  ok "Firebase registered on ${PROJECT_ID}"
fi

# Ensure a Web app exists.
APP_ID="$(firebase apps:list WEB --project "$PROJECT_ID" --json 2>/dev/null \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
apps = d.get('result', [])
print(apps[0]['appId'] if apps else '', end='')
")"

if [[ -z "$APP_ID" ]]; then
  log "no Web app found. Creating one named 'workshop-pulse'..."
  firebase apps:create WEB workshop-pulse --project "$PROJECT_ID" --quiet >/dev/null
  APP_ID="$(firebase apps:list WEB --project "$PROJECT_ID" --json 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['result'][0]['appId'])")"
fi
ok "Web app id: ${APP_ID}"

# Pull the SDK config.
log "fetching firebase apps:sdkconfig..."
SDK_JSON="$(firebase apps:sdkconfig WEB "$APP_ID" --project "$PROJECT_ID" --json 2>/dev/null \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
# response shape: {'status': 'success', 'result': {'sdkConfig': {...}}}
cfg = d['result']['sdkConfig'] if 'result' in d else d
print(json.dumps(cfg))
")"

# Extract keys.
VITE_API_KEY="$(echo "$SDK_JSON"     | python3 -c "import sys,json; print(json.load(sys.stdin).get('apiKey',''))")"
VITE_AUTH_DOMAIN="$(echo "$SDK_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('authDomain',''))")"
VITE_PROJECT_ID="$(echo "$SDK_JSON"  | python3 -c "import sys,json; print(json.load(sys.stdin).get('projectId',''))")"
VITE_APP_ID="$(echo "$SDK_JSON"      | python3 -c "import sys,json; print(json.load(sys.stdin).get('appId',''))")"

[[ -n "$VITE_API_KEY"     ]] || die "could not parse apiKey from sdkconfig"
[[ -n "$VITE_AUTH_DOMAIN" ]] || die "could not parse authDomain"
[[ -n "$VITE_PROJECT_ID"  ]] || die "could not parse projectId"
[[ -n "$VITE_APP_ID"      ]] || die "could not parse appId"

# Write into frontend/.env.
touch "$ENV_FILE"

# upsert helper
upsert() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    # macOS sed: use -i ''; GNU sed: use -i. Detect.
    if sed --version >/dev/null 2>&1; then
      sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
    else
      sed -i '' "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
    fi
  else
    echo "${key}=${val}" >> "$ENV_FILE"
  fi
}

upsert VITE_FIREBASE_API_KEY     "$VITE_API_KEY"
upsert VITE_FIREBASE_AUTH_DOMAIN "$VITE_AUTH_DOMAIN"
upsert VITE_FIREBASE_PROJECT_ID  "$VITE_PROJECT_ID"
upsert VITE_FIREBASE_APP_ID      "$VITE_APP_ID"

# Default agent endpoint (idempotent).
if ! grep -q '^VITE_AGENT_ENDPOINT=' "$ENV_FILE"; then
  echo "VITE_AGENT_ENDPOINT=http://localhost:8080" >> "$ENV_FILE"
fi

ok "frontend/.env populated with VITE_FIREBASE_* + VITE_AGENT_ENDPOINT"

# Enable Anonymous Auth provider via REST (best-effort; safe to re-run).
ACCESS_TOKEN="$(gcloud auth application-default print-access-token 2>/dev/null || true)"
if [[ -n "$ACCESS_TOKEN" ]]; then
  log "ensuring Anonymous Auth provider is enabled..."
  curl -s -X PATCH \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    "https://identitytoolkit.googleapis.com/admin/v2/projects/${PROJECT_ID}/config?updateMask=signIn.anonymous.enabled" \
    -d '{"signIn":{"anonymous":{"enabled":true}}}' >/dev/null \
    && ok "Anonymous Auth enabled on ${PROJECT_ID}" \
    || warn "could not auto-enable Anonymous Auth (do it manually in Firebase Console > Authentication > Sign-in method)"
else
  warn "no ADC token; enable Anonymous Auth manually in Firebase Console"
fi
