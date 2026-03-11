# s4dbox — Lightweight Universal Seedbox Manager

A modular seedbox management tool built entirely in Bash. No heavy runtimes, no containers — just shell scripts that directly manage your system.

## Features

- **System Monitoring** — Real-time CPU, RAM, disk I/O, and network stats from `/proc` and `/sys`
- **Application Manager** — Install, remove, and manage seedbox apps with auto-configuration
- **System Tuning** — Kernel, network, and disk optimization tuned for torrent workloads
- **Nginx Reverse Proxy** — Auto-generated configs with SSL support for all apps
- **Security Hardening** — SSH hardening, fail2ban, UFW/firewalld baseline firewall
- **Storage Manager** — Disk listing, SMART checks, mount management
- **Network Manager** — Interface stats, port scanning, VPN status
- **Interactive TUI** — Pure bash arrow-key menus, checkboxes, progress bars

## Supported Platforms

| OS Family | Distributions |
|-----------|---------------|
| Debian | Debian, Ubuntu, Linux Mint, Pop!_OS, Kali, Zorin |
| Arch | Arch Linux, Manjaro, EndeavourOS, Garuda |
| RHEL | Fedora, RHEL, CentOS, Rocky, AlmaLinux |

| Architecture | Status |
|-------------|--------|
| x86_64 | ✅ Full support |
| ARM64 (aarch64) | ✅ Full support |

## Quick Install

```bash
# One-click install
curl -fsSL https://raw.githubusercontent.com/s4d/s4dbox/main/install.sh | sudo bash

# Or clone and install
git clone https://github.com/s4d/s4dbox.git
cd s4dbox
sudo ./install.sh
```

## Usage

```bash
sudo s4dbox              # Launch TUI
sudo s4dbox install      # First-time guided setup
sudo s4dbox monitor      # System monitor
sudo s4dbox tune         # Apply system tuning
sudo s4dbox security     # Run security hardening
sudo s4dbox status       # Show installed app status
sudo s4dbox help         # Show help
```

## Supported Applications

| App | Description |
|-----|-------------|
| **qBittorrent** | Torrent client with pre-compiled binaries (4.3.9, 4.5.5, 4.6.7, 5.0.3, 5.1.0β1) |
| **Jellyfin** | Open-source media server |
| **Plex** | Media server |
| **FileBrowser** | Web file manager |
| **rTorrent** | CLI torrent client |
| **ruTorrent** | rTorrent web UI |
| **Tailscale** | WireGuard-based mesh VPN |

## Project Structure

```
s4dbox/
├── s4dbox              # Main entry point
├── install.sh          # One-click installer
├── lib/                # Shared libraries
│   ├── colors.sh       #   Terminal colors & spinners
│   ├── config.sh       #   Configuration management
│   ├── logging.sh      #   File logging
│   ├── system.sh       #   OS/arch detection, package abstraction
│   └── users.sh        #   User management
├── modules/            # Feature modules
│   ├── app_manager.sh  #   App lifecycle management
│   ├── monitor.sh      #   System monitoring
│   ├── network.sh      #   Network tools
│   ├── nginx.sh        #   Nginx reverse proxy
│   ├── security.sh     #   SSH, fail2ban, firewall
│   ├── storage.sh      #   Disk management
│   ├── tui.sh          #   Terminal UI framework
│   └── tune.sh         #   System tuning
└── apps/               # Per-app scripts
    ├── install/        #   Installation scripts
    ├── remove/         #   Removal scripts
    ├── nginx/          #   Nginx configs
    └── configs/        #   App configs
```

## Configuration

- Main config: `/etc/s4dbox/s4dbox.conf`
- App state: `/etc/s4dbox/installed_apps/`
- Logs: `/var/log/s4dbox/s4dbox.log`

## Resource Usage

s4dbox itself uses minimal resources:
- **RAM**: Shell scripts + monitoring reads from `/proc` — under 10MB
- **CPU**: Near zero when idle, brief spikes during installs
- **Disk**: ~500KB for the tool itself

## Credits

- Kernel & network tuning based on [jerry048/Tune](https://github.com/jerry048/Tune)
- Pre-compiled qBittorrent binaries from [jerry048/Seedbox-Components](https://github.com/jerry048/Seedbox-Components)
- Inspired by [swizzin](https://github.com/swizzin/swizzin), [QuickBox](https://github.com/amcrest/quickbox-lite), and [CasaOS](https://github.com/IceWhaleTech/CasaOS)

## License

MIT
