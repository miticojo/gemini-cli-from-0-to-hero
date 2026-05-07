# Copyright 2026 Google LLC
# Licensed under the Apache License, Version 2.0
"""Workshop Pulse — insight-agent root.

Hub orchestrator with two sub-agents:
  - question_generator: brief -> poll JSON
  - sentiment_insight:  votes -> {mood, themes, summary}

Model: Vertex AI gemini-3.1-pro-preview (configurable via env).
"""

from __future__ import annotations

import json
import os
from pathlib import Path

import google.auth
from google.adk.agents import Agent
from google.adk.apps import App
from google.adk.models import Gemini
from google.genai import types


def _load_dotenv() -> None:
    """Tiny dotenv loader; avoids extra dependency."""
    env_file = Path(__file__).resolve().parents[1] / ".env"
    if not env_file.exists():
        return
    for line in env_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        os.environ.setdefault(key.strip(), val.strip().strip('"').strip("'"))


_load_dotenv()

# Vertex AI ADC bootstrap
_, _project = google.auth.default()
os.environ.setdefault("GOOGLE_CLOUD_PROJECT", _project or "")
os.environ.setdefault("GOOGLE_CLOUD_LOCATION", "global")
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "True"

MODEL_ID = os.environ.get("GEMINI_MODEL", "gemini-3.1-pro-preview")


def _model() -> Gemini:
    return Gemini(
        model=MODEL_ID,
        retry_options=types.HttpRetryOptions(attempts=3),
    )


# --------------------------------------------------------------------------- #
# Sub-agent: question_generator
# --------------------------------------------------------------------------- #
QUESTION_GEN_INSTRUCTION = """\
You design a concise feedback poll for a workshop.

Inputs you receive in the user message (JSON):
  - workshop_topic: str
  - num_questions: int (default 4 if missing)
  - target_audience: str (default "developers")

Return ONLY valid JSON matching this schema:
{
  "poll": {
    "title": "string",
    "questions": [
      { "id": "q1", "text": "string", "type": "single|multi|open",
        "options": ["string", "..."] }
    ]
  }
}

Rules:
  - Mix question types: at least one "open", rest "single" or "multi".
  - Keep questions neutral; avoid leading wording.
  - Options 3-5 items for closed questions.
  - No preamble, no markdown fences, only the JSON object.
"""

question_generator = Agent(
    name="question_generator",
    description="Generates a balanced feedback poll JSON from a workshop brief.",
    model=_model(),
    instruction=QUESTION_GEN_INSTRUCTION,
)


# --------------------------------------------------------------------------- #
# Sub-agent: sentiment_insight
# --------------------------------------------------------------------------- #
SENTIMENT_INSTRUCTION = """\
You analyse workshop poll responses and produce an actionable insight.

Inputs (JSON in the user message):
  - workshop_id: str
  - votes: list of { userId, value, openText? }

Return ONLY valid JSON matching this schema:
{
  "mood": "positive | mixed | constructive | negative",
  "themes": ["string", "..."],
  "summary": "2-3 sentence narrative for the admin"
}

Rules:
  - Weigh openText more than closed values when deciding mood.
  - 3-5 themes, lowercase, no duplicates.
  - Summary is direct, factual, no marketing tone.
  - No preamble, no markdown fences, only the JSON object.
"""

sentiment_insight = Agent(
    name="sentiment_insight",
    description="Classifies workshop feedback votes into mood, themes, and summary.",
    model=_model(),
    instruction=SENTIMENT_INSTRUCTION,
)


# --------------------------------------------------------------------------- #
# Hub orchestrator
# --------------------------------------------------------------------------- #
ROOT_INSTRUCTION = """\
You are the Workshop Pulse insight orchestrator.

Route every request based on the `task` field in the user message:
  - task = "generate-poll"     -> delegate to question_generator
  - task = "analyze-sentiment" -> delegate to sentiment_insight

Pass through the `payload` field as the JSON input to the chosen sub-agent.
Return the sub-agent output verbatim. Never invent fields. If `task` is unknown,
return: {"error": "unknown task: <value>"}.
"""

root_agent = Agent(
    name="root_agent",
    description="Routes workshop tasks to the question_generator or sentiment_insight sub-agents.",
    model=_model(),
    instruction=ROOT_INSTRUCTION,
    sub_agents=[question_generator, sentiment_insight],
)


app = App(
    root_agent=root_agent,
    name="app",  # must match the directory name; ADK uses dir as app_name
)


# --------------------------------------------------------------------------- #
# Smoke test (run as: `python -m app.agent`)
# --------------------------------------------------------------------------- #
if __name__ == "__main__":
    sample = {
        "task": "generate-poll",
        "payload": {
            "workshop_topic": "Gemini CLI from zero to hero",
            "num_questions": 4,
            "target_audience": "developers",
        },
    }
    print(json.dumps(sample, indent=2))
    print(f"model: {MODEL_ID}")
    print(f"project: {os.environ.get('GOOGLE_CLOUD_PROJECT')}")
    print(f"location: {os.environ.get('GOOGLE_CLOUD_LOCATION')}")
