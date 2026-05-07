# Workshop Pulse — Gemini CLI Project Context

## Mission
Demo end-to-end app for collecting workshop feedback via Google-authenticated polls,
with admin stats dashboard, QR code access, post-event thank-you email containing a
custom Nano Banana hero image, and ADK insight-agent (local-first, Agent Engine optional).

## Model

- **Primary model**: `gemini-3.1-pro-preview` on **Vertex AI**, location `global`.
- **Auth**: Application Default Credentials via `gcloud auth application-default login`.
- **Env**: `GOOGLE_GENAI_USE_VERTEXAI=true`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION=global`.
- Note: deploy regions (Agent Engine, Cloud Run, Firestore) stay `us-central1`; only the model lives at `global`.
- Never hard-code API keys. Read from `.env` only.

## Stack

- **Frontend**: Vite + React + TypeScript, Firebase Auth (Google SSO), Recharts.
- **Backend**: Firestore (collections `workshops`, `polls`, `votes`, `users`), Firebase Security Rules role-based.
- **Agent**: Google ADK (Python) via `agents-cli`. Two sub-agents:
  - `question-generator` — input: workshop brief → output: poll JSON.
  - `sentiment-insight` — input: votes array → output: `{mood, themes, summary}`.
- **Image**: Nano Banana extension via MCP.
- **Email**: Workspace extension (Gmail draft) via MCP.
- **Deploy stretch**: Agent Engine (Reasoning Engine) + Firebase Hosting + Cloud Function proxy.

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
- Security rules: role-based via custom claim `role: "admin"|"attendee"`.
- No secrets in repo. `.env.example` only.
- Commit message format: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`).

## Subagents available (in `.gemini/agents/`)

- `@spec-writer` — produces `SPEC.md` from brief.
- `@frontend-builder` — Vite + React + Firebase wiring.
- `@backend-builder` — Firestore schema + security rules.
- `@image-designer` — Nano Banana asset generation.
- `@adk-builder` — ADK insight-agent scaffold + deploy.

Recursion guard: subagents must not invoke other subagents. Hub orchestrates only.

## Custom skills (in `.gemini/skills/`)

- `poll-schema-designer` — Firestore schema + rules from brief.
- `thank-you-email` — Gmail draft with Nano Banana hero, mood-aware.
- `firebase-deploy-checklist` — preflight 6-step pre-deploy.

## ADK skills (auto-loaded via `agents-cli setup`)

`adk-cheatsheet`, `adk-dev-guide`, `adk-eval-guide`, `adk-deploy-guide`,
`google-agents-cli-scaffold`, `google-agents-cli-workflow`,
`google-agents-cli-adk-code`.

## Workflow rules

- Default to **Plan Mode** (`/plan`) before any multi-file change.
- Use **checkpointing**; expose `/restore` if a subagent diverges.
- Run `/compress` when context window > 70%.
- Never `--yolo` during the workshop.

## Out of scope (today)

- Agent-to-Agent (A2A) protocol — mention only, no demo.
- Production auth hardening beyond Firebase rules.
- Multi-tenant isolation.
