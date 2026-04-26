#!/usr/bin/env bash
set -Eeuo pipefail

verify_command() {
  local name="$1" cmd="$2" detail="${3:-}"
  [[ -n "$detail" ]] || detail="$cmd"

  if [[ "$BOOTSTRAP_DRY_RUN" == "yes" ]]; then
    log_info "DRY-RUN verify: $detail"
    record_summary "$name" "planned" "$detail"
    return 0
  fi
  if bash -lc "$cmd" >> "$LOG_FILE" 2>&1; then
    log_success "Verified $name"
    record_summary "$name" "ok" "$detail"
  else
    log_error "Verification failed for $name"
    record_summary "$name" "failed" "$detail"
    return 1
  fi
}

verify_service() {
  local service="$1"
  if [[ "$BOOTSTRAP_DRY_RUN" == "yes" ]]; then
    log_info "DRY-RUN verify service: $service"
    record_summary "$service" "planned" "systemctl is-active $service"
    return 0
  fi
  if systemctl is-active --quiet "$service"; then
    log_success "Service active: $service"
    record_summary "$service" "ok" "active"
  else
    log_error "Service inactive: $service"
    record_summary "$service" "failed" "inactive"
    return 1
  fi
}
