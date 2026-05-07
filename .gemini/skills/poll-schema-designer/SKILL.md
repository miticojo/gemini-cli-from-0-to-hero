---
name: poll-schema-designer
description: "Designs Firestore collections, security rules, and composite indexes for polling, voting, and feedback applications. Triggers on requests like: design poll schema, firestore rules for polls, vote collection, feedback data model, attendee role, admin role, workshop polls, polling app schema, voting database, survey schema."
---

# Poll Schema Designer

You produce three artefacts in a single response:

1. `backend/firestore.schema.md` — collection tree with field types and required fields.
2. `backend/firestore.rules` — security rules.
3. `backend/firestore.indexes.json` — composite indexes for common queries.

## Canonical collections

```
workshops/{workshopId}
  name: string
  date: timestamp
  createdBy: string (uid)
  createdAt: timestamp
  /polls/{pollId}
    title: string
    type: "single" | "multi" | "open"
    options: array<string> (empty for "open")
    order: number
    createdAt: timestamp
    /votes/{voteId}
      userId: string (uid)
      value: string | array<string> (per type)
      openText: string?
      createdAt: timestamp

users/{userId}
  email: string
  role: "admin" | "attendee"
  workshops: array<string>
```

## Security rules baseline

- Reads:
  - `workshops/{w}` readable by attendee in `users/{uid}.workshops` or admin.
  - `polls/{p}` same as parent workshop.
  - `votes/{v}` readable only by admin of parent workshop OR own vote.
- Writes:
  - `workshops` create: any authenticated user; update/delete: only `createdBy` or admin claim.
  - `polls`: only workshop owner.
  - `votes` create: attendee only, exactly once per `(pollId, userId)`; update/delete: never.
- Always validate `request.resource.data.userId == request.auth.uid` for vote create.

## Indexes (mandatory)

- `votes` collection group: `(pollId asc, createdAt asc)` — for stats queries.
- `polls`: `(workshopId asc, order asc)` — for ordered render.

## Output format

Always return the three files in fenced code blocks with explicit paths, in the
order: schema → rules → indexes. Never produce code outside these three artefacts
when this skill is active.

## See also

- `references/rules-snippets.md` — common rule fragments.
- `scripts/validate_rules.sh` — quick lint via `firebase emulators`.
