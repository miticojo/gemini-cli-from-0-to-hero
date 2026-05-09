// Reference target for slot 5b mega-prompt output.
// Anonymous auth: signs the user in transparently on import, no Google popup.
//
// Why this pattern works for the workshop:
//   - Zero OAuth wiring (no authorized domains for Cloud Shell preview URL).
//   - Persistent uid per browser via setPersistence(browserLocalPersistence).
//   - Firestore rules accept request.auth != null — so a future Google SSO
//     upgrade is purely a frontend swap, no rules change.

import { initializeApp } from 'firebase/app';
import {
  getAuth,
  signInAnonymously,
  setPersistence,
  browserLocalPersistence,
} from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};

if (!firebaseConfig.apiKey) {
  throw new Error(
    'VITE_FIREBASE_API_KEY missing. Run `make firebase-config` to populate frontend/.env',
  );
}

export const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

// Sign in anonymously on import. Persistence keeps the same uid across reloads.
setPersistence(auth, browserLocalPersistence)
  .then(() => signInAnonymously(auth))
  .catch((err) => {
    console.error('Anonymous sign-in failed:', err);
  });
