#!/usr/bin/env bash
set -Eeuo pipefail

step_main() {
  local key="90-summary"
  if skip_if_done "$key"; then return 0; fi

  log_success "Bootstrap summary file: $SUMMARY_FILE"
  log_success "Machine summary file: $MACHINE_SUMMARY_FILE"
  if [[ -s "$SUMMARY_FILE" ]]; then
    log_info "Summary entries:"
    sed 's/^/  /' "$SUMMARY_FILE" | tee -a "$LOG_FILE" >&2
  else
    log_warn "No summary entries were recorded"
  fi

  mark_done "$key"
}
