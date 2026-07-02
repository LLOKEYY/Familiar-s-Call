#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="familiarscall-daily"

if ! command -v fly >/dev/null 2>&1; then
  echo "Install flyctl: https://fly.io/docs/hands-on/install-flyctl/"
  echo "Then run: fly auth login"
  exit 1
fi

cd "$ROOT"
fly deploy . --config server/fly.toml

echo
echo "Deployed."
echo "Health:  https://${APP_NAME}.fly.dev/health"
echo "Game URL: https://${APP_NAME}.fly.dev"
