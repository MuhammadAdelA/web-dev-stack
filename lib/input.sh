#!/usr/bin/env bash
set -Eeuo pipefail

prompt_with_default() {
  local var_name="$1" prompt="$2" default="$3"
  local value
  if [[ "$BOOTSTRAP_NON_INTERACTIVE" == "yes" ]]; then
    printf -v "$var_name" '%s' "$default"
    return 0
  fi
  if ! read -r -p "$prompt [$default]: " value; then
    log_warn "Input unavailable for '$prompt'; using default: $default"
    value="$default"
  fi
  value="${value:-$default}"
  printf -v "$var_name" '%s' "$value"
}

prompt_yes_no() {
  local var_name="$1" prompt="$2" default="$3" ans
  prompt_with_default ans "$prompt (yes/no)" "$default"
  if is_yes "$ans"; then
    printf -v "$var_name" 'yes'
  else
    printf -v "$var_name" 'no'
  fi
}

validate_choices() {
  case "$WEBSERVER" in
    apache|nginx|none) ;;
    *) die "WEBSERVER must be apache, nginx, or none" ;;
  esac
  case "$DB_SERVER" in
    mysql|mariadb|none) ;;
    *) die "DB_SERVER must be mysql, mariadb, or none" ;;
  esac

  if is_yes "$CONFIGURE_DEV_DB_USER"; then
    [[ -n "$DB_DEV_USER" ]] || die "CONFIGURE_DEV_DB_USER=yes requires DB_DEV_USER"
    [[ -n "$DB_DEV_PASSWORD" ]] || die "CONFIGURE_DEV_DB_USER=yes requires DB_DEV_PASSWORD"
    [[ "$DB_DEV_USER" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || die "DB_DEV_USER must start with a letter/underscore and use only letters, numbers, or underscores"
    [[ "$DB_DEV_PASSWORD" != *"'"* ]] || die "DB_DEV_PASSWORD must not contain single quotes"
    [[ "$DB_DEV_PASSWORD" != *'"'* ]] || die "DB_DEV_PASSWORD must not contain double quotes"
    [[ "$DB_DEV_PASSWORD" != *"\\"* ]] || die "DB_DEV_PASSWORD must not contain backslashes"
  fi

  if is_yes "$INSTALL_PHPMYADMIN"; then
    [[ "$DB_SERVER" != "none" ]] || die "phpMyAdmin requires DB_SERVER=mysql or mariadb"
    [[ "$WEBSERVER" != "none" ]] || die "phpMyAdmin requires Apache or Nginx"
    is_yes "$INSTALL_PHP" || die "phpMyAdmin requires PHP"
  fi

  if is_yes "$INSTALL_PNPM" && ! is_yes "$INSTALL_NODE"; then
    die "INSTALL_PNPM=yes requires INSTALL_NODE=yes"
  fi
  if is_yes "$INSTALL_YARN" && ! is_yes "$INSTALL_NODE"; then
    die "INSTALL_YARN=yes requires INSTALL_NODE=yes"
  fi
  if is_yes "$INSTALL_PHP"; then
    [[ -n "$PHP_VERSIONS" ]] || die "INSTALL_PHP=yes requires PHP_VERSIONS"
    [[ -n "$PHP_DEFAULT_VERSION" ]] || die "INSTALL_PHP=yes requires PHP_DEFAULT_VERSION"
    normalize_csv_spaces "$PHP_VERSIONS" | grep -qw "$PHP_DEFAULT_VERSION" || die "PHP_DEFAULT_VERSION must exist in PHP_VERSIONS"
  fi
}

render_plan() {
  cat <<PLAN
Bootstrap plan:
  WEBSERVER=$WEBSERVER
  INSTALL_PHP=$INSTALL_PHP
  PHP_VERSIONS=$PHP_VERSIONS
  PHP_DEFAULT_VERSION=$PHP_DEFAULT_VERSION
  INSTALL_COMPOSER=$INSTALL_COMPOSER
  COMPOSER_DEV_USER=$COMPOSER_DEV_USER
  INSTALL_NODE=$INSTALL_NODE
  NODE_MAJOR=$NODE_MAJOR
  INSTALL_PNPM=$INSTALL_PNPM
  INSTALL_YARN=$INSTALL_YARN
  DB_SERVER=$DB_SERVER
  CONFIGURE_DEV_DB_USER=$CONFIGURE_DEV_DB_USER
  DB_DEV_USER=$DB_DEV_USER
  DB_DEV_PASSWORD=<hidden>
  INSTALL_POSTGRESQL=$INSTALL_POSTGRESQL
  INSTALL_REDIS=$INSTALL_REDIS
  INSTALL_PHPMYADMIN=$INSTALL_PHPMYADMIN
  INSTALL_VIRTUALSERVERS=$INSTALL_VIRTUALSERVERS
  PHPMYADMIN_ALIAS=$PHPMYADMIN_ALIAS
PLAN
}
