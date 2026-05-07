import { useState } from 'react';
import { queryAgent } from './lib/agent';

export function App() {
  const [topic, setTopic] = useState('Gemini CLI from zero to hero');
  const [out, setOut] = useState<string>('');
  const [busy, setBusy] = useState(false);

  async function generate() {
    setBusy(true);
    setOut('');
    try {
      const result = await queryAgent('generate-poll', {
        workshop_topic: topic,
        num_questions: 4,
        target_audience: 'developers',
      });
      setOut(JSON.stringify(result, null, 2));
    } catch (err) {
      setOut(String(err));
    } finally {
      setBusy(false);
    }
  }

  return (
    <main style={{ fontFamily: 'system-ui', maxWidth: 720, margin: '40px auto', padding: 24 }}>
      <h1>Workshop Pulse — agent smoke test</h1>
      <p>
        Endpoint: <code>{import.meta.env.VITE_AGENT_ENDPOINT ?? 'http://localhost:8080'}</code>
      </p>
      <input
        value={topic}
        onChange={(e) => setTopic(e.target.value)}
        style={{ width: '100%', padding: 8, fontSize: 16, marginBottom: 12 }}
      />
      <button onClick={generate} disabled={busy} style={{ padding: '8px 16px', fontSize: 16 }}>
        {busy ? 'Generating…' : 'Generate poll'}
      </button>
      <pre style={{ background: '#f4f4f4', padding: 16, marginTop: 24, overflow: 'auto' }}>
        {out || '(agent output will appear here)'}
      </pre>
    </main>
  );
}
