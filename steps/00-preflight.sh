#!/usr/bin/env bash
set -Eeuo pipefail

step_main() {
  local key="00-preflight"
  if skip_if_done "$key"; then return 0; fi

  require_root
  require_ubuntu
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" == "ubuntu" ]]; then
      ubuntu_version_at_least "24.04" || die "Ubuntu 24.04 or newer is required"
    fi
  fi

  command_exists apt-get || die "apt-get is required"
  command_exists systemctl || log_warn "systemctl not found; service checks may be limited"

  if [[ "$BOOTSTRAP_DRY_RUN" != "yes" ]]; then
    ping -c1 -W3 1.1.1.1 >/dev/null 2>&1 || log_warn "Network check failed; repository access may fail"
    getent hosts archive.ubuntu.com >/dev/null 2>&1 || log_warn "DNS resolution for archive.ubuntu.com failed"
    df -Pm / | awk 'NR==2 { if ($4 < 4096) exit 1 }' || die "Less than 4 GiB free disk space on /"
  fi

  set_timezone_if_needed || log_warn "Timezone configuration skipped"
  mark_done "$key"
}
