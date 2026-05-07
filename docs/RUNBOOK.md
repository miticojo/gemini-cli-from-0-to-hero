# Workshop Pulse — Facilitator Runbook (90 min)

Single-file operational guide. Open this during the workshop and scroll
top-to-bottom. Everything you need is here.

> **Audience**: developers · **Env**: Google Cloud Shell · **Goal**: build
> Workshop Pulse end-to-end via Gemini CLI orchestration.
>
> Reference targets that should emerge from `gemini` live are in
> `docs/reference/EXPECTED-{agent.py,App.tsx,agent.ts}`. **Do not project them.**
> Glance at them silently to pace the room.

---

## Table of contents

- [Pre-flight T-24h](#pre-flight-t-24h)
- [Pre-flight T-30min](#pre-flight-t-30min)
- [Mental model (recurring)](#mental-model-recurring)
- [Slot 1 · Setup smoke-test (0–5')](#slot-1--setup-smoke-test-05)
- [Slot 2 · GEMINI.md + extensions + skills (5–15')](#slot-2--geminimd--extensions--skills-515)
- [Slot 3 · Skills concept + skill creator (15–24')](#slot-3--skills-concept--skill-creator-1524)
- [Slot 4 · Subagents tour + @spec-writer (24–32')](#slot-4--subagents-tour--spec-writer-2432)
- [Slot 5a · Backend rules (32–40')](#slot-5a--backend-rules-3240)
- [Slot 5b · Frontend scaffold (40–46')](#slot-5b--frontend-scaffold-4046)
- [Slot 6 · ADK agent local-first (46–66')](#slot-6--adk-agent-local-first-4666)
- [Slot 7 · Nano Banana + email (66–76')](#slot-7--nano-banana--email-6676)
- [Slot 8 · QR + Hosting deploy (76–84')](#slot-8--qr--hosting-deploy-7684)
- [Slot 9 stretch · ADK to Agent Engine (84–88')](#slot-9-stretch--adk-to-agent-engine-8488)
- [Slot 10 · Wrap (88–90')](#slot-10--wrap-8890)
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
- [ ] Firebase project created, **Auth → Google provider enabled**, Cloud Shell
  preview domain added to authorized domains.
- [ ] `NANOBANANA_API_KEY` exported (workaround issue #20724).
- [ ] Repo seed pushed to GitHub; audience knows the URL.
- [ ] Audience email sent: clone URL + `make bootstrap` instructions.

## Pre-flight T-30min

```bash
gcloud config configurations activate workshop  # or: scripts/gcloud-profile.sh switch workshop
cd <repo-root>
source .gemini/env.sh
make gemini-test       # 4 cheap smoke tests; ALL must pass
```

If any test fails, stop. Diagnose with:
- `gemini skills list` — look for `Validation failed` lines
- `gemini -p "ping"` — confirms Vertex AI auth
- `gcloud config get-value account` — confirms admin account
- `cat ~/.gemini/trustedFolders.json | grep gemini-cli-from-0-to-hero` — workspace trusted?

Open in side panel: `docs/reference/EXPECTED-flow.md` (this file's deeper twin
with verbatim prompts), `docs/reference/EXPECTED-agent.py` (target rewrite).

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

If green: 4 ✓ in 30 seconds. If anyone fails, point them at the table in
`docs/CLOUDSHELL.md` "Common Cloud Shell issues" and pair them with a
neighbour. Don't block the room.

---

## Slot 2 · GEMINI.md + extensions + skills (5–15')

Narrate `GEMINI.md` (model, stack, conventions). Then in `gemini`:

```text
> /skills
> /memory show
gemini extensions list
```

Audience sees:
- 7 ADK skills (`google-agents-cli-*`, `adk-*`) at user tier `~/.agents/skills/`
- 3 workspace skills (`poll-schema-designer`, `thank-you-email`,
  `firebase-deploy-checklist`) at workspace tier `.gemini/skills/`
- 5 subagents listed via `gemini -p "list subagents in this workspace"`

**Pedagogy line**:
> "Skills are *playbooks*. Subagents are *isolated workers*. Extensions bring
> *external capabilities* (MCP). All three live in the workspace, version-
> controlled, shared with the team."

---

## Slot 3 · Skills concept + skill creator (15–24')

Show skill anatomy — open `.gemini/skills/poll-schema-designer/SKILL.md`,
read the YAML frontmatter aloud:

```yaml
---
name: poll-schema-designer
description: "Designs Firestore collections, security rules…
  Triggers on: poll schema, vote collection, feedback model"
---
```

Then have Gemini build a new one live:

```text
> Create a new workspace-tier skill called "poll-stats-helper" that knows
  how to compose Firestore aggregation queries for vote counts. It should
  live in .gemini/skills/poll-stats-helper/ with a SKILL.md whose
  description triggers on phrases like "vote stats", "tally results",
  "aggregate poll".
```

### Expected
- New dir `.gemini/skills/poll-stats-helper/` with `SKILL.md`.
- YAML frontmatter has `name` + keyword-rich `description`.
- Body has at least a stub query template.

### Recovery
- If Gemini puts it in `~/.gemini/skills/`: *"move it under the project's
  `.gemini/skills/` so the team shares it."*
- After: run `/skills` and point at the new skill in the list.

---

## Slot 4 · Subagents tour + @spec-writer (24–32')

Open `.gemini/agents/spec-writer.md` briefly. Narrate the YAML frontmatter
(name, description, tools whitelist, model, temperature, max_turns).

> "Subagent has its **own context window**. It does not see your chat. You
> brief it with one prompt, it does the work, returns a result."

```text
> @spec-writer Produce SPEC.md for Workshop Pulse based on GEMINI.md.
```

### Expected
File `SPEC.md` at repo root, 7 sections:
1. Objective
2. User stories
3. Data model (collections + fields + types)
4. Routes
5. Agent contracts (input/output JSON schemas)
6. Acceptance criteria
7. Out of scope

### Recovery
- If thin output: *"go deeper on the data model — list every field with type"*.
- If wrong stack: *"re-read GEMINI.md; do not propose stack changes"*.

### 30-second mention: `conductor`

After `@spec-writer` finishes:

> "For multi-feature projects there's the official `conductor` extension —
> splits planning into product/tech-stack/workflow + per-track spec/plan.
> Same 'measure twice' philosophy, larger granularity. Today we want one
> deep spec, so `@spec-writer` wins. Conductor is in your homework."

---

## Slot 5a · Backend rules (32–40')

```text
> @backend-builder Generate the Firestore data model, security rules, and
  composite indexes for Workshop Pulse. Use the poll-schema-designer skill.
```

### Expected
- `backend/firestore.schema.md` — collection tree with field types.
- `backend/firestore.rules` — admin/attendee role-based; vote create unique
  per `(pollId, userId)`; admin reads all votes in their workshop.
- `backend/firestore.indexes.json` — composite index on `votes` by
  `(pollId asc, createdAt asc)`.

### Recovery
- If skill not invoked: *"Activate the poll-schema-designer skill before
  producing the rules."*
- If rules permissive: *"votes must never be readable by other attendees."*

---

## Slot 5b · Frontend scaffold (40–46')

```text
> @frontend-builder Build the Workshop Pulse frontend on top of the existing
  Vite stub: React Router with /admin and /p/:workshopId routes, Firebase
  Auth (Google SSO) wired in src/lib/firebase.ts, a Login button, and a
  placeholder admin dashboard. Read src/App.tsx and replace the stub. Don't
  wire the agent yet — that's the next step.
```

### Expected
- `frontend/src/lib/firebase.ts` (single instance, exports `auth`, `db`).
- `frontend/src/App.tsx` updated with `<RouterProvider>`.
- `frontend/src/routes/Admin.tsx`, `frontend/src/routes/Attendee.tsx`.
- `frontend/src/components/Login.tsx` (Google sign-in button).
- `frontend/.env.example` updated if missing keys.

### Recovery
- If heavy UI lib added (MUI, Chakra): *"keep deps to react-router-dom,
  firebase, recharts only."*
- If Firebase config hard-coded: *"read from `import.meta.env.VITE_FIREBASE_*`."*

---

## Slot 6 · ADK agent local-first (46–66')

Three steps inside the slot.

### 6a · Rewrite `insight-agent/app/agent.py` (46–54')

```text
> @adk-builder Rewrite insight-agent/app/agent.py per the contract in
  GEMINI.md: a root_agent that routes on the `task` field of the user
  message, plus two sub-agents `question_generator` and `sentiment_insight`.
  Use Vertex AI gemini-3.1-pro-preview at location global. Keep the
  App(name="app") so the directory matches. Activate the
  google-agents-cli-adk-code skill.
```

#### Expected (matches `docs/reference/EXPECTED-agent.py` semantically)
- Root agent: `sub_agents=[question_generator, sentiment_insight]`.
- `question_generator` instruction: JSON-only output with poll schema.
- `sentiment_insight` instruction: JSON-only output with `mood`, `themes`,
  `summary`.
- `App(name="app")` (must match directory).
- Reads `GEMINI_MODEL`, `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION` env.

#### Recovery
- If `App(name=…)` mismatches dir: *"the App.name must equal the directory
  name 'app' or ADK rejects sessions."*
- If preview model 404s: *"fall back to gemini-2.5-flash; set GEMINI_MODEL
  in insight-agent/.env."*
- If sub-agents have no JSON-only constraint: *"add 'No preamble, no
  markdown fences, only the JSON object' to the instruction."*

### 6b · Start the playground (54–58')

In a second tab:
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

Last text part of the events array = poll JSON (possibly fenced with ` ```json `).

### 6c · Wire the frontend (58–64')

```text
> @frontend-builder Create frontend/src/lib/agent.ts that:
  - reads VITE_AGENT_ENDPOINT (default http://localhost:8080),
  - creates an ADK session via POST /apps/app/users/{userId}/sessions,
  - POSTs to /run with appName="app", userId="workshop-attendee",
    sessionId=<created>, newMessage with parts[0].text = JSON.stringify({task, payload}),
  - extracts the last text part from the events array,
  - strips ```json fences,
  - returns parsed JSON.
  Then add a "Generate poll" button on the admin page that calls
  queryAgent('generate-poll', {workshop_topic, num_questions: 4, target_audience: 'developers'}).
```

#### Expected (matches `docs/reference/EXPECTED-agent.ts`)
- `queryAgent(task, payload)` helper.
- Session created via `POST /apps/app/users/{userId}/sessions`.
- `/run` body uses **camelCase** keys (`appName`, `userId`, `sessionId`,
  `newMessage`).
- Strip-fence regex applied to the last text part.

#### Recovery
- If using `/run_sse` (streaming): *"use /run sync for simplicity."*
- If session id missing: *"the session-create response has `id`, not
  `sessionId`."*
- If lowercase keys: *"the ADK API uses camelCase: appName, userId,
  sessionId, newMessage."*

### 6d · End-to-end demo (64–66')

Audience clicks "Generate poll" on `/admin`. Real poll JSON renders. Then:

```text
> Now wire the attendee voting page so submitted votes get stored in
  Firestore under workshops/{w}/polls/{p}/votes, then add an "Analyze
  sentiment" button on /admin that calls queryAgent('analyze-sentiment',
  { workshop_id, votes }) and renders the resulting mood as a colored
  badge plus a list of themes.
```

---

## Slot 7 · Nano Banana + email (66–76')

```text
> @image-designer Build the post-workshop thank-you email pipeline.
  Activate the thank-you-email skill. Take the sentiment output from slot 6,
  generate a hero image with mcp_nanobanana_generate using the mood-to-style
  mapping, then create a Gmail draft via the Workspace MCP for each attendee.
  Output a single function compose_thank_you(workshopId, sentiment, recipients).
```

### Expected
- `functions/email/compose_thank_you.{ts,py}` with the pipeline.
- Hero image cached on `(workshopId, mood)`.
- Gmail draft created (NEVER sent).

### Mood → style cue (memorize)
- `positive` → bright warm, celebratory
- `mixed` → balanced, editorial
- `constructive` → cool focused
- `negative` → soft empathetic

### Recovery
- If sends instead of drafting: *"never send live; always create a draft."*
- If `NANOBANANA_API_KEY` 401: announce known issue #20724, switch to
  `assets/hero-fallback.jpg` and continue.

---

## Slot 8 · QR + Hosting deploy (76–84')

### 8a · QR code (76–80')

```text
> @frontend-builder Add a /admin/qr page that renders a QR code pointing
  to window.location.origin + '/p/' + workshopId. Use the qrcode npm package.
```

### 8b · Deploy (80–84')

```text
> @backend-builder Activate the firebase-deploy-checklist skill. Walk through
  the six preflight steps. If all pass, ask me before running
  `firebase deploy --only hosting,firestore:rules,firestore:indexes`.
```

Audience scans the projected QR with their phone, signs in with Google, votes.
Live data flows into Firestore. Admin page refreshes.

### Recovery
- OAuth redirect fails: Cloud Shell preview domain not in Firebase Auth
  authorized domains — add it on the spot or stay localhost.
- Deploy permission error: confirm the active gcloud account is project
  Owner or Firebase Admin.

---

## Slot 9 stretch · ADK to Agent Engine (84–88')

**Skip if any earlier slot ran long.** This is bonus.

```text
> @adk-builder Activate google-agents-cli-deploy. Deploy insight-agent to
  Agent Engine. After deploy succeeds, generate a Cloud Function proxy at
  functions/agentProxy.ts that verifies the Firebase ID token and forwards
  to the deployed reasoning engine. Then update VITE_AGENT_ENDPOINT in
  frontend/.env to point at the Cloud Function URL.
```

If deploy fails or runs >3 min: show pre-recorded video, narrate, move on.

---

## Slot 10 · Wrap (88–90')

```text
> /memory add Lessons learned: <facilitator-notes>
```

Final words (1 minute total):

- **A2A protocol** — agent-to-agent interop is the next frontier, mention,
  point at the Multi-Agent A2A Medium post.
- **`conductor` extension** — for graduating from "one demo" to "many features":
  ```bash
  gemini extensions install https://github.com/gemini-cli-extensions/conductor --consent
  ```
- **`agents-cli` skills** — `adk-deploy-guide`, `adk-eval-guide`,
  `google-agents-cli-observability` cover what we skipped.

Repo template = audience's starting point. Dismiss.

---

## Universal recovery moves

| Symptom | Move |
|---|---|
| Gemini hallucinates a path | "Read GEMINI.md again, then redo." |
| Subagent goes off-rails | `/restore` to the last checkpoint. |
| Context > 70% used | `/compress`. |
| Skill ignored | "Activate the X skill before continuing." |
| Diff is huge / unfocused | "Show me a plan first." (Plan Mode) |
| Audience confused: skill vs subagent | Show the mental-model slide. |
| 403 from `cloudcode-pa.googleapis.com` | gemini reverted to Code Assist; `source .gemini/env.sh` again. |
| `Skipping project agents due to untrusted folder` | Add workspace to `~/.gemini/trustedFolders.json` (bootstrap does it). |
| `Validation failed: tools.N: Invalid tool name` | Subagent frontmatter has bad tool — use `run_shell_command`, `replace`, `search_file_content` (NOT `run_shell`/`edit`/`grep`). |

## Cut order if running long

1. Drop **slot 9** (stretch deploy) — keep local agent only.
2. Drop **slot 8 admin stats** — show a screenshot instead.
3. Drop **slot 7 Nano Banana + email** — say "homework, the skill is in the repo".
4. **Never drop slots 3, 4, 6** — pedagogical core (skills, subagents, ADK).

## Success criteria

By T+90, every audience member's Cloud Shell session contains:

- Working `gemini` loading project `GEMINI.md` + 5 subagents + 3 workspace skills.
- Running `insight-agent` answering both tasks on `:8080`.
- Frontend on `:8081` calling that agent end-to-end.
- Populated Firestore (real or emulator) with at least one poll and votes.
- A draft Gmail message in their account.

Deploy is bonus, not pass/fail.

---

## Resources

- `GEMINI.md` — project memory (always check first)
- `docs/CLOUDSHELL.md` — Cloud Shell quirks + auth gotchas
- `docs/WORKSHOP-PLAN.md` — high-level plan + risk matrix (companion to this runbook)
- `docs/reference/EXPECTED-agent.py` — target ADK rewrite (silent reference)
- `docs/reference/EXPECTED-App.tsx` — target frontend
- `docs/reference/EXPECTED-agent.ts` — target ADK client
- `docs/reference/EXPECTED-flow.md` — original prompt-by-prompt cheat sheet
- `scripts/bootstrap.sh` — idempotent setup
- `scripts/gcloud-profile.sh` — multi-project gcloud + ADC isolation
- `scripts/gemini-smoke-test.sh` — `make gemini-test` (4 cheap checks)

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
