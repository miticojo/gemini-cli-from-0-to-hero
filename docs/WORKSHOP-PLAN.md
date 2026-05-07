# Workshop Pulse — 90-minute plan

Audience: developers. Environment: Google Cloud Shell.
Goal: deliver Workshop Pulse end-to-end via Gemini CLI orchestration; deploy is
a stretch.

## Mental model (always-visible slide)

> **GEMINI.md** = who we are (fixed context)
> **Extensions** = what we can do (MCP tools + slash commands)
> **Skills** = how we do things (replicable processes, on-demand)
> **Subagents** = who delegates what (isolated execution)
> **Plan Mode + Checkpointing** = how we stay in control

## Slot-by-slot

| Slot | Min | Topic | Deliverable |
|---|---|---|---|
| 1 | 0–5 | Intro + Cloud Shell smoke test (`make bootstrap` if not done) | All deps green |
| 2 | 5–15 | `GEMINI.md` walkthrough + `gemini extensions list` + `/skills` | 7 ADK + 3 workspace skills visible |
| 3 | 15–24 | **Skills concept** + skill creator live: produce `poll-schema-designer` | New skill, `/skills` shows it |
| 4 | 24–32 | **Subagents concept** + 5 subagent files | All 5 visible via `@<name>` |
| 5 | 32–46 | Build app: `@backend-builder` invokes `poll-schema-designer` → `firestore.rules` + indexes; `@frontend-builder` scaffolds Vite + Auth | Backend + frontend stub working |
| 6 | 46–66 | **ADK block (local-first)**: `@adk-builder` → `agents-cli create insight-agent --prototype`; configure `gemini-3.1-pro-preview`; add `question_generator` + `sentiment_insight`; run `make agent-dev`; verify from frontend | Agent on :8080, React calls round-trip |
| 7 | 66–76 | Nano Banana + email: `thank-you-email` skill on sentiment output | Mood-aware Gmail draft created |
| 8 | 76–84 | QR code + Firebase Hosting deploy of frontend; live audience demo | Audience scans QR, votes, admin sees stats |
| 9 | 84–88 | **Stretch**: `agents-cli deploy --target agent-engine`; flip `VITE_AGENT_ENDPOINT` | Agent on Engine, app keeps working |
| 10 | 88–90 | Wrap: `/memory add`, A2A mention, repo template | Audience leaves with reusable seed |

## Risk matrix

| Risk | Likelihood | Mitigation |
|---|---|---|
| Preview model not allowlisted | M | `GEMINI_MODEL=gemini-2.5-flash` fallback documented |
| `agents-cli setup` slow on Cloud Shell | M | Audience runs bootstrap before; demo skips reinstall |
| Vite dev server port conflict | L | `Makefile` defaults to 8081 on Cloud Shell |
| Firebase OAuth domain not whitelisted | M | Pre-flight: add Cloud Shell preview domain |
| Audience network drops | L | Backup screen recording of the deploy |
| Slot 6 overruns | H | Pre-built `insight-agent/` is in repo — fall back to walking through it |
| A2A questions derail | M | Slide says "next workshop"; redirect |

## Cut order if running long

1. Drop slot 9 (stretch deploy) — keep local agent.
2. Drop slot 8 admin stats — show a screenshot instead.
3. Drop slot 7 Nano Banana + email — say "homework, repo has the skill".
4. Never drop slots 3, 4, 6 — they are the pedagogical core.

## Success criteria

- Every audience member ends the session with a Cloud Shell session containing:
  - working `gemini` CLI loading project `GEMINI.md` + 5 subagents + 3 workspace skills,
  - a running `insight-agent` answering both tasks on port 8080,
  - a frontend on port 8081 calling that agent,
  - a populated Firestore (or emulator) with at least one poll and votes,
  - a draft Gmail message in their account.
- Deploy is bonus, not pass/fail.
