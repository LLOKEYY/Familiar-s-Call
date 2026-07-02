from __future__ import annotations

import json
import os
import sqlite3
from pathlib import Path
from typing import Any


def _resolve_db_path() -> Path:
    override = os.environ.get("FC_DB_PATH", "").strip()
    if override:
        return Path(override)
    return Path(__file__).resolve().parents[1] / "familiarscall.db"


DB_PATH = _resolve_db_path()


def connect() -> sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with connect() as conn:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS players (
                profile_id TEXT PRIMARY KEY,
                created_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS daily_state (
                profile_id TEXT NOT NULL,
                daily_day TEXT NOT NULL,
                ritual_ids TEXT NOT NULL,
                ritual_completed TEXT NOT NULL,
                daily_battle_wins INTEGER NOT NULL DEFAULT 0,
                pack_claimed INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (profile_id, daily_day)
            );
            """
        )


def ensure_player(profile_id: str) -> None:
    with connect() as conn:
        row = conn.execute(
            "SELECT profile_id FROM players WHERE profile_id = ?",
            (profile_id,),
        ).fetchone()
        if row is None:
            conn.execute(
                "INSERT INTO players (profile_id, created_at) VALUES (?, datetime('now'))",
                (profile_id,),
            )
            conn.commit()


def get_daily_state(profile_id: str, daily_day: str, ritual_ids: list[str]) -> dict[str, Any]:
    ensure_player(profile_id)
    with connect() as conn:
        row = conn.execute(
            """
            SELECT ritual_ids, ritual_completed, daily_battle_wins, pack_claimed
            FROM daily_state
            WHERE profile_id = ? AND daily_day = ?
            """,
            (profile_id, daily_day),
        ).fetchone()
        if row is None:
            completed = {ritual_id: False for ritual_id in ritual_ids}
            conn.execute(
                """
                INSERT INTO daily_state (
                    profile_id, daily_day, ritual_ids, ritual_completed,
                    daily_battle_wins, pack_claimed
                ) VALUES (?, ?, ?, ?, 0, 0)
                """,
                (
                    profile_id,
                    daily_day,
                    json.dumps(ritual_ids),
                    json.dumps(completed),
                ),
            )
            conn.commit()
            return {
                "ritual_ids": ritual_ids,
                "ritual_completed": completed,
                "daily_battle_wins": 0,
                "pack_claimed": False,
            }

        stored_ids = json.loads(row["ritual_ids"])
        if stored_ids != ritual_ids:
            completed = {ritual_id: False for ritual_id in ritual_ids}
            conn.execute(
                """
                UPDATE daily_state
                SET ritual_ids = ?, ritual_completed = ?, daily_battle_wins = 0, pack_claimed = 0
                WHERE profile_id = ? AND daily_day = ?
                """,
                (json.dumps(ritual_ids), json.dumps(completed), profile_id, daily_day),
            )
            conn.commit()
            return {
                "ritual_ids": ritual_ids,
                "ritual_completed": completed,
                "daily_battle_wins": 0,
                "pack_claimed": False,
            }

        return {
            "ritual_ids": stored_ids,
            "ritual_completed": json.loads(row["ritual_completed"]),
            "daily_battle_wins": int(row["daily_battle_wins"]),
            "pack_claimed": bool(row["pack_claimed"]),
        }


def save_daily_state(
    profile_id: str,
    daily_day: str,
    ritual_ids: list[str],
    ritual_completed: dict[str, bool],
    daily_battle_wins: int,
    pack_claimed: bool,
) -> None:
    with connect() as conn:
        conn.execute(
            """
            INSERT INTO daily_state (
                profile_id, daily_day, ritual_ids, ritual_completed,
                daily_battle_wins, pack_claimed
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(profile_id, daily_day) DO UPDATE SET
                ritual_ids = excluded.ritual_ids,
                ritual_completed = excluded.ritual_completed,
                daily_battle_wins = excluded.daily_battle_wins,
                pack_claimed = excluded.pack_claimed
            """,
            (
                profile_id,
                daily_day,
                json.dumps(ritual_ids),
                json.dumps(ritual_completed),
                daily_battle_wins,
                1 if pack_claimed else 0,
            ),
        )
        conn.commit()
