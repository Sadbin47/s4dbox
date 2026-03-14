# Apps Catalog

Applications are grouped by function for easier navigation.

## Torrent Clients

Implementation path: `apps/install/*.sh` and `apps/remove/*.sh`

- `qbittorrent`
- `rtorrent`
- `rutorrent`
- `qui`

## Media and Automation

Implementation path: `apps/install/*.sh` and `apps/remove/*.sh`

- `jellyfin`
- `plex`
- `sonarr`
- `prowlarr`
- `jackett`
- `jellyseerr`

## File and Cloud

Implementation path: `apps/install/*.sh` and `apps/remove/*.sh`

- `filebrowser`
- `nextcloud`
- `cloudreve`
- `maketorrent_webui`

## Automation and Tools

Implementation path: `apps/install/*.sh` and `apps/remove/*.sh`

- `autobrr`
- `autodl_irssi`
- `ssh_tools`

## Network and Remote Access

Implementation path: `apps/install/*.sh` and `apps/remove/*.sh`

- `tailscale`
- `wireguard`
- `openvpn`
- `vnc_desktop`
- `filezilla_gui`
- `jdownloader2_gui`

## Notes

- Docker-based apps use `apps/install/docker_helpers.sh`.
- Native apps rely on distro package managers through `pkg_install`.
- App state is tracked in `/etc/s4dbox/installed_apps/`.
