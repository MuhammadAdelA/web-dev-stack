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

step_main() {
  local key="70-tools"
  if skip_if_done "$key"; then return 0; fi

  if is_yes "$INSTALL_PHPMYADMIN"; then
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

  mark_done "$key"
}
