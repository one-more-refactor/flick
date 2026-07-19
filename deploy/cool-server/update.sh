#!/bin/sh
# flick auto-updater — polls the public repos and rebuilds/restarts on change.
# Installed by setup-server.sh to ~/services/flick/update.sh and driven by
# flick-update.timer (rootless systemd --user). Every step is logged to
# ~/services/flick/update.log; a failed build never touches the running
# container — the last-good SHA stays recorded and the old image keeps serving.
set -eu

DIR="$HOME/services/flick"
LOG="$DIR/update.log"
STATE="$DIR/versions"
mkdir -p "$STATE"

log() { printf '%s %s\n' "$(date -Is)" "$*" >> "$LOG"; }

head_of() {
  git ls-remote "https://github.com/one-more-refactor/$1" refs/heads/master 2>/dev/null | cut -f1
}

# check <name> <unit> <sha> — rebuild image from the repo's git URL when <sha>
# (which may combine several repos) differs from the recorded one.
check() {
  name=$1; unit=$2; sha=$3
  [ -n "$sha" ] || { log "$name: ls-remote failed, skipping"; return 0; }
  old=$(cat "$STATE/$name" 2>/dev/null || echo none)
  [ "$sha" = "$old" ] && return 0
  log "$name: $old -> $sha, building"
  if podman build -q -t "localhost/$name:latest" \
      "https://github.com/one-more-refactor/$name.git" \
      -f deploy/Containerfile >> "$LOG" 2>&1; then
    systemctl --user restart "$unit"
    printf '%s' "$sha" > "$STATE/$name"
    log "$name: deployed"
  else
    log "$name: BUILD FAILED — keeping $old"
  fi
}

backend=$(head_of flick-backend)
web=$(head_of flick-web)
landing=$(head_of flick-landing)
admin=$(head_of flick-admin)

# The backend image bakes the web client in, so a web push rebuilds it too.
check flick-backend flick-backend "${backend:-}+${web:-}"
check flick-landing flick-landing "${landing:-}"
check flick-admin   flick-admin   "${admin:-}"

podman image prune -f > /dev/null 2>&1 || true
