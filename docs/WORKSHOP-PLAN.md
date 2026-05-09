# Workshop Pulse — 90-minute plan

Audience: developers. Environment: Google Cloud Shell.
Goal: deliver Workshop Pulse end-to-end via Gemini CLI orchestration with
**5 live prompts** total and a working anonymous-auth app at the end.

## Mental model (always-visible slide)

> **GEMINI.md** = who we are (fixed context)
> **Extensions** = what we can do (MCP tools + slash commands)
> **Skills** = how we do things (replicable processes, on-demand)
> **Subagents** = who delegates what (isolated execution)
> **Plan Mode + Checkpointing** = how we stay in control

## Slot-by-slot

| Slot | Min | Topic | Live `gemini` prompts |
|---|---|---|---|
| 1 | 0–5   | Setup smoke-test (`make gemini-test`)             | 0 |
| 2 | 5–15  | GEMINI.md + extensions + skills + subagents       | 0 (just /skills, /memory show) |
| 3 | 15–40 | **Conductor PRD** (`/conductor:setup` + `/conductor:newTrack`) | 2 |
| 4 | 40–48 | Mega-prompt **backend** (`@backend-builder` + skill) | 1 |
| 5 | 48–60 | Mega-prompt **frontend** (`@frontend-builder`)    | 1 |
| 6 | 60–75 | Mega-prompt **ADK** (`@adk-builder` + skill)      | 1 |
| 7 | 75–85 | Integration + audience demo                       | 0 |
| 8 | 85–90 | Wrap + homework                                   | 0 |

**Total**: 5 live prompts, 90 minutes, one working app.

## Risk matrix

| Risk | Likelihood | Mitigation |
|---|---|---|
| Preview model not allowlisted | M | `GEMINI_MODEL=gemini-2.5-flash` fallback documented in T-24h checklist |
| Conductor `/conductor:setup` quota / token cost | M | Run a rehearsal 24h prior on the same project to warm caches |
| Mega-prompt fails halfway through one layer | M | `/restore` + re-issue the same mega-prompt (idempotent — spec did not change) |
| Anonymous Auth not enabled in Firebase Console | L | `firebase-config.sh` enables via REST; verify in T-24h checklist |
| `frontend/.env` missing Firebase keys | L | `make scaffold-frontend` chains to `firebase-config` automatically |
| Cloud Shell preview port conflict | L | Makefile defaults to 8081; `VITE_PORT=8082` override |
| Audience network flaky | L | All work happens in their Cloud Shell; mobile votes use Cloud Shell preview public URL |
| Conductor produces shallow spec | L | Rehearsal A/B test confirmed conductor's `plan.md` + project context outweigh spec depth for the 3-mega-prompt flow |
| Demo phones can't reach Cloud Shell preview | L | Anonymous Auth means no domain whitelist; preview URL is internet-reachable |
| Slot 3 overruns on PRD discussion | M | Set a hard timer at 40 min; cut the new-track variations to 1 only |

## Cut order if running long

1. Drop slot 8 (wrap to 30 sec, link to `docs/HOMEWORK.md`).
2. Compress slot 7 demo to facilitator-driven (skip audience phones).
3. Skip a second `/conductor:newTrack` if you started one for variety.
4. **Never drop**: slot 3a (`/conductor:setup`), slot 4, slot 5, slot 6.
   These are the pedagogical core.

## Success criteria

- Every audience member's Cloud Shell ends the session with:
  - working `gemini` loading project context + 5 subagents + 3 workspace skills + `conductor` extension,
  - `conductor/` folder with full project context + 1 track,
  - working `backend/firestore.{schema.md,rules,indexes.json}`,
  - working `frontend/` with anonymous auth and live agent integration,
  - working `insight-agent/` with rewritten `agent.py`,
  - real votes in their Firestore from real audience.
- Total live `gemini -p` prompts ≤ 5.
- Zero Google OAuth popups during demo.
- App "just works" on first audience scan.
