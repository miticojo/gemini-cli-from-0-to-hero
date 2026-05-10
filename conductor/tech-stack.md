# Tech Stack

- **Frontend:** Vite + React 19 + TypeScript strict
- **Auth:** Firebase **Anonymous** Auth (`signInAnonymously` on import). No Google SSO popup, no OAuth domain whitelist. Optional Google upgrade documented as homework.
- **Database:** Firestore (collections `workshops`, `polls`, `votes`)
- **AI Agent:** Google ADK Python on Vertex AI
- **Model (build-time, mega-prompts):** `gemini-3-flash-preview` (default), `gemini-3.1-pro-preview` (only `@adk-builder` Python rewrite)
- **Model (run-time, insight-agent sub-agents):** `gemini-3.1-pro-preview` for question generation + sentiment analysis
- **Location:** `global` (model), `us-central1` (deploy region)
- **Build:** `make scaffold-frontend`, `make scaffold-agent`, `make agent-dev`, `make frontend-dev`
