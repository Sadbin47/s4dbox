# s4dbox — Lightweight Universal Seedbox Manager

A modular seedbox management tool built in Bash with a clear app lifecycle and optional Docker-backed services for complex GUI apps.

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
curl -fsSL https://raw.githubusercontent.com/Sadbin47/s4dbox/main/install.sh | sudo bash

# Or clone and install
git clone https://github.com/Sadbin47/s4dbox.git
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

## Documentation

- Project layout and conventions: `docs/PROJECT_ORGANIZATION.md`
- App grouping and IDs: `docs/APPS_CATALOG.md`
- First-time setup logic: `modules/setup_wizard.sh`

## Supported Applications

### Torrent Clients

| App | Description |
|-----|-------------|
| **qBittorrent** | Torrent client with pre-compiled binaries (4.3.9, 4.5.5, 4.6.7, 5.0.3, 5.1.0β1) |
| **Transmission** | Lightweight torrent client |
| **rTorrent** | CLI torrent client |
| **ruTorrent** | rTorrent web UI |
| **Qui** | Modern torrent web UI |

### Media and Automation

| App | Description |
|-----|-------------|
| **Jellyfin** | Open-source media server |
| **Plex** | Media server |
| **Sonarr V4** | TV series automation |
| **Readarr** | Book/audiobook automation |
| **Jellyseerr** | Media request management |
| **autobrr** | Indexer automation and filtering |
| **autodl-irssi** | IRC announce auto-downloader plugin |

### File and Cloud

| App | Description |
|-----|-------------|
| **FileBrowser** | Web file manager |
| **Nextcloud** | Personal cloud platform |
| **Cloudreve** | Multi-user cloud file manager |
| **MakeTorrent WebUI** | Web interface for creating torrent files |

### Tools Bundle

| App | Description |
|-----|-------------|
| **CLI Tools Bundle** | 7z, ffmpeg, mediainfo, mktorrent, mkvinfo, unrar, unzip |

### Network and Remote Access

| App | Description |
|-----|-------------|
| **Tailscale** | WireGuard-based mesh VPN |
| **WireGuard** | WireGuard tools and service-ready setup |
| **OpenVPN** | OpenVPN service-ready setup |
| **VNC Desktop** | Browser-accessible remote desktop |
| **FileZilla GUI** | GUI FTP/SFTP client via web/VNC |
| **JDownloader2 GUI** | GUI downloader via web/VNC |

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
│   ├── setup_wizard.sh #   First-time setup flow
│   ├── storage.sh      #   Disk management
│   ├── tui.sh          #   Terminal UI framework
│   └── tune.sh         #   System tuning
└── apps/               # Per-app scripts
    ├── install/        #   Compatibility shims + categorized installers
    │   ├── torrent/
    │   ├── media/
    │   ├── file/
    │   ├── automation/
    │   ├── network/
    │   ├── remote/
    │   └── shared/
    ├── remove/         #   Compatibility shims + categorized removers
    │   ├── torrent/
    │   ├── media/
    │   ├── file/
    │   ├── automation/
    │   ├── network/
    │   └── remote/
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
- Inspired by [swizzin](https://github.com/swizzin/swizzin), [QuickBoxLite](https://github.com/amcrest/quickbox-lite), and [CasaOS](https://github.com/IceWhaleTech/CasaOS)

## License

MIT
