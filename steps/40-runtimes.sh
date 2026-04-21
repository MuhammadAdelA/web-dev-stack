#!/usr/bin/env bash
set -Eeuo pipefail

install_php_versions() {
  local versions version ext packages
  versions="$(normalize_csv_spaces "$PHP_VERSIONS")"
  for version in $versions; do
    packages=("php${version}-cli" "php${version}-fpm" "php${version}-common")
    for ext in $PRIMARY_PHP_EXTENSIONS; do
      packages+=("php${version}-${ext}")
    done
    install_packages "Installing PHP $version runtime" "${packages[@]}"
  done

  if [[ "$WEBSERVER" == "apache" ]]; then
    install_packages "Installing Apache PHP module for PHP $PHP_DEFAULT_VERSION" "libapache2-mod-php${PHP_DEFAULT_VERSION}"
  fi

  if [[ "$BOOTSTRAP_DRY_RUN" != "yes" ]]; then
    run_bash "Switching CLI PHP alternative to $PHP_DEFAULT_VERSION" "update-alternatives --set php /usr/bin/php${PHP_DEFAULT_VERSION}"
    command_exists phar && run_bash "Switching phar alternative" "update-alternatives --set phar /usr/bin/phar${PHP_DEFAULT_VERSION} || true"
    command_exists phar.phar && run_bash "Switching phar.phar alternative" "update-alternatives --set phar.phar /usr/bin/phar.phar${PHP_DEFAULT_VERSION} || true"
  else
    log_info "DRY-RUN switch PHP CLI alternative to $PHP_DEFAULT_VERSION"
  fi
}

install_composer() {
  if command_exists composer && is_yes "$SKIP_EXISTING" && ! is_yes "$FORCE_REPAIR"; then
    log_warn "Composer already exists; skipping install"
    return 0
  fi

  run_bash "Downloading Composer installer" "php -r \"copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');\""
  run_bash "Installing Composer" "php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer"
  run_bash "Removing Composer installer" "rm -f /tmp/composer-setup.php"
}

install_node_stack() {
  install_packages "Installing Node.js" nodejs

  if is_yes "$INSTALL_PNPM"; then
    run_bash "Installing pnpm globally" "npm install -g pnpm"
  fi
  if is_yes "$INSTALL_YARN"; then
    run_bash "Installing Yarn globally" "npm install -g yarn"
  fi
}

step_main() {
  local key="40-runtimes"
  if skip_if_done "$key"; then return 0; fi

  if is_yes "$INSTALL_PHP"; then
    install_php_versions
  else
    log_info "Skipping PHP runtime installation"
  fi

  if is_yes "$INSTALL_COMPOSER" && is_yes "$INSTALL_PHP"; then
    install_composer
  fi

  if is_yes "$INSTALL_NODE"; then
    install_node_stack
  else
    log_info "Skipping Node.js installation"
  fi

  mark_done "$key"
}
