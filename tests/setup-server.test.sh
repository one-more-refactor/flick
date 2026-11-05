#!/bin/sh
# deploy/cool-server/setup-server.sh — the one-shot production setup. Runs it in
# a fake $HOME with stubbed systemctl/loginctl/curl and checks that it installs
# the updater, patches the backend unit exactly once, flags units the updater
# can't see, handles the tunnel token as a secret, and is safe to re-run.
. "$(dirname "$0")/lib.sh"

CURL_STUB='out=; url=
while [ $# -gt 0 ]; do
  case "$1" in -o) out=$2; shift ;; -*) ;; *) url=$1 ;; esac
  shift
done
printf "# fetched %s\n" "$url" > "$out"'

seed() {
  QUAD="$T/home/.config/containers/systemd"
  SVC="$T/home/services/flick"
  UNITS="$T/home/.config/systemd/user"
  mkdir -p "$QUAD" "$SVC/versions"
  cat > "$QUAD/flick-backend.container" <<'EOF'
[Container]
ContainerName=flick-backend
Image=ghcr.io/one-more-refactor/flick-backend:latest
AutoUpdate=registry
Environment=FLICK_ADMIN_TOKEN=test-not-a-secret
EOF
  # a leftover from the build-on-box era: local image, no AutoUpdate
  cat > "$QUAD/flick-landing.container" <<'EOF'
[Container]
ContainerName=flick-landing
Image=localhost/flick-landing:latest
EOF
}

run_setup() {
  RC=0
  env -i PATH="$T/bin" HOME="$T/home" USER=tester ${TOKEN:+FLICK_TUNNEL_TOKEN="$TOKEN"} \
    sh "$ROOT/deploy/cool-server/setup-server.sh" > "$T/out" 2>&1 || RC=$?
}

echo "deploy/cool-server/setup-server.sh"

TOOLS="dirname mkdir install rm grep sed"

# --- first run, no tunnel token ------------------------------------------------
sandbox $TOOLS
stub curl "$CURL_STUB"; stub systemctl ':'; stub loginctl ':'
seed
TOKEN=
run_setup
B="$QUAD/flick-backend.container"
check "first run exits 0" "[ $RC = 0 ]"
check "installs update.sh executable" "[ -x '$SVC/update.sh' ] && cmp -s '$SVC/update.sh' '$ROOT/deploy/cool-server/update.sh'"
check "installs the updater service + timer" "[ -f '$UNITS/flick-update.service' ] && [ -f '$UNITS/flick-update.timer' ]"
check "removes the dead build-era versions dir" "[ ! -e '$SVC/versions' ]"
check "fetches the admin quadlets from flick-admin" "[ -f '$QUAD/flick.network' ] && [ -f '$QUAD/flick-admin.container' ] && grep -q 'raw.githubusercontent.com/one-more-refactor/flick-admin/master/deploy/flick-admin.container' '$CALLS'"
check "joins the backend to flick.network right after ContainerName" "grep -A1 -x 'ContainerName=flick-backend' '$B' | grep -qx 'Network=flick.network'"
check "advertises the admin panel URL to the backend" "grep -qx 'Environment=FLICK_ADMIN_URL=https://admin.myflick.app' '$B'"
check "leaves the existing admin token alone" "grep -qx 'Environment=FLICK_ADMIN_TOKEN=test-not-a-secret' '$B'"
check "flags a unit running a local image" "grep -qF 'flick-landing.container does not run a ghcr image' '$T/out'"
check "flags a unit missing AutoUpdate=registry" "grep -qF 'flick-landing.container is missing AutoUpdate=registry' '$T/out'"
check "does not flag the healthy backend unit" "! grep -F '!!' '$T/out' | grep -q 'flick-backend'"
check "enables the updater timer" "grep -qx 'systemctl --user enable --now flick-update.timer' '$CALLS'"
check "no token: no ingress connector" "[ ! -e '$UNITS/flick-cloudflared.service' ] && ! grep -q cloudflared '$CALLS'"
check "enables linger for the service user" "grep -qx 'loginctl enable-linger tester' '$CALLS'"
check "lists the manual Cloudflare steps" "grep -qF 'admin.myflick.app -> http://127.0.0.1:3013' '$T/out'"

# --- re-run is idempotent --------------------------------------------------------
cp "$B" "$T/backend.first"
: > "$CALLS"
run_setup
check "re-run exits 0" "[ $RC = 0 ]"
check "re-run leaves the backend unit byte-identical" "cmp -s '$B' '$T/backend.first'"
check "re-run does not re-download existing quadlets" "! grep -q '^curl ' '$CALLS'"
cleanup

# --- with a tunnel token ------------------------------------------------------------
sandbox $TOOLS
stub curl "$CURL_STUB"; stub systemctl ':'; stub loginctl ':'
seed
TOKEN=test-tunnel-token
run_setup
check "token run exits 0" "[ $RC = 0 ]"
check "writes the tunnel token verbatim" "[ \"\$(cat '$SVC/tunnel_token')\" = test-tunnel-token ]"
check "tunnel token is mode 600" "[ \"\$(stat -c %a '$SVC/tunnel_token')\" = 600 ]"
check "installs and enables the ingress connector" "[ -f '$UNITS/flick-cloudflared.service' ] && grep -qx 'systemctl --user enable --now flick-cloudflared.service' '$CALLS'"
check "never echoes the token" "! grep -qF test-tunnel-token '$T/out'"
TOKEN=
cleanup

# --- backend unit missing -------------------------------------------------------------
sandbox $TOOLS
stub curl "$CURL_STUB"; stub systemctl ':'; stub loginctl ':'
seed
rm "$QUAD/flick-backend.container"
run_setup
check "missing backend unit: still exits 0" "[ $RC = 0 ]"
check "missing backend unit: says to install it first" "grep -qF 'install the backend quadlet first' '$T/out'"
cleanup

finish
