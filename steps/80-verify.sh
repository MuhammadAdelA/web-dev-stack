#!/usr/bin/env bash
set -Eeuo pipefail

verify_composer_non_root() {
  if ! is_yes "$INSTALL_COMPOSER" || ! is_yes "$INSTALL_PHP"; then
    return 0
  fi

  if [[ "$BOOTSTRAP_DRY_RUN" == "yes" ]]; then
    verify_command "composer" "sudo -u '$COMPOSER_DEV_USER' composer --version"
    return 0
  fi

  if id "$COMPOSER_DEV_USER" >/dev/null 2>&1; then
    verify_command "composer" "sudo -u '$COMPOSER_DEV_USER' composer --version"
  else
    verify_command "composer" "COMPOSER_ALLOW_SUPERUSER=1 composer --version"
  fi
}

verify_phpmyadmin_local() {
  if ! is_yes "$INSTALL_PHPMYADMIN"; then
    return 0
  fi

  if [[ "$BOOTSTRAP_DRY_RUN" == "yes" ]]; then
    verify_command "phpmyadmin-http" "curl -fsSI http://127.0.0.1${PHPMYADMIN_ALIAS}"
    verify_command "phpmyadmin-php-page" "curl -fsS http://127.0.0.1${PHPMYADMIN_ALIAS}/index.php | grep -qi 'phpmyadmin'"
    return 0
  fi

  verify_command "phpmyadmin-files" "test -d /usr/share/phpmyadmin"
  verify_command "phpmyadmin-http" "curl -fsSI http://127.0.0.1${PHPMYADMIN_ALIAS}"
  verify_command "phpmyadmin-php-page" "curl -fsS http://127.0.0.1${PHPMYADMIN_ALIAS}/index.php | grep -qi 'phpmyadmin'"
}

verify_virtualservers_helper() {
  if ! is_yes "$INSTALL_VIRTUALSERVERS"; then
    return 0
  fi
  verify_command "virtualservers" "virtualservers --help"
}

verify_apache_php_binding() {
  if [[ "$WEBSERVER" != "apache" ]] || ! is_yes "$INSTALL_PHP"; then
    return 0
  fi

  verify_command "apache-php-module" "a2query -m php${PHP_DEFAULT_VERSION}"
}

step_main() {
  local key="80-verify"
  if skip_if_done "$key"; then return 0; fi

  case "$WEBSERVER" in
    apache)
      verify_command "apache-version" "apache2 -v"
      verify_service "apache2"
      ;;
    nginx)
      verify_command "nginx-version" "nginx -v"
      verify_service "nginx"
      ;;
  esac

  if is_yes "$INSTALL_PHP"; then
    local version
    for version in $(normalize_csv_spaces "$PHP_VERSIONS"); do
      verify_command "php${version}" "php${version} -v"
      verify_service "php${version}-fpm"
    done
    verify_command "php-default" "php -v"
  fi

  verify_composer_non_root

  if is_yes "$INSTALL_NODE"; then
    verify_command "node" "node -v"
    verify_command "npm" "npm -v"
    is_yes "$INSTALL_PNPM" && verify_command "pnpm" "pnpm -v"
    is_yes "$INSTALL_YARN" && verify_command "yarn" "yarn -v"
  fi

  case "$DB_SERVER" in
    mysql)
      verify_command "mysql" "mysql --version"
      verify_service "mysql"
      ;;
    mariadb)
      verify_command "mariadb" "mariadb --version"
      verify_service "mariadb"
      ;;
  esac

  is_yes "$INSTALL_POSTGRESQL" && { verify_command "psql" "psql --version"; verify_service "postgresql"; }
  is_yes "$INSTALL_REDIS" && { verify_command "redis-server" "redis-server --version"; verify_service "redis-server"; }

  verify_apache_php_binding
  verify_phpmyadmin_local
  verify_virtualservers_helper
  mark_done "$key"
}
