#!/usr/bin/env bash
# gcloud-profile.sh — manage isolated gcloud configurations + ADC files.
#
# Why: Application Default Credentials live in a single file at
#   ~/.config/gcloud/application_default_credentials.json
# A standard `gcloud auth application-default login` overwrites whatever was
# there, breaking other projects. This script keeps a per-profile ADC backup
# and swaps it on demand alongside the gcloud configuration.
#
# Usage:
#   scripts/gcloud-profile.sh setup    <profile> <account> <project>   # one-time
#   scripts/gcloud-profile.sh switch   <profile>                       # activate
#   scripts/gcloud-profile.sh list                                     # all
#   scripts/gcloud-profile.sh status                                   # current
#   scripts/gcloud-profile.sh backup   <profile>                       # save ADC
#   scripts/gcloud-profile.sh remove   <profile>                       # cleanup
#
# Profiles are stored under ~/.config/gcloud/profiles/<profile>/adc.json
# (the gcloud configuration name itself is shared with gcloud).

set -euo pipefail

PROFILES_DIR="${HOME}/.config/gcloud/profiles"
ADC_PATH="${HOME}/.config/gcloud/application_default_credentials.json"
mkdir -p "$PROFILES_DIR"

cmd="${1:-status}"
shift || true

log()  { printf "  • %s\n" "$*"; }
ok()   { printf "  ✓ %s\n" "$*"; }
warn() { printf "  ! %s\n" "$*" >&2; }
die()  { printf "  ✗ %s\n" "$*" >&2; exit 1; }

# Returns 0 if port is currently in use, 1 otherwise.
port_busy() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -i ":${port}" -sTCP:LISTEN >/dev/null 2>&1
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE ":${port}\$"
  else
    # last-resort probe
    (echo > "/dev/tcp/127.0.0.1/${port}") >/dev/null 2>&1
  fi
}

require_profile() {
  local p="${1:-}"
  [[ -n "$p" ]] || die "profile name required"
  printf "%s" "$p"
}

cmd_setup() {
  local profile account project
  profile="$(require_profile "${1:-}")"
  account="${2:-}"; project="${3:-}"
  [[ -n "$account" ]] || die "usage: setup <profile> <account> <project>"
  [[ -n "$project" ]] || die "usage: setup <profile> <account> <project>"

  echo "▶ Setting up profile '${profile}' (account=${account}, project=${project})"

  # 1. gcloud configuration (idempotent)
  if gcloud config configurations describe "$profile" >/dev/null 2>&1; then
    ok "gcloud configuration '${profile}' already exists"
  else
    gcloud config configurations create "$profile" --no-activate >/dev/null
    ok "gcloud configuration '${profile}' created"
  fi
  gcloud config configurations activate "$profile" >/dev/null
  gcloud config set account "$account" >/dev/null
  gcloud config set project "$project" >/dev/null
  ok "configuration set: account=${account}, project=${project}"

  # 2. interactive ADC login (browser opens unless 8085 busy)
  echo ""
  if port_busy 8085; then
    warn "Port 8085 is occupied (gcloud's OAuth callback default)."
    log "Falling back to device flow (--no-launch-browser)."
    log "Copy the URL into a browser, paste the code back into this terminal."
    gcloud auth application-default login --account="$account" --no-launch-browser
  else
    log "Launching ADC login for '${account}' (a browser tab will open)..."
    gcloud auth application-default login --account="$account"
  fi

  # 3. quota project
  gcloud auth application-default set-quota-project "$project" >/dev/null
  ok "ADC quota project set to '${project}'"

  # 4. backup ADC
  cmd_backup "$profile"

  # 5. enable required APIs
  echo ""
  log "Enabling APIs (idempotent): aiplatform, firestore, cloudfunctions, run, firebase..."
  gcloud services enable \
    aiplatform.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iam.googleapis.com \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    cloudfunctions.googleapis.com \
    firebase.googleapis.com \
    firestore.googleapis.com \
    --project="$project" --quiet || warn "some APIs failed to enable (check billing)"
  ok "APIs enabled"

  echo ""
  ok "Profile '${profile}' is ready."
  echo "    Switch later with:   scripts/gcloud-profile.sh switch ${profile}"
}

cmd_backup() {
  local profile
  profile="$(require_profile "${1:-}")"
  [[ -f "$ADC_PATH" ]] || die "no ADC file at ${ADC_PATH}; run setup or login first"
  mkdir -p "${PROFILES_DIR}/${profile}"
  cp "$ADC_PATH" "${PROFILES_DIR}/${profile}/adc.json"
  ok "ADC backup saved → ${PROFILES_DIR}/${profile}/adc.json"
}

cmd_switch() {
  local profile backup
  profile="$(require_profile "${1:-}")"
  backup="${PROFILES_DIR}/${profile}/adc.json"

  gcloud config configurations describe "$profile" >/dev/null 2>&1 \
    || die "profile '${profile}' has no gcloud configuration. Run setup first."
  [[ -f "$backup" ]] \
    || die "profile '${profile}' has no ADC backup. Run: $0 backup ${profile} (after gcloud auth application-default login)"

  gcloud config configurations activate "$profile" >/dev/null
  cp "$backup" "$ADC_PATH"
  ok "Switched to profile '${profile}'"
  cmd_status
}

cmd_list() {
  echo "▶ Profiles with ADC backup:"
  if [[ ! -d "$PROFILES_DIR" || -z "$(ls -A "$PROFILES_DIR" 2>/dev/null)" ]]; then
    echo "  (none)"
  else
    for d in "$PROFILES_DIR"/*/; do
      local name="${d%/}"; name="${name##*/}"
      local has_adc="no"
      [[ -f "${d}adc.json" ]] && has_adc="yes"
      printf "  %-20s  ADC backup: %s\n" "$name" "$has_adc"
    done
  fi
  echo ""
  echo "▶ All gcloud configurations:"
  gcloud config configurations list 2>&1
}

cmd_status() {
  local active project account quota
  active="$(gcloud config configurations list --filter='is_active=true' --format='value(name)' 2>/dev/null)"
  account="$(gcloud config get-value account 2>/dev/null)"
  project="$(gcloud config get-value project 2>/dev/null)"
  quota="$(gcloud auth application-default print-access-token >/dev/null 2>&1 && echo 'present' || echo 'missing')"

  echo "  Active profile : ${active:-?}"
  echo "  Account        : ${account:-?}"
  echo "  Project        : ${project:-?}"
  echo "  ADC token      : ${quota}"
}

cmd_remove() {
  local profile
  profile="$(require_profile "${1:-}")"
  echo "▶ Removing profile '${profile}'"

  if gcloud config configurations describe "$profile" >/dev/null 2>&1; then
    # cannot delete active config
    local active
    active="$(gcloud config configurations list --filter='is_active=true' --format='value(name)' 2>/dev/null)"
    if [[ "$active" == "$profile" ]]; then
      warn "profile is active; activate another first (e.g. 'default')"
      exit 1
    fi
    gcloud config configurations delete "$profile" --quiet
    ok "gcloud configuration deleted"
  fi
  if [[ -d "${PROFILES_DIR}/${profile}" ]]; then
    rm -rf "${PROFILES_DIR}/${profile}"
    ok "ADC backup removed"
  fi
}

case "$cmd" in
  setup)   cmd_setup   "$@" ;;
  backup)  cmd_backup  "$@" ;;
  switch)  cmd_switch  "$@" ;;
  list)    cmd_list ;;
  status)  cmd_status ;;
  remove)  cmd_remove  "$@" ;;
  -h|--help|help)
    sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *) die "unknown command: ${cmd}. Try: setup | switch | list | status | backup | remove"
    ;;
esac
