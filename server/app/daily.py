from __future__ import annotations

import hashlib
import json
import os
import random
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _data_dir() -> Path:
    override = os.environ.get("FC_DATA_DIR", "").strip()
    if override:
        return Path(override)
    return Path(__file__).resolve().parents[2] / "data"


RITUALS_PATH = _data_dir() / "daily_rituals.json"
ECONOMY_PATH = _data_dir() / "economy_config.json"


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def utc_day_key(when: datetime | None = None) -> str:
    moment = when or datetime.now(timezone.utc)
    return moment.strftime("%Y-%m-%d")


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def dust_reward() -> int:
    economy = load_json(ECONOMY_PATH)
    eco = int(economy.get("daily_ritual_dust_reward", 0))
    if eco > 0:
        return eco
    rituals = load_json(RITUALS_PATH)
    return int(rituals.get("dust_reward", 150))


def _stable_seed(value: str) -> int:
    digest = hashlib.sha256(value.encode("utf-8")).hexdigest()
    return int(digest[:8], 16)


def pick_rituals(daily_day: str) -> list[str]:
    cfg = load_json(RITUALS_PATH)
    easy = str(cfg.get("easy_ritual", "win_2_battles"))
    rotation: list[dict[str, Any]] = cfg.get("school_rotation", [])
    school_id = "win_field_pyromancy"
    if rotation:
        year, month, day = (int(part) for part in daily_day.split("-"))
        index = (year * 372 + month * 31 + day) % len(rotation)
        school_id = str(rotation[index].get("id", school_id))

    varied_pool: list[str] = [str(item) for item in cfg.get("varied_pool", [])]
    remove_ids = {easy, school_id}
    for entry in rotation:
        if isinstance(entry, dict):
            remove_ids.add(str(entry.get("id", "")))
    varied_pool = [item for item in varied_pool if item not in remove_ids]

    varied_id = easy
    if varied_pool:
        rng = random.Random(_stable_seed(f"{daily_day}:varied"))
        varied_id = rng.choice(varied_pool)
    return [easy, school_id, varied_id]


def empty_completed(ritual_ids: list[str]) -> dict[str, bool]:
    return {ritual_id: False for ritual_id in ritual_ids}
