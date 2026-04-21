#!/usr/bin/env bash
set -Eeuo pipefail

step_main() {
  local key="30-packages-base"
  if skip_if_done "$key"; then return 0; fi

  install_packages "Installing base packages" \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    lsb-release \
    unzip \
    zip \
    software-properties-common \
    build-essential \
    acl \
    sudo \
    wget

  mark_done "$key"
}
