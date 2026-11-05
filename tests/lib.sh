#!/bin/sh
# Shared helpers for the shell integration tests. Each test runs the real
# script (install.sh, deploy/cool-server/*.sh) inside a throwaway sandbox whose
# PATH holds ONLY stubs + the handful of coreutils the script needs, so no real
# docker/podman/git/systemctl on the host can ever be touched or leak in.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
FAILS=0
PASSES=0

# sandbox <tool>... — fresh $T with $T/bin holding symlinks to the named real
# tools; stubs are added afterwards with `stub`.
sandbox() {
  T=$(mktemp -d "${TMPDIR:-/tmp}/flick-test.XXXXXX")
  mkdir -p "$T/bin" "$T/home"
  for tool in sh "$@"; do
    real=$(command -v "$tool") || { echo "test prerequisite missing: $tool" >&2; exit 2; }
    ln -s "$real" "$T/bin/$tool"
  done
  CALLS="$T/calls.log"
  : > "$CALLS"
  export CALLS
}

# stub <name> <body> — an executable in $T/bin that logs "<name> <args>" to
# $CALLS, then runs <body> (sh) with the original arguments.
stub() {
  name=$1; body=$2
  {
    echo '#!/bin/sh'
    printf '%s\n' "printf '%s\\n' \"$name \$*\" >> \"\$CALLS\""
    printf '%s\n' "$body"
  } > "$T/bin/$name"
  chmod +x "$T/bin/$name"
}

cleanup() { [ -n "${T:-}" ] && rm -rf "$T"; T=; }

ok()   { PASSES=$((PASSES + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf '  FAIL  %s\n' "$1"; [ -z "${2:-}" ] || printf '        %s\n' "$2"; }

# check <description> <shell condition>
check() {
  if sh -c "$2"; then ok "$1"; else fail "$1" "condition: $2"; fi
}

contains() { grep -qF -- "$2" "$1"; }

finish() {
  printf '\n%s passed, %s failed\n' "$PASSES" "$FAILS"
  [ "$FAILS" = 0 ]
}
