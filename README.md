# s4dbox

Simple seedbox manager in Bash.

Use it to install and manage torrent, media, cloud, and remote-access apps from one TUI.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/Sadbin47/s4dbox/main/install.sh | sudo bash
sudo s4dbox
```

## Main Commands

```bash
sudo s4dbox              # open TUI
sudo s4dbox install      # first-time setup wizard
sudo s4dbox status       # show app status
sudo s4dbox monitor      # system monitor
sudo s4dbox tune         # apply tuning profile
sudo s4dbox security     # ssh/firewall/fail2ban
sudo s4dbox help         # command help
```

## What It Manages

- Torrent clients: qBittorrent, rTorrent, ruTorrent, Qui
- Media stack: Jellyfin, Plex, Sonarr, Prowlarr, Jackett, Jellyseerr
- File/cloud: FileBrowser, Nextcloud, Cloudreve, MakeTorrent WebUI
- Automation/tools: autobrr, autodl-irssi, CLI tools bundle
- Network/remote: Tailscale, WireGuard, OpenVPN, VNC Desktop, FileZilla GUI, JDownloader2 GUI

## Notes

- Nginx reverse proxy is optional.
- Some apps work best on direct ports instead of path proxies.
- Main config: `/etc/s4dbox/s4dbox.conf`
- Installed app state: `/etc/s4dbox/installed_apps/`
- Log file: `/var/log/s4dbox/s4dbox.log`

## Docs

- Project organization: [docs/PROJECT_ORGANIZATION.md](docs/PROJECT_ORGANIZATION.md)
- App catalog: [docs/APPS_CATALOG.md](docs/APPS_CATALOG.md)

## License

MIT. See [LICENSE](LICENSE).