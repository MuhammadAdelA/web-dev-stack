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

configure_apache_php_handler() {
  local php_module="php${PHP_DEFAULT_VERSION}"

  install_packages "Ensuring Apache PHP module package for PHP $PHP_DEFAULT_VERSION" "libapache2-mod-php${PHP_DEFAULT_VERSION}"

  # mod_php requires Apache prefork MPM; switch from event when needed.
  run_bash "Ensuring Apache prefork MPM for mod_php" "
if a2query -m mpm_event >/dev/null 2>&1; then
  a2dismod mpm_event
fi
a2enmod mpm_prefork
"

  # Keep Apache PHP handler explicit and predictable on re-runs.
  run_bash "Disabling non-default Apache PHP modules" "
for mod_file in /etc/apache2/mods-enabled/php*.load; do
  [ -e \"\$mod_file\" ] || continue
  mod_name=\$(basename \"\$mod_file\" .load)
  if [ \"\$mod_name\" != \"$php_module\" ]; then
    a2dismod \"\$mod_name\"
  fi
done
"
  run_cmd "Enabling Apache PHP module $php_module" a2enmod "$php_module"
}

step_main() {
  local key="50-webservers"
  if skip_if_done "$key"; then return 0; fi

  case "$WEBSERVER" in
    apache)
      install_packages "Installing Apache" apache2
      run_cmd "Enabling Apache rewrite" a2enmod rewrite
      run_cmd "Enabling Apache headers" a2enmod headers
      ensure_web_root_owned_by_dev_user
      if is_yes "$INSTALL_PHP"; then
        configure_apache_php_handler
      fi
      run_cmd "Enabling Apache" systemctl enable apache2
      reload_or_restart_service apache2
      ;;
    nginx)
      install_packages "Installing Nginx" nginx
      ensure_web_root_owned_by_dev_user
      run_cmd "Enabling Nginx" systemctl enable nginx
      reload_or_restart_service nginx
      ;;
    none)
      log_info "Skipping web server installation"
      ;;
  esac

  mark_done "$key"
}
