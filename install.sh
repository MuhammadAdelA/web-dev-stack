#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DEFAULT="MuhammadAdelA/web-dev-stack"
REPO="${REPO:-$REPO_DEFAULT}"
REF="${REF:-main}"

ARCHIVE_URL="https://codeload.github.com/${REPO}/tar.gz/refs/heads/${REF}"
WORK_DIR="$(mktemp -d -t web-dev-bootstrap.XXXXXXXX)"
ARCHIVE_PATH="$WORK_DIR/kit.tgz"
KIT_DIR="$WORK_DIR/kit"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

log() {
  printf '[installer] %s\n' "$*" >&2
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf '[installer] missing required command: %s\n' "$1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd tar
need_cmd mktemp

log "Downloading ${REPO}@${REF}"
curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_PATH"

mkdir -p "$KIT_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$KIT_DIR" --strip-components=1

cd "$KIT_DIR"
[[ -f bootstrap.sh ]] || {
  log "bootstrap.sh not found in downloaded archive"
  exit 1
}
chmod +x bootstrap.sh

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  need_cmd sudo
  log "Running bootstrap with sudo"
  exec sudo -E ./bootstrap.sh "$@"
fi

log "Running bootstrap as root"
exec ./bootstrap.sh "$@"
