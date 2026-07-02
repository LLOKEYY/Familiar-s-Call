from __future__ import annotations

from typing import Any

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from . import db
from .daily import dust_reward, pick_rituals, utc_day_key, utc_now_iso


app = FastAPI(title="Familiar's Call Daily API", version="1.0.0")


class RitualCompleteBody(BaseModel):
    ritual_id: str = Field(min_length=1)


def _require_profile_id(profile_id: str | None) -> str:
    cleaned = (profile_id or "").strip()
    if len(cleaned) < 8:
        raise HTTPException(status_code=401, detail="Missing or invalid X-Profile-Id header")
    return cleaned


def _daily_payload(profile_id: str) -> dict[str, Any]:
    daily_day = utc_day_key()
    ritual_ids = pick_rituals(daily_day)
    state = db.get_daily_state(profile_id, daily_day, ritual_ids)
    return {
        "ok": True,
        "server_time_utc": utc_now_iso(),
        "daily_day": daily_day,
        "ritual_ids": state["ritual_ids"],
        "ritual_completed": state["ritual_completed"],
        "daily_battle_wins": state["daily_battle_wins"],
        "pack_claimed": state["pack_claimed"],
        "dust_reward": dust_reward(),
    }


@app.on_event("startup")
def on_startup() -> None:
    db.init_db()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/v1/daily/status")
def daily_status(x_profile_id: str | None = Header(default=None)) -> dict[str, Any]:
    profile_id = _require_profile_id(x_profile_id)
    return _daily_payload(profile_id)


@app.post("/v1/daily/claim-pack")
def claim_pack(x_profile_id: str | None = Header(default=None)) -> dict[str, Any]:
    profile_id = _require_profile_id(x_profile_id)
    daily_day = utc_day_key()
    ritual_ids = pick_rituals(daily_day)
    state = db.get_daily_state(profile_id, daily_day, ritual_ids)
    if state["pack_claimed"]:
        raise HTTPException(status_code=409, detail="Daily pack already claimed")

    db.save_daily_state(
        profile_id,
        daily_day,
        state["ritual_ids"],
        state["ritual_completed"],
        state["daily_battle_wins"],
        True,
    )
    payload = _daily_payload(profile_id)
    payload["message"] = "Daily pack claimed"
    return payload


@app.post("/v1/daily/record-battle-win")
def record_battle_win(x_profile_id: str | None = Header(default=None)) -> dict[str, Any]:
    profile_id = _require_profile_id(x_profile_id)
    daily_day = utc_day_key()
    ritual_ids = pick_rituals(daily_day)
    state = db.get_daily_state(profile_id, daily_day, ritual_ids)
    wins = int(state["daily_battle_wins"]) + 1
    db.save_daily_state(
        profile_id,
        daily_day,
        state["ritual_ids"],
        state["ritual_completed"],
        wins,
        state["pack_claimed"],
    )
    payload = _daily_payload(profile_id)
    payload["daily_battle_wins"] = wins
    return payload


@app.post("/v1/daily/complete-ritual")
def complete_ritual(
    body: RitualCompleteBody,
    x_profile_id: str | None = Header(default=None),
) -> dict[str, Any]:
    profile_id = _require_profile_id(x_profile_id)
    daily_day = utc_day_key()
    ritual_ids = pick_rituals(daily_day)
    state = db.get_daily_state(profile_id, daily_day, ritual_ids)

    ritual_id = body.ritual_id.strip()
    if ritual_id not in state["ritual_ids"]:
        raise HTTPException(status_code=400, detail="Ritual not active today")

    completed: dict[str, bool] = dict(state["ritual_completed"])
    if completed.get(ritual_id, False):
        raise HTTPException(status_code=409, detail="Ritual already completed")

    completed[ritual_id] = True
    db.save_daily_state(
        profile_id,
        daily_day,
        state["ritual_ids"],
        completed,
        state["daily_battle_wins"],
        state["pack_claimed"],
    )
    payload = _daily_payload(profile_id)
    payload["ritual_id"] = ritual_id
    payload["dust_granted"] = dust_reward()
    return payload
