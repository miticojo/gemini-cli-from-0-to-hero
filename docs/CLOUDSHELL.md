# Cloud Shell notes

Workshop runs on Google Cloud Shell. This page captures the deltas vs. running
locally and the gotchas surfaced during rehearsal.

## What's already there

| Tool | Pre-installed |
|---|---|
| `gcloud`, `gsutil`, `bq` | yes |
| `node` (v20+) | yes |
| `python3` (3.12+) | yes |
| `docker` | yes |
| `git` | yes |
| Application Default Credentials | yes (auto-configured for the logged-in user) |

## What `make bootstrap` installs

| Tool | How |
|---|---|
| `@google/gemini-cli` | `npm i -g` |
| `firebase-tools` | `npm i -g` |
| `uv` (provides `uvx`) | `pip install --user uv` |
| `agents-cli` + 7 ADK skills | `uvx google-agents-cli setup` |
| ADK Python deps | `uv pip install -e .` inside `insight-agent/.venv` |
| Frontend deps | `npm install` inside `frontend/` |

Runs in 4-6 minutes cold on Cloud Shell. **Idempotent** — re-running is safe.

## Persistent vs. ephemeral

- `$HOME` (5 GB) **persists** between Cloud Shell sessions; everything else does not.
- Clone the repo into `$HOME` so deps survive.
- The default working directory `~/cloudshell_open/...` is fine.

## Web Preview ports

Cloud Shell exposes ports **8080-8084** through the **Web Preview** button.

| Service | Port | Why |
|---|---|---|
| ADK agent (FastAPI) | **8080** | matches the `Web Preview` default; click → opens `/dev-ui` |
| Vite frontend | **8081** | `Makefile` already targets this when `CLOUD_SHELL=true` |
| Spare | 8082-8084 | Firebase emulator UI (4000), Firestore (8080) collide — prefer here |

`vite.config.ts` whitelists `*.cloudshell.dev` so the preview proxy works.

## Authentication

ADC is auto-provisioned for the active user. **Do not run** `gcloud auth login`
or `gcloud auth application-default login` unless ADC is explicitly missing —
it can break the auto-credentials.

For the agent to call Vertex AI, the active project must have
`aiplatform.googleapis.com` enabled. The bootstrap script does this.

## Preview model availability

`gemini-3.1-pro-preview` may require allowlisting per project. Check with:

```bash
ACCESS_TOKEN=$(gcloud auth application-default print-access-token)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  "https://aiplatform.googleapis.com/v1/projects/$GOOGLE_CLOUD_PROJECT/locations/global/publishers/google/models/gemini-3.1-pro-preview:generateContent" \
  -X POST -H "Content-Type: application/json" -d '{"contents":[{"role":"user","parts":[{"text":"hi"}]}]}'
```

`200` = available. `404` = fall back to `gemini-2.5-flash` by setting
`GEMINI_MODEL=gemini-2.5-flash` in `insight-agent/.env`.

## Gemini CLI auth — must use Vertex AI

By default `gemini` uses Code Assist (`oauth-personal`) which calls
`cloudcode-pa.googleapis.com` and is **not** what we want for the workshop.

The bootstrap writes `.gemini/settings.json` with:
```json
{ "security": { "auth": { "selectedType": "vertex-ai" } },
  "general":  { "model": "gemini-3.1-pro-preview" } }
```
…and `.gemini/env.sh` with the right `GOOGLE_*` env vars. **Source it**
before running gemini:
```bash
source .gemini/env.sh
gemini
```

To verify:
```bash
make gemini-test    # 4 cheap smoke tests, ~3 model calls total
```

## Workspace must be trusted

Gemini CLI silently skips `.gemini/agents/` and `.gemini/skills/` until the
workspace is trusted. The bootstrap adds the repo root to
`~/.gemini/trustedFolders.json` automatically.

To check, look for the line `Skipping project agents due to untrusted folder`
in `gemini skills list` output — if it appears, the folder is not trusted.

## Subagent tool name gotchas

Subagent frontmatter accepts only the canonical Gemini CLI tool names:

✓ `read_file`, `write_file`, `replace`, `run_shell_command`,
`search_file_content`, `glob`, `web_fetch`, `google_web_search`

✗ `run_shell` (use `run_shell_command`), `edit` (use `replace`),
`grep` (use `search_file_content`), `mcp_*` literal names (MCP tools are
inherited from the parent session — do not enumerate them in frontmatter).

A misnamed tool in `tools:` causes:
```
Failed to load agent from .gemini/agents/X.md: Validation failed: tools.N: Invalid tool name
```

## Common Cloud Shell issues

| Symptom | Fix |
|---|---|
| `Permission denied` on `npm i -g` | use `npm config set prefix ~/.npm-global` then `export PATH=~/.npm-global/bin:$PATH` |
| `uv: command not found` after install | `export PATH=$HOME/.local/bin:$PATH` and add to `~/.bashrc` |
| Web Preview shows blank page | confirm Vite started with `--host 0.0.0.0` (the Makefile does it) |
| `403 PERMISSION_DENIED` from Vertex | API not enabled — re-run `gcloud services enable aiplatform.googleapis.com` |
| Cloud Shell session timeout (1h idle) | files in `$HOME` survive; just `make agent-dev` again |
| Firebase Auth OAuth redirect fails | add Cloud Shell preview URL to Firebase Auth → authorized domains |
| `403` from `cloudcode-pa.googleapis.com` | gemini using Code Assist, not Vertex. Source `.gemini/env.sh` and verify `.gemini/settings.json` has `vertex-ai` |
| `Skipping project agents due to untrusted folder` | re-run `make bootstrap`; it adds the workspace to `trustedFolders.json` |
| `Subagent 'X' not found` | `tools:` list contains an invalid name. Run `gemini skills list` and read the `Validation failed` line |

## Optional advanced extensions (post-workshop)

Not part of the main flow — install only if you want to extend the pattern to
multi-feature projects after the workshop ends.

### `conductor` — Context-Driven Development workflow

```bash
gemini extensions install https://github.com/gemini-cli-extensions/conductor --consent
gemini   # then run /conductor:setup
```

Splits planning into `product.md`, `tech-stack.md`, `workflow.md`,
`product-guidelines.md`, plus per-track `spec.md` + multi-phase `plan.md`.
Token-heavy because of continuous context analysis.

When to choose conductor over `@spec-writer`:

| Goal | Use |
|---|---|
| Single rich spec for one feature with full data model + contracts | `@spec-writer` |
| Multi-feature project with persistent context + per-feature plans | `conductor` |
| Single 90-minute demo of an end-to-end build | `@spec-writer` (this workshop) |
| Long-lived project, many tracks, many contributors | `conductor` |

Rehearsal A/B test results live in `tmp/ab-test/` (gitignored): conductor's
per-track `spec.md` was thinner than `@spec-writer`'s output for the same
brief, but conductor adds an actionable 5-phase `plan.md` checklist that
`@spec-writer` does not produce.

## Cloud Shell tutorial mode

For a self-paced run, you can render any markdown file as a side panel via
the `?cloudshell_tutorial=<path>` URL parameter — for example point it at
`docs/RUNBOOK.md` to step through the workshop solo.
