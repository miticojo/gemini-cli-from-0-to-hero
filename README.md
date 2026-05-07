# Gemini CLI — from zero to hero (90' workshop)

End-to-end demo: build **Workshop Pulse**, a Google-authenticated feedback polling
app, by orchestrating Gemini CLI with **extensions, MCP servers, custom skills,
subagents, and an ADK insight-agent on Vertex AI**. Local-first; deploy is a
stretch goal.

> **Workshop env**: Google Cloud Shell. Everything below is verified to work on
> Cloud Shell (default web preview ports 8080 + 8081) and on local macOS/Linux.

[![Open in Cloud Shell](https://gstatic.com/cloudssh/images/open-btn.svg)](https://shell.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/YOUR-ORG/gemini-cli-from-0-to-hero&cloudshell_workspace=.&cloudshell_tutorial=docs/TUTORIAL.md)

---

## What you build

| Layer | Tech |
|---|---|
| Frontend | Vite + React 19 + TypeScript, Firebase Auth (Google SSO), Recharts |
| Backend | Firestore + role-based security rules + composite indexes |
| Agent | Google ADK (Python), root + 2 sub-agents, Vertex AI `gemini-3.1-pro-preview` |
| Image | Nano Banana extension (mood-aware hero for thank-you mail) |
| Email | Workspace extension (Gmail draft, inline image) |
| Deploy | (stretch) Agent Engine + Firebase Hosting + Cloud Function proxy |

## Quickstart (Cloud Shell)

```bash
# 1. clone
git clone https://github.com/YOUR-ORG/gemini-cli-from-0-to-hero
cd gemini-cli-from-0-to-hero

# 2. point to your GCP project
gcloud config set project YOUR_PROJECT_ID

# 3. run the bootstrap (installs gemini-cli, agents-cli, firebase, uv, ADK deps, frontend deps)
make bootstrap

# 4. start the agent (port 8080, ADK FastAPI playground)
make agent-dev

# 5. in a second tab, start the frontend (port 8081 on Cloud Shell, 5173 local)
make frontend-dev

# 6. open Gemini CLI in a third tab and start the workshop
gemini
```

In Cloud Shell, click **Web Preview** → choose port 8080 to see the agent UI,
and 8081 to see the frontend. Both ports are pre-allowed.

## Repo layout

```
.
├── GEMINI.md                # project context loaded by Gemini CLI
├── .gemini/
│   ├── agents/              # 5 subagents pre-authored
│   │   ├── spec-writer.md
│   │   ├── frontend-builder.md
│   │   ├── backend-builder.md
│   │   ├── image-designer.md
│   │   └── adk-builder.md
│   └── skills/              # 3 workspace-tier skills
│       ├── poll-schema-designer/
│       ├── thank-you-email/
│       └── firebase-deploy-checklist/
├── insight-agent/           # ADK Python agent (scaffolded by agents-cli)
│   └── app/agent.py         # root + question_generator + sentiment_insight
├── frontend/                # Vite + React TS, agent client in src/lib/agent.ts
├── backend/                 # Firestore rules + indexes (generated live)
├── functions/               # Cloud Function proxy (stretch)
├── scripts/bootstrap.sh     # idempotent setup for Cloud Shell + local
├── Makefile                 # one-line commands
└── docs/
    ├── RUNBOOK.md           # ★ facilitator runbook (open during workshop)
    ├── WORKSHOP-PLAN.md     # 90' high-level plan + risk matrix
    ├── CLOUDSHELL.md        # Cloud Shell-specific notes
    └── reference/           # silent targets + prompt cheat sheet
```

## How the agent is wired

```
              ┌──────────────────────────┐
              │  React (port 8081 / 5173) │
              └────────────┬──────────────┘
                           │  POST /run
                           ▼
LOCAL  →  http://localhost:8080  (ADK FastAPI playground)
                           │
DEPLOYED → Cloud Function proxy → IAM → Agent Engine reasoning engine
                           │
              ┌────────────┴──────────────┐
              │  root_agent (orchestrator) │
              └──┬─────────────────────┬──┘
                 │                     │
        question_generator     sentiment_insight
        (brief → poll JSON)    (votes → mood + themes)
```

The frontend calls `POST /run` with `{ task, payload }` packed into the user
message. The root agent transfers control to the right sub-agent and returns
its JSON output verbatim.

## Two ADK use cases

1. **`generate-poll`** — admin describes the workshop in plain text; the
   `question_generator` returns a structured poll (mix of single / multi / open
   questions, neutral wording, 3-5 options each).
2. **`analyze-sentiment`** — votes are forwarded to `sentiment_insight` which
   classifies mood (`positive` / `mixed` / `constructive` / `negative`),
   extracts themes, and produces an admin summary that drives:
   - the admin dashboard chart annotations,
   - the Nano Banana hero style cue for the thank-you email,
   - the body tone of the email itself.

## Skills the workshop uses

| Skill | Tier | What it does |
|---|---|---|
| `google-agents-cli-scaffold` | user (`~/.agents/skills/`) | scaffolds ADK projects |
| `google-agents-cli-deploy` | user | deploys to Agent Engine / Cloud Run |
| `google-agents-cli-eval` | user | LLM-as-judge evals + evalsets |
| `google-agents-cli-observability` | user | OTel + Cloud Trace wiring |
| `google-agents-cli-adk-code` | user | ADK Python idioms |
| `google-agents-cli-publish` | user | publish agent definitions |
| `google-agents-cli-workflow` | user | end-to-end ADK workflow |
| `poll-schema-designer` | workspace (`.gemini/skills/`) | Firestore schema + rules |
| `thank-you-email` | workspace | mood-aware Gmail draft + Nano Banana hero |
| `firebase-deploy-checklist` | workspace | 6-step preflight before `firebase deploy` |

`activate_skill` is invoked automatically when the description keywords match
the user prompt; the workshop deliberately exercises several triggers.

## Model

- **Workshop**: Vertex AI `gemini-3.1-pro-preview` (set in `insight-agent/.env`).
- **Rehearsal note**: if the preview model is not allowlisted on your project,
  fall back via `GEMINI_MODEL=gemini-2.5-flash` in `insight-agent/.env`. The
  agent code reads the env var at startup.

## Testing it locally without the frontend

```bash
make agent-dev    # in tab 1
# in tab 2:
SID=$(curl -s -X POST http://127.0.0.1:8080/apps/app/users/me/sessions \
  -H content-type:application/json -d '{}' | jq -r .id)

curl -s -X POST http://127.0.0.1:8080/run \
  -H content-type:application/json \
  -d "{
    \"appName\":\"app\",\"userId\":\"me\",\"sessionId\":\"$SID\",
    \"newMessage\":{\"role\":\"user\",\"parts\":[{
      \"text\":\"{\\\"task\\\":\\\"generate-poll\\\",\\\"payload\\\":{\\\"workshop_topic\\\":\\\"Gemini CLI\\\",\\\"num_questions\\\":3}}\"
    }]}}"
```

## Multiple GCP projects on the same machine

If you juggle several projects (workshop + day job), `scripts/gcloud-profile.sh`
keeps each one's gcloud configuration **and** Application Default Credentials
file isolated, so switching contexts is one command.

```bash
# one-time setup (browser opens for ADC login)
scripts/gcloud-profile.sh setup workshop you@example.com  your-workshop-project-id
scripts/gcloud-profile.sh setup default  you@yourdomain   your-default-project-id

# switch contexts
scripts/gcloud-profile.sh switch workshop
scripts/gcloud-profile.sh switch default

# status / list
scripts/gcloud-profile.sh status     # or: make gcloud-status
scripts/gcloud-profile.sh list       # or: make gcloud-list
```

The script copies the ADC json to `~/.config/gcloud/profiles/<profile>/adc.json`
on `setup`/`backup`, and swaps it back on `switch`. APIs (`aiplatform`,
`firestore`, `cloudfunctions`, `run`, `firebase`, …) are enabled automatically
during `setup`.

## Pre-flight (24h before workshop)

- [ ] GCP project with billing enabled.
- [ ] `aiplatform.googleapis.com` enabled.
- [ ] `gemini-3.1-pro-preview` accessible (request allowlist if needed).
- [ ] `firebase` project created and Auth → Google provider enabled.
- [ ] `NANOBANANA_API_KEY` exported (workaround issue #20724).
- [ ] Audience clones the repo and runs `make bootstrap` once.

## Documentation

- **[`docs/RUNBOOK.md`](docs/RUNBOOK.md)** — facilitator runbook. Single self-contained guide for the live workshop: pre-flight, slot-by-slot prompts, expected outputs, recovery moves, success criteria. **Open this during delivery.**
- [`docs/WORKSHOP-PLAN.md`](docs/WORKSHOP-PLAN.md) — 90-minute plan, slot by slot (high-level companion).
- [`docs/CLOUDSHELL.md`](docs/CLOUDSHELL.md) — Cloud Shell quirks, web preview, auth gotchas.
- [`docs/reference/`](docs/reference/) — silent reference targets (`EXPECTED-*.py/.tsx/.ts`) + the prompt-by-prompt cheat sheet `EXPECTED-flow.md`.
- [`GEMINI.md`](GEMINI.md) — project context, conventions, model config.

## License

Apache-2.0 (matching the ADK scaffold).
