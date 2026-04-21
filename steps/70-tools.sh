#!/usr/bin/env bash
set -Eeuo pipefail

preseed_phpmyadmin() {
  if [[ "$BOOTSTRAP_DRY_RUN" == "yes" ]]; then
    log_info "DRY-RUN preseed phpMyAdmin debconf"
    return 0
  fi

  case "$WEBSERVER" in
    apache)
      debconf-set-selections <<DEBCONF
phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2
phpmyadmin phpmyadmin/dbconfig-install boolean false
DEBCONF
      ;;
    nginx)
      debconf-set-selections <<DEBCONF
phpmyadmin phpmyadmin/reconfigure-webserver multiselect
phpmyadmin phpmyadmin/dbconfig-install boolean false
DEBCONF
      ;;
  esac
}

ensure_phpmyadmin_alias_helpers() {
  if ! declare -F configure_apache_phpmyadmin_alias >/dev/null; then
    configure_apache_phpmyadmin_alias() {
      local conf_target="/etc/apache2/conf-available/phpmyadmin-bootstrap.conf"
      local content
      content="Alias ${PHPMYADMIN_ALIAS} /usr/share/phpmyadmin\n<Directory /usr/share/phpmyadmin>\n    Options SymLinksIfOwnerMatch\n    DirectoryIndex index.php\n    AllowOverride None\n    Require all granted\n</Directory>\n"
      write_file_if_changed "$conf_target" "$(printf '%b' "$content")"
      run_cmd "Enabling phpMyAdmin Apache config" a2enconf phpmyadmin-bootstrap
    }
  fi

  if ! declare -F configure_nginx_phpmyadmin_alias >/dev/null; then
    configure_nginx_phpmyadmin_alias() {
      local conf_target="/etc/nginx/snippets/phpmyadmin.conf"
      local content
      content="location ${PHPMYADMIN_ALIAS} {\n    alias /usr/share/phpmyadmin;\n    index index.php;\n}\nlocation ~ ^${PHPMYADMIN_ALIAS}/(.+\\.php)$ {\n    alias /usr/share/phpmyadmin/$1;\n    include snippets/fastcgi-php.conf;\n    fastcgi_param SCRIPT_FILENAME /usr/share/phpmyadmin/$1;\n    fastcgi_pass unix:/run/php/php${PHP_DEFAULT_VERSION}-fpm.sock;\n}\n"
      write_file_if_changed "$conf_target" "$(printf '%b' "$content")"
      log_warn "Nginx phpMyAdmin snippet written to $conf_target; include it in your server block manually if needed"
    }
  fi
}

install_virtualservers_helper() {
  local tool_path="/usr/local/bin/virtualservers"
  local tool_content

  tool_content="$(cat <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage:
  virtualservers create <server_name> <docroot> [apache|nginx|both]
  virtualservers list
  virtualservers --help

Examples:
  sudo virtualservers create app.local /var/www/app.local nginx
  sudo virtualservers create demo.local /var/www/demo.local both

Notes:
  - This tool only scaffolds site config files and docroots.
  - It does not automatically enable sites or reload services.
USAGE
}

die() {
  printf 'virtualservers: %s\n' "$*" >&2
  exit 1
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "run as root (sudo)"
}

validate_server_name() {
  local name="$1"
  [[ "$name" =~ ^[A-Za-z0-9.-]+$ ]] || die "invalid server_name '$name' (allowed: letters, digits, dot, dash)"
}

validate_docroot() {
  local path="$1"
  [[ "$path" == /* ]] || die "docroot must be an absolute path"
}

write_apache_vhost() {
  local name="$1" docroot="$2"
  local conf="/etc/apache2/sites-available/${name}.conf"
  if [[ -f "$conf" ]]; then
    printf 'Apache config already exists: %s\n' "$conf"
    return 0
  fi

  cat > "$conf" <<EOF
<VirtualHost *:80>
    ServerName $name
    ServerAlias www.$name
    DocumentRoot $docroot

    <Directory $docroot>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${name}_error.log
    CustomLog \${APACHE_LOG_DIR}/${name}_access.log combined
</VirtualHost>
EOF
  printf 'Created Apache config: %s\n' "$conf"
}

write_nginx_server() {
  local name="$1" docroot="$2"
  local conf="/etc/nginx/sites-available/${name}.conf"
  if [[ -f "$conf" ]]; then
    printf 'Nginx config already exists: %s\n' "$conf"
    return 0
  fi

  cat > "$conf" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $name www.$name;

    root $docroot;
    index index.html index.htm index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
  printf 'Created Nginx config: %s\n' "$conf"
}

create_virtual_server() {
  local name="${1:-}" docroot="${2:-}" mode="${3:-both}"
  [[ -n "$name" && -n "$docroot" ]] || die "create requires <server_name> <docroot> [apache|nginx|both]"
  validate_server_name "$name"
  validate_docroot "$docroot"

  case "$mode" in
    apache|nginx|both) ;;
    *) die "mode must be apache, nginx, or both" ;;
  esac

  mkdir -p "$docroot"
  if [[ ! -f "$docroot/index.html" ]]; then
    printf '<!doctype html><title>%s</title><h1>%s</h1>\n' "$name" "$name" > "$docroot/index.html"
    printf 'Created docroot index: %s/index.html\n' "$docroot"
  fi

  if [[ "$mode" == "apache" || "$mode" == "both" ]]; then
    write_apache_vhost "$name" "$docroot"
  fi
  if [[ "$mode" == "nginx" || "$mode" == "both" ]]; then
    write_nginx_server "$name" "$docroot"
  fi

  printf '\nNext steps:\n'
  if [[ "$mode" == "apache" || "$mode" == "both" ]]; then
    printf '  sudo a2ensite %s.conf && sudo systemctl reload apache2\n' "$name"
  fi
  if [[ "$mode" == "nginx" || "$mode" == "both" ]]; then
    printf '  sudo ln -s /etc/nginx/sites-available/%s.conf /etc/nginx/sites-enabled/%s.conf\n' "$name" "$name"
    printf '  sudo nginx -t && sudo systemctl reload nginx\n'
  fi
}

list_virtual_server_files() {
  printf 'Apache sites:\n'
  ls -1 /etc/apache2/sites-available 2>/dev/null || true
  printf '\nNginx sites:\n'
  ls -1 /etc/nginx/sites-available 2>/dev/null || true
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    create)
      require_root
      shift
      create_virtual_server "${1:-}" "${2:-}" "${3:-both}"
      ;;
    list)
      list_virtual_server_files
      ;;
    -h|--help|help|"")
      usage
      ;;
    *)
      die "unknown command '$cmd' (use --help)"
      ;;
  esac
}

main "$@"
SCRIPT
)"

  write_file_if_changed "$tool_path" "$tool_content" 0755
  log_info "virtualservers helper available at $tool_path"
}

step_main() {
  local key="70-tools"
  if skip_if_done "$key"; then return 0; fi

  if is_yes "$INSTALL_PHPMYADMIN"; then
    ensure_phpmyadmin_alias_helpers
    preseed_phpmyadmin
    install_packages "Installing phpMyAdmin" phpmyadmin

    case "$WEBSERVER" in
      apache)
        configure_apache_phpmyadmin_alias
        run_cmd "Reloading Apache" systemctl reload apache2
        ;;
      nginx)
        configure_nginx_phpmyadmin_alias
        run_cmd "Reloading Nginx" systemctl reload nginx
        ;;
    esac
  else
    log_info "Skipping phpMyAdmin installation"
  fi

  if is_yes "$INSTALL_VIRTUALSERVERS"; then
    install_virtualservers_helper
  else
    log_info "Skipping virtualservers helper installation"
  fi

  mark_done "$key"
}
