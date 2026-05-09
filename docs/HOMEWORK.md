# Workshop Pulse — Homework recipes

The 90-minute workshop ships an app that works end-to-end with Anonymous
Auth. Three follow-ups extend it. Each is one prompt + a small verify step.

> **Pre-requisite for all three**: you finished the workshop. You have
> `conductor/`, `backend/`, `frontend/`, and `insight-agent/` populated and
> running locally. `make gemini-test` still passes.

---

## Recipe 1 — Google SSO upgrade

**Goal**: keep Anonymous Auth as the default but let users upgrade to
Google SSO without losing their `uid` (votes survive the upgrade).

### Why it works without rules changes

`backend/firestore.rules` only checks `request.auth != null`. Both
Anonymous and Google providers satisfy that. The upgrade is purely a
frontend swap; rules and indexes do not change.

### One prompt

```text
> @frontend-builder Upgrade frontend/src/lib/firebase.ts to keep
  signInAnonymously as the default but expose a "Sign in with Google"
  button on the Admin page. The Google flow MUST use linkWithPopup against
  the existing anonymous user, NOT a fresh signInWithPopup, so the uid is
  preserved and existing workshop ownership ('createdBy') keeps working.
  Add the button to frontend/src/components/GoogleUpgrade.tsx; mount it
  on /admin only. Persist the linked credential.
```

### Verify

1. Open `/admin` while signed in anonymously. Observe `anon-XXXX` badge.
2. Click "Sign in with Google" → choose account.
3. Reload — badge now shows your email; the same `uid` is preserved.
4. Workshops you created before still list under "My workshops".

### Pre-flight gotchas

- Firebase Console → Authentication → Sign-in method → enable Google.
- Cloud Shell preview URL must be added to Firebase Auth → Authorized
  domains. Use `cloudshell.dev` wildcard if Firebase allows it; else add
  the specific preview hostname.
- If `linkWithPopup` errors with `auth/credential-already-in-use`, that
  Google account has already been linked to another anonymous user.
  Surface a "Sign in to that account instead" fallback.

---

## Recipe 2 — Nano Banana thank-you email

**Goal**: after a workshop ends, draft a personalised Gmail message to
each attendee with a custom hero image whose mood matches the sentiment
analysis.

### Pre-requisites

```bash
gemini extensions install https://github.com/gemini-cli-extensions/nanobanana --consent
gemini extensions install @gemini-cli-extensions/workspace --consent
export NANOBANANA_API_KEY=…
```

### One prompt

```text
> @image-designer Build the post-workshop thank-you email pipeline.
  Activate the thank-you-email skill. Take the sentiment-insight agent
  output ({mood, themes, summary}) and:
  1. Generate a hero image with mcp_nanobanana_generate using the mood→style
     mapping from the skill.
  2. Cache the image at functions/email-assets/hero-{workshopId}-{mood}.jpg.
  3. Compose an HTML body referencing the workshop name, summary, themes
     list, and the hero as a cid: inline image.
  4. Use the Workspace MCP gmail_drafts_create to create a draft (NEVER
     send) for each recipient in the input list.
  Output a single TypeScript function compose_thank_you(workshopId,
  sentiment, recipients) at functions/email/compose_thank_you.ts.
```

### Verify

1. Run a sentiment analysis from `/admin` to populate
   `{ mood, themes, summary }`.
2. Call `compose_thank_you(...)` from a Cloud Function or local node script.
3. Check Gmail → Drafts. Verify hero image renders inline.

### Mood → style cue (memorise)

- `positive` → bright warm, celebratory.
- `mixed` → balanced, editorial.
- `constructive` → cool focused.
- `negative` → soft empathetic.

### Pre-flight gotchas

- `NANOBANANA_API_KEY` env var bug (issue #20724) — verify it's read by
  the extension; if not, restart `gemini` in a fresh shell.
- Workspace OAuth scope: extension needs `gmail.compose` for drafts.

---

## Recipe 3 — Agent Engine deploy + Cloud Function proxy

**Goal**: replace `http://localhost:8080` with a managed Vertex AI Agent
Engine endpoint. Cloud Function proxy verifies the Firebase ID token
(anonymous tokens are still valid) and forwards to the reasoning engine
via service-account IAM.

### Pre-requisites

- Cloud Run, Cloud Functions, Agent Engine APIs enabled in your project
  (already enabled by `make bootstrap`).
- A service account with `roles/aiplatform.user` for the Cloud Function
  to call Agent Engine.

### One prompt

```text
> @adk-builder Activate google-agents-cli-deploy. Deploy insight-agent to
  Agent Engine in region us-central1. After deploy succeeds, generate a
  Cloud Function (2nd gen, HTTPS, Node 20) at functions/agentProxy/index.ts
  that:
  1. Verifies the Firebase ID token from the Authorization header
     (admin.auth().verifyIdToken). Anonymous tokens are valid auth.
  2. Forwards the body to the deployed Reasoning Engine via the
     google-cloud/aiplatform Node SDK. Pass through { task, payload }.
  3. Returns the agent response as application/json.
  Then update frontend/.env to set VITE_AGENT_ENDPOINT to the Cloud
  Function URL. Commit nothing; print the deploy commands the user needs
  to run.
```

### Verify

1. Run the printed `firebase deploy --only functions:agentProxy` command.
2. Reload `/admin`. Click "Generate poll" — verify the request goes to
   the Cloud Function URL (DevTools → Network).
3. Cold-start latency should be ~3-5s on first call, ~500ms thereafter.

### Pre-flight gotchas

- Cloud Function default service account often lacks Agent Engine
  invoke permissions; grant `roles/aiplatform.user` explicitly.
- Anonymous Firebase ID tokens look the same as Google ones to
  `verifyIdToken` — no special-casing needed.
- Cold-start: keep `min_instances=1` for demos to avoid the first-call
  spinner.

---

## Bonus — A2A protocol

Not a recipe, just a pointer. Agent-to-Agent (A2A) is the open protocol
for multi-agent interop. Once your `insight-agent` is on Agent Engine,
you can connect it to other agents (Google's, third-party, your team's)
via the same protocol. Reference:
[Multi-Agent A2A with ADK + Cloud Run + Gemini CLI](https://medium.com/google-cloud/multi-agent-a2a-with-the-agent-development-kit-adk-cloud-run-and-gemini-cli-52f8be838ad6).
