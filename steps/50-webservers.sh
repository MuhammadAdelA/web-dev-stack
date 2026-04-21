#!/usr/bin/env bash
set -Eeuo pipefail

configure_apache_phpmyadmin_alias() {
  local conf_target="/etc/apache2/conf-available/phpmyadmin-bootstrap.conf"
  local content
  content="Alias ${PHPMYADMIN_ALIAS} /usr/share/phpmyadmin\n<Directory /usr/share/phpmyadmin>\n    Options SymLinksIfOwnerMatch\n    DirectoryIndex index.php\n    AllowOverride None\n    Require all granted\n</Directory>\n"
  write_file_if_changed "$conf_target" "$(printf '%b' "$content")"
  run_cmd "Enabling phpMyAdmin Apache config" a2enconf phpmyadmin-bootstrap
}

configure_nginx_phpmyadmin_alias() {
  local conf_target="/etc/nginx/snippets/phpmyadmin.conf"
  local content
  content="location ${PHPMYADMIN_ALIAS} {\n    alias /usr/share/phpmyadmin;\n    index index.php;\n}\nlocation ~ ^${PHPMYADMIN_ALIAS}/(.+\\.php)$ {\n    alias /usr/share/phpmyadmin/$1;\n    include snippets/fastcgi-php.conf;\n    fastcgi_param SCRIPT_FILENAME /usr/share/phpmyadmin/$1;\n    fastcgi_pass unix:/run/php/php${PHP_DEFAULT_VERSION}-fpm.sock;\n}\n"
  write_file_if_changed "$conf_target" "$(printf '%b' "$content")"
  log_warn "Nginx phpMyAdmin snippet written to $conf_target; include it in your server block manually if needed"
}

step_main() {
  local key="50-webservers"
  if skip_if_done "$key"; then return 0; fi

  case "$WEBSERVER" in
    apache)
      install_packages "Installing Apache" apache2
      run_cmd "Enabling Apache rewrite" a2enmod rewrite
      run_cmd "Enabling Apache headers" a2enmod headers
      run_cmd "Enabling Apache" systemctl enable apache2
      run_cmd "Starting Apache" systemctl restart apache2
      ;;
    nginx)
      install_packages "Installing Nginx" nginx
      run_cmd "Enabling Nginx" systemctl enable nginx
      run_cmd "Starting Nginx" systemctl restart nginx
      ;;
    none)
      log_info "Skipping web server installation"
      ;;
  esac

  mark_done "$key"
}
