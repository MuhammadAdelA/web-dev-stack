# Web Dev Bootstrap Kit

A standalone post-golden-image bootstrap kit for Ubuntu 24.04+ that prepares a general web development environment.

## Features

- Step-based bootstrap runner
- Dry-run mode
- Interactive or non-interactive configuration
- Structured logging and machine-readable summary
- Conflict-aware validation
- Optional components:
  - Apache or Nginx
  - Multiple PHP versions
  - Composer
  - Node.js + pnpm/yarn
  - MySQL or MariaDB
  - PostgreSQL
  - Redis
  - phpMyAdmin

## Quick start

```bash
sudo cp bootstrap.env.example bootstrap.env
sudo BOOTSTRAP_ENV=$PWD/bootstrap.env ./bootstrap.sh
```

Dry-run example:

```bash
sudo ./bootstrap.sh --config configs/nginx-php-postgres-node.env --dry-run
```

## Available steps

- `00-preflight.sh`
- `10-input.sh`
- `20-repositories.sh`
- `30-packages-base.sh`
- `40-runtimes.sh`
- `50-webservers.sh`
- `60-databases.sh`
- `70-tools.sh`
- `80-verify.sh`
- `90-summary.sh`

## Notes

- This kit targets Ubuntu 24.04 or newer.
- It keeps the golden image generic; project-specific setup should happen after boot.
- Composer verification prefers running as a non-root dev user. If that user does not exist, verification falls back to `COMPOSER_ALLOW_SUPERUSER=1`.
- phpMyAdmin is optional and requires PHP plus Apache or Nginx, and a MySQL-compatible server.
- For Nginx, the script writes a reusable snippet to `/etc/nginx/snippets/phpmyadmin.conf`.
