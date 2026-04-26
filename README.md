# Web Dev Stack Bootstrap

`web-dev-stack` is a standalone bootstrap kit for preparing an Ubuntu web-development machine after the base OS is installed.

It is useful when you want a repeatable way to turn a fresh Ubuntu VM, cloud instance, WSL-like environment, or local development server into a ready-to-use web development box with PHP, Node.js, databases, web servers, Redis, phpMyAdmin, and local virtual-host helpers.

This repository is **not an application framework** and it does not create a project for you. It prepares the machine that your projects will run on.

---

## What this project solves

A new development machine usually needs the same setup work every time:

- enable the right package repositories;
- install base tools;
- install PHP and common extensions;
- install Composer;
- install Node.js and package managers;
- install and start web servers;
- install databases and Redis;
- create local development database users;
- apply safe development defaults;
- verify that everything actually works.

`web-dev-stack` automates that setup using small ordered steps that can be run fully, partially, or only in dry-run mode.

---

## Supported target

- Ubuntu **24.04 or newer**
- Root or `sudo` access
- `apt-get` based systems
- `systemd` based service management for full service checks

Dry-run mode can run in more limited environments, but real installation is intended for Ubuntu.

---

## Main features

| Area | What it provides |
| --- | --- |
| Runner | Step-based bootstrap script with `--only`, `--from`, and `--until` |
| Safety | Dry-run mode, non-interactive mode, validation, lock file, logs |
| Web servers | Apache, Nginx, or no web server |
| PHP | One or more PHP versions, default CLI PHP, common extensions, PHP-FPM |
| Composer | Global Composer installation and non-root verification |
| Node.js | NodeSource-based Node.js, optional pnpm and Yarn |
| Databases | MySQL or MariaDB, optional PostgreSQL, optional Redis |
| Dev DB user | Optional development DB user/password setup |
| Tools | Optional phpMyAdmin and `virtualservers` helper |
| Presets | Optional development presets for Apache, PHP, MySQL/MariaDB, phpMyAdmin, Node corepack |
| Verification | Post-install verification for installed commands and services |
| CI | GitHub Actions workflow for ShellCheck, syntax checks, and bootstrap dry-runs |

---

## Repository layout

```text
.
├── bootstrap.sh                  # Main runner
├── install.sh                    # Online installer wrapper
├── bootstrap.env.example         # Example environment configuration
├── configs/                      # Ready-made dry-run config profiles
├── lib/                          # Shared shell helpers
├── steps/                        # Ordered bootstrap steps
├── scripts/                      # Convenience run scripts
└── .github/workflows/            # CI checks
```

The bootstrap flow is intentionally split into files so you can run only the part you need.

---

## Available steps

```text
00-preflight.sh
10-input.sh
20-repositories.sh
30-packages-base.sh
40-runtimes.sh
50-webservers.sh
60-databases.sh
70-tools.sh
75-dev-preconfig.sh
80-verify.sh
90-summary.sh
```

List them from the CLI:

```bash
./bootstrap.sh --list
```

---

## Quick start: local checkout

Clone the repository, review the config, then run a dry-run first.

```bash
git clone https://github.com/MuhammadAdelA/web-dev-stack.git
cd web-dev-stack
cp bootstrap.env.example bootstrap.env
sudo BOOTSTRAP_ENV=$PWD/bootstrap.env ./bootstrap.sh --dry-run --non-interactive
```

Run for real after reviewing the plan:

```bash
sudo BOOTSTRAP_ENV=$PWD/bootstrap.env ./bootstrap.sh --no-dry-run --non-interactive
```

---

## Quick start: online installer

Run directly from GitHub in dry-run mode:

```bash
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | \
  bash -s -- --dry-run --non-interactive
```

Run a real install with explicit options:

```bash
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | \
  bash -s -- \
    --no-dry-run \
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
    --db-server mariadb \
    --configure-dev-db-user yes \
    --db-dev-password "ChangeMe-Use-A-Real-Password" \
    --install-postgresql yes \
    --install-redis yes
```

When using `curl | bash`, stdin is not interactive. The bootstrap detects that and runs with current environment, config, or default values.

---

## Built-in configuration profiles

The `configs/` directory contains ready-made profiles.

| File | Intended use | Notes |
| --- | --- | --- |
| `configs/nginx-php-postgres-node.env` | Nginx, PHP, Composer, Node, pnpm, PostgreSQL, Redis, virtualservers | Good for Laravel/API work without MySQL-family DB |
| `configs/apache-php-mariadb-phpmyadmin-node.env` | Apache, PHP, Composer, MariaDB, phpMyAdmin, Node, dev presets | Good for classic PHP/phpMyAdmin workflows |

The bundled config profiles intentionally set:

```bash
BOOTSTRAP_DRY_RUN=yes
```

Use `--no-dry-run` when you are ready to apply them for real.

Example:

```bash
sudo ./bootstrap.sh \
  --config configs/apache-php-mariadb-phpmyadmin-node.env \
  --no-dry-run \
  --non-interactive \
  --db-dev-password "Use-A-Strong-Local-Password"
```

---

## Real-world scenarios

### 1. Fresh Ubuntu VM for Laravel development

Use this when you want PHP, Composer, Nginx, PostgreSQL, Redis, Node.js, and pnpm.

```bash
sudo ./bootstrap.sh \
  --config configs/nginx-php-postgres-node.env \
  --no-dry-run \
  --non-interactive \
  --db-dev-password "LocalDevOnly-StrongPass"
```

After it finishes, verify the important tools:

```bash
php -v
composer --version
node -v
pnpm -v
psql --version
redis-server --version
```

A typical next step would be cloning a Laravel project into `/var/www` and configuring an Nginx server block or using your own project-specific deployment script.

---

### 2. Classic PHP box with Apache, MariaDB, and phpMyAdmin

Use this when you want an environment similar to a traditional LAMP setup, but managed through explicit steps.

```bash
sudo ./bootstrap.sh \
  --config configs/apache-php-mariadb-phpmyadmin-node.env \
  --no-dry-run \
  --non-interactive \
  --db-dev-user "$USER" \
  --db-dev-password "LocalMariaDB-StrongPass"
```

This profile can install phpMyAdmin and apply bundled development presets.

Useful verification commands:

```bash
apache2 -v
php -v
mariadb --version
systemctl status apache2 --no-pager
systemctl status mariadb --no-pager
```

Open phpMyAdmin locally:

```text
http://127.0.0.1/phpmyadmin
```

---

### 3. Minimal machine with no web server and no databases

Use this when you only want to verify the runner or prepare a machine without installing services.

```bash
sudo ./bootstrap.sh \
  --dry-run \
  --non-interactive \
  --webserver none \
  --install-php no \
  --install-composer no \
  --install-node no \
  --install-pnpm no \
  --install-yarn no \
  --db-server none \
  --configure-dev-db-user no \
  --install-postgresql no \
  --install-redis no \
  --install-phpmyadmin no \
  --install-virtualservers no
```

This is also the style used by the CI dry-run check to ensure the runner can validate a minimal no-service setup.

---

### 4. Install only Node.js and pnpm

```bash
sudo ./bootstrap.sh \
  --no-dry-run \
  --non-interactive \
  --webserver none \
  --install-php no \
  --install-composer no \
  --install-node yes \
  --node-major 22 \
  --install-pnpm yes \
  --install-yarn no \
  --db-server none \
  --configure-dev-db-user no \
  --install-postgresql no \
  --install-redis no \
  --install-phpmyadmin no \
  --install-virtualservers no
```

---

### 5. Install only the virtual host helper

The optional `virtualservers` helper creates Apache/Nginx site files and document roots. It does not enable sites automatically.

Install only the helper:

```bash
sudo ./bootstrap.sh \
  --only 70-tools.sh \
  --no-dry-run \
  --non-interactive \
  --install-virtualservers yes
```

Create a local Nginx site scaffold:

```bash
sudo virtualservers create app.local /var/www/app.local nginx
```

Then enable the Nginx site manually:

```bash
sudo ln -s /etc/nginx/sites-available/app.local.conf /etc/nginx/sites-enabled/app.local.conf
sudo nginx -t
sudo systemctl reload nginx
```

---

### 6. Re-run verification only

Use this after manually changing services or after a partial run.

```bash
sudo ./bootstrap.sh --only 80-verify.sh --non-interactive
```

If the default settings do not match what is actually installed, pass explicit flags so verification knows what to expect.

Example: verify a no-webserver PostgreSQL-only machine:

```bash
sudo ./bootstrap.sh \
  --only 80-verify.sh \
  --non-interactive \
  --webserver none \
  --install-php no \
  --install-composer no \
  --install-node no \
  --install-pnpm no \
  --install-yarn no \
  --db-server none \
  --install-postgresql yes \
  --install-redis no \
  --install-phpmyadmin no \
  --install-virtualservers no
```

---

### 7. Re-apply Apache, PHP, and phpMyAdmin wiring

Useful when packages are already installed but Apache/PHP/phpMyAdmin binding needs to be refreshed.

```bash
sudo ./bootstrap.sh \
  --from 50-webservers.sh \
  --until 80-verify.sh \
  --no-dry-run \
  --non-interactive \
  --webserver apache \
  --install-php yes \
  --php-versions "8.3" \
  --php-default 8.3 \
  --install-phpmyadmin yes \
  --db-server mariadb
```

---

## Common CLI options

| Option | Values | Description |
| --- | --- | --- |
| `--dry-run` / `--no-dry-run` | yes/no behavior | Preview actions or execute them |
| `--non-interactive` / `--interactive` | mode | Disable or enable prompts |
| `--config <file>` | path | Load a shell-style config file |
| `--webserver` | `apache`, `nginx`, `none` | Choose web server |
| `--install-php` | `yes`, `no` | Install PHP runtimes |
| `--php-versions` | quoted list | Example: `"8.2 8.3"` |
| `--php-default` | version | Default CLI/Apache PHP version |
| `--install-composer` | `yes`, `no` | Install Composer globally |
| `--install-node` | `yes`, `no` | Install Node.js |
| `--node-major` | major version | Example: `22` |
| `--install-pnpm` | `yes`, `no` | Install pnpm globally |
| `--install-yarn` | `yes`, `no` | Install Yarn globally |
| `--db-server` | `mysql`, `mariadb`, `none` | Primary MySQL-family DB |
| `--install-postgresql` | `yes`, `no` | Install PostgreSQL |
| `--install-redis` | `yes`, `no` | Install Redis |
| `--configure-dev-db-user` | `yes`, `no` | Create/update dev DB user |
| `--db-dev-user` | username | DB development username |
| `--db-dev-password` | password | DB development password |
| `--install-phpmyadmin` | `yes`, `no` | Install phpMyAdmin |
| `--phpmyadmin-alias` | path | Default: `/phpmyadmin` |
| `--install-virtualservers` | `yes`, `no` | Install helper tool |
| `--apply-dev-presets` | `yes`, `no` | Apply bundled dev configs |
| `--only <step>` | step filename | Run exactly one step |
| `--from <step>` | step filename | Start from a step |
| `--until <step>` | step filename | Stop after a step |
| `--list` | none | List available steps |

---

## Configuration files

You can configure the bootstrap through any combination of:

1. CLI flags;
2. `--config <file>`;
3. `BOOTSTRAP_ENV=/path/to/file`;
4. environment variables;
5. built-in defaults.

Example config:

```bash
BOOTSTRAP_DRY_RUN=no
BOOTSTRAP_NON_INTERACTIVE=yes
WEBSERVER=nginx
INSTALL_PHP=yes
PHP_VERSIONS="8.2 8.3"
PHP_DEFAULT_VERSION=8.3
INSTALL_COMPOSER=yes
INSTALL_NODE=yes
NODE_MAJOR=22
INSTALL_PNPM=yes
INSTALL_YARN=no
DB_SERVER=mariadb
CONFIGURE_DEV_DB_USER=yes
DB_DEV_USER=developer
DB_DEV_PASSWORD=ChangeThisPassword
INSTALL_POSTGRESQL=yes
INSTALL_REDIS=yes
INSTALL_PHPMYADMIN=no
INSTALL_VIRTUALSERVERS=yes
APPLY_DEV_PRESETS=no
```

Run with it:

```bash
sudo ./bootstrap.sh --config ./my-bootstrap.env --non-interactive
```

Important: config files are sourced by Bash. Only use config files you trust.

---

## Development presets

Set this when you want the bootstrap to apply development-oriented defaults:

```bash
--apply-dev-presets yes
```

The bundled presets may include:

- Apache development directory configuration;
- PHP development ini values such as `display_errors`, larger upload limits, and timezone;
- MySQL/MariaDB `utf8mb4` defaults;
- phpMyAdmin temp directory configuration;
- Node corepack shims.

These presets are intended for local development machines, not hardened production servers.

---

## Logs, summaries, and verification

The bootstrap writes logs and summaries for every run.

Real mode defaults:

```text
/var/log/web-dev-bootstrap/
/var/lib/web-dev-bootstrap/
```

Dry-run mode defaults:

```text
/tmp/web-dev-bootstrap/logs/
/tmp/web-dev-bootstrap/state/
```

Files created per run:

```text
bootstrap-<RUN_ID>.log
summary-<RUN_ID>.tsv
summary-<RUN_ID>.jsonl
bootstrap-<RUN_ID>.state
```

Sensitive DB password details are redacted from log and summary output.

---

## Online installer details

The online installer downloads the repository archive and then runs `bootstrap.sh`.

Default:

```bash
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | \
  bash -s -- --dry-run
```

Use another branch:

```bash
curl -fsSL https://raw.githubusercontent.com/MuhammadAdelA/web-dev-stack/main/install.sh | \
  REF=my-branch bash -s -- --dry-run
```

Current note: `install.sh` downloads from `refs/heads/$REF`, so `REF` is currently a branch name.

---

## CI checks

The repository includes a GitHub Actions workflow that runs on pull requests, pushes to `main`, and manual dispatch.

It checks:

- Bash syntax for shell scripts;
- Bash syntax for env-style config files;
- ShellCheck with sourced-file analysis;
- dry-run bootstrap scenarios for common profiles;
- dry-run bootstrap scenario for a minimal no-service profile.

---

## Security and safety notes

- Run a dry-run before real installation.
- Do not use the default `Password123` outside disposable local development.
- Prefer passing a strong local password through `--db-dev-password` or a private config file.
- Config files are Bash-sourced; do not run untrusted config files.
- The script changes packages, services, users/groups, `/var/www`, and system config files in real mode.
- This project is designed for development environments, not production hardening.
- phpMyAdmin should be used carefully and only when you need it.
- For public or shared servers, review every selected component before running `--no-dry-run`.

---

## Troubleshooting

### `INSTALL_PNPM=yes requires INSTALL_NODE=yes`

You disabled Node.js but left pnpm enabled.

Fix:

```bash
--install-node no --install-pnpm no --install-yarn no
```

---

### `Verification failed for nginx-version`

The verification step expected Nginx, but Nginx is not installed or was disabled in your intended setup.

Fix by passing the real machine profile:

```bash
sudo ./bootstrap.sh \
  --only 80-verify.sh \
  --non-interactive \
  --webserver none
```

Also disable unrelated components if they are not installed.

---

### phpMyAdmin is installed but not reachable through Nginx

For Nginx, the bootstrap writes a reusable snippet:

```text
/etc/nginx/snippets/phpmyadmin.conf
```

Include it in your server block and reload Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

### Permission denied under `/var/log/web-dev-bootstrap`

Real mode writes to system paths.

Fix:

```bash
sudo ./bootstrap.sh --no-dry-run
```

---

### `Another bootstrap process is already running`

A lock file is active because another bootstrap process is running.

Fix: wait for the other run to finish. If you are sure no process is running, inspect:

```text
/var/lib/web-dev-bootstrap/bootstrap.lock
```

---

### MySQL, MariaDB, or PostgreSQL dev login fails

The configured username/password may not match the DB state.

Re-run database setup with explicit credentials:

```bash
sudo ./bootstrap.sh \
  --only 60-databases.sh \
  --no-dry-run \
  --non-interactive \
  --configure-dev-db-user yes \
  --db-dev-user "$USER" \
  --db-dev-password "NewLocalDevPassword"
```

---

## Recommended workflow

For safest usage:

1. Start with a fresh Ubuntu 24.04+ machine.
2. Run a dry-run with the exact profile you want.
3. Review the printed bootstrap plan.
4. Override the default DB password.
5. Run with `--no-dry-run`.
6. Check the summary file.
7. Run project-specific setup after the machine bootstrap finishes.

Example:

```bash
sudo ./bootstrap.sh --config configs/nginx-php-postgres-node.env --dry-run --non-interactive
sudo ./bootstrap.sh \
  --config configs/nginx-php-postgres-node.env \
  --no-dry-run \
  --non-interactive \
  --db-dev-password "StrongLocalPassword"
```

---

## License

No license file is currently included. Add one before distributing or reusing this project outside your own account or organization.
