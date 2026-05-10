# Workshop Pulse — Facilitator Runbook (75 min default · 60 min compressed)

Single-file operational guide. Open this during the workshop and scroll
top-to-bottom.

> **Audience**: developers · **Env**: Google Cloud Shell · **Goal**: build
> Workshop Pulse end-to-end via Gemini CLI orchestration in 8 slots, with
> exactly **3 live mega-prompts** (one per layer). The `conductor/` PRD is
> pre-baked in the repo seed — slot 3 walks through it instead of generating
> it live, saving 15 minutes for the build.
>
> Reference targets that should emerge from `gemini` live are in
> `docs/reference/EXPECTED-{agent.py,App.tsx,agent.ts,firebase.ts,firestore.rules}`.
> **Do not project them.** Glance silently to pace the room.

---

## Timeline overview

| Slot | 75' default | 60' compressed | Topic |
|---|---|---|---|
| 1 | 0–5 | 0–3 | Setup smoke-test |
| 2 | 5–15 | 3–8 | GEMINI.md + extensions + skills |
| 3 | 15–25 | 8–15 | Conductor walkthrough (pre-baked) |
| 4 | 25–33 | 15–22 | Mega-prompt backend |
| 5 | 33–45 | 22–32 | Mega-prompt frontend |
| 6 | 45–60 | 32–45 | Mega-prompt ADK |
| 7 | 60–70 | 45–55 | Integration + audience demo |
| 8 | 70–75 | 55–60 | Wrap + homework |

Total live `gemini` prompts in either timeline: **3** (`@backend-builder`,
`@frontend-builder`, `@adk-builder`). Conductor is pre-baked. Setup smoke
test is `make gemini-test` — zero prompts.

## Table of contents

- [Pre-flight T-24h](#pre-flight-t-24h)
- [Pre-flight T-30min](#pre-flight-t-30min)
- [Mental model (recurring)](#mental-model-recurring)
- [Slot 1 · Setup smoke-test](#slot-1--setup-smoke-test-05)
- [Slot 2 · GEMINI.md + extensions + skills](#slot-2--geminimd--extensions--skills-515)
- [Slot 3 · Conductor walkthrough (pre-baked)](#slot-3--conductor-walkthrough-1525)
- [Slot 4 · Mega-prompt backend](#slot-4--mega-prompt-backend-4048)
- [Slot 5 · Mega-prompt frontend](#slot-5--mega-prompt-frontend-4860)
- [Slot 6 · Mega-prompt ADK](#slot-6--mega-prompt-adk-6075)
- [Slot 7 · Integration + audience demo](#slot-7--integration--audience-demo-7585)
- [Slot 8 · Wrap + homework](#slot-8--wrap--homework-8590)
- [Universal recovery moves](#universal-recovery-moves)
- [Cut order if running long](#cut-order-if-running-long)
- [Success criteria](#success-criteria)
- [Resources](#resources)

---

## Pre-flight T-24h

- [ ] GCP project with billing enabled.
- [ ] gcloud profile dedicated for the workshop:
  ```bash
  scripts/gcloud-profile.sh setup workshop <account> <project_id>
  ```
- [ ] Vertex AI API enabled (the script does this).
- [ ] `gemini-3.1-pro-preview` reachable on `global` location:
  ```bash
  ACCESS_TOKEN=$(gcloud auth application-default print-access-token)
  curl -s -o /dev/null -w "%{http_code}\n" \
    -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" \
    -X POST "https://aiplatform.googleapis.com/v1/projects/$GOOGLE_CLOUD_PROJECT/locations/global/publishers/google/models/gemini-3.1-pro-preview:generateContent" \
    -d '{"contents":[{"role":"user","parts":[{"text":"hi"}]}]}'
  ```
  `200` ✓ · `404` → set `GEMINI_MODEL=gemini-2.5-flash` in `.gemini/env.sh`.
- [ ] Firebase project registered: `firebase projects:addfirebase
  $GOOGLE_CLOUD_PROJECT` (the `firebase-config.sh` script will run this
  automatically on first `make scaffold-frontend`, but doing it once
  manually warms quota).
- [ ] **Anonymous Auth enabled** in Firebase Console → Authentication →
  Sign-in method → Anonymous. (`firebase-config.sh` tries to enable it
  via REST; verify it actually flipped to "Enabled".)
- [ ] Conductor extension installed (`make bootstrap` does this).
- [ ] Repo seed pushed to GitHub; audience knows the URL.
- [ ] Audience email sent: clone URL + `make bootstrap` instructions.

## Pre-flight T-30min

```bash
gcloud config configurations activate workshop
cd <repo-root>
source .gemini/env.sh
make gemini-test       # 4 cheap smoke tests; ALL must pass
```

If any test fails, stop. Diagnose with:
- `gemini skills list` — look for `Validation failed` lines.
- `gemini -p "ping"` — confirms Vertex AI auth.
- `gcloud config get-value account` — confirms admin account.
- `cat ~/.gemini/trustedFolders.json | grep gemini-cli-from-0-to-hero`.
- `ls ~/.gemini/extensions/conductor` — extension installed?

Open in side panel: `docs/reference/EXPECTED-flow.md` (verbatim prompts),
`docs/reference/EXPECTED-agent.py`, `EXPECTED-App.tsx`, `EXPECTED-firebase.ts`.

---

## Mental model (recurring)

Hold this slide visible on the secondary monitor for the whole session.

| | What it is | When to invoke |
|---|---|---|
| **GEMINI.md** | Project memory | Always loaded |
| **Extension** | MCP tools + slash commands | External capabilities |
| **Skill** | Reusable procedure | "How to do X" |
| **Subagent** | Isolated executor | "Who delegates Y" |
| **Plan Mode + checkpointing** | Quality gate | Always |

Pattern: **subagent invokes skill**. They are not alternatives.

---

## Slot 1 · Setup smoke-test (0–5')

Audience already ran `make bootstrap`. Confirm:

```bash
make gemini-test
```

If green: 4 ✓ in 30 seconds. If anyone fails, point them at
`docs/CLOUDSHELL.md` "Common Cloud Shell issues".

### Show what's in the repo right now

```text
ls -la
```

Audience sees:
- `GEMINI.md` — project memory.
- `.gemini/agents/`, `.gemini/skills/`, `.gemini/settings.json`.
- `conductor/` — **pre-baked PRD context** (slot 3 walks through it).
- `scripts/`, `Makefile`, `docs/`.

**No `frontend/`, no `insight-agent/`, no `backend/`, no `functions/`.**

> "We start with the orchestration platform — agents, skills, conductor
> context — and we generate every line of application code in the next
> 70 minutes through three mega-prompts."

---

## Slot 2 · GEMINI.md + extensions + skills (5–15')

Narrate `GEMINI.md` (model, anonymous auth, stack, conventions). Then in `gemini`:

```text
> /skills
> /memory show
gemini extensions list
```

Audience sees:
- 7 ADK skills (`google-agents-cli-*`, `adk-*`) at user tier `~/.agents/skills/`.
- 3 workspace skills (`poll-schema-designer`, `thank-you-email`,
  `firebase-deploy-checklist`) at workspace tier `.gemini/skills/`.
- 5 subagents listed via `gemini -p "list subagents in this workspace"`.
- `conductor` extension installed and loaded.

**Pedagogy line**:
> "Skills are *playbooks*. Subagents are *isolated workers*. Extensions bring
> *external capabilities* (MCP and slash commands). All three live in the
> workspace, version-controlled, shared with the team. Now we use them."

---

## Slot 3 · Conductor walkthrough (15–25')

**The `conductor/` folder is pre-baked in the repo seed.** This is intentional:
the workshop's pedagogical job is to teach the *discipline*, not to watch a
wizard answer 10 questions. Time saved goes to building.

### 3a · Show the pre-baked artefacts (15–20')

```bash
ls conductor/
tree conductor/        # or: find conductor -type f
```

Audience sees:
- `conductor/product.md` — vision + why-it-matters.
- `conductor/tech-stack.md` — Vite + Firebase Anonymous + ADK + Vertex AI.
- `conductor/workflow.md` — trunk-based, conventional commits.
- `conductor/product-guidelines.md` — code style + security + API contracts.
- `conductor/tracks.md` — track registry.
- `conductor/tracks/bootstrap-foundation/{spec.md, plan.md, metadata.json, index.md}`.

Open `product.md` and `tech-stack.md` and read aloud. Then open
`tracks/bootstrap-foundation/spec.md` and `plan.md` — these are what the
three mega-prompts read in slots 4/5/6.

**Pedagogy line**:
> "This folder is committable, diffable, replicable. Context lives next to
> code. The build that follows is `≤ 5 prompts` because everything is
> already specified. The hard work is done — the rest is execution."

### 3b · How conductor would have generated this (20–25')

```text
> /conductor:setup            # interactive wizard: product, tech stack, workflow, guidelines
> /conductor:newTrack "<feature description>"   # generates per-track spec + plan
```

Walk through the slash commands without running them. `setup` is one-time
per project; `newTrack` runs once per feature. Both produce committable
markdown. For a fresh project the audience would:

1. `gemini extensions install conductor --consent` (already done by `make bootstrap`).
2. `/conductor:setup` — answer ~6 questions about the product.
3. `/conductor:newTrack "build the foundation"` — get a spec + multi-phase plan.

**Optional live demo** (skip if compressed): run
`/conductor:newTrack "Add user profile editing"` to show a SECOND track
materialise. Don't implement it — just observe `conductor/tracks/<new-id>/`
appear with a fresh `spec.md` + `plan.md`.

---

## Slot 4 · Mega-prompt backend (25–33')

```text
> @backend-builder Read conductor/tracks/<track-id>/spec.md and plan.md.

  STEP 1: activate_skill('poll-schema-designer') — this is mandatory before
  writing any rule.

  STEP 2: Generate the COMPLETE Firestore data model for Workshop Pulse:
  - backend/firestore.schema.md
  - backend/firestore.rules using ANONYMOUS auth: any signed-in user
    (anonymous OR Google) can read polls and write exactly one vote per
    (pollId, userId). Admin distinction is by `createdBy == request.auth.uid`
    on the workshop doc. No custom claims, no users/ collection.
    Enforce vote uniqueness via voteId == request.auth.uid (do not use exists()).
  - backend/firestore.indexes.json with the composite index on votes by
    (pollId asc, createdAt asc).

  Stop when all three files exist; do not run any deploy.
```

### Expected
- `backend/firestore.schema.md` — collection tree.
- `backend/firestore.rules` — admin via `createdBy`; vote uniqueness via
  `voteId == request.auth.uid` (matches `EXPECTED-firestore.rules`).
- `backend/firestore.indexes.json` — composite index on `votes`.

### Recovery
- If `users/` collection appears: *"drop the users collection — we use
  anonymous auth, no profile docs needed."*
- If rules use custom claims: *"no custom claims; admin = createdBy on
  the workshop doc."*
- If skill not invoked: *"activate poll-schema-designer first."*

---

## Slot 5 · Mega-prompt frontend (33–45')

### 5a · Materialize Vite + Firebase env (48–50', side terminal)

```bash
make scaffold-frontend
# wraps:
#   1) npm create vite@latest frontend -- --template react-ts -y
#   2) cd frontend && npm install
#   3) make firebase-config  → ensures Firebase web app exists, runs
#      firebase apps:sdkconfig WEB --json, writes VITE_FIREBASE_*
#      into frontend/.env, enables Anonymous Auth via REST.
```

Audience sees `frontend/.env` populated automatically. **No manual editing.**

### 5b · One mega-prompt (50–60')

```text
> @frontend-builder Read conductor/tracks/<track-id>/spec.md.
  The frontend/ directory was scaffolded with `npm create vite -- --template
  react-ts`, deps (firebase, react-router-dom, recharts, qrcode, @types/qrcode)
  are installed, frontend/.env is populated with VITE_FIREBASE_*, and
  tsconfig has noUnusedLocals=false. Do NOT call npm install.

  Build the COMPLETE Workshop Pulse frontend in one turn:
  1. frontend/src/lib/firebase.ts — initialize app, call signInAnonymously()
     on import, export auth + db. Read all VITE_FIREBASE_* from import.meta.env.
     NO Google sign-in popup.
  2. frontend/src/lib/agent.ts — Export `type Task = 'generate-poll' | 'analyze-sentiment'`
     and `queryAgent(task: Task, payload: unknown)`. Create session via
     POST /apps/app/users/{uid}/sessions (use auth.currentUser.uid for {uid}),
     then POST /run with body { appName: 'app', userId, sessionId, newMessage }.
     Parse the last text part of the events array. Strip ```json fences before
     JSON.parse. VITE_AGENT_ENDPOINT default http://localhost:8080.
  3. frontend/src/App.tsx — <RouterProvider> with /admin and /p/:workshopId.
  4. frontend/src/routes/Admin.tsx — list workshops, "Generate poll" button
     calling queryAgent('generate-poll', {...}), "Analyze sentiment" button
     calling queryAgent('analyze-sentiment', {...}), Recharts BarChart of vote
     counts, QR section rendering window.location.origin + '/p/' + workshopId.
  5. frontend/src/routes/Attendee.tsx — fetch poll by workshopId, render
     vote form, submit to Firestore with voteId === auth.currentUser.uid.

  Constraints: only the four installed libraries. No MUI / Chakra / shadcn.
  Verify with `tsc -b --noEmit` runs clean as your last step.
```

### Expected (matches `EXPECTED-firebase.ts`, `EXPECTED-agent.ts`, `EXPECTED-App.tsx`)
- `signInAnonymously(auth)` called on import in `firebase.ts`.
- `agent.ts` uses camelCase keys + fence-stripping.
- `Admin.tsx` has both buttons + Recharts BarChart + QR.
- `Attendee.tsx` enforces single vote per user.
- New deps installed: only the four whitelisted libraries.

### Recovery
- If Google popup appears: *"replace signInWithPopup with signInAnonymously
  on import; no Google provider in the workshop flow."*
- If lowercase keys: *"the ADK API uses camelCase: appName, userId,
  sessionId, newMessage."*
- If MUI/Chakra installed: *"keep deps to firebase, react-router-dom,
  recharts, qrcode only."*

---

## Slot 6 · Mega-prompt ADK (45–60')

### 6a · Materialize ADK scaffold (60–61', side terminal)

```bash
make scaffold-agent
# wraps:
#   uvx google-agents-cli create insight-agent --prototype --yes \
#     --skip-checks --region us-central1 --deployment-target none
#   then: uv venv + uv pip install -e .
```

Audience sees the default weather/time ReAct scaffold appear (~30 s).

### 6b · One mega-prompt (61–72')

```text
> @adk-builder The insight-agent/ directory was scaffolded with
  `agents-cli create insight-agent --prototype` and contains the default
  weather/time ReAct agent.

  STEP 1: activate_skill('google-agents-cli-adk-code') — this is mandatory.

  STEP 2: Rewrite insight-agent/app/agent.py per GEMINI.md:
  - root_agent that routes on the `task` field of the user message
  - question_generator sub-agent (workshop_topic -> poll JSON, JSON-only output,
    no markdown fences)
  - sentiment_insight sub-agent (votes -> {mood, themes, summary}, JSON-only
    output, no markdown fences)
  - Vertex AI gemini-3.1-pro-preview at location global
  - App(name="app") — MUST match the directory name 'app' or ADK rejects sessions
  - Read GEMINI_MODEL, GOOGLE_CLOUD_PROJECT, GOOGLE_CLOUD_LOCATION from env
    with sensible defaults.

  STEP 3: Create insight-agent/.env with workshop project values.

  STEP 4: Print the command `make agent-dev` for the user. Do NOT start
  the server yourself.
```

### Expected (matches `EXPECTED-agent.py`)
- Two sub-agents in `agent.py`: `question_generator`, `sentiment_insight`.
- `App(name="app")` matches directory name.
- `insight-agent/.env` has model + project + location values.
- Sub-agent instructions include the JSON-only constraint.

### Recovery
- `App(name=…)` mismatch: *"the App.name must equal the directory name 'app'."*
- Preview model 404: *"fall back to gemini-2.5-flash; set GEMINI_MODEL in
  insight-agent/.env."*
- Markdown wrapper around JSON output: *"add 'No preamble, no markdown
  fences, only the JSON object' to each sub-agent instruction."*

### 6c · Start the playground (72–75', side terminal)

```bash
make agent-dev          # uvicorn on :8080
```

Smoke from a third tab:
```bash
SID=$(curl -s -X POST http://127.0.0.1:8080/apps/app/users/me/sessions \
        -H content-type:application/json -d '{}' | jq -r .id)
curl -s -X POST http://127.0.0.1:8080/run -H content-type:application/json \
  -d "{\"appName\":\"app\",\"userId\":\"me\",\"sessionId\":\"$SID\",
      \"newMessage\":{\"role\":\"user\",\"parts\":[{
        \"text\":\"{\\\"task\\\":\\\"generate-poll\\\",\\\"payload\\\":
                  {\\\"workshop_topic\\\":\\\"Gemini CLI\\\",\\\"num_questions\\\":3}}\"
      }]}}"
```

Last text part = poll JSON.

---

## Slot 7 · Integration + audience demo (60–70')

```bash
make frontend-dev       # Vite on :8081 (Cloud Shell) or :5173 (local)
```

In Cloud Shell, click **Web Preview** → port 8081. Audience opens it on
their phones (preview URL works on the public internet for the duration
of the session — Anonymous Auth means no domain whitelist needed).

Live flow:
1. Facilitator opens `/admin`, clicks "Generate poll".
2. Audience scans QR (Cloud Shell preview URL → `/p/<workshopId>`).
3. Audience votes once each (`signInAnonymously` happens transparently).
4. Facilitator clicks "Analyze sentiment" — mood + themes render.
5. Recharts updates with real vote counts.

**This is the moment.** App works on first try because:
- `firebase-config.sh` populated env vars.
- Anonymous Auth needs zero OAuth wiring.
- Three mega-prompts produced consistent code.

### Recovery
- Port collision: `make frontend-dev VITE_PORT=8082`.
- Anonymous Auth disabled: open Firebase Console → Authentication →
  Sign-in method → enable Anonymous (`firebase-config.sh` should have done
  it; verify).
- Vite preview blocked: confirm `vite.config.ts` allows
  `*.cloudshell.dev` host (the scaffold default + `@frontend-builder`
  should have configured it).

---

## Slot 8 · Wrap + homework (70–75')

```text
> /memory add Lessons learned: <facilitator-notes>
```

Final words (1 minute total):

- **Google SSO upgrade** — the rules already accept `request.auth != null`,
  so the upgrade is purely a frontend swap. Recipe in `docs/HOMEWORK.md`.
- **Nano Banana thank-you email** — `@image-designer` + `thank-you-email`
  skill produce a mood-aware Gmail draft. Recipe in `docs/HOMEWORK.md`.
- **Agent Engine deploy + Cloud Function proxy** — `@adk-builder` + the
  `google-agents-cli-deploy` skill. Recipe in `docs/HOMEWORK.md`.
- **A2A protocol** — the next frontier (one-line mention).

Repo template = audience's starting point. Dismiss.

---

## Universal recovery moves

| Symptom | Move |
|---|---|
| Gemini hallucinates a path | "Read GEMINI.md / conductor/tracks/<id>/spec.md again, then redo." |
| Subagent goes off-rails | `/restore` to the last checkpoint. |
| Context > 70% used | `/compress`. |
| Skill ignored | "Activate the X skill before continuing." |
| Diff is huge / unfocused | "Show me a plan first." (Plan Mode) |
| Audience confused: skill vs subagent | Show the mental-model slide. |
| 403 from `cloudcode-pa.googleapis.com` | gemini reverted to Code Assist; `source .gemini/env.sh` again. |
| Conductor `/conductor:setup` stuck | re-run with `--yolo` once and feed answers as a single block (see slot 3a table). |
| `Skipping project agents due to untrusted folder` | bootstrap re-add to `~/.gemini/trustedFolders.json`. |
| `Validation failed: tools.N: Invalid tool name` | use `run_shell_command`, `replace`, `search_file_content`. |
| Mega-prompt fails halfway | `/restore`, then re-issue the same mega-prompt — it's idempotent because the spec didn't change. |
| `frontend/.env` missing keys | `make firebase-config` (idempotent re-run). |
| Anonymous auth not working | Firebase Console → Authentication → enable Anonymous; reload the app. |

## Cut order if running long

1. Drop **slot 8** — wrap in 30 seconds, hand out the homework link.
2. Compress **slot 7** demo to facilitator-driven (skip audience phones,
   facilitator demos solo).
3. Skip **slot 3b** (the optional `/conductor:newTrack` live demo for a
   second feature). The pre-baked track 1 carries the workshop.
4. Compress **slot 2** to a 5-min `gemini extensions list` + `/skills`
   only, skip the deep narrative on Skill vs Subagent.
5. **Never drop slots 3a, 4, 5, 6** — pedagogical core (PRD walkthrough +
   3 mega-prompts).

## Success criteria

By T+90, every audience member's Cloud Shell session contains:

- Working `gemini` loading project `GEMINI.md` + 5 subagents + 3 workspace
  skills + `conductor` extension.
- `conductor/` folder with `product.md`, `tech-stack.md`, etc., plus one
  track with `spec.md` + `plan.md`.
- `backend/firestore.{schema.md,rules,indexes.json}`.
- `frontend/` with `signInAnonymously` flow, agent client, admin/attendee routes.
- `insight-agent/` with rewritten `agent.py` + 2 sub-agents.
- A populated Firestore with at least one poll and votes from real audience.

Total live `gemini` prompts in the workshop: 5 (1 `/conductor:setup`, 1
`/conductor:newTrack`, 3 mega-prompts).

---

## Resources

- `GEMINI.md` — project memory.
- `docs/CLOUDSHELL.md` — Cloud Shell quirks + auth gotchas.
- `docs/WORKSHOP-PLAN.md` — high-level plan + risk matrix.
- `docs/HOMEWORK.md` — Google SSO, Nano Banana email, Agent Engine deploy recipes.
- `docs/reference/EXPECTED-agent.py` — target ADK rewrite.
- `docs/reference/EXPECTED-App.tsx` — target frontend root.
- `docs/reference/EXPECTED-agent.ts` — target ADK client.
- `docs/reference/EXPECTED-firebase.ts` — target Firebase init (anonymous auth).
- `docs/reference/EXPECTED-firestore.rules` — target rules.
- `docs/reference/EXPECTED-flow.md` — original prompt-by-prompt cheat sheet.
- `scripts/bootstrap.sh` — idempotent setup.
- `scripts/firebase-config.sh` — auto-populate `frontend/.env`.
- `scripts/gcloud-profile.sh` — multi-project gcloud + ADC isolation.
- `scripts/gemini-smoke-test.sh` — `make gemini-test` (4 cheap checks).

External:
- Gemini CLI docs: https://geminicli.com/docs/
- Subagents: https://geminicli.com/docs/core/subagents/
- Skills: https://geminicli.com/docs/cli/skills/
- agents-cli: https://google.github.io/agents-cli/
- ADK: https://adk.dev/
- Conductor: https://github.com/gemini-cli-extensions/conductor
- Nano Banana ext: https://github.com/gemini-cli-extensions/nanobanana
- Firebase ext: https://github.com/gemini-cli-extensions/firebase
- A2A Medium reference: https://medium.com/google-cloud/multi-agent-a2a-with-the-agent-development-kit-adk-cloud-run-and-gemini-cli-52f8be838ad6
