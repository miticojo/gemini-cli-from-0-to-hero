# Product Guidelines

## Code Style

- **Frontend:** TypeScript strict + function components (no class components).
  Imports: only `firebase`, `react-router-dom`, `recharts`, `qrcode` (and
  their `@types/*` dev dependencies). Never `signInWithPopup`.
- **Backend/Agent:** Python 3.11+ with type hints, ADK idioms only.
  Sub-agents emit JSON-only output (no markdown fences).

## Security

- Application Default Credentials (ADC) only. Never hard-code API keys.
  Read from `.env`.
- Firestore Security Rules: anonymous-auth-friendly. `request.auth != null`
  for any signed-in user. Admin distinction via `createdBy ==
  request.auth.uid` on the workshop document. No `users/` collection,
  no custom claims, no role lookups.
- Vote uniqueness enforced by `voteId == request.auth.uid` (cheaper than
  `exists()`).

## API contracts (non-negotiable)

- Frontend `agent.ts`:
  ```typescript
  export type Task = 'generate-poll' | 'analyze-sentiment';
  export async function queryAgent(task: Task, payload: unknown): Promise<unknown>;
  ```
  ADK request body uses **camelCase**: `appName: 'app'`, `userId`,
  `sessionId`, `newMessage`. Sessions created via
  `POST /apps/app/users/{uid}/sessions` first, then `POST /run`.

- ADK `agent.py`:
  ```python
  app = App(root_agent=root_agent, name="app")  # name MUST equal directory
  ```
