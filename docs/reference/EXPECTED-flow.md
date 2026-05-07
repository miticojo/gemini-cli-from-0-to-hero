# Facilitator cheat sheet — prompt-by-prompt flow

This is the script you (facilitator) feed to Gemini CLI during the live workshop.
For each slot it lists:

- **Prompt** — what to type literally.
- **Expected** — what should land on disk after Gemini finishes.
- **Recovery** — what to do if Gemini diverges.

The fully-worked targets live alongside this file:
`EXPECTED-agent.py`, `EXPECTED-App.tsx`, `EXPECTED-agent.ts`.
Refer to them silently while pacing the room. **Do not show them on screen** —
audience must see Gemini produce the code.

---

## Slot 2 — `GEMINI.md` walkthrough (5–15')

No code generation. Audience runs:

```text
gemini
> /skills
> /memory show
> @adk-builder
```

Just verify all 5 subagents and 10 skills (7 ADK + 3 workspace) are listed.

---

## Slot 3 — Skills concept + create a custom skill (15–24')

### Prompt

```text
Create a new workspace-tier skill called "poll-stats-helper" that knows how
to compose Firestore aggregation queries for vote counts. It should live in
.gemini/skills/poll-stats-helper/ with a SKILL.md whose description triggers
on phrases like "vote stats", "tally results", "aggregate poll".
```

### Expected

- New directory `.gemini/skills/poll-stats-helper/SKILL.md`.
- YAML frontmatter `name`, `description` keyword-rich.
- Skill body with a stub query template.

### Recovery

If Gemini puts it in `~/.gemini/skills/` instead of workspace, instruct:
"move it under the project's `.gemini/skills/` directory so the team shares it."

After: run `/skills` and confirm the new skill appears.

---

## Slot 4 — Subagents tour (24–32')

No new code. Audience reads `.gemini/agents/*.md` while you narrate the
distinction:

> "Skill = how. Subagent = who-in-isolation. Subagents have their own context
> window. Skills inject instructions into the current conversation."

Then call:

```text
@spec-writer Produce SPEC.md for Workshop Pulse based on GEMINI.md.
```

Expected: a `SPEC.md` at repo root with user stories, data model, agent
contracts, acceptance criteria.

### 30-second mention: when to graduate to `conductor`

After `@spec-writer` finishes, hold up the deep `SPEC.md` and say:

> "Today we want one rich spec for one feature, so `@spec-writer` is the right
> tool — single artefact, deep coverage of the data model, routes, and agent
> contracts. For projects with many features over time there's the official
> `conductor` extension which splits things into `product.md` + `tech-stack.md`
> + per-track `spec.md` + multi-phase `plan.md` checklist. Same 'measure
> twice' philosophy, larger granularity. We'll skip it today and link it as
> homework."

Don't install conductor live — keep momentum. The rehearsal A/B test
(`tmp/ab-test/`) showed conductor's per-track spec is shallower than
`@spec-writer`'s for a single feature, but its `plan.md` and persistent
`product.md`/`tech-stack.md` are wins on multi-feature projects.

---

## Slot 5 — Build app: backend + frontend (32–46')

### 5a — Backend rules

```text
@backend-builder Generate the Firestore data model, security rules, and
composite indexes for Workshop Pulse. Use the poll-schema-designer skill.
```

#### Expected
- `backend/firestore.schema.md`
- `backend/firestore.rules`
- `backend/firestore.indexes.json`

Rules must enforce: vote create only by attendee, exactly once per `(pollId, userId)`;
admin reads all votes in their workshop.

#### Recovery
If Gemini writes inline rules without invoking the skill, prompt:
"Activate the poll-schema-designer skill before producing the rules."

### 5b — Frontend scaffold

```text
@frontend-builder Build the Workshop Pulse frontend on top of the existing
Vite stub: React Router with /admin and /p/:workshopId routes, Firebase Auth
(Google SSO) wired in src/lib/firebase.ts, a Login button, and a placeholder
admin dashboard. Read src/App.tsx and replace the stub. Don't wire the agent
yet — that's the next step.
```

#### Expected
- `frontend/src/lib/firebase.ts` (init, exports `auth`, `db`).
- `frontend/src/App.tsx` updated with `<RouterProvider>`.
- `frontend/src/routes/Admin.tsx`, `frontend/src/routes/Attendee.tsx`.
- `frontend/src/components/Login.tsx` (Google sign-in button).
- `frontend/.env.example` updated if missing keys.

#### Recovery
If Gemini installs heavy UI libs (MUI, Chakra) — stop and instruct:
"keep dependencies to react-router-dom, firebase, recharts only."

---

## Slot 6 — ADK agent local-first (46–66')

### 6a — Rewrite the scaffold

```text
@adk-builder Rewrite insight-agent/app/agent.py per the contract in GEMINI.md:
a root_agent that routes on the `task` field of the user message, plus two
sub-agents `question_generator` and `sentiment_insight`. Use Vertex AI
gemini-3.1-pro-preview. Keep the App(name="app") so the directory matches.
Activate the google-agents-cli-adk-code skill.
```

#### Expected
- `insight-agent/app/agent.py` matches `EXPECTED-agent.py` semantically:
  - root agent with `sub_agents=[question_generator, sentiment_insight]`.
  - both sub-agents with strict JSON-only instructions.
  - `_load_dotenv()` helper or direct env reading.

#### Recovery
- If Gemini forgets the App name → "the App.name must equal the directory name 'app' or ADK rejects sessions."
- If preview model 404 → "fall back to gemini-2.5-flash; set GEMINI_MODEL in insight-agent/.env."

### 6b — Start the playground

```text
@adk-builder run the agent on port 8080.
```

Or just `make agent-dev` in a second terminal.

### 6c — Wire the frontend

```text
@frontend-builder Create frontend/src/lib/agent.ts that:
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

#### Expected
- `frontend/src/lib/agent.ts` matches `EXPECTED-agent.ts` semantically.
- Button visible on `/admin` route.
- Click → poll JSON rendered.

#### Recovery
- If Gemini calls `/run_sse` (streaming) → ask for `/run` (sync) for simplicity.
- If session id missing → "the session-create response has `id`, not `sessionId`."

### 6d — Demo: end-to-end roundtrip

Audience clicks the button on `/admin`, sees a real poll generated by the
sub-agent. Then ask Gemini:

```text
Now wire the attendee voting page so submitted votes get stored in Firestore
under workshops/{w}/polls/{p}/votes, then add an "Analyze sentiment" button
on /admin that calls queryAgent('analyze-sentiment', { workshop_id, votes })
and renders the resulting mood as a colored badge plus a list of themes.
```

---

## Slot 7 — Nano Banana + email (66–76')

```text
@image-designer Build the post-workshop thank-you email pipeline. Activate
the thank-you-email skill. Take the sentiment output from slot 6, generate a
hero image with mcp_nanobanana_generate using the mood-to-style mapping, then
create a Gmail draft via the Workspace MCP for each attendee. Output a single
function compose_thank_you(workshopId, sentiment, recipients).
```

#### Expected
- `functions/email/compose_thank_you.ts` (or `.py`) with the pipeline.
- Calls cached on `(workshopId, mood)`.
- Gmail draft created (not sent).

---

## Slot 8 — QR + Hosting deploy (76–84')

### 8a — QR code

```text
@frontend-builder Add a /admin/qr page that renders a QR code pointing to
window.location.origin + '/p/' + workshopId. Use the qrcode npm package.
```

### 8b — Deploy

```text
@backend-builder Activate the firebase-deploy-checklist skill. Walk through
the six preflight steps. If all pass, ask me before running `firebase deploy
--only hosting,firestore:rules,firestore:indexes`.
```

Audience then scans the QR with their phone, signs in with Google, votes.
Live data flows into Firestore. Admin page refreshes stats.

---

## Slot 9 — Stretch: deploy ADK to Agent Engine (84–88')

```text
@adk-builder Activate google-agents-cli-deploy. Deploy insight-agent to
Agent Engine. After deploy succeeds, generate a Cloud Function proxy at
functions/agentProxy.ts that verifies the Firebase ID token and forwards
to the deployed reasoning engine. Then update VITE_AGENT_ENDPOINT in
frontend/.env to point at the Cloud Function URL.
```

If time runs out, skip. Show the pre-built reference instead and explain.

---

## Slot 10 — Wrap (88–90')

```text
/memory add Lessons learned from this workshop: <facilitator notes>
```

Final words on:
- **A2A protocol** — agent-to-agent interop is the next frontier (one-line mention, point at the Multi-Agent A2A Medium post).
- **`conductor` extension** — for graduating from "one workshop demo" to "many features in a managed project", install:
  ```bash
  gemini extensions install https://github.com/gemini-cli-extensions/conductor --consent
  ```
  then `/conductor:setup` once, `/conductor:newTrack` per feature.
- **`agents-cli`** — already installed; remind that `adk-deploy-guide`,
  `adk-eval-guide`, and `google-agents-cli-observability` skills cover what we
  skipped today.

Dismiss.

---

## Universal recovery moves

| Symptom | Move |
|---|---|
| Gemini hallucinates a file path | "Read GEMINI.md again, then redo." |
| Subagent goes off-rails | `/restore` to the last checkpoint. |
| Context > 70% used | `/compress`. |
| Gemini ignores a skill | "Activate the X skill before continuing." |
| Diff is huge and unfocused | "Show me a plan before writing code." (Plan Mode) |
| Audience confused on skill vs subagent | Point at the always-visible mental-model slide. |

## Time-budget reminders

- Aim for **≤ 3 prompts per slot**. More than that = audience loses thread.
- Keep each Gemini turn **under 90 seconds**. Interrupt and refine if longer.
- If a sub-agent burns 4+ turns, hard-stop with `/compress` and re-issue a
  tighter prompt.
