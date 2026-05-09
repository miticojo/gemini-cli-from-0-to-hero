# Workshop Pulse — Gemini CLI Project Context

## Mission
Demo end-to-end app for collecting workshop feedback via anonymous polls,
with admin stats dashboard and a Vertex AI ADK insight-agent that generates
poll questions and analyses sentiment. Built live in 90 minutes via Gemini
CLI orchestration.

## Model

- **Primary model**: `gemini-3.1-pro-preview` on **Vertex AI**, location `global`.
- **Auth (gcloud / Vertex)**: Application Default Credentials via `gcloud auth application-default login`.
- **Env**: `GOOGLE_GENAI_USE_VERTEXAI=true`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION=global`.
- Note: deploy regions (Agent Engine, Cloud Run, Firestore) stay `us-central1`; only the model lives at `global`.
- Never hard-code API keys. Read from `.env` only.

## Auth (app)

The Workshop Pulse app uses **Firebase Anonymous Auth** by default:

- `signInAnonymously()` runs once on import in `frontend/src/lib/firebase.ts`.
- No Google OAuth popup. No authorized-domains dance with Cloud Shell preview URLs.
- Workshop admin = the user who created the workshop document
  (`createdBy == request.auth.uid`).
- One vote per `(pollId, request.auth.uid)`, enforced by setting
  `voteId = request.auth.uid`.

A **Google SSO upgrade** is documented in `docs/HOMEWORK.md`. The Firestore
rules accept `request.auth != null` for both providers, so adding Google
later is purely a frontend change.

## Stack

- **Frontend**: Vite + React + TypeScript, Firebase Anonymous Auth, Recharts.
- **Backend**: Firestore (collections `workshops`, `polls`, `votes`), Firebase Security Rules anonymous-auth-friendly.
- **Agent**: Google ADK (Python) via `agents-cli`. Two sub-agents:
  - `question-generator` — input: workshop brief → output: poll JSON.
  - `sentiment-insight` — input: votes array → output: `{mood, themes, summary}`.
- **Spec workflow**: `conductor` extension (`/conductor:setup` + `/conductor:newTrack`) produces `conductor/tracks/<id>/spec.md` and `plan.md`. `@spec-writer` is the alternative for non-Conductor projects.

Out-of-scope today: Nano Banana email pipeline, Agent Engine deploy + Cloud
Function proxy. Both have full recipes in `docs/HOMEWORK.md`.

## Architecture switch (dual-track)

```
LOCAL    → frontend hits  http://localhost:8080  (agents-cli playground)
DEPLOYED → frontend hits  Cloud Function proxy   → IAM → Agent Engine endpoint
```

Single env var `VITE_AGENT_ENDPOINT` switches the target. Same agent code both paths.

## Conventions

- TypeScript strict, React function components, no class components.
- Python 3.11+, type hints, ADK idioms only.
- Firestore: never `read all`, always queries scoped by `workshopId`.
- Security rules: anonymous-auth + `createdBy` ownership; **no** `users/{uid}.role` lookups.
- No secrets in repo. `.env.example` only.
- Commit message format: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`).

## Subagents available (in `.gemini/agents/`)

Active in the workshop:
- `@frontend-builder` — Vite + React + Firebase Anonymous Auth + agent client.
- `@backend-builder` — Firestore schema + anonymous-auth rules + indexes.
- `@adk-builder` — ADK insight-agent rewrite + Vertex AI wiring.

Available but not invoked in main flow:
- `@spec-writer` — alternative to Conductor for single-feature SPEC.md.
- `@image-designer` — homework recipe (Nano Banana thank-you email).

Recursion guard: subagents must not invoke other subagents. Hub orchestrates only.

## Custom skills (in `.gemini/skills/`)

- `poll-schema-designer` — Firestore schema + anonymous-auth rules from brief.
- `thank-you-email` — Gmail draft with Nano Banana hero (homework recipe).
- `firebase-deploy-checklist` — preflight 6-step pre-deploy (homework recipe).

## ADK skills (auto-loaded via `agents-cli setup`)

`adk-cheatsheet`, `adk-dev-guide`, `adk-eval-guide`, `adk-deploy-guide`,
`google-agents-cli-scaffold`, `google-agents-cli-workflow`,
`google-agents-cli-adk-code`.

## Extensions

- `conductor` — `/conductor:setup`, `/conductor:newTrack`, `/conductor:implement`.
  The PRD spine of the workshop.

## Workflow rules

- Default to **Plan Mode** (`/plan`) before any multi-file change.
- Use **checkpointing**; expose `/restore` if a subagent diverges.
- Run `/compress` when context window > 70%.
- Never `--yolo` during the workshop.

## Out of scope (today)

- Google SSO (homework — anonymous default works for the demo).
- Nano Banana hero image + thank-you email pipeline (homework).
- Agent Engine deploy + Cloud Function proxy (homework).
- Agent-to-Agent (A2A) protocol (mention only, no demo).
- Multi-tenant isolation, hardening beyond rules.
