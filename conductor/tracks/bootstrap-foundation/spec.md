# Specification: Bootstrap Workshop Pulse foundation

## Objective
Deliver an end-to-end Workshop Pulse experience in one workshop session:
admin creates a workshop, AI generates poll questions, attendees vote
anonymously by scanning a QR, admin sees live aggregated stats and triggers
AI sentiment analysis on the open responses.

## User stories

- As an **admin**, I create a workshop, click "Generate poll", and get
  three balanced questions in seconds (mix of single/multi/open).
- As an **admin**, I display a QR pointing to my workshop URL on the
  projector.
- As an **attendee**, I scan the QR, get signed in anonymously without any
  popup, and vote with one tap. I cannot vote twice for the same poll.
- As an **admin**, I see vote counts update live in a BarChart.
- As an **admin**, I click "Analyze sentiment" and get a mood badge plus a
  list of themes extracted from the open responses.

## Data model (Firestore)

```
workshops/{workshopId}
  name, date, createdBy, createdAt
  /polls/{pollId}
    title, type ("single"|"multi"|"open"), options[], order, createdAt
    /votes/{voteId == userId}
      userId, value, openText?, createdAt
```

No `users/` collection — anonymous uids do not need profile docs.

## Routes

- `/admin` — workshop list, "Generate poll" / "Analyze sentiment" buttons,
  Recharts BarChart, QR for the active workshop.
- `/p/:workshopId` — attendee vote form.

## Agent contracts

- `question_generator`: input `{workshop_topic, num_questions, target_audience}`
  → output `{poll: {title, questions: [{id, text, type, options?}]}}`.
- `sentiment_insight`: input `{workshop_id, votes: [...]}` → output
  `{mood: "positive"|"mixed"|"constructive"|"negative", themes: [...], summary}`.

Both sub-agents emit JSON-only (no markdown fences, no preamble).

## Acceptance criteria

- App boots on Cloud Shell (`make agent-dev` + `make frontend-dev`) without
  any manual `.env` editing.
- Audience can scan a QR and vote without a Google sign-in popup.
- Admin generates a poll in one click; sentiment analysis returns a mood +
  themes in one click.
- `tsc -b --noEmit` is clean; Firestore rules pass `firebase emulators`
  `match` checks.
- Total live `gemini` prompts in the workshop ≤ 5.

## Out of scope (homework)

- Google SSO upgrade (recipe: link the existing anonymous user via
  `linkWithPopup`).
- Nano Banana thank-you email pipeline.
- Agent Engine deploy + Cloud Function proxy.
