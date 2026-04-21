#!/usr/bin/env bash
set -Eeuo pipefail

step_main() {
  local key="60-databases"
  if skip_if_done "$key"; then return 0; fi

  case "$DB_SERVER" in
    mysql)
      install_packages "Installing MySQL Server" mysql-server mysql-client
      run_cmd "Enabling MySQL" systemctl enable mysql
      run_cmd "Starting MySQL" systemctl restart mysql
      ;;
    mariadb)
      install_packages "Installing MariaDB Server" mariadb-server mariadb-client
      run_cmd "Enabling MariaDB" systemctl enable mariadb
      run_cmd "Starting MariaDB" systemctl restart mariadb
      ;;
    none)
      log_info "Skipping MySQL/MariaDB installation"
      ;;
  esac

  if is_yes "$INSTALL_POSTGRESQL"; then
    install_packages "Installing PostgreSQL" postgresql postgresql-client
    run_cmd "Enabling PostgreSQL" systemctl enable postgresql
    run_cmd "Starting PostgreSQL" systemctl restart postgresql
  fi

  if is_yes "$INSTALL_REDIS"; then
    install_packages "Installing Redis" redis-server redis-tools
    run_cmd "Enabling Redis" systemctl enable redis-server
    run_cmd "Starting Redis" systemctl restart redis-server
  fi

  mark_done "$key"
}
