# Codex Project Guidance

You are working inside a VS Code + Ubuntu environment to test and, if necessary, improve a general-purpose post-golden-image web development bootstrap kit.

## Main objective
Build, validate, and harden a reusable Ubuntu bootstrap system for general web development environments after a clean/generic golden image. This is NOT tied to any specific application or product. The goal is to prepare a web development workstation/server baseline on Ubuntu with optional components selected at runtime.

## Current project status
A first working implementation already exists as a standalone kit. The current artifact includes:
- bootstrap.sh
- bootstrap.env.example
- README.md
- a step-based shell structure with logging, summary output, dry-run support, and interactive/non-interactive modes

## What has already been completed
1. A standalone bootstrap kit was created, separate from any product-specific codebase.
2. The kit supports optional installation/selection of:
   - Apache
   - Nginx
   - Multiple PHP versions
   - Composer
   - Node.js
   - pnpm
   - Yarn
   - MySQL OR MariaDB
   - PostgreSQL
   - Redis
   - phpMyAdmin
3. The design already enforces key operational principles:
   - idempotent behavior as much as possible
   - no silent failure
   - step-based execution
   - structured logging
   - conflict-aware decisions
   - post-step verification
4. Composer verification logic was intentionally designed to avoid treating the “running as root” warning as a hard failure.
5. phpMyAdmin was explicitly included as an optional component.
6. Initial validation already passed:
   - shell syntax checks
   - --list style checks
   - dry-run scenarios
7. A previous dry-run/state-file issue was already fixed by separating state per run.
8. Important limitation: real service installation was NOT fully validated on a real Ubuntu 24.04 target yet. Current validation is structural + dry-run oriented, not final production-like runtime validation.

## Primary constraints you must preserve
- This is a GENERAL web development bootstrap kit, not tied to any one project.
- Do NOT turn it into a product-specific scaffold.
- Keep the golden image philosophy intact:
  - the base image should remain generic and clean
  - all customization belongs in post-boot bootstrap
- No GUI.
- Use scripts only.
- No silent failures.
- Every meaningful failure must be surfaced clearly with logs and exit codes.
- Avoid destructive overwrites.
- Back up or preserve existing config where reasonable.
- Treat MySQL and MariaDB as mutually exclusive primary DB server choices unless there is a clearly justified and safe exception.
- Apache/Nginx coexistence must be handled explicitly and safely.
- Multiple PHP versions are allowed, but default selection must be explicit and predictable.
- phpMyAdmin must remain optional, not forced by default.
- Do not assume root-only workflows for verification if a safer non-root check exists.
- Dry-run must remain supported.
- Non-interactive execution via env/config must remain supported.
- Do not replace the current architecture with a completely different toolchain unless absolutely necessary.

## Target environment for real validation
- Ubuntu 24.04
- Bash-based execution
- Real package installation and service checks
- Intended usage from VS Code connected to Ubuntu

## Your tasks
1. Inspect the current kit and understand the existing structure before changing anything.
2. Run realistic validation on Ubuntu 24.04, not just syntax and dry-run.
3. Confirm whether the current implementation actually works end-to-end for selected scenarios.
4. Fix issues only where necessary.
5. Improve robustness without bloating the kit.
6. Preserve the general-purpose nature of the project.

## Functional expectations
The bootstrap system should support:
- interactive mode
- non-interactive mode
- selective component enablement
- step-based execution
- dry-run mode
- resumable/re-runnable behavior where possible
- logging to files and stdout
- summary output at the end
- preflight checks
- verification after installation

## Expected component behavior
- Web server:
  - apache / nginx / both / none
- PHP:
  - one or multiple selected versions
  - explicit default CLI version
- Composer:
  - must verify successfully without treating root warning behavior as an install failure
- Node:
  - install a predictable version strategy
- Package managers:
  - npm / pnpm / yarn as applicable
- Database:
  - mysql OR mariadb
  - optional postgresql
  - optional redis
- phpMyAdmin:
  - optional
  - should only be enabled when the environment makes sense
  - should not be exposed carelessly by default

## Testing expectations
Please validate at least these scenarios on real Ubuntu 24.04:
1. Nginx + PHP 8.2/8.3 + Composer + Node + pnpm + PostgreSQL + Redis
2. Apache + PHP 8.3 + Composer + MariaDB + phpMyAdmin
3. Minimal Node-only web dev environment
4. Re-run behavior on an already prepared machine
5. Failure-path checks:
   - invalid conflicting DB selection
   - invalid PHP default selection
   - missing repo/package failure visibility
   - service verification failure visibility

## What to pay special attention to
- apt/repository correctness on Ubuntu 24.04
- service enable/start/status verification
- port conflicts
- Apache/Nginx coexistence behavior
- PHP package naming/versioning correctness
- Composer install/verification behavior
- phpMyAdmin integration quality
- idempotency and re-run safety
- logging clarity
- state handling
- summary/report accuracy

## Preferred development approach
- Make minimal, targeted fixes first
- Keep the step-based shell architecture
- Improve reliability before adding new features
- Prefer clear shell over clever shell
- Document any behavior changes in README
- Do not silently remove features that were explicitly requested

## Required deliverables
1. Updated bootstrap kit code if changes are needed
2. A concise change summary
3. Real Ubuntu 24.04 test results
4. A list of anything still not fully reliable
5. Clear notes on how to run:
   - dry-run
   - interactive
   - non-interactive
6. Any recommended next improvements, but only after validation is complete

## Acceptance standard
The work is successful only if the kit is validated on real Ubuntu 24.04 with actual installation/service checks and remains:
- generic
- script-only
- safe to re-run
- clear in logging
- explicit in failures
- optional/component-driven
- suitable for post-golden-image setup of a general web development environment