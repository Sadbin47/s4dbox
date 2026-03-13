#!/usr/bin/env bash
# s4dbox - MakeTorrent WebUI installer

install_maketorrent_webui() {
    local port username app_dir app_file service_file

    username="$(get_seedbox_user)"
    [[ -z "$username" ]] && username="$(prompt_user_setup)"

    port="$(tui_input "MakeTorrent WebUI port" "8899")"
    app_dir="/opt/s4dbox/appsdata/maketorrent-webui"
    app_file="${app_dir}/app.py"
    service_file="/etc/systemd/system/maketorrent-webui.service"

    msg_step "Installing MakeTorrent WebUI"

    spinner_start "Installing dependencies"
    case "$S4D_DISTRO_FAMILY" in
        debian)
            pkg_install python3
            pkg_install python3-flask
            pkg_install mktorrent
            ;;
        arch)
            pkg_install python
            pkg_install python-flask
            pkg_install mktorrent
            ;;
        rhel|suse)
            pkg_install python3
            pkg_install python3-flask
            pkg_install mktorrent
            ;;
        *)
            spinner_stop 1
            msg_error "Unsupported distro for MakeTorrent WebUI"
            return 1
            ;;
    esac
    local rc=$?
    spinner_stop $rc
    [[ $rc -ne 0 ]] && return 1

    mkdir -p "$app_dir"

    cat > "$app_file" <<'PYAPP'
from flask import Flask, request, render_template_string
import os
import subprocess

app = Flask(__name__)

TEMPLATE = """
<!doctype html>
<html>
<head><title>MakeTorrent WebUI</title></head>
<body style=\"font-family: sans-serif; max-width: 840px; margin: 2rem auto;\">
  <h2>MakeTorrent WebUI</h2>
  <form method=\"post\">
    <p><label>Source path<br><input name=\"source\" style=\"width:100%\" required></label></p>
    <p><label>Output .torrent file<br><input name=\"output\" style=\"width:100%\" required></label></p>
    <p><label>Tracker URL<br><input name=\"tracker\" style=\"width:100%\" required></label></p>
    <p><label>Piece size (power-of-two exponent, default 22)<br><input name=\"piece\" value=\"22\"></label></p>
    <p><button type=\"submit\">Create Torrent</button></p>
  </form>
  {% if result %}
  <pre style=\"background:#111;color:#ddd;padding:1rem;white-space:pre-wrap\">{{ result }}</pre>
  {% endif %}
</body>
</html>
"""

@app.route('/', methods=['GET', 'POST'])
def index():
    result = ''
    if request.method == 'POST':
        source = request.form.get('source', '').strip()
        output = request.form.get('output', '').strip()
        tracker = request.form.get('tracker', '').strip()
        piece = request.form.get('piece', '22').strip()

        if not source or not output or not tracker:
            result = 'Missing required fields.'
        elif not os.path.exists(source):
            result = f'Source path does not exist: {source}'
        else:
            cmd = ['mktorrent', '-l', piece, '-a', tracker, '-o', output, source]
            try:
                proc = subprocess.run(cmd, text=True, capture_output=True, check=False)
                result = proc.stdout + '\n' + proc.stderr
                if proc.returncode == 0:
                    result = 'Torrent created successfully.\n\n' + result
            except Exception as exc:
                result = f'Error: {exc}'

    return render_template_string(TEMPLATE, result=result)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', '8899')))
PYAPP

    cat > "$service_file" <<EOF
[Unit]
Description=MakeTorrent WebUI
After=network.target

[Service]
Type=simple
User=${username}
WorkingDirectory=${app_dir}
Environment=PORT=${port}
ExecStart=/usr/bin/python3 ${app_file}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable maketorrent-webui 2>/dev/null || true
    systemctl restart maketorrent-webui

    config_set "S4D_MAKETORRENT_WEBUI_PORT" "$port"

    msg_ok "MakeTorrent WebUI installed"
    msg_info "WebUI: http://$(get_local_ip):${port}"
    return 0
}
