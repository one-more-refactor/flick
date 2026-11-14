#!/bin/sh
# One-shot (idempotent) production setup for the flick box. Run ON the server:
#
#   sh setup-server.sh                       # updater + admin panel
#   FLICK_TUNNEL_TOKEN=eyJ… sh setup-server.sh   # + the ingress connector
#
# Installs/refreshes: the auto-updater (script + user timer), the flick-admin
# + flick.network Quadlet units, the ingress connector (when a tunnel token is
# supplied), and prints what still needs a human. It never touches existing
# secrets (FLICK_ADMIN_TOKEN stays whatever the backend unit already carries),
# but it refuses to run at all while that token is the placeholder or short.
set -eu

SVC="$HOME/services/flick"
QUAD="$HOME/.config/containers/systemd"
UNITS="$HOME/.config/systemd/user"
HERE=$(cd "$(dirname "$0")" && pwd)
BACKEND="$QUAD/flick-backend.container"

# --- refuse a weak admin token, before changing anything ---------------------
# The backend accepts any non-empty FLICK_ADMIN_TOKEN, and the committed quadlet
# ships CHANGE_ME, so a box set up straight from the repo would guard
# /api/admin/* with a placeholder. Read every place the unit can take the token
# from (Environment=, EnvironmentFile=, a podman Secret=) and stop if any value
# is missing, CHANGE_ME or under 32 characters. Make one: openssl rand -hex 32
admin_tokens() {
  sed -n 's/^Environment="\{0,1\}FLICK_ADMIN_TOKEN=\([^"]*\)"\{0,1\}[[:space:]]*$/\1/p' "$BACKEND"
  sed -n 's/^EnvironmentFile=-\{0,1\}//p' "$BACKEND" | while IFS= read -r f; do
    f=$(printf '%s' "$f" | sed "s|%h|$HOME|g")
    if [ -r "$f" ]; then
      sed -n "s/^FLICK_ADMIN_TOKEN=[\"']\{0,1\}\([^\"']*\)[\"']\{0,1\}[[:space:]]*\$/\1/p" "$f"
    fi
  done
  sed -n 's/^Secret=\([^,]*\),.*target=FLICK_ADMIN_TOKEN.*$/\1/p' "$BACKEND" | while IFS= read -r s; do
    podman secret inspect --showsecret --format '{{.SecretData}}' "$s" 2>/dev/null || true
  done
}
if [ -f "$BACKEND" ]; then
  tokens=$(admin_tokens)
  if [ -z "$tokens" ]; then
    echo "!! no readable FLICK_ADMIN_TOKEN for $BACKEND — set one (openssl rand -hex 32), then re-run." >&2
    exit 1
  fi
  while IFS= read -r t; do
    if [ "$t" = CHANGE_ME ] || [ "${#t}" -lt 32 ]; then
      echo "!! FLICK_ADMIN_TOKEN for $BACKEND is CHANGE_ME, empty or under 32 chars." >&2
      echo "   Replace it with: openssl rand -hex 32   — refusing to continue." >&2
      exit 1
    fi
  done <<EOF
$tokens
EOF
fi

mkdir -p "$SVC" "$QUAD" "$UNITS"

# --- auto-updater ----------------------------------------------------------
install -m 0755 "$HERE/update.sh" "$SVC/update.sh"
install -m 0644 "$HERE/flick-update.service" "$UNITS/flick-update.service"
install -m 0644 "$HERE/flick-update.timer" "$UNITS/flick-update.timer"
# The updater pulls and never builds, so the git-SHA state the old build-on-box
# updater kept is dead weight — and a stale `versions` dir would be misleading
# the next time someone reads the log next to it.
rm -rf "$SVC/versions"

# --- admin panel quadlets (fetched from the flick-admin repo) ---------------
for f in flick.network flick-admin.container; do
  if [ ! -f "$QUAD/$f" ]; then
    curl -fsSL "https://raw.githubusercontent.com/one-more-refactor/flick-admin/master/deploy/$f" -o "$QUAD/$f"
    echo "installed $QUAD/$f"
  fi
done

# The backend must join flick.network and advertise the panel URL.
if [ -f "$BACKEND" ]; then
  grep -q '^Network=flick.network' "$BACKEND" || sed -i '/^ContainerName=/a Network=flick.network' "$BACKEND"
  grep -q 'FLICK_ADMIN_URL' "$BACKEND" || sed -i '/FLICK_ADMIN_TOKEN/a Environment=FLICK_ADMIN_URL=https://admin.myflick.app' "$BACKEND"
else
  echo "!! $BACKEND missing — install the backend quadlet first (flick-backend/deploy)."
fi

# --- every unit must be registry-tracked, or the updater can't see it --------
# `podman auto-update` only touches containers whose unit carries
# AutoUpdate=registry and runs a registry image. A unit still pointing at a
# locally built `localhost/…` image would silently never update again.
for f in flick-backend.container flick-landing.container flick-admin.container; do
  [ -f "$QUAD/$f" ] || continue
  grep -q '^Image=ghcr\.io/one-more-refactor/' "$QUAD/$f" \
    || echo "!! $QUAD/$f does not run a ghcr image — the updater pulls, it no longer builds."
  grep -q '^AutoUpdate=registry' "$QUAD/$f" \
    || echo "!! $QUAD/$f is missing AutoUpdate=registry — it will never be updated."
done

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
echo "✓ auto-updater installed — pull only (flick-update.timer, every 15 min; log: $SVC/update.log)"
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
