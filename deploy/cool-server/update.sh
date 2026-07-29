#!/bin/sh
# flick auto-updater — pull only. Nothing is ever built on this box.
#
# Every component repo's release.yml builds the multi-arch image in CI on a v*
# tag, pushes it to ghcr and moves `:latest` onto it. The Quadlet units carry
# `AutoUpdate=registry` and reference those ghcr tags, so all this box has to do
# is ask the registry whether the digest behind `:latest` moved — which is what
# `podman auto-update` does. It pulls only when the digest changed, restarts
# only the units whose image actually moved, and rolls a unit back to the
# previous image if the new one fails to come up. Untagged master pushes never
# reach production: no release, no image, nothing to pull.
#
# Installed by setup-server.sh to ~/services/flick/update.sh and driven by
# flick-update.timer (rootless systemd --user). Everything is logged to
# ~/services/flick/update.log.
#
#   podman auto-update --dry-run   # what would change, right now
#   podman auto-update rollback    # undo the last update by hand
#   podman pull ghcr.io/one-more-refactor/flick-backend:v0.11.0
#                                  # pin a known-good version, then set the
#                                  # unit's Image= to it to freeze this host
set -eu

DIR="$HOME/services/flick"
LOG="$DIR/update.log"
mkdir -p "$DIR"

log() { printf '%s %s\n' "$(date -Is)" "$*" >> "$LOG"; }

# One line per auto-update unit: "<unit> <image> <updated>", where <updated> is
# false when the digest had not moved. Only the movers are worth a log line.
if out=$(podman auto-update --format '{{.Unit}} {{.Image}} {{.Updated}}' 2>&1); then
  printf '%s\n' "$out" | while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      *" false") ;;
      *) log "$line" ;;
    esac
  done
else
  log "auto-update failed, keeping what is running: $out"
fi

# Drop the images this superseded. The previous release stays reachable in ghcr
# under its version tag, so a rollback is a pull away.
podman image prune -f > /dev/null 2>&1 || true
