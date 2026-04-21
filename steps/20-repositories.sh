#!/usr/bin/env bash
set -Eeuo pipefail

step_main() {
  local key="20-repositories"
  if skip_if_done "$key"; then return 0; fi

  enable_universe_repo

  if is_yes "$INSTALL_PHP"; then
    add_ondrej_php_repo
  fi

  if is_yes "$INSTALL_NODE"; then
    add_nodesource_repo
  fi

  apt_update
  mark_done "$key"
}
