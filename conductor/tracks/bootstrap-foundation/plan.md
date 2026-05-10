# Implementation Plan: Bootstrap Foundation

Three mega-prompts. Each consumed by one subagent. ≤ 15 minutes per phase.

## Phase 1 — Backend (firestore schema + rules + indexes)

Subagent: `@backend-builder`. Skill: `poll-schema-designer`.

- [ ] Generate `backend/firestore.schema.md` with the canonical collection tree.
- [ ] Generate `backend/firestore.rules` with anonymous-auth-friendly rules:
  `request.auth != null` for signed-in checks; admin via
  `createdBy == request.auth.uid`; vote uniqueness via
  `voteId == request.auth.uid`.
- [ ] Generate `backend/firestore.indexes.json` with the composite index on
  `votes` `(pollId asc, createdAt asc)`.

## Phase 2 — Frontend (Vite + Anonymous Auth + agent client + UI)

Subagent: `@frontend-builder`. Pre-step: `make scaffold-frontend` (npm
create vite + dep install + tsconfig relax + `frontend/.env` populated by
`firebase-config.sh`).

- [ ] `frontend/src/lib/firebase.ts` — `signInAnonymously` on import.
- [ ] `frontend/src/lib/agent.ts` — `Task` type + `queryAgent(task, payload)`,
  `appName: 'app'`, camelCase keys, fence-stripping.
- [ ] `frontend/src/App.tsx` — router with `/admin` and `/p/:workshopId`.
- [ ] `frontend/src/routes/Admin.tsx` — generate/analyze buttons, BarChart, QR.
- [ ] `frontend/src/routes/Attendee.tsx` — vote form with single-vote enforcement.

## Phase 3 — ADK Insight Agent (Python rewrite)

Subagent: `@adk-builder`. Skill: `google-agents-cli-adk-code`. Pre-step:
`make scaffold-agent`.

- [ ] Rewrite `insight-agent/app/agent.py` — root_agent + 2 sub-agents,
  `App(name="app")`, Vertex AI `gemini-3.1-pro-preview` at `global`.
- [ ] Write `insight-agent/.env` with `GEMINI_MODEL`, `GOOGLE_CLOUD_PROJECT`,
  `GOOGLE_CLOUD_LOCATION=global`, `GOOGLE_GENAI_USE_VERTEXAI=true`.

## Phase 4 — Integration smoke

- [ ] `make agent-dev` (port 8080) + `make frontend-dev` (port 8081).
- [ ] curl roundtrip: create session → POST /run → poll JSON returned.
- [ ] Browser: `/admin` → "Generate poll" → JSON renders → vote on phone via
  Cloud Shell preview URL → admin sees vote in BarChart → "Analyze sentiment"
  returns mood badge.
