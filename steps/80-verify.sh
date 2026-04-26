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

verify_db_dev_credentials() {
  if ! is_yes "$CONFIGURE_DEV_DB_USER"; then
    return 0
  fi

  case "$DB_SERVER" in
    mysql)
      verify_command \
        "mysql-dev-login" \
        "mysql -u\"$DB_DEV_USER\" -p\"$DB_DEV_PASSWORD\" -e \"SELECT 1;\"" \
        "mysql -u\"$DB_DEV_USER\" -p\"<redacted>\" -e \"SELECT 1;\""
      ;;
    mariadb)
      verify_command \
        "mariadb-dev-login" \
        "mariadb -u\"$DB_DEV_USER\" -p\"$DB_DEV_PASSWORD\" -e \"SELECT 1;\"" \
        "mariadb -u\"$DB_DEV_USER\" -p\"<redacted>\" -e \"SELECT 1;\""
      ;;
  esac

  if is_yes "$INSTALL_POSTGRESQL"; then
    verify_command \
      "postgresql-dev-login" \
      "PGPASSWORD=\"$DB_DEV_PASSWORD\" psql -h 127.0.0.1 -U \"$DB_DEV_USER\" -d \"$DB_DEV_USER\" -c 'SELECT 1;'" \
      "PGPASSWORD=\"<redacted>\" psql -h 127.0.0.1 -U \"$DB_DEV_USER\" -d \"$DB_DEV_USER\" -c 'SELECT 1;'"
  fi
}

verify_apache_php_binding() {
  if [[ "$WEBSERVER" != "apache" ]] || ! is_yes "$INSTALL_PHP"; then
    return 0
  fi

  verify_command "apache-php-module" "a2query -m php${PHP_DEFAULT_VERSION}"
}

verify_dev_presets() {
  local version
  if ! is_yes "$APPLY_DEV_PRESETS"; then
    return 0
  fi

  if [[ "$WEBSERVER" == "apache" ]]; then
    verify_command "apache-dev-preset" "a2query -c web-dev-bootstrap-dev"
  fi

  if is_yes "$INSTALL_PHP"; then
    for version in $(normalize_csv_spaces "$PHP_VERSIONS"); do
      verify_command "php${version}-dev-preset" "php${version} --ini | grep -q 'web-dev-bootstrap-dev.ini'"
    done
  fi

  case "$DB_SERVER" in
    mysql)
      verify_command "mysql-dev-preset-file" "test -f /etc/mysql/mysql.conf.d/99-web-dev-bootstrap-dev.cnf"
      ;;
    mariadb)
      verify_command "mariadb-dev-preset-file" "test -f /etc/mysql/mariadb.conf.d/99-web-dev-bootstrap-dev.cnf"
      ;;
  esac

  if is_yes "$INSTALL_PHPMYADMIN"; then
    verify_command "phpmyadmin-dev-preset-file" "test -f /etc/phpmyadmin/conf.d/99-web-dev-bootstrap-dev.php"
  fi
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

  verify_db_dev_credentials
  verify_apache_php_binding
  verify_phpmyadmin_local
  verify_virtualservers_helper
  verify_dev_presets
  mark_done "$key"
}
