#!/usr/bin/env bash
# Smoke-test the Gemini CLI setup for this workshop project.
# Runs four cheap, idempotent checks. Total cost: ~3 model calls.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=.gemini/env.sh
[[ -f .gemini/env.sh ]] && source .gemini/env.sh

if ! command -v gemini >/dev/null 2>&1; then
  echo "✗ gemini CLI not installed. Run: make bootstrap" >&2
  exit 1
fi

pass() { printf "  ✓ %s\n" "$*"; }
fail() { printf "  ✗ %s\n" "$*" >&2; exit 1; }

echo "▶ Test A — workspace skills + subagents load"
out="$(gemini skills list 2>&1 || true)"
echo "$out" | grep -qE "Failed to load agent|Validation failed|Invalid tool" \
  && fail "subagent validation errors:
$out"
echo "$out" | grep -q "/${ROOT##*/}/.gemini/skills/poll-schema-designer/SKILL.md" \
  || fail "poll-schema-designer skill not visible. Is the workspace trusted?"
pass "workspace skills + subagents load"

echo "▶ Test B — Vertex AI reaches the model"
out="$(gemini -p "Reply with exactly the literal string PONG and nothing else." 2>&1 || true)"
echo "$out" | tail -1 | grep -q "PONG" \
  || fail "Vertex AI smoke failed. Output tail:
$(echo "$out" | tail -5)"
pass "Vertex AI / ${GEMINI_MODEL:-default} responds"

echo "▶ Test C — subagent invocation (@spec-writer)"
out="$(gemini -p "@spec-writer In one short sentence, name the file you would write and the model mentioned in GEMINI.md." 2>&1 || true)"
echo "$out" | grep -qi "SPEC.md" || fail "spec-writer did not name SPEC.md. Output:
$out"
echo "$out" | grep -qi "gemini-3.1-pro-preview" || fail "spec-writer did not cite the configured model. Output:
$out"
pass "@spec-writer reads GEMINI.md correctly"

echo "▶ Test D — skill triggering (poll-schema-designer)"
out="$(gemini --approval-mode plan -p "I need to design a poll schema with vote collection. Don't write code yet — name the skill you would activate, and list the three filenames it produces." 2>&1 || true)"
echo "$out" | grep -qi "poll-schema-designer" || fail "did not identify poll-schema-designer. Output:
$out"
echo "$out" | grep -q "firestore.rules" || fail "did not name firestore.rules. Output:
$out"
pass "skill triggering recognised"

echo ""
echo "✅ All smoke tests passed."
