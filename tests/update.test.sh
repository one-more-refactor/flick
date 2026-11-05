#!/bin/sh
# deploy/cool-server/update.sh — the production auto-updater. Runs it against a
# stubbed podman and checks the log contract: only movers and failures are
# logged, a failed auto-update never aborts, and superseded images are pruned.
. "$(dirname "$0")/lib.sh"

run_update() {
  RC=0
  env -i PATH="$T/bin" HOME="$T/home" sh "$ROOT/deploy/cool-server/update.sh" > "$T/out" 2>&1 || RC=$?
  LOG="$T/home/services/flick/update.log"
}

echo "deploy/cool-server/update.sh"

sandbox date mkdir
stub podman 'case "$1" in
  auto-update)
    echo "flick-backend.service ghcr.io/one-more-refactor/flick-backend:latest true"
    echo "flick-admin.service ghcr.io/one-more-refactor/flick-admin:latest false" ;;
esac'
run_update
check "a mover run exits 0" "[ $RC = 0 ]"
check "asks podman auto-update with the unit/image/updated format" "grep -qF 'podman auto-update --format {{.Unit}} {{.Image}} {{.Updated}}' '$CALLS'"
check "logs the unit whose digest moved" "grep -q 'flick-backend.service ghcr.io/one-more-refactor/flick-backend:latest true' '$LOG'"
check "does not log units that stayed put" "! grep -q 'flick-admin' '$LOG'"
check "prunes superseded images" "grep -qx 'podman image prune -f' '$CALLS'"
check "is silent on stdout (timer logs go to update.log)" "[ ! -s '$T/out' ]"
cleanup

sandbox date mkdir
stub podman 'case "$1" in
  auto-update) echo "flick-backend.service ghcr.io/one-more-refactor/flick-backend:latest false" ;;
esac'
run_update
check "a quiet run exits 0" "[ $RC = 0 ]"
check "a quiet run writes no log lines" "[ ! -s '$LOG' ]"
cleanup

sandbox date mkdir
stub podman 'case "$1" in
  auto-update) echo "Error: registry unreachable" >&2; exit 125 ;;
esac'
run_update
check "a failed auto-update still exits 0 (keeps what is running)" "[ $RC = 0 ]"
check "a failed auto-update is logged with podman's reason" "grep -q 'auto-update failed, keeping what is running: Error: registry unreachable' '$LOG'"
check "a failed auto-update still prunes" "grep -qx 'podman image prune -f' '$CALLS'"
cleanup

finish
