/**
 * Workshop Pulse — agent client.
 *
 * Talks to either the local ADK playground (port 8080) or the deployed
 * Cloud Function proxy. Endpoint switches via VITE_AGENT_ENDPOINT.
 */

const ENDPOINT = (import.meta.env.VITE_AGENT_ENDPOINT ?? 'http://localhost:8080').replace(/\/$/, '');
const APP_NAME = 'app'; // ADK uses the agent directory name as app id
const USER_ID = 'workshop-attendee';

export type Task = 'generate-poll' | 'analyze-sentiment';

export async function queryAgent(task: Task, payload: unknown): Promise<unknown> {
  const sessionId = await createSession();

  const res = await fetch(`${ENDPOINT}/run`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      appName: APP_NAME,
      userId: USER_ID,
      sessionId,
      newMessage: {
        role: 'user',
        parts: [{ text: JSON.stringify({ task, payload }) }],
      },
    }),
  });

  if (!res.ok) {
    throw new Error(`agent /run failed: ${res.status} ${await res.text()}`);
  }

  const events = await res.json();
  const lastText = stripFences(extractLastText(events));
  try {
    return JSON.parse(lastText);
  } catch {
    return { raw: lastText };
  }
}

function stripFences(s: string): string {
  return s.replace(/^```(?:json)?\s*/i, '').replace(/\s*```\s*$/i, '').trim();
}

async function createSession(): Promise<string> {
  const res = await fetch(`${ENDPOINT}/apps/${APP_NAME}/users/${USER_ID}/sessions`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({}),
  });
  if (!res.ok) throw new Error(`session create failed: ${res.status}`);
  const session = (await res.json()) as { id?: string };
  if (!session.id) throw new Error('session response missing id');
  return session.id;
}

function extractLastText(events: unknown): string {
  if (!Array.isArray(events)) return '';
  for (let i = events.length - 1; i >= 0; i--) {
    const ev = events[i] as { content?: { parts?: { text?: string }[] } };
    const parts = ev?.content?.parts;
    if (parts) {
      for (let j = parts.length - 1; j >= 0; j--) {
        if (typeof parts[j].text === 'string') return parts[j].text!;
      }
    }
  }
  return '';
}
