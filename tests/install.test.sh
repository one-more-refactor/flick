#!/bin/sh
# install.sh — the one-command self-host path users copy from the README.
# Runs the real installer against stubbed git/docker/podman and checks what it
# would do to the user's machine.
. "$(dirname "$0")/lib.sh"

GIT_STUB='case "$1" in
  clone) for a; do last=$a; done; mkdir -p "$last/.git" ;;
esac'
DOCKER_OK='[ "$*" = "compose version" ] && exit 0
printf "cwd %s\n" "$PWD" >> "$CALLS"'
NO='exit 1'

# run_install [args] — runs install.sh from $T/work, output in $T/out, rc in $RC
run_install() {
  mkdir -p "$T/work"
  RC=0
  (cd "$T/work" && env -i PATH="$T/bin" HOME="$T/home" ${FLICK_DIR:+FLICK_DIR="$FLICK_DIR"} \
    sh "$ROOT/install.sh" "$@") > "$T/out" 2>&1 || RC=$?
}

echo "install.sh"

# --- fresh install with Docker ---------------------------------------------
sandbox grep touch cat mkdir openssl head od tr
stub git "$GIT_STUB"; stub docker "$DOCKER_OK"; stub podman "$NO"
run_install
check "fresh install exits 0" "[ $RC = 0 ]"
check "clones the umbrella repo shallowly" "grep -qx 'git clone --depth 1 https://github.com/one-more-refactor/flick.git flick' '$CALLS'"
check "brings the stack up with a build" "grep -qx 'docker compose up -d --build' '$CALLS'"
check "runs compose inside the checkout" "grep -qx 'cwd $T/work/flick' '$CALLS'"
check "prints the local URL" "grep -qF 'http://localhost:8484' '$T/out'"
check "does not create .env without --with-admin" "[ ! -e '$T/work/flick/.env' ]"

# --- re-run = upgrade in place -----------------------------------------------
: > "$CALLS"
run_install
check "re-run exits 0" "[ $RC = 0 ]"
check "re-run fast-forwards instead of cloning" "grep -qx 'git -C flick pull --ff-only' '$CALLS' && ! grep -q 'git clone' '$CALLS'"
cleanup

# --- --with-admin writes a persistent, idempotent .env --------------------------
sandbox grep touch cat mkdir openssl head od tr
stub git "$GIT_STUB"; stub docker "$DOCKER_OK"; stub podman "$NO"
run_install --with-admin
ENV="$T/work/flick/.env"
check "--with-admin exits 0" "[ $RC = 0 ]"
check ".env enables the admin profile" "grep -qx 'COMPOSE_PROFILES=admin' '$ENV'"
check ".env carries a 48-hex admin token" "grep -Eqx 'FLICK_ADMIN_TOKEN=[0-9a-f]{48}' '$ENV'"
check ".env points the server at the panel" "grep -qx 'FLICK_ADMIN_URL=http://localhost:8485' '$ENV'"
check "prints the panel URL" "grep -qF 'http://localhost:8485' '$T/out'"
cp "$ENV" "$T/env.first"
run_install --with-admin
check "re-running --with-admin keeps .env byte-identical (token survives upgrades)" "cmp -s '$ENV' '$T/env.first'"
cleanup

# --- token fallback when openssl is absent -------------------------------------
sandbox grep touch cat mkdir head od tr
stub git "$GIT_STUB"; stub docker "$DOCKER_OK"; stub podman "$NO"
run_install --with-admin
check "without openssl the token still comes from /dev/urandom (48 hex)" "grep -Eqx 'FLICK_ADMIN_TOKEN=[0-9a-f]{48}' '$T/work/flick/.env'"
cleanup

# --- FLICK_DIR ------------------------------------------------------------------
sandbox grep touch cat mkdir openssl head od tr
stub git "$GIT_STUB"; stub docker "$DOCKER_OK"; stub podman "$NO"
FLICK_DIR=reader run_install
check "FLICK_DIR picks the checkout directory" "grep -qx 'git clone --depth 1 https://github.com/one-more-refactor/flick.git reader' '$CALLS' && grep -qx 'cwd $T/work/reader' '$CALLS'"
cleanup

# --- Podman fallbacks -----------------------------------------------------------
sandbox grep touch cat mkdir openssl head od tr
stub git "$GIT_STUB"; stub docker "$NO"; stub podman "$NO"; stub podman-compose ':'
run_install
check "falls back to podman-compose when docker compose is missing" "[ $RC = 0 ] && grep -qx 'podman-compose up -d --build' '$CALLS'"
cleanup

sandbox grep touch cat mkdir openssl head od tr
stub git "$GIT_STUB"; stub docker "$NO"
stub podman '[ "$*" = "compose version" ] && exit 0; :'
run_install
check "falls back to 'podman compose'" "[ $RC = 0 ] && grep -qx 'podman compose up -d --build' '$CALLS'"
cleanup

# --- refusals -------------------------------------------------------------------
sandbox grep touch cat mkdir openssl head od tr
stub git "$GIT_STUB"; stub docker "$NO"; stub podman "$NO"
run_install
check "no compose runtime: exits non-zero" "[ $RC != 0 ]"
check "no compose runtime: says what to install" "grep -qF 'Need Docker or Podman Compose' '$T/out'"
check "no compose runtime: clones nothing" "! grep -q '^git ' '$CALLS'"
cleanup

sandbox grep touch cat mkdir openssl head od tr
stub docker "$DOCKER_OK"; stub podman "$NO"
run_install
check "missing git: exits non-zero with a hint" "[ $RC != 0 ] && grep -qF 'git is required' '$T/out'"
cleanup

sandbox grep touch cat mkdir openssl head od tr
stub git "$GIT_STUB"; stub docker "$DOCKER_OK"; stub podman "$NO"
run_install --wtih-admin
check "unknown flag: exits non-zero before touching anything" "[ $RC != 0 ] && grep -qF 'unknown flag: --wtih-admin' '$T/out' && [ ! -s '$CALLS' ]"
cleanup

finish
