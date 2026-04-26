#!/usr/bin/env bash
set -Eeuo pipefail

escape_glob_pattern() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\*/\\*}"
  value="${value//\?/\\?}"
  value="${value//\[/\\[}"
  value="${value//\]/\\]}"
  printf '%s' "$value"
}

redact_sensitive() {
  local text="$*"
  local redacted="$text"
  local secret pattern

  if [[ -n "${DB_DEV_PASSWORD:-}" ]]; then
    secret="$DB_DEV_PASSWORD"
    pattern="$(escape_glob_pattern "$secret")"
    redacted="${redacted//$pattern/<redacted>}"
  fi

  printf '%s' "$redacted" | sed -E \
    -e 's/(DB_DEV_PASSWORD=)[^[:space:]]+/\1<redacted>/g' \
    -e 's/(PGPASSWORD=")([^"]*)(")/\1<redacted>\3/g' \
    -e "s/(PGPASSWORD=')([^']*)(')/\1<redacted>\3/g" \
    -e 's/(PGPASSWORD=)[^[:space:]]+/\1<redacted>/g' \
    -e 's/(-p")([^"]*)(")/\1<redacted>\3/g' \
    -e "s/(-p')([^']*)(')/\1<redacted>\3/g" \
    -e 's/(^|[[:space:]])(-p)[^[:space:]]+/\1\2<redacted>/g'
}

log_raw() {
  local level="$1"; shift
  local msg="$*"
  local ts
  msg="$(redact_sensitive "$msg")"
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  if [[ -n "${LOG_FILE:-}" ]]; then
    printf '[%s] [%s] %s\n' "$ts" "$level" "$msg" | tee -a "$LOG_FILE" >&2
  else
    printf '[%s] [%s] %s\n' "$ts" "$level" "$msg" >&2
  fi
}

log_info() { log_raw INFO "$*"; }
log_warn() { log_raw WARN "$*"; }
log_error() { log_raw ERROR "$*"; }
log_success() { log_raw OK "$*"; }

die() {
  log_error "$*"
  exit 1
}

on_error() {
  local line="$1" cmd="$2"
  log_error "Failure at line $line: $cmd"
}

record_summary() {
  local component="$1" status="$2" detail="$3"
  component="$(redact_sensitive "$component")"
  status="$(redact_sensitive "$status")"
  detail="$(redact_sensitive "$detail")"
  printf '%s\t%s\t%s\n' "$component" "$status" "$detail" >> "$SUMMARY_FILE"
  printf '{"component":"%s","status":"%s","detail":"%s"}\n' \
    "$(json_escape "$component")" "$(json_escape "$status")" "$(json_escape "$detail")" >> "$MACHINE_SUMMARY_FILE"
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

acquire_lock() {
  local lock_file="${LOCK_FILE:-}"
  [[ -n "$lock_file" ]] || die "LOCK_FILE is not set; initialize bootstrap paths before acquiring the lock"
  exec 9>"$lock_file"
  if ! flock -n 9; then
    die "Another bootstrap process is already running. Lock: $lock_file"
  fi
}

release_lock() {
  flock -u 9 || true
}

run_cmd() {
  local description="$1"; shift
  log_info "$description"
  if [[ "$BOOTSTRAP_DRY_RUN" == "yes" ]]; then
    log_info "DRY-RUN: $*"
    return 0
  fi
  "$@" >> "$LOG_FILE" 2>&1
}

run_bash() {
  local description="$1"; shift
  local script="$*"
  log_info "$description"
  if [[ "$BOOTSTRAP_DRY_RUN" == "yes" ]]; then
    log_info "DRY-RUN bash: $script"
    return 0
  fi
  bash -lc "$script" >> "$LOG_FILE" 2>&1
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run this script as root or with sudo"
}

require_ubuntu() {
  [[ -f /etc/os-release ]] || die "/etc/os-release not found"
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    if [[ "${BOOTSTRAP_DRY_RUN:-no}" == "yes" ]]; then
      log_warn "Non-Ubuntu environment detected (${ID:-unknown}); allowing dry-run for test purposes only"
      return 0
    fi
    die "This bootstrap currently supports Ubuntu only"
  fi
}

ubuntu_version_at_least() {
  local minimum="$1"
  local current
  current="$(. /etc/os-release && printf '%s' "$VERSION_ID")"
  dpkg --compare-versions "$current" ge "$minimum"
}

is_yes() {
  case "${1:-}" in
    yes|y|Y|true|TRUE|1|on) return 0 ;;
    *) return 1 ;;
  esac
}

append_state() {
  printf '%s=%s\n' "$1" "$2" >> "$STATE_FILE"
}

already_in_state() {
  grep -qE "^$1=$2$" "$STATE_FILE" 2>/dev/null
}

mark_done() {
  append_state "$1" "done"
}

step_done() {
  already_in_state "$1" "done"
}

skip_if_done() {
  local step_key="$1"
  if step_done "$step_key" && is_yes "$SKIP_EXISTING" && ! is_yes "$FORCE_REPAIR"; then
    log_warn "Skipping $step_key because it was already completed"
    return 0
  fi
  return 1
}

normalize_csv_spaces() {
  printf '%s' "$1" | tr ',' ' ' | xargs
}

safe_service_is_active() {
  systemctl is-active --quiet "$1" >/dev/null 2>&1
}

reload_or_restart_service() {
  local service="$1"
  run_bash "Reloading or restarting $service" "
if systemctl is-active --quiet '$service'; then
  systemctl reload '$service' || systemctl restart '$service'
else
  systemctl restart '$service'
fi
"
}

set_timezone_if_needed() {
  [[ -n "${BOOTSTRAP_TIMEZONE:-}" ]] || return 0
  run_cmd "Setting timezone to $BOOTSTRAP_TIMEZONE" timedatectl set-timezone "$BOOTSTRAP_TIMEZONE"
}

ensure_web_root_owned_by_dev_user() {
  if ! id "$DEV_USER" >/dev/null 2>&1; then
    log_warn "DEV_USER '$DEV_USER' does not exist; skipping /var/www ownership update"
    return 0
  fi

  run_cmd "Ensuring $DEV_USER is in www-data group" usermod -a -G www-data "$DEV_USER"
  run_bash "Setting /var/www ownership to $DEV_USER:www-data" "install -d -m 0755 /var/www && chown -R '$DEV_USER':www-data /var/www"
}

write_file_if_changed() {
  local target="$1" content="$2" mode="${3:-0644}"
  if [[ -f "$target" ]] && [[ "$(cat "$target")" == "$content" ]]; then
    return 0
  fi
  if [[ "$BOOTSTRAP_DRY_RUN" == "yes" ]]; then
    log_info "DRY-RUN write file: $target"
    return 0
  fi
  printf '%s' "$content" > "$target"
  chmod "$mode" "$target"
}
