# Familiar's Call — Daily API (legacy)

> **Deprecated:** Use **Supabase** instead — see [`../supabase/README.md`](../supabase/README.md).  
> This Python server is kept for reference and local experiments only.

Small self-hosted backend for **UTC-midnight daily resets**. The game client used to call this when `data/backend_config.json` had a `base_url`. The client now uses Supabase.

## Run locally

```bash
cd server
python -m venv .venv
.venv\Scripts\activate          # Windows
pip install -r requirements.txt
uvicorn app.main:app --reload --host 127.0.0.1 --port 8080
```

Health check: `GET http://127.0.0.1:8080/health`

Enable the client in `data/backend_config.json`:

```json
{
  "enabled": true,
  "base_url": "http://127.0.0.1:8080"
}
```

## Auth (MVP)

All `/v1/daily/*` routes require header:

```
X-Profile-Id: <player profile_id from local save>
```

This matches the anonymous local profile created on first launch. Google / Apple linking can map the same `profile_id` later.

## Time rule

- `daily_day` = current **UTC** calendar date (`YYYY-MM-DD`)
- State resets automatically when UTC date changes (new row keyed by `profile_id + daily_day`)

## API contract

### `GET /v1/daily/status`

Returns authoritative daily state for the player.

**Response `200`**

```json
{
  "ok": true,
  "server_time_utc": "2026-07-01T15:04:05Z",
  "daily_day": "2026-07-01",
  "ritual_ids": ["win_2_battles", "win_field_nature", "win_with_burn"],
  "ritual_completed": {
    "win_2_battles": false,
    "win_field_nature": false,
    "win_with_burn": false
  },
  "daily_battle_wins": 0,
  "pack_claimed": false,
  "dust_reward": 150
}
```

### `POST /v1/daily/claim-pack`

Marks today's free page as claimed. Client rolls the familiar locally **after** a successful response.

**Response `200`** — same shape as `/daily/status`, with `pack_claimed: true`

**Response `409`** — already claimed today

### `POST /v1/daily/record-battle-win`

Increments server battle-win counter for today's rituals (e.g. `win_2_battles`).

**Response `200`** — status payload with updated `daily_battle_wins`

### `POST /v1/daily/complete-ritual`

**Body**

```json
{ "ritual_id": "win_field_nature" }
```

**Response `200`**

```json
{
  "ok": true,
  "ritual_id": "win_field_nature",
  "dust_granted": 150,
  "...": "full /daily/status fields"
}
```

**Response `400`** — ritual not in today's list  
**Response `409`** — already completed

## Client cache fields (`GameState`)

| Field | Role |
|-------|------|
| `daily_ritual_date` | Cached `daily_day` from server |
| `daily_ritual_ids` | Cached ritual list |
| `daily_ritual_completed` | Cached completion map |
| `daily_battle_wins` | Cached win count |
| `daily_free_page_claimed` | Cached `pack_claimed` |
| `daily_cache_day` | Last successfully synced UTC day |
| `daily_server_online` | Runtime only — `true` after last sync succeeded |

Local `user://save.json` is a **cache** for offline display. When the backend is enabled, pack claims and ritual rewards require a successful server call.

## HTTPS deploy (Fly.io)

Fly provides free-tier hosting with automatic HTTPS. The app runs in Docker with a persistent volume for SQLite.

### One-time setup

1. Install the Fly CLI: [fly.io/docs/hands-on/install-flyctl](https://fly.io/docs/hands-on/install-flyctl/)
2. Log in: `fly auth login`
3. (Optional) Change the app name in `server/fly.toml` (`app = "..."`) — must be globally unique on Fly.
4. From the **project root**, run:
   ```bat
   server\setup_fly.bat
   ```
   This creates the Fly app and a 1 GB volume for the database.

   Edit `app = "..."` in `server/fly.toml` first if you want a custom name (must be unique on Fly).

### Deploy / update

From the project root:

```bat
server\deploy_fly.bat
```

Or on macOS/Linux:

```bash
chmod +x server/deploy_fly.sh
./server/deploy_fly.sh
```

First deploy builds the Docker image (includes `server/` + `data/` JSON) and starts the machine.

**Verify:** open `https://<your-app-name>.fly.dev/health` — expect `{"status":"ok"}`.

### Point the game at production

In-game (debug build): **Settings → Developer → Backend URL** → set:

```text
https://<your-app-name>.fly.dev
```

Turn on **Server dailies enabled**, then **Sync**.

Or set defaults in `data/backend_config.json` for release builds:

```json
{
  "enabled": true,
  "base_url": "https://your-app-name.fly.dev"
}
```

Use `https://` only — Fly redirects HTTP to HTTPS automatically (`force_https` in `fly.toml`).

### Files

| File | Purpose |
|------|---------|
| `server/Dockerfile` | Production image |
| `server/fly.toml` | Fly app config, HTTPS, health check, volume mount |
| `server/setup_fly.bat` | One-time Fly app + volume creation |
| `server/deploy_fly.bat` | Build and deploy from Windows |
| `server/deploy_fly.sh` | Build and deploy from macOS/Linux |
| `server/render.yaml` | Optional [Render](https://render.com) blueprint (also HTTPS) |

### Environment variables (production)

| Variable | Default in Docker | Purpose |
|----------|-------------------|---------|
| `FC_DATA_DIR` | `/app/data` | `daily_rituals.json`, `economy_config.json` |
| `FC_DB_PATH` | `/data/familiarscall.db` | SQLite on persistent volume |
| `PORT` | `8080` | HTTP port (Fly sets this internally) |

### Alternative: Render

1. Push the repo to GitHub.
2. In Render: **New → Blueprint** and select `server/render.yaml`.
3. Render assigns an `https://….onrender.com` URL with TLS.
4. Set that URL as the game `base_url`.

### VPS / manual Docker

From the **project root**:

```bash
docker build -f server/Dockerfile -t familiarscall-daily .
docker run -p 8080:8080 -v fc_daily_data:/data familiarscall-daily
```

Put **Caddy** or **nginx** in front for TLS on your domain.

Optional next steps: HMAC request signing, platform account linking, server-side battle verification, cloud save sync.
