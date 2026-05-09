// Reference target for slot 5b mega-prompt output.
// Shows the App root with router; auth happens transparently in firebase.ts.

import { StrictMode, useEffect, useState } from 'react';
import { createBrowserRouter, RouterProvider } from 'react-router-dom';
import { auth } from './lib/firebase';
import { Admin } from './routes/Admin';
import { Attendee } from './routes/Attendee';

const router = createBrowserRouter([
  { path: '/', element: <Admin /> },
  { path: '/admin', element: <Admin /> },
  { path: '/p/:workshopId', element: <Attendee /> },
]);

export function App() {
  const [uid, setUid] = useState<string | null>(null);

  useEffect(() => {
    // signInAnonymously already kicked off in firebase.ts on import.
    // We just subscribe to onAuthStateChanged to surface the uid.
    const unsub = auth.onAuthStateChanged((user) => {
      setUid(user?.uid ?? null);
    });
    return unsub;
  }, []);

  return (
    <StrictMode>
      <RouterProvider router={router} />
      {uid && (
        <div
          style={{
            position: 'fixed',
            bottom: 8,
            right: 8,
            fontFamily: 'system-ui',
            fontSize: 11,
            color: '#888',
            background: 'rgba(255,255,255,0.7)',
            padding: '2px 6px',
            borderRadius: 4,
          }}
        >
          anon-{uid.slice(-6)}
        </div>
      )}
    </StrictMode>
  );
}
