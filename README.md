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
  - virtualservers helper tool (Apache/Nginx vhost scaffolding)

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
sudo BOOTSTRAP_NON_INTERACTIVE=yes WEBSERVER=none INSTALL_PHP=no INSTALL_COMPOSER=no INSTALL_NODE=yes NODE_MAJOR=22 INSTALL_PNPM=yes INSTALL_YARN=no DB_SERVER=none INSTALL_POSTGRESQL=no INSTALL_REDIS=no INSTALL_PHPMYADMIN=no INSTALL_VIRTUALSERVERS=no ./bootstrap.sh

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

Run with flags only (no config file):

```bash
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | bash -s -- \
  --non-interactive \
  --webserver nginx \
  --install-php yes \
  --php-versions "8.2 8.3" \
  --php-default 8.3 \
  --install-composer yes \
  --install-node yes \
  --node-major 22 \
  --install-pnpm yes \
  --install-yarn no \
  --db-server none \
  --install-postgresql yes \
  --install-redis yes \
  --install-phpmyadmin no \
  --install-virtualservers yes
```

Force real execution when a config enables dry-run:

```bash
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | bash -s -- --config configs/nginx-php-postgres-node.env --no-dry-run --non-interactive
```

Common option flags:

- `--no-dry-run` or `--dry-run`
- `--non-interactive` or `--interactive`
- `--webserver apache|nginx|none`
- `--install-php yes|no`, `--php-versions "..."`
- `--install-composer yes|no`, `--composer-dev-user <user>`
- `--install-node yes|no`, `--node-major <version>`, `--install-pnpm yes|no`, `--install-yarn yes|no`
- `--db-server mysql|mariadb|none`, `--install-postgresql yes|no`, `--install-redis yes|no`
- `--install-phpmyadmin yes|no`, `--phpmyadmin-alias /phpmyadmin`
- `--install-virtualservers yes|no`

Use the virtualservers helper after installation:

```bash
# Create config files for a local dev site (without auto-enabling them)
sudo virtualservers create app.local /var/www/app.local nginx
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

More practical use cases:

```bash
# Install only the virtualservers helper (no full-stack verify)
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | sudo bash -s -- --only 70-tools.sh --install-virtualservers yes --non-interactive --no-dry-run

# Run tools + verify on a minimal machine without expecting web/db/php/node services
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | sudo bash -s -- --from 70-tools.sh --install-virtualservers yes --webserver none --install-php no --install-composer no --install-node no --db-server none --install-postgresql no --install-redis no --install-phpmyadmin no --non-interactive --no-dry-run

# Apply Apache + PHP binding only
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | sudo bash -s -- --only 50-webservers.sh --webserver apache --install-php yes --php-default 8.3 --non-interactive --no-dry-run

# Re-apply Apache + PHP + phpMyAdmin wiring and verify it
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | sudo bash -s -- --from 50-webservers.sh --until 80-verify.sh --webserver apache --install-php yes --php-default 8.3 --install-phpmyadmin yes --db-server mariadb --non-interactive --no-dry-run
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
- `DEV_USER` defaults dynamically to `SUDO_USER`, then `USER`, then `root`; `COMPOSER_DEV_USER` defaults to `DEV_USER`.
- Composer verification prefers running as a non-root dev user. If that user does not exist, verification falls back to `COMPOSER_ALLOW_SUPERUSER=1`.
- phpMyAdmin is optional and requires PHP plus Apache or Nginx, and a MySQL-compatible server.
- virtualservers is optional and installs `/usr/local/bin/virtualservers` for scaffolding Apache/Nginx site files.
- For Apache + PHP, the bootstrap explicitly enables `php${PHP_DEFAULT_VERSION}` and verifies it with `a2query`.
- For Nginx, the script writes a reusable snippet to `/etc/nginx/snippets/phpmyadmin.conf`.

## Troubleshooting

- `Verification failed for nginx-version` after using `--from 70-tools.sh`:
Cause: `--from 70-tools.sh` still runs `80-verify.sh`, and defaults may expect Nginx when no config/flags are provided.
Fix: use `--only 70-tools.sh` for tool-only install, or pass explicit flags to disable unrelated checks (`--webserver none --install-php no --install-node no --db-server none ...`).

- phpMyAdmin installed but PHP is not executing through Apache:
Cause: Apache PHP module/MPM/binding may not match the selected PHP default in partial runs.
Fix: re-run from webserver through verify:
`curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | sudo bash -s -- --from 50-webservers.sh --until 80-verify.sh --webserver apache --install-php yes --php-default 8.3 --install-phpmyadmin yes --db-server mariadb --non-interactive --no-dry-run`

- `Permission denied` under `/var/log/web-dev-bootstrap` or `/var/lib/web-dev-bootstrap`:
Cause: real mode (`--no-dry-run`) writes system paths and requires root.
Fix: run with `sudo`.

- `Another bootstrap process is already running`:
Cause: two bootstrap commands ran concurrently.
Fix: run one bootstrap command at a time and retry.
