"""
SAF Gym — FastAPI Workout Plan Generator
========================================
RAG pipeline: similarity search over fitness_dataset_v4.json → LLM → validated plan

Run locally:
    uvicorn main:app --reload --port 8000

Environment variables (set in .env or your cloud dashboard):
    DATASET_PATH      — absolute path to fitness_dataset_v4.json (local dev only)
    ANTHROPIC_API_KEY — console.anthropic.com
    GEMINI_API_KEY    — aistudio.google.com (free)
    GROQ_API_KEY      — console.groq.com (free)
    CEREBRAS_API_KEY  — cloud.cerebras.ai (free)
    OPENROUTER_API_KEY— openrouter.ai (free)
    MISTRAL_API_KEY   — console.mistral.ai (free)
    TOP_K             — number of similar examples sent to LLM (default: 3)
"""

import json
import os
import re
import time
import logging
from contextlib import asynccontextmanager
from typing import Optional

import numpy as np
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator
from dotenv import load_dotenv

# ── Load .env ──────────────────────────────────────────────────────────────────
load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(levelname)s | %(message)s")
log = logging.getLogger("saf")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — API KEYS
# ══════════════════════════════════════════════════════════════════════════════
# ⚠️  TO UPDATE A KEY: change it in your cloud dashboard's environment variables
#     (Render → Environment, Railway → Variables) OR in the .env file locally.
#     Never hardcode keys here in production.

API_KEYS = {
    "anthropic":   os.getenv("ANTHROPIC_API_KEY", ""),
    "gemini":      os.getenv("GEMINI_API_KEY", ""),
    "groq":        os.getenv("GROQ_API_KEY", ""),
    "cerebras":    os.getenv("CEREBRAS_API_KEY", ""),
    "openrouter":  os.getenv("OPENROUTER_API_KEY", ""),
    "mistral":     os.getenv("MISTRAL_API_KEY", ""),
}

# LLM provider attempt order — first available key wins, rest are fallbacks
PROVIDER_ORDER = ["anthropic", "gemini", "groq", "cerebras", "openrouter", "mistral"]

# Number of similar dataset examples to send to the LLM as few-shot context
TOP_K = int(os.getenv("TOP_K", "3"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — DATASET
# ══════════════════════════════════════════════════════════════════════════════

DATASET: list = []
DATASET_VECTORS: np.ndarray | None = None

GOAL_MAP       = {"lose_weight": 0, "maintain": 1, "gain_muscle": 2, "athletic": 3,
                  "weight_loss": 0, "hypertrophy": 2, "strength": 2}
EXPERIENCE_MAP = {"beginner": 0, "intermediate": 1, "advanced": 2}
GENDER_MAP     = {"female": 0, "male": 1, "other": 0.5}
INJURY_MAP     = {"none": 0, "knee_pain": 1, "back_pain": 2,
                  "shoulder_pain": 3, "wrist_pain": 4}


def _input_to_vector(inp: dict) -> np.ndarray:
    """Convert a user profile dict to a 9-dim normalized feature vector."""
    return np.array([
        inp.get("age", 25)         / 60.0,
        GENDER_MAP.get(inp.get("gender", "male"), 0.5),
        inp.get("height_cm", 170)  / 220.0,
        inp.get("weight_kg", 70)   / 150.0,
        inp.get("bmi", 22)         / 40.0,
        GOAL_MAP.get(inp.get("goal", "gain_muscle"), 2)             / 3.0,
        EXPERIENCE_MAP.get(inp.get("experience", "beginner"), 0)    / 2.0,
        inp.get("training_days", 3) / 7.0,
        INJURY_MAP.get(inp.get("injuries", "none"), 0)              / 4.0,
    ], dtype=float)


def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-8))


def _find_similar(user_input: dict, top_k: int = TOP_K) -> list:
    """Return top_k most similar samples from the pre-loaded dataset."""
    query_vec = _input_to_vector(user_input)
    scores = [_cosine_similarity(query_vec, dv) for dv in DATASET_VECTORS]
    top_indices = np.argsort(scores)[::-1][:top_k]
    return [
        {"similarity": round(scores[i], 3), "sample": DATASET[i]}
        for i in top_indices
    ]


def _load_dataset() -> None:
    """Load the dataset JSON and pre-compute feature vectors at startup."""
    global DATASET, DATASET_VECTORS

    # Try env var first (cloud), then the path next to this file, then the
    # original development path inside the Flutter project.
    candidates = [
        os.getenv("DATASET_PATH", ""),
        os.path.join(os.path.dirname(__file__), "fitness_dataset_v4.json"),
        r"d:\Slim and fit\saf_gym_app\Final_model\fitness_dataset_v4.json",
    ]

    for path in candidates:
        if path and os.path.isfile(path):
            log.info(f"Loading dataset from: {path}")
            with open(path, encoding="utf-8") as f:
                DATASET = json.load(f)
            DATASET_VECTORS = np.array(
                [_input_to_vector(s["input"]) for s in DATASET]
            )
            log.info(f"✅ Dataset loaded: {len(DATASET)} samples")
            return

    raise FileNotFoundError(
        "fitness_dataset_v4.json not found. "
        "Set DATASET_PATH env var or place the file next to main.py."
    )


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3 — PROMPT BUILDER
# ══════════════════════════════════════════════════════════════════════════════

SYSTEM_PROMPT = """You are an expert fitness coach and workout programmer.
Given a user profile, generate a personalized weekly workout plan.

CRITICAL: Respond ONLY with a valid JSON object. No explanations, no markdown, no backticks.

Required JSON structure:
{
  "workout_split": "full_body | upper_lower | push_pull_legs | bro_split",
  "weekly_program": {
    "day_1": [
      {
        "exercise": "exercise name",
        "target_muscle": "muscle group",
        "equipment": "equipment type",
        "sets": 3,
        "reps": 10
      }
    ]
  }
}

Rules:
- Always consider injuries and avoid exercises that could worsen them
- Match volume and intensity to experience level
- Number of training days must match training_days in the profile
- Use the provided examples as style reference"""


def _build_prompt(user_input: dict, similar_examples: list) -> str:
    lines = ["Here are similar user profiles and their workout plans as reference:\n"]
    for i, ex in enumerate(similar_examples, 1):
        lines.append(f"--- Example {i} (similarity: {ex['similarity']}) ---")
        lines.append(f"Input: {json.dumps(ex['sample']['input'])}")
        lines.append(f"Output: {json.dumps(ex['sample']['output'])}")
        lines.append("")
    lines.append("--- New User ---")
    lines.append(f"Input: {json.dumps(user_input)}")
    lines.append("\nGenerate the workout plan JSON for this user:")
    return "\n".join(lines)


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — LLM PROVIDERS
# ══════════════════════════════════════════════════════════════════════════════
# ⚠️  TO CHANGE A MODEL: find the provider section below and update the model name.

OPENAI_COMPATIBLE = {
    # ⚠️ GROQ model — update here to change the model
    "groq":       {"base_url": "https://api.groq.com/openai/v1",
                   "model":    "llama-3.3-70b-versatile"},
    # ⚠️ CEREBRAS model — update here to change the model
    "cerebras":   {"base_url": "https://api.cerebras.ai/v1",
                   "model":    "llama-3.3-70b"},
    # ⚠️ OPENROUTER model — update here to change the model
    "openrouter": {"base_url": "https://openrouter.ai/api/v1",
                   "model":    "meta-llama/llama-3.3-70b-instruct:free"},
    # ⚠️ MISTRAL model — update here to change the model
    "mistral":    {"base_url": "https://api.mistral.ai/v1",
                   "model":    "mistral-small-latest"},
}


def _parse_json_response(text: str) -> dict:
    """Extract and parse JSON from LLM response, handles markdown code fences."""
    text = re.sub(r"```(?:json)?\n?", "", text).strip()
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match:
        return json.loads(match.group())
    raise ValueError(f"No valid JSON found in response: {text[:200]}")


def _call_anthropic(system: str, user: str) -> str:
    """Call Anthropic Claude."""
    import anthropic
    # ⚠️ ANTHROPIC model — update here to change the model
    client = anthropic.Anthropic(api_key=API_KEYS["anthropic"])
    msg = client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=2000,
        system=system,
        messages=[{"role": "user", "content": user}],
    )
    return msg.content[0].text


def _call_gemini(system: str, user: str) -> str:
    """Call Google Gemini via native SDK."""
    import google.generativeai as genai
    genai.configure(api_key=API_KEYS["gemini"])
    # ⚠️ GEMINI model — update here to change the model
    model = genai.GenerativeModel(
        model_name="gemini-2.5-flash",
        system_instruction=system,
        generation_config={"response_mime_type": "application/json"},
    )
    response = model.generate_content(user)
    return response.text


def _call_openai_compatible(provider: str, system: str, user: str) -> str:
    """Call Groq / Cerebras / OpenRouter / Mistral (all OpenAI-compatible)."""
    from openai import OpenAI
    cfg = OPENAI_COMPATIBLE[provider]
    client = OpenAI(api_key=API_KEYS[provider], base_url=cfg["base_url"])
    response = client.chat.completions.create(
        model=cfg["model"],
        messages=[
            {"role": "system", "content": system},
            {"role": "user",   "content": user},
        ],
        response_format={"type": "json_object"},
        max_tokens=2000,
    )
    return response.choices[0].message.content


def _call_llm_with_fallback(system: str, user: str) -> tuple[dict, str]:
    """
    Try each provider in PROVIDER_ORDER until one succeeds.
    Returns (parsed_json_dict, provider_name_used).
    """
    errors = []
    for provider in PROVIDER_ORDER:
        key = API_KEYS.get(provider, "").strip()
        if not key:
            continue
        try:
            log.info(f"  ⏳ Trying {provider}...")
            if provider == "anthropic":
                raw = _call_anthropic(system, user)
            elif provider == "gemini":
                raw = _call_gemini(system, user)
            else:
                raw = _call_openai_compatible(provider, system, user)
            result = _parse_json_response(raw)
            log.info(f"  ✅ Success with {provider}")
            return result, provider
        except Exception as e:
            log.warning(f"  ❌ {provider} failed: {e}")
            errors.append(f"{provider}: {e}")

    raise RuntimeError("All LLM providers failed:\n" + "\n".join(errors))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5 — PYDANTIC MODELS (request / response)
# ══════════════════════════════════════════════════════════════════════════════

class PlanRequest(BaseModel):
    age:           int
    gender:        str        # "male" | "female" | "other"
    height_cm:     float
    weight_kg:     float
    bmi:           float
    goal:          str        # "gain_muscle" | "lose_weight" | "strength" | "maintain"
    experience:    str        # "beginner" | "intermediate" | "advanced"
    training_days: int        # 1–7
    injuries:      str = "none"
    # Optional: preferred LLM provider to try first
    preferred_provider: Optional[str] = None


class ExerciseOut(BaseModel):
    exercise:      str
    target_muscle: str
    equipment:     str
    sets:          int
    reps:          int

    @field_validator("sets", "reps")
    @classmethod
    def positive(cls, v: int) -> int:
        assert v > 0, "must be > 0"
        return v


class PlanResponse(BaseModel):
    workout_split:  str
    weekly_program: dict[str, list[ExerciseOut]]
    meta:           dict


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 6 — FASTAPI APP
# ══════════════════════════════════════════════════════════════════════════════

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load dataset once when the server starts."""
    _load_dataset()
    available = [k for k, v in API_KEYS.items() if v.strip()]
    log.info(f"🔑 Available LLM providers: {available or 'NONE — add API keys!'}")
    yield  # server runs here
    log.info("Server shutting down.")


app = FastAPI(
    title="SAF Gym — Workout Plan Generator",
    description="RAG-powered personalized workout plan API",
    version="1.0.0",
    lifespan=lifespan,
)

# Allow requests from the Flutter app (any origin in dev, tighten in prod)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {
        "status": "ok",
        "dataset_samples": len(DATASET),
        "available_providers": [k for k, v in API_KEYS.items() if v.strip()],
    }


@app.get("/health")
def health():
    return {"status": "healthy", "dataset_loaded": len(DATASET) > 0}


@app.post("/generate-plan", response_model=PlanResponse)
def generate_plan(req: PlanRequest):
    """
    Generate a personalized workout plan for the given user profile.

    Steps:
      1. Find top-K similar profiles in the dataset (cosine similarity)
      2. Build a few-shot prompt with those examples
      3. Call an LLM (with automatic fallback across providers)
      4. Validate and return the structured plan
    """
    if DATASET_VECTORS is None or len(DATASET) == 0:
        raise HTTPException(status_code=503, detail="Dataset not loaded")

    t0 = time.perf_counter()

    user_input = {
        "age":           req.age,
        "gender":        req.gender.lower(),
        "height_cm":     req.height_cm,
        "weight_kg":     req.weight_kg,
        "bmi":           req.bmi,
        "goal":          req.goal.lower(),
        "experience":    req.experience.lower(),
        "training_days": req.training_days,
        "injuries":      req.injuries.lower(),
    }

    log.info(f"🏋️ Generating plan for: {user_input}")

    # Step 1: Similarity search
    similar = _find_similar(user_input, top_k=TOP_K)
    log.info(f"📊 Top similarities: {[s['similarity'] for s in similar]}")

    # Step 2: Build prompt
    prompt = _build_prompt(user_input, similar)

    # Step 3: Call LLM
    try:
        raw_plan, provider_used = _call_llm_with_fallback(SYSTEM_PROMPT, prompt)
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))

    # Step 4: Validate & shape response
    try:
        validated = PlanResponse(
            workout_split=raw_plan["workout_split"],
            weekly_program=raw_plan["weekly_program"],
            meta={
                "provider_used": provider_used,
                "top_k_similarities": [s["similarity"] for s in similar],
                "generation_ms": round((time.perf_counter() - t0) * 1000),
            },
        )
    except Exception as e:
        log.warning(f"⚠️ Validation issue, returning raw: {e}")
        # Return raw plan even if validation partially fails
        return PlanResponse(
            workout_split=raw_plan.get("workout_split", "full_body"),
            weekly_program=raw_plan.get("weekly_program", {}),
            meta={
                "provider_used": provider_used,
                "validation_warning": str(e),
                "generation_ms": round((time.perf_counter() - t0) * 1000),
            },
        )

    log.info(
        f"✅ Plan ready | split={validated.workout_split} | "
        f"days={list(validated.weekly_program.keys())} | "
        f"provider={provider_used}"
    )
    return validated
