#!/bin/sh
# flick — self-host installer.
#
#   curl -fsSL https://raw.githubusercontent.com/one-more-refactor/flick/master/install.sh | sh
#
# Brings up the self-host edition (everything free) with Docker or Podman
# Compose. Your library lives in a named volume; re-running upgrades in place.
set -eu

REPO="https://github.com/one-more-refactor/flick.git"
DIR="${FLICK_DIR:-flick}"
PORT="8484"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

# --- pick a compose command ------------------------------------------------
if docker compose version >/dev/null 2>&1; then
  COMPOSE="docker compose"
elif command -v podman-compose >/dev/null 2>&1; then
  COMPOSE="podman-compose"
elif podman compose version >/dev/null 2>&1; then
  COMPOSE="podman compose"
else
  die "Need Docker or Podman Compose. Install one, then re-run.
  Docker:  https://docs.docker.com/get-docker/
  Podman:  https://podman.io  (plus podman-compose)"
fi
command -v git >/dev/null 2>&1 || die "git is required."

# --- fetch / update the repo ----------------------------------------------
if [ -d "$DIR/.git" ]; then
  say "› Updating $DIR"
  git -C "$DIR" pull --ff-only
else
  say "› Cloning flick into ./$DIR"
  git clone --depth 1 "$REPO" "$DIR"
fi
cd "$DIR"

# --- build & run -----------------------------------------------------------
say "› Building and starting flick (first build compiles Rust — grab a coffee)"
$COMPOSE up -d --build

cat <<EOF

  flick is up.  →  http://localhost:${PORT}

  logs:     (cd $DIR && $COMPOSE logs -f)
  stop:     (cd $DIR && $COMPOSE down)
  upgrade:  re-run this installer

  Everything is free in the self-host edition. Read the docs at
  https://github.com/one-more-refactor/flick
EOF
