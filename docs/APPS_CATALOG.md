# Apps Catalog

Applications are grouped by function for easier navigation.

## Torrent Clients

Implementation path: `apps/install/torrent/` and `apps/remove/torrent/`

- `qbittorrent`
- `transmission`
- `rtorrent`
- `rutorrent`
- `qui`

## Media and Automation

Implementation path: `apps/install/media/` and `apps/remove/media/`

- `jellyfin`
- `plex`
- `sonarr`
- `readarr`
- `jellyseerr`

## File and Cloud

Implementation path: `apps/install/file/` and `apps/remove/file/`

- `filebrowser`
- `nextcloud`
- `cloudreve`
- `maketorrent_webui`

## Automation and Tools

Implementation path: `apps/install/automation/` and `apps/remove/automation/`

- `autobrr`
- `autodl_irssi`
- `ssh_tools`

## Network and Remote Access

Implementation paths:

- Network apps: `apps/install/network/` and `apps/remove/network/`
- Remote apps: `apps/install/remote/` and `apps/remove/remote/`

- `tailscale`
- `wireguard`
- `openvpn`
- `vnc_desktop`
- `filezilla_gui`
- `jdownloader2_gui`

## Notes

- Docker-based apps use `apps/install/docker_helpers.sh`.
- Legacy paths in `apps/install/*.sh` and `apps/remove/*.sh` are compatibility shims.
- Native apps rely on distro package managers through `pkg_install`.
- App state is tracked in `/etc/s4dbox/installed_apps/`.
