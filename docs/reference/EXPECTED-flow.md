# Facilitator cheat sheet — prompt-by-prompt flow

This is the script you (facilitator) feed to Gemini CLI during the live
workshop. For each slot it lists:

- **Prompt** — what to type literally.
- **Expected** — what should land on disk after Gemini finishes.
- **Recovery** — what to do if Gemini diverges.

The fully-worked targets live alongside this file:
`EXPECTED-agent.py`, `EXPECTED-App.tsx`, `EXPECTED-agent.ts`,
`EXPECTED-firebase.ts`, `EXPECTED-firestore.rules`. Refer to them silently
while pacing the room. **Do not project them** — audience must see Gemini
produce the code.

> **Total live prompts in the workshop: 5.**
> Conductor `/conductor:setup` (slot 3a), `/conductor:newTrack` (slot 3b),
> backend mega-prompt (slot 4), frontend mega-prompt (slot 5),
> ADK mega-prompt (slot 6). Slots 1, 2, 7, 8 are zero-prompt.

---

## Slot 1 · Setup smoke-test (0–5')

No `gemini` prompt. Run:

```bash
make gemini-test
```

Expect 4 ✓.

---

## Slot 2 · GEMINI.md + extensions + skills (5–15')

No code generation. Audience runs in `gemini`:

```text
> /skills
> /memory show
gemini extensions list
```

Verify 5 subagents + 10 skills (7 ADK + 3 workspace) + `conductor` extension.

---

## Slot 3a · `/conductor:setup` (15–25')

```text
> /conductor:setup
```

Walk through the wizard interactively. Use the answer table from
`docs/RUNBOOK.md` slot 3a. If wizard hangs, re-run with `--yolo` once and
paste all answers as a single block.

### Expected
- `conductor/index.md`
- `conductor/product.md`
- `conductor/tech-stack.md`
- `conductor/workflow.md`
- `conductor/product-guidelines.md`
- `conductor/tracks.md` (empty registry)

---

## Slot 3b · `/conductor:newTrack` (25–40')

```text
> /conductor:newTrack "Bootstrap Workshop Pulse foundation: admin creates
  workshop, generates AI poll, displays QR. Attendee scans, signs in
  anonymously, votes. Admin sees live stats and triggers sentiment analysis."
```

### Expected
- `conductor/tracks/<id>/spec.md`
- `conductor/tracks/<id>/plan.md` (multi-phase checklist)
- `conductor/tracks/<id>/metadata.json`
- `conductor/tracks/<id>/index.md`
- `conductor/tracks.md` registry updated

### Recovery
- If spec is too thin: *"deepen the data model in spec.md — list every
  Firestore field with its type."*
- If plan has fewer than 3 phases: *"split the plan into Backend, Frontend,
  ADK Agent phases."*

---

## Slot 4 · Mega-prompt backend (40–48')

```text
> @backend-builder Read conductor/tracks/<track-id>/spec.md and plan.md.

  STEP 1: activate_skill('poll-schema-designer') — mandatory.

  STEP 2: Generate the COMPLETE Firestore data model for Workshop Pulse:
  - backend/firestore.schema.md
  - backend/firestore.rules using ANONYMOUS auth: request.auth != null
    sufficient; admin via createdBy == request.auth.uid; vote uniqueness via
    voteId == request.auth.uid (do NOT use exists()). No custom claims,
    no users/ collection.
  - backend/firestore.indexes.json with the composite index on votes by
    (pollId asc, createdAt asc).

  Stop when all three files exist; do not run any deploy.
```

### Expected (matches `EXPECTED-firestore.rules`)
- `backend/firestore.schema.md` — collection tree.
- `backend/firestore.rules` with:
  - admin via `createdBy == request.auth.uid`,
  - vote uniqueness via `voteId == request.auth.uid`,
  - no `users/` collection lookup,
  - no custom claims.
- `backend/firestore.indexes.json` — composite index on `votes`
  `(pollId asc, createdAt asc)`.

### Recovery
- If rules use custom claims: *"no custom claims; admin = createdBy on the
  workshop doc."*
- If `users/` collection appears: *"drop users — anonymous auth needs no
  profile docs."*
- If skill not invoked: *"activate poll-schema-designer first."*

---

## Slot 5 · Mega-prompt frontend (48–60')

### 5a · Materialize Vite (side terminal, 48–50')

```bash
make scaffold-frontend
```

This chains: `npm create vite` → `npm install` → `make firebase-config`
(populates `frontend/.env` with `VITE_FIREBASE_*`).

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
     Parse last text part. Strip ```json fences before JSON.parse.
     VITE_AGENT_ENDPOINT default http://localhost:8080.
  3. frontend/src/App.tsx — <RouterProvider> with /admin and /p/:workshopId.
  4. frontend/src/routes/Admin.tsx — list workshops, "Generate poll" button
     calling queryAgent('generate-poll', {...}), "Analyze sentiment" button
     calling queryAgent('analyze-sentiment', {...}), Recharts BarChart of vote
     counts, QR section rendering window.location.origin + '/p/' + workshopId.
  5. frontend/src/routes/Attendee.tsx — fetch poll by workshopId, render
     vote form, submit to Firestore with voteId === auth.currentUser.uid.

  Constraints: only the four installed libraries. No MUI / Chakra / shadcn.
  Verify `tsc -b --noEmit` runs clean as the last step.
```

### Expected (matches `EXPECTED-firebase.ts`, `EXPECTED-agent.ts`, `EXPECTED-App.tsx`)
- `signInAnonymously(auth)` on import in `firebase.ts`.
- `agent.ts` uses camelCase keys + fence-stripping.
- Both routes wired; QR rendered.
- Only the four whitelisted deps installed.

### Recovery
- Google popup appears: *"replace signInWithPopup with signInAnonymously
  on import; no Google provider in the workshop flow."*
- Lowercase `/run` body keys: *"the ADK API uses camelCase: appName,
  userId, sessionId, newMessage."*
- Missing fence-stripping: *"strip ```json / ``` fences before JSON.parse."*
- Wrong deps: *"keep deps to firebase, react-router-dom, recharts, qrcode."*

---

## Slot 6 · Mega-prompt ADK (60–75')

### 6a · Materialize ADK scaffold (side terminal, 60–61')

```bash
make scaffold-agent
```

### 6b · One mega-prompt (61–72')

```text
> @adk-builder The insight-agent/ directory was scaffolded with
  `agents-cli create insight-agent --prototype` and contains the default
  weather/time ReAct agent.

  STEP 1: activate_skill('google-agents-cli-adk-code') — mandatory.

  STEP 2: Rewrite insight-agent/app/agent.py per GEMINI.md:
  - root_agent that routes on the `task` field of the user message
  - question_generator sub-agent (workshop_topic -> poll JSON, JSON-only,
    no markdown fences)
  - sentiment_insight sub-agent (votes -> {mood, themes, summary}, JSON-only,
    no markdown fences)
  - Vertex AI gemini-3.1-pro-preview at location global
  - App(name="app") matching the directory (mandatory or ADK rejects sessions)
  - Read GEMINI_MODEL, GOOGLE_CLOUD_PROJECT, GOOGLE_CLOUD_LOCATION from env

  STEP 3: Create insight-agent/.env with workshop project values.

  STEP 4: Print `make agent-dev`. Do NOT start the server.
```

### Expected (matches `EXPECTED-agent.py`)
- `agent.py` with root_agent + 2 sub-agents, JSON-only instructions.
- `App(name="app")` matches dir.
- `insight-agent/.env` with model + project + location.

### Recovery
- `App(name=…)` mismatch: *"the App.name must equal the directory name 'app'."*
- Preview model 404: *"fall back to gemini-2.5-flash; set GEMINI_MODEL in
  insight-agent/.env."*
- JSON wrapped in markdown fences: *"add 'No preamble, no markdown fences,
  only the JSON object' to each sub-agent instruction."*

### 6c · Start the agent (side terminal, 72–75')

```bash
make agent-dev          # uvicorn on :8080
```

Smoke-test with curl as in RUNBOOK slot 6c.

---

## Slot 7 · Integration + audience demo (75–85')

```bash
make frontend-dev
```

No `gemini` prompts. Click around, demo, audience votes.

---

## Slot 8 · Wrap + homework (85–90')

```text
> /memory add Lessons learned: <facilitator-notes>
```

Final words:
- Google SSO upgrade — see `docs/HOMEWORK.md`.
- Nano Banana thank-you email — see `docs/HOMEWORK.md`.
- Agent Engine deploy + Cloud Function proxy — see `docs/HOMEWORK.md`.
- A2A protocol — point at the Multi-Agent A2A Medium post.

---

## Universal recovery moves

| Symptom | Move |
|---|---|
| Gemini hallucinates a path | "Read GEMINI.md / conductor/tracks/<id>/spec.md again, then redo." |
| Subagent goes off-rails | `/restore` to the last checkpoint. |
| Context > 70% used | `/compress`. |
| Skill ignored | "Activate the X skill before continuing." |
| Diff is huge / unfocused | "Show me a plan first." (Plan Mode) |
| Mega-prompt fails halfway | `/restore`, then re-issue same mega-prompt — idempotent. |
| `frontend/.env` missing keys | `make firebase-config` (idempotent re-run). |
| Anonymous auth not working | Firebase Console → Authentication → enable Anonymous; reload. |

## Time-budget reminders

- **Slot 3 hard cap**: 40 minutes. Set a timer.
- **Mega-prompts (4/5/6)**: aim for ≤ 5 min each. If a turn runs longer,
  `/restore` and re-prompt with sharper constraints.
- Total live `gemini` prompts: 5. If you find yourself typing a 6th, ask
  why — there's likely a recovery move that's better than another prompt.
