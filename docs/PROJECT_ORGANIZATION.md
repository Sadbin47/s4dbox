# Project Organization

This document explains how the s4dbox project is structured and how to add new features safely.

## Directory Layout

- `s4dbox`: main entrypoint and first-time setup flow.
- `install.sh`: one-click installer for local or remote installation.
- `lib/`: shared libraries (colors, logging, system detection, config, users).
- `modules/`: runtime feature modules used by the TUI.
- `apps/install/`: legacy entrypoint shims and categorized install handlers.
- `apps/remove/`: legacy entrypoint shims and categorized remove handlers.
- `apps/nginx/`: optional per-app nginx proxy snippets.
- `docs/`: project documentation.

## App Lifecycle Contract

Each app should follow this contract:

1. Implement app installer in `apps/install/<category>/<app>.sh` with `install_<app>()`.
2. Implement app remover in `apps/remove/<category>/<app>.sh` with `remove_<app>()`.
3. Keep compatibility shims at `apps/install/<app>.sh` and `apps/remove/<app>.sh`.
4. Register app label in `modules/app_manager.sh` (`S4D_APP_DESC`).
5. Optionally add app to first-time setup options in `modules/setup_wizard.sh`.
6. Persist ports/settings using `config_set`.
7. Report status by adding the app case to `app_status` if needed.

## Install/Remove Categories

- `torrent/`: torrent clients and torrent web UIs.
- `media/`: media servers and arr-stack applications.
- `file/`: file management and cloud storage apps.
- `automation/`: automation and CLI tool bundles.
- `network/`: VPN and network access tools.
- `remote/`: remote desktop and GUI-over-web tools.
- `shared/`: shared helper libraries (install side).

## Naming Rules

- App ID: lowercase snake_case (example: `jdownloader2_gui`).
- Installer function: `install_<app_id>`.
- Remover function: `remove_<app_id>`.
- Docker systemd unit: `s4d-<app_id>.service`.
- Docker data path: `/opt/s4dbox/appsdata/<app_id>/`.

## Stability Guidelines

- Keep existing app install/remove behavior unchanged.
- Prefer additive changes over rewrites.
- Keep per-app scripts isolated from each other.
- Keep legacy shim paths valid to avoid breaking existing integrations.
- If an app can break host dependencies, prefer Docker deployment.
- Always validate syntax (`bash -n`) after edits.
