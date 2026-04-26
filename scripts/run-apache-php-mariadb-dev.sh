#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOTSTRAP_BIN="$ROOT_DIR/bootstrap.sh"
CONFIG_FILE="$ROOT_DIR/configs/apache-php-mariadb-phpmyadmin-node.env"

if [[ ! -x "$BOOTSTRAP_BIN" ]]; then
  printf 'bootstrap script not found or not executable: %s\n' "$BOOTSTRAP_BIN" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  printf 'config file not found: %s\n' "$CONFIG_FILE" >&2
  exit 1
fi

ARGS=(
  --config "$CONFIG_FILE"
  --non-interactive
  --no-dry-run
  --from 50-webservers.sh
  --until 80-verify.sh
  --apply-dev-presets yes
)

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  exec sudo -E "$BOOTSTRAP_BIN" "${ARGS[@]}" "$@"
fi

exec "$BOOTSTRAP_BIN" "${ARGS[@]}" "$@"
