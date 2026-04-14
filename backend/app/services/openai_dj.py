import httpx
from fastapi import HTTPException, status

from app.core.config import settings
from app.schemas.ai import DJScriptRequest


class OpenAIDJService:
    model = "gpt-4o-mini"
    endpoint = "https://api.openai.com/v1/chat/completions"

    @classmethod
    async def generate_script(cls, payload: DJScriptRequest) -> str:
        if not settings.OPENAI_API_KEY:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="AI DJ is not configured on the server",
            )

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                cls.endpoint,
                headers={
                    "Authorization": f"Bearer {settings.OPENAI_API_KEY}",
                    "Content-Type": "application/json",
                },
                json=cls._build_request_body(payload),
            )

        if response.status_code != 200:
            detail = response.text or "OpenAI request failed"
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Failed to generate AI DJ script: {detail}",
            )

        try:
            content = response.json()["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="OpenAI returned an unexpected response",
            ) from exc

        return content.replace("\"", "").strip()

    @classmethod
    def _build_request_body(cls, payload: DJScriptRequest) -> dict:
        next_song_instruction = cls._next_song_instruction(payload)
        recent_scripts_context = cls._recent_scripts_context(payload.recent_scripts)

        system_prompt = f"""
You are an energetic, extremely concise, highly motivating AI Radio DJ for a runner.
You are interrupting their music mid-workout to give them a brief update.

RULES:
- Keep it strictly under 2 sentences. Max 25 words.
- Be punchy, naturally conversational, and high-energy.
- Do not sound like a robot.
- Reference their current state if relevant (e.g., if their HR is too high, tell them to breathe).
- CRITICAL: You MUST use completely different wording, sentence structures, and phrases each time.
- NEVER repeat or closely paraphrase any of your recent scripts listed below.
- Vary your vocabulary, tone, and energy level. Sometimes be hype, sometimes be chill, sometimes be funny.
- Do NOT start with the same opening word as any recent script.

YOUR RECENT SCRIPTS (do NOT repeat these or say anything similar):
{recent_scripts_context}
""".strip()

        user_prompt = f"""
Runner's Name: {payload.runner_name}
Current Heart Rate: {payload.current_heart_rate} BPM
Elapsed Workout Time: {payload.elapsed_time_seconds // 60} minutes
Currently Playing: "{payload.current_song_title}" by {payload.current_song_artist} ({payload.current_song_elapsed_seconds}s / {payload.current_song_duration_seconds}s into the song)
Trigger Reason: {payload.trigger_reason}
{next_song_instruction}

Generate the 1-2 sentence DJ script to say to the runner right now. Use their name every once in a while to make it personal. Make it sound completely different from the recent scripts above.
""".strip()

        return {
            "model": cls.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "temperature": 1.0,
            "max_tokens": 60,
        }

    @staticmethod
    def _recent_scripts_context(recent_scripts: list[str]) -> str:
        if not recent_scripts:
            return "None yet - this is the first time you're speaking!"

        return "\n".join(
            f'{index + 1}. "{script}"'
            for index, script in enumerate(recent_scripts[-10:])
        )

    @staticmethod
    def _next_song_instruction(payload: DJScriptRequest) -> str:
        if (
            payload.trigger_reason == "song_transition"
            and payload.next_song_title
            and payload.next_song_artist
        ):
            return (
                f'Next Song Queuing Up: "{payload.next_song_title}" by {payload.next_song_artist}. '
                "You SHOULD mention or tease this upcoming track."
            )

        return "Do NOT mention any upcoming or next song. Focus only on their current state and motivation."
