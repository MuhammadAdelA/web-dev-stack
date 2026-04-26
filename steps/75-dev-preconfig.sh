#!/usr/bin/env bash
set -Eeuo pipefail

apply_apache_dev_preset() {
  local conf_target="/etc/apache2/conf-available/web-dev-bootstrap-dev.conf"
  local content
  content="$(cat <<'CONF'
ServerName localhost
<Directory /var/www/html>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
CONF
)"
  write_file_if_changed "$conf_target" "$content"
  run_cmd "Enabling Apache dev preset config" a2enconf web-dev-bootstrap-dev
  reload_or_restart_service apache2
}

apply_php_dev_preset() {
  local ini_target="/etc/php/mods-available/web-dev-bootstrap-dev.ini"
  local content version
  content="$(cat <<CONF
; Managed by web-dev-bootstrap
display_errors = On
display_startup_errors = On
error_reporting = E_ALL
memory_limit = 512M
upload_max_filesize = 64M
post_max_size = 64M
date.timezone = ${BOOTSTRAP_TIMEZONE}
CONF
)"
  write_file_if_changed "$ini_target" "$content"

  for version in $(normalize_csv_spaces "$PHP_VERSIONS"); do
    if [[ "$BOOTSTRAP_DRY_RUN" != "yes" && ! -d "/etc/php/${version}" ]]; then
      log_warn "PHP $version not detected under /etc/php; skipping dev preset for this version"
      continue
    fi
    run_cmd "Enabling PHP dev preset module for PHP $version" phpenmod -v "$version" web-dev-bootstrap-dev
    reload_or_restart_service "php${version}-fpm"
  done

  if [[ "$WEBSERVER" == "apache" ]]; then
    reload_or_restart_service apache2
  fi
}

apply_mysql_family_dev_preset() {
  local config_target="$1"
  local service_name="$2"
  local content

  content="$(cat <<'CONF'
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
CONF
)"
  write_file_if_changed "$config_target" "$content"
  reload_or_restart_service "$service_name"
}

apply_phpmyadmin_dev_preset() {
  local config_target="/etc/phpmyadmin/conf.d/99-web-dev-bootstrap-dev.php"
  local content

  run_bash "Preparing phpMyAdmin temp directory" "install -d -m 0770 -o www-data -g www-data /var/lib/phpmyadmin/tmp"
  content="$(cat <<'CONF'
<?php
$cfg['TempDir'] = '/var/lib/phpmyadmin/tmp';
CONF
)"
  write_file_if_changed "$config_target" "$content"

  case "$WEBSERVER" in
    apache) reload_or_restart_service apache2 ;;
    nginx) reload_or_restart_service nginx ;;
  esac
}

apply_node_dev_preset() {
  run_bash "Enabling Node corepack shims" "corepack enable || true"
}

step_main() {
  local key="75-dev-preconfig"
  if skip_if_done "$key"; then return 0; fi

  if ! is_yes "$APPLY_DEV_PRESETS"; then
    log_info "Skipping bundled dev pre-configs"
    mark_done "$key"
    return 0
  fi

  if [[ "$WEBSERVER" == "apache" ]]; then
    apply_apache_dev_preset
  fi

  if is_yes "$INSTALL_PHP"; then
    apply_php_dev_preset
  fi

  case "$DB_SERVER" in
    mysql)
      apply_mysql_family_dev_preset "/etc/mysql/mysql.conf.d/99-web-dev-bootstrap-dev.cnf" mysql
      ;;
    mariadb)
      apply_mysql_family_dev_preset "/etc/mysql/mariadb.conf.d/99-web-dev-bootstrap-dev.cnf" mariadb
      ;;
  esac

  if is_yes "$INSTALL_PHPMYADMIN"; then
    apply_phpmyadmin_dev_preset
  fi

  if is_yes "$INSTALL_NODE"; then
    apply_node_dev_preset
  fi

  mark_done "$key"
}
