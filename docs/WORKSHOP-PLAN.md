# Workshop Pulse — 75' default · 60' compressed

Audience: developers. Environment: Google Cloud Shell.
Goal: deliver Workshop Pulse end-to-end via Gemini CLI orchestration with
**3 live mega-prompts** total and a working anonymous-auth app at the end.

## Mental model (always-visible slide)

> **GEMINI.md** = who we are (fixed context)
> **Extensions** = what we can do (MCP tools + slash commands)
> **Skills** = how we do things (replicable processes, on-demand)
> **Subagents** = who delegates what (isolated execution)
> **Plan Mode + Checkpointing** = how we stay in control

## Slot-by-slot

| Slot | 75' default | 60' compressed | Topic | Live prompts |
|---|---|---|---|---|
| 1 | 0–5   | 0–3   | Setup smoke-test (`make gemini-test`)             | 0 |
| 2 | 5–15  | 3–8   | GEMINI.md + extensions + skills + subagents       | 0 |
| 3 | 15–25 | 8–15  | **Conductor walkthrough (pre-baked)**             | 0 |
| 4 | 25–33 | 15–22 | Mega-prompt **backend** (`@backend-builder` + skill) | 1 |
| 5 | 33–45 | 22–32 | Mega-prompt **frontend** (`@frontend-builder`)    | 1 |
| 6 | 45–60 | 32–45 | Mega-prompt **ADK** (`@adk-builder` + skill)      | 1 |
| 7 | 60–70 | 45–55 | Integration + audience demo                       | 0 |
| 8 | 70–75 | 55–60 | Wrap + homework                                   | 0 |

**Total**: 3 live prompts. 75 min default, 60 min when compressed.

## Why pre-bake `conductor/`

A live `/conductor:setup` walkthrough takes ~25 minutes (interactive Q&A
on product, tech stack, workflow, guidelines). The pedagogical value is
in the *artefacts and discipline*, not in watching a wizard. Slot 3 now:

1. Shows the pre-baked `conductor/` folder structure (5 min).
2. Reads `product.md`, `spec.md`, `plan.md` aloud (3 min).
3. Explains how `/conductor:setup` + `/conductor:newTrack` would have
   produced this in a fresh project (2 min).

Total: 10 minutes saved → goes to slots 4/5/6 build buffer.

## Risk matrix

| Risk | Likelihood | Mitigation |
|---|---|---|
| Preview model not allowlisted | M | `GEMINI_MODEL=gemini-2.5-flash` fallback documented in T-24h checklist |
| Mega-prompt fails halfway through one layer | M | `/restore` + re-issue same mega-prompt (idempotent because spec didn't change) |
| Anonymous Auth not enabled in Firebase Console | L | `firebase-config.sh` enables via REST; verify in T-24h checklist |
| `frontend/.env` missing Firebase keys | L | `make scaffold-frontend` chains to `firebase-config` automatically |
| Cloud Shell preview port conflict | L | Makefile defaults to 8081; `VITE_PORT=8082` override |
| Audience network flaky | L | All work happens in their Cloud Shell; mobile votes use Cloud Shell preview public URL |
| Audience asks "where did `conductor/` come from?" | M | Slot 3b answers it: explain `/conductor:setup` + `/conductor:newTrack` slash commands without running them |
| Demo phones can't reach Cloud Shell preview | L | Anonymous Auth means no domain whitelist; preview URL is internet-reachable |
| Frontend mega-prompt produces TS strict errors | L | `make scaffold-frontend` patches `tsconfig.app.json` to `noUnusedLocals: false` |

## Cut order if running long

1. Drop slot 8 (wrap to 30 sec, link to `docs/HOMEWORK.md`).
2. Compress slot 7 demo to facilitator-driven (skip audience phones).
3. Skip the optional `/conductor:newTrack` second-feature live demo in 3b.
4. Compress slot 2 to a 5-min `gemini extensions list` + `/skills`.
5. **Never drop**: slot 3a, slot 4, slot 5, slot 6.

## Success criteria

- Every audience member's Cloud Shell ends the session with:
  - working `gemini` loading project context + 5 subagents + 3 workspace skills + `conductor` extension,
  - pre-baked `conductor/` folder + 1 track ready,
  - working `backend/firestore.{schema.md,rules,indexes.json}`,
  - working `frontend/` with anonymous auth + live agent integration,
  - working `insight-agent/` with rewritten `agent.py`,
  - real votes in their Firestore from real audience.
- Total live `gemini -p` prompts: 3.
- Zero Google OAuth popups during demo.
- App "just works" on first audience scan.
