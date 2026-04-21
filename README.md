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

## Installation examples

Local checkout:

```bash
# Interactive (prompts enabled)
sudo ./bootstrap.sh

# Scenario 1: Nginx + PHP + Composer + Node + pnpm + PostgreSQL + Redis
sudo ./bootstrap.sh --config configs/nginx-php-postgres-node.env --non-interactive

# Scenario 2: Apache + PHP + Composer + MariaDB + phpMyAdmin
sudo ./bootstrap.sh --config configs/apache-php-mariadb-phpmyadmin.env --non-interactive

# Scenario 3: Minimal Node-only environment
sudo BOOTSTRAP_NON_INTERACTIVE=yes WEBSERVER=none INSTALL_PHP=no INSTALL_COMPOSER=no INSTALL_NODE=yes NODE_MAJOR=22 INSTALL_PNPM=yes INSTALL_YARN=no DB_SERVER=none INSTALL_POSTGRESQL=no INSTALL_REDIS=no INSTALL_PHPMYADMIN=no ./bootstrap.sh

# Re-run only verification on an already prepared machine
sudo ./bootstrap.sh --only 80-verify.sh --non-interactive
```

## Online installer

Run directly from GitHub (default branch):

```bash
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | bash -s -- --dry-run
```

When run via a non-interactive stdin stream (for example `curl | bash`), the bootstrap auto-enables non-interactive mode and uses env/config/default values.

Run a real install:

```bash
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | bash -s -- --non-interactive
```

Use a bundled config profile with the online installer:

```bash
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | bash -s -- --non-interactive --config configs/nginx-php-postgres-node.env
```

Run selected steps only:

```bash
# Step range
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | bash -s -- --dry-run --from 20-repositories.sh --until 40-runtimes.sh

# Verify step only
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | bash -s -- --non-interactive --only 80-verify.sh
```

Pin a specific branch or tag for the downloaded kit:

```bash
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | REF=<branch-or-tag> bash -s -- --dry-run
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
