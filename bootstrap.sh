#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BOOTSTRAP_ROOT="$SCRIPT_DIR"
export LIB_DIR="$SCRIPT_DIR/lib"
export STEPS_DIR="$SCRIPT_DIR/steps"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/input.sh"
source "$LIB_DIR/apt.sh"
source "$LIB_DIR/verify.sh"

CONFIG_FILE=""
BOOTSTRAP_ENV="${BOOTSTRAP_ENV:-}"
DRY_RUN="${BOOTSTRAP_DRY_RUN:-no}"
NON_INTERACTIVE="${BOOTSTRAP_NON_INTERACTIVE:-no}"
CLI_DRY_RUN_SET="no"
CLI_NON_INTERACTIVE_SET="no"
ONLY_STEP=""
FROM_STEP=""
UNTIL_STEP=""
LIST_ONLY="no"
FORCE_REPAIR="${FORCE_REPAIR:-no}"
SKIP_EXISTING="${SKIP_EXISTING:-yes}"

DEFAULT_STEP_ORDER=(
  "00-preflight.sh"
  "10-input.sh"
  "20-repositories.sh"
  "30-packages-base.sh"
  "40-runtimes.sh"
  "50-webservers.sh"
  "60-databases.sh"
  "70-tools.sh"
  "80-verify.sh"
  "90-summary.sh"
)

usage() {
  cat <<USAGE
Usage: ./bootstrap.sh [options]

Options:
  --config <file>       Load configuration file.
  --dry-run             Print actions without executing them.
  --non-interactive     Do not prompt; require config/env values.
  --only <step>         Run one step only.
  --from <step>         Start from a given step.
  --until <step>        Stop after a given step.
  --list                List available steps.
  -h, --help            Show this help.
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --config)
        CONFIG_FILE="${2:-}"
        [[ -n "$CONFIG_FILE" ]] || die "--config requires a file path"
        shift 2
        ;;
      --dry-run)
        DRY_RUN="yes"
        CLI_DRY_RUN_SET="yes"
        shift
        ;;
      --non-interactive)
        NON_INTERACTIVE="yes"
        CLI_NON_INTERACTIVE_SET="yes"
        shift
        ;;
      --only)
        ONLY_STEP="${2:-}"
        [[ -n "$ONLY_STEP" ]] || die "--only requires a step name"
        shift 2
        ;;
      --from)
        FROM_STEP="${2:-}"
        [[ -n "$FROM_STEP" ]] || die "--from requires a step name"
        shift 2
        ;;
      --until)
        UNTIL_STEP="${2:-}"
        [[ -n "$UNTIL_STEP" ]] || die "--until requires a step name"
        shift 2
        ;;
      --list)
        LIST_ONLY="yes"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown option: $1"
        ;;
    esac
  done
}

load_configs() {
  if [[ -n "$CONFIG_FILE" ]]; then
    [[ -f "$CONFIG_FILE" ]] || die "Config file not found: $CONFIG_FILE"
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
  fi

  if [[ -n "$BOOTSTRAP_ENV" ]]; then
    [[ -f "$BOOTSTRAP_ENV" ]] || die "BOOTSTRAP_ENV file not found: $BOOTSTRAP_ENV"
    # shellcheck disable=SC1090
    source "$BOOTSTRAP_ENV"
  fi

  if [[ "$CLI_DRY_RUN_SET" != "yes" && -n "${BOOTSTRAP_DRY_RUN:-}" ]]; then
    DRY_RUN="$BOOTSTRAP_DRY_RUN"
  fi
  if [[ "$CLI_NON_INTERACTIVE_SET" != "yes" && -n "${BOOTSTRAP_NON_INTERACTIVE:-}" ]]; then
    NON_INTERACTIVE="$BOOTSTRAP_NON_INTERACTIVE"
  fi
}

bootstrap_defaults() {
  export BOOTSTRAP_DRY_RUN="$DRY_RUN"
  export BOOTSTRAP_NON_INTERACTIVE="$NON_INTERACTIVE"
  export FORCE_REPAIR SKIP_EXISTING

  export BOOTSTRAP_NAME="${BOOTSTRAP_NAME:-web-dev-bootstrap}"
  export BOOTSTRAP_TIMEZONE="${BOOTSTRAP_TIMEZONE:-UTC}"
  export BOOTSTRAP_LOG_ROOT="${BOOTSTRAP_LOG_ROOT:-/var/log/web-dev-bootstrap}"
  export BOOTSTRAP_STATE_ROOT="${BOOTSTRAP_STATE_ROOT:-/var/lib/web-dev-bootstrap}"
  export DEV_USER="${DEV_USER:-${SUDO_USER:-${USER:-root}}}"
  export WEBSERVER="${WEBSERVER:-nginx}"
  export INSTALL_PHP="${INSTALL_PHP:-yes}"
  export PHP_VERSIONS="${PHP_VERSIONS:-8.3}"
  export PHP_DEFAULT_VERSION="${PHP_DEFAULT_VERSION:-8.3}"
  export INSTALL_COMPOSER="${INSTALL_COMPOSER:-yes}"
  export COMPOSER_DEV_USER="${COMPOSER_DEV_USER:-$DEV_USER}"
  export INSTALL_NODE="${INSTALL_NODE:-yes}"
  export NODE_MAJOR="${NODE_MAJOR:-22}"
  export INSTALL_PNPM="${INSTALL_PNPM:-yes}"
  export INSTALL_YARN="${INSTALL_YARN:-no}"
  export DB_SERVER="${DB_SERVER:-mariadb}"
  export INSTALL_POSTGRESQL="${INSTALL_POSTGRESQL:-yes}"
  export INSTALL_REDIS="${INSTALL_REDIS:-yes}"
  export INSTALL_PHPMYADMIN="${INSTALL_PHPMYADMIN:-no}"
  export PHPMYADMIN_ALIAS="${PHPMYADMIN_ALIAS:-/phpmyadmin}"
  export ENABLE_UNIVERSE="${ENABLE_UNIVERSE:-yes}"
  export ENABLE_PPA_ONDREJ_PHP="${ENABLE_PPA_ONDREJ_PHP:-yes}"
  export ENABLE_NODESOURCE="${ENABLE_NODESOURCE:-yes}"
  export PRIMARY_PHP_EXTENSIONS="${PRIMARY_PHP_EXTENSIONS:-mysql pgsql sqlite3 curl mbstring xml zip intl bcmath gd}" 

  init_paths
}

init_paths() {
  local log_root state_root ts
  ts="$(date +%Y%m%d-%H%M%S)"
  log_root="$BOOTSTRAP_LOG_ROOT"
  state_root="$BOOTSTRAP_STATE_ROOT"

  if [[ "$BOOTSTRAP_DRY_RUN" == "yes" ]]; then
    log_root="${TMPDIR:-/tmp}/web-dev-bootstrap/logs"
    state_root="${TMPDIR:-/tmp}/web-dev-bootstrap/state"
  fi

  mkdir -p "$log_root" "$state_root"
  export RUN_ID="${RUN_ID:-$ts}"
  export LOG_FILE="${LOG_FILE:-$log_root/bootstrap-$RUN_ID.log}"
  export SUMMARY_FILE="${SUMMARY_FILE:-$log_root/summary-$RUN_ID.tsv}"
  export MACHINE_SUMMARY_FILE="${MACHINE_SUMMARY_FILE:-$log_root/summary-$RUN_ID.jsonl}"
  export STATE_FILE="${STATE_FILE:-$state_root/bootstrap-$RUN_ID.state}"
  export LOCK_FILE="${LOCK_FILE:-$state_root/bootstrap.lock}"
  touch "$LOG_FILE" "$SUMMARY_FILE" "$MACHINE_SUMMARY_FILE" "$STATE_FILE"
}

print_step_list() {
  printf '%s\n' "${DEFAULT_STEP_ORDER[@]}"
}

step_exists() {
  local needle="$1"
  shift
  local step
  for step in "$@"; do
    if [[ "$step" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

select_steps() {
  local steps=("${DEFAULT_STEP_ORDER[@]}")
  local filtered=()
  local index=0
  local from_index=-1
  local until_index=-1
  local enabled=0

  if [[ -n "$ONLY_STEP" ]]; then
    step_exists "$ONLY_STEP" "${steps[@]}" || die "Unknown step for --only: $ONLY_STEP"
    SELECTED_STEPS=("$ONLY_STEP")
    return
  fi

  if [[ -n "$FROM_STEP" ]]; then
    step_exists "$FROM_STEP" "${steps[@]}" || die "Unknown step for --from: $FROM_STEP"
  fi
  if [[ -n "$UNTIL_STEP" ]]; then
    step_exists "$UNTIL_STEP" "${steps[@]}" || die "Unknown step for --until: $UNTIL_STEP"
  fi

  if [[ -n "$FROM_STEP" && -n "$UNTIL_STEP" ]]; then
    for step in "${steps[@]}"; do
      if [[ "$step" == "$FROM_STEP" ]]; then
        from_index=$index
      fi
      if [[ "$step" == "$UNTIL_STEP" ]]; then
        until_index=$index
      fi
      ((index += 1))
    done

    if (( from_index > until_index )); then
      die "--from step must not come after --until step ($FROM_STEP > $UNTIL_STEP)"
    fi
  fi

  for step in "${steps[@]}"; do
    if [[ -n "$FROM_STEP" && "$step" == "$FROM_STEP" ]]; then
      enabled=1
    fi
    if [[ -z "$FROM_STEP" ]]; then
      enabled=1
    fi
    if [[ $enabled -eq 1 ]]; then
      filtered+=("$step")
    fi
    if [[ -n "$UNTIL_STEP" && "$step" == "$UNTIL_STEP" ]]; then
      break
    fi
  done

  SELECTED_STEPS=("${filtered[@]}")
}

run_step_file() {
  local step="$1"
  local step_path="$STEPS_DIR/$step"
  [[ -f "$step_path" ]] || die "Missing step file: $step_path"
  # shellcheck disable=SC1090
  source "$step_path"
  if declare -F step_main >/dev/null; then
    log_info "Running $step"
    step_main
    unset -f step_main
  else
    die "Step file does not define step_main(): $step"
  fi
}

main() {
  parse_args "$@"
  if [[ "$LIST_ONLY" == "yes" ]]; then
    print_step_list
    exit 0
  fi
  load_configs
  bootstrap_defaults
  acquire_lock
  trap 'release_lock' EXIT
  trap 'on_error $LINENO "$BASH_COMMAND"' ERR

  if [[ "$BOOTSTRAP_NON_INTERACTIVE" != "yes" && ! -t 0 ]]; then
    export BOOTSTRAP_NON_INTERACTIVE="yes"
    log_warn "STDIN is not a TTY; auto-enabling non-interactive mode with current/default values"
  fi

  select_steps
  log_info "Run ID: $RUN_ID"
  log_info "Log file: $LOG_FILE"
  log_info "Dry run: $BOOTSTRAP_DRY_RUN"
  log_info "Non-interactive: $BOOTSTRAP_NON_INTERACTIVE"

  for step in "${SELECTED_STEPS[@]}"; do
    run_step_file "$step"
  done

  log_success "Bootstrap finished"
}

main "$@"
