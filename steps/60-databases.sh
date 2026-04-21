#!/usr/bin/env bash
set -Eeuo pipefail

sql_escape_literal() {
  printf '%s' "$1" | sed "s/'/''/g"
}

configure_mysql_family_dev_user() {
  local client="$1"
  local user_sql pass_sql sql

  user_sql="$(sql_escape_literal "$DB_DEV_USER")"
  pass_sql="$(sql_escape_literal "$DB_DEV_PASSWORD")"
  sql="CREATE USER IF NOT EXISTS '${user_sql}'@'localhost' IDENTIFIED BY '${pass_sql}'; ALTER USER '${user_sql}'@'localhost' IDENTIFIED BY '${pass_sql}'; GRANT ALL PRIVILEGES ON *.* TO '${user_sql}'@'localhost'; FLUSH PRIVILEGES;"

  run_bash "Configuring ${client} dev user '$DB_DEV_USER'" "$client -e \"$sql\""
}

configure_postgresql_dev_user() {
  local role_ident role_lit pass_lit

  role_ident="$DB_DEV_USER"
  role_lit="$(sql_escape_literal "$DB_DEV_USER")"
  pass_lit="$(sql_escape_literal "$DB_DEV_PASSWORD")"

  run_bash "Configuring PostgreSQL dev role '$DB_DEV_USER'" "
if sudo -u postgres psql -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${role_lit}'\" | grep -q 1; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c \"ALTER ROLE ${role_ident} WITH LOGIN PASSWORD '${pass_lit}' CREATEDB;\"
else
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c \"CREATE ROLE ${role_ident} WITH LOGIN PASSWORD '${pass_lit}' CREATEDB;\"
fi
"

  run_bash "Ensuring PostgreSQL database '$DB_DEV_USER' exists" "
if ! sudo -u postgres psql -tAc \"SELECT 1 FROM pg_database WHERE datname='${role_lit}'\" | grep -q 1; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c \"CREATE DATABASE ${role_ident} OWNER ${role_ident};\"
fi
"
}

configure_dev_db_credentials() {
  if ! is_yes "$CONFIGURE_DEV_DB_USER"; then
    log_info "Skipping dev DB user/password configuration"
    return 0
  fi

  case "$DB_SERVER" in
    mysql)
      configure_mysql_family_dev_user mysql
      ;;
    mariadb)
      configure_mysql_family_dev_user mariadb
      ;;
    none)
      log_info "Skipping MySQL/MariaDB dev user setup because DB_SERVER=none"
      ;;
  esac

  if is_yes "$INSTALL_POSTGRESQL"; then
    configure_postgresql_dev_user
  else
    log_info "Skipping PostgreSQL dev user setup"
  fi
}

step_main() {
  local key="60-databases"
  if skip_if_done "$key"; then return 0; fi

  case "$DB_SERVER" in
    mysql)
      install_packages "Installing MySQL Server" mysql-server mysql-client
      run_cmd "Enabling MySQL" systemctl enable mysql
      reload_or_restart_service mysql
      ;;
    mariadb)
      install_packages "Installing MariaDB Server" mariadb-server mariadb-client
      run_cmd "Enabling MariaDB" systemctl enable mariadb
      reload_or_restart_service mariadb
      ;;
    none)
      log_info "Skipping MySQL/MariaDB installation"
      ;;
  esac

  if is_yes "$INSTALL_POSTGRESQL"; then
    install_packages "Installing PostgreSQL" postgresql postgresql-client
    run_cmd "Enabling PostgreSQL" systemctl enable postgresql
    reload_or_restart_service postgresql
  fi

  configure_dev_db_credentials

  if is_yes "$INSTALL_REDIS"; then
    install_packages "Installing Redis" redis-server redis-tools
    run_cmd "Enabling Redis" systemctl enable redis-server
    reload_or_restart_service redis-server
  fi

  mark_done "$key"
}
