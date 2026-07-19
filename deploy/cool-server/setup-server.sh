#!/bin/sh
# One-shot (idempotent) production setup for the flick box. Run ON the server:
#
#   sh setup-server.sh                       # updater + admin panel
#   FLICK_TUNNEL_TOKEN=eyJ… sh setup-server.sh   # + the ingress connector
#
# Installs/refreshes: the auto-updater (script + user timer), the flick-admin
# + flick.network Quadlet units, the ingress connector (when a tunnel token is
# supplied), and prints what still needs a human. It never touches existing
# secrets (FLICK_ADMIN_TOKEN stays whatever the backend unit already carries).
set -eu

SVC="$HOME/services/flick"
QUAD="$HOME/.config/containers/systemd"
UNITS="$HOME/.config/systemd/user"
HERE=$(cd "$(dirname "$0")" && pwd)

mkdir -p "$SVC" "$QUAD" "$UNITS"

# --- auto-updater ----------------------------------------------------------
install -m 0755 "$HERE/update.sh" "$SVC/update.sh"
install -m 0644 "$HERE/flick-update.service" "$UNITS/flick-update.service"
install -m 0644 "$HERE/flick-update.timer" "$UNITS/flick-update.timer"

# --- admin panel quadlets (fetched from the flick-admin repo) ---------------
for f in flick.network flick-admin.container; do
  if [ ! -f "$QUAD/$f" ]; then
    curl -fsSL "https://raw.githubusercontent.com/one-more-refactor/flick-admin/master/deploy/$f" -o "$QUAD/$f"
    echo "installed $QUAD/$f"
  fi
done

# The backend must join flick.network and advertise the panel URL.
BACKEND="$QUAD/flick-backend.container"
if [ -f "$BACKEND" ]; then
  grep -q '^Network=flick.network' "$BACKEND" || sed -i '/^ContainerName=/a Network=flick.network' "$BACKEND"
  grep -q 'FLICK_ADMIN_URL' "$BACKEND" || sed -i '/FLICK_ADMIN_TOKEN/a Environment=FLICK_ADMIN_URL=https://admin.myflick.app' "$BACKEND"
else
  echo "!! $BACKEND missing — install the backend quadlet first (flick-backend/deploy)."
fi

# --- ingress connector (host netns; only when a token is supplied) ----------
if [ -n "${FLICK_TUNNEL_TOKEN:-}" ]; then
  umask 077
  printf '%s' "$FLICK_TUNNEL_TOKEN" > "$SVC/tunnel_token"
  install -m 0644 "$HERE/flick-cloudflared.service" "$UNITS/flick-cloudflared.service"
  echo "installed flick-cloudflared.service"
fi

systemctl --user daemon-reload
systemctl --user enable --now flick-update.timer
[ -f "$UNITS/flick-cloudflared.service" ] && systemctl --user enable --now flick-cloudflared.service
systemctl --user restart flick-backend 2>/dev/null || true
systemctl --user start flick-admin 2>/dev/null || true
# survive logout/reboot without an active session
loginctl enable-linger "$USER" 2>/dev/null || true

echo
echo "✓ auto-updater installed (flick-update.timer, every 15 min; log: $SVC/update.log)"
echo "✓ admin panel unit installed (127.0.0.1:3013)"
[ -f "$UNITS/flick-cloudflared.service" ] && echo "✓ ingress connector installed (flick_prod tunnel)"
echo
echo "still manual:"
echo "  · Cloudflare public hostnames on the flick_prod tunnel (origins MUST be"
echo "    http://127.0.0.1:PORT — 'localhost' resolves to ::1 here and 502s):"
echo "      app.myflick.app   -> http://127.0.0.1:3011"
echo "      myflick.app       -> http://127.0.0.1:3012"
echo "      admin.myflick.app -> http://127.0.0.1:3013"
echo "  · first admin: sign into the panel with the env token, users -> make admin"
