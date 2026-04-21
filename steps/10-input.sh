#!/usr/bin/env bash
set -Eeuo pipefail

step_main() {
  local key="10-input"
  if skip_if_done "$key"; then return 0; fi

  if [[ "$BOOTSTRAP_NON_INTERACTIVE" != "yes" ]]; then
    prompt_with_default WEBSERVER "Web server (apache/nginx/none)" "$WEBSERVER"
    prompt_yes_no INSTALL_PHP "Install PHP" "$INSTALL_PHP"
    if is_yes "$INSTALL_PHP"; then
      prompt_with_default PHP_VERSIONS "PHP versions (space or comma separated)" "$PHP_VERSIONS"
      PHP_VERSIONS="$(normalize_csv_spaces "$PHP_VERSIONS")"
      prompt_with_default PHP_DEFAULT_VERSION "Default PHP version" "$PHP_DEFAULT_VERSION"
      prompt_yes_no INSTALL_COMPOSER "Install Composer" "$INSTALL_COMPOSER"
    fi
    prompt_yes_no INSTALL_NODE "Install Node.js" "$INSTALL_NODE"
    if is_yes "$INSTALL_NODE"; then
      prompt_with_default NODE_MAJOR "Node major version" "$NODE_MAJOR"
      prompt_yes_no INSTALL_PNPM "Install pnpm" "$INSTALL_PNPM"
      prompt_yes_no INSTALL_YARN "Install Yarn" "$INSTALL_YARN"
    fi
    prompt_with_default DB_SERVER "Primary DB server (mysql/mariadb/none)" "$DB_SERVER"
    prompt_yes_no CONFIGURE_DEV_DB_USER "Configure default DB dev user/password" "$CONFIGURE_DEV_DB_USER"
    if is_yes "$CONFIGURE_DEV_DB_USER"; then
      prompt_with_default DB_DEV_USER "DB dev user" "$DB_DEV_USER"
      prompt_with_default DB_DEV_PASSWORD "DB dev password" "$DB_DEV_PASSWORD"
    fi
    prompt_yes_no INSTALL_POSTGRESQL "Install PostgreSQL" "$INSTALL_POSTGRESQL"
    prompt_yes_no INSTALL_REDIS "Install Redis" "$INSTALL_REDIS"
    prompt_yes_no INSTALL_PHPMYADMIN "Install phpMyAdmin" "$INSTALL_PHPMYADMIN"
    if is_yes "$INSTALL_PHPMYADMIN"; then
      prompt_with_default PHPMYADMIN_ALIAS "phpMyAdmin URL alias" "$PHPMYADMIN_ALIAS"
    fi
    prompt_yes_no INSTALL_VIRTUALSERVERS "Install virtualservers helper tool" "$INSTALL_VIRTUALSERVERS"
  else
    PHP_VERSIONS="$(normalize_csv_spaces "$PHP_VERSIONS")"
  fi

  validate_choices
  render_plan | tee -a "$LOG_FILE"
  mark_done "$key"
}
