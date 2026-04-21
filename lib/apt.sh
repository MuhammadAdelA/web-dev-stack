#!/usr/bin/env bash
set -Eeuo pipefail

apt_update() {
  run_cmd "Refreshing apt package index" apt-get update -y
}

install_packages() {
  local description="$1"
  shift
  local packages=("$@")
  [[ ${#packages[@]} -gt 0 ]] || return 0
  run_cmd "$description" apt-get install -y --no-install-recommends "${packages[@]}"
}

enable_universe_repo() {
  if ! is_yes "$ENABLE_UNIVERSE"; then
    return 0
  fi
  if grep -Rq "^[^#].*universe" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    log_info "Universe repository already enabled"
    return 0
  fi
  install_packages "Installing add-apt-repository helper" software-properties-common
  run_cmd "Enabling Universe repository" add-apt-repository -y universe
}

add_ondrej_php_repo() {
  if ! is_yes "$ENABLE_PPA_ONDREJ_PHP"; then
    log_warn "Ondrej PHP repo is disabled; multiple PHP versions may not be available"
    return 0
  fi
  if grep -Rqs "ondrej/php" /etc/apt/sources.list.d /etc/apt/sources.list 2>/dev/null; then
    log_info "Ondrej PHP repository already configured"
    return 0
  fi
  install_packages "Installing repo prerequisites for PHP PPA" software-properties-common ca-certificates lsb-release gnupg
  run_cmd "Adding Ondrej PHP PPA" add-apt-repository -y ppa:ondrej/php
}

add_nodesource_repo() {
  if ! is_yes "$ENABLE_NODESOURCE"; then
    log_warn "NodeSource repository is disabled; Node.js install may use Ubuntu packages if available"
    return 0
  fi
  if [[ -f /etc/apt/sources.list.d/nodesource.list ]] || grep -Rqs "deb.nodesource.com" /etc/apt/sources.list.d /etc/apt/sources.list 2>/dev/null; then
    log_info "NodeSource repository already configured"
    return 0
  fi
  install_packages "Installing NodeSource repository prerequisites" ca-certificates curl gnupg
  run_bash "Creating apt keyrings directory" "install -d -m 0755 /etc/apt/keyrings"
  run_bash "Downloading NodeSource GPG key" "curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg"
  local source_line
  source_line="deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main\n"
  if [[ "$BOOTSTRAP_DRY_RUN" == "yes" ]]; then
    log_info "DRY-RUN write /etc/apt/sources.list.d/nodesource.list"
  else
    printf '%b' "$source_line" > /etc/apt/sources.list.d/nodesource.list
  fi
}
