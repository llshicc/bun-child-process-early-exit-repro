#!/bin/sh
# usage: ./run.sh [bun=bun] [probe=repro] [rounds=5] [files=60] [hogs=2*cpus] [bun test flags=--parallel=4]
#
# Copies <probe>.test.ts into <files> test files (one spawn per file), loads the
# CPU with <hogs> busy loops, runs `bun test` <rounds> times and counts the files
# that print a LOST line. Every busy loop is killed on exit.
#
# probes: repro    node:child_process spawn(), waits for 'exit'
#         control  Bun.spawn(), waits for `exited` (same child)
#         execfile promisify(execFile), waits for it to settle
BUN=${1:-bun}; PROBE=${2:-repro}; ROUNDS=${3:-5}; FILES=${4:-60}
HOGS=${5:-$(($(getconf _NPROCESSORS_ONLN) * 2))}
if [ "$#" -ge 5 ]; then shift 5; else set --; fi
FLAGS=${*:---parallel=4}
HERE=$(cd "$(dirname "$0")" && pwd)
case "$BUN" in /*) ;; */*) BUN="$(cd "$(dirname "$BUN")" && pwd)/$(basename "$BUN")" ;; esac
"$BUN" --revision >/dev/null || { echo "cannot run $BUN"; exit 2; }
[ -f "$HERE/$PROBE.test.ts" ] || { echo "no probe $PROBE.test.ts"; exit 2; }
DIR=$(mktemp -d "$HERE/work.XXXXXX")
i=1; while [ "$i" -le "$FILES" ]; do cp "$HERE/$PROBE.test.ts" "$DIR/t$i.test.ts"; i=$((i + 1)); done
hogs=""
cleanup() { for p in $hogs; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap cleanup EXIT INT TERM HUP
i=0; while [ "$i" -lt "$HOGS" ]; do yes > /dev/null & hogs="$hogs $!"; i=$((i + 1)); done
sleep 1
lost=0; total=0; r=1
while [ "$r" -le "$ROUNDS" ]; do
  # hard cap per round so nothing can wedge the shell
  out=$(cd "$DIR" && perl -e 'alarm 300; exec @ARGV' "$BUN" test $FLAGS . 2>&1)
  printf '%s\n' "$out" > "$DIR/round$r.log"
  printf '%s\n' "$out" | grep -qE '^Ran [0-9]+ tests' || echo "round $r: NO SUMMARY (see $DIR/round$r.log)"
  n=$(printf '%s\n' "$out" | grep -c '^LOST')
  printf '%s\n' "$out" | grep '^LOST' | sed "s/^/  round $r: /"
  lost=$((lost + n)); total=$((total + FILES))
  echo "round $r: lost=$n/$FILES"
  r=$((r + 1))
done
cleanup; trap - EXIT
echo "RESULT bun=$("$BUN" --revision) probe=$PROBE flags='$FLAGS' hogs=$HOGS lost=$lost/$total (logs: $DIR)"
