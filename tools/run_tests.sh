#!/usr/bin/env bash
# Runs every headless test in game/tests and the map sweep. Exit 1 if anything fails.
# Usage: GODOT=/path/to/godot tools/run_tests.sh [test_name ...]
set -u
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
names=("$@")
if [ ${#names[@]} -eq 0 ]; then
  for f in game/tests/test_*.gd; do names+=("$(basename "$f" .gd)"); done
fi
failed=0
for t in "${names[@]}"; do
  out="$(timeout 600 "$GODOT" --headless --path game --script "res://tests/$t.gd" 2>&1)"
  code=$?
  summary="$(printf '%s\n' "$out" | grep -E '^[0-9]+ checks' | tail -1)"
  errors="$(printf '%s\n' "$out" | grep -c 'SCRIPT ERROR')"
  if [ $code -ne 0 ] || [ "$errors" -ne 0 ] || [ -z "$summary" ]; then
    failed=1
    echo "FAIL $t (exit=$code, script errors=$errors) ${summary:-no summary}"
    printf '%s\n' "$out" | grep -E '^FAIL|SCRIPT ERROR' -A2 | head -20
  else
    echo "ok   $t: $summary"
  fi
done
if [ $# -eq 0 ]; then
  out="$(timeout 900 "$GODOT" --headless --path game --script res://tools/sweep.gd 2>&1)"
  if [ $? -ne 0 ] || printf '%s\n' "$out" | grep -q 'SCRIPT ERROR'; then
    failed=1; echo "FAIL map sweep"; printf '%s\n' "$out" | grep -E 'SCRIPT ERROR|FAIL' -A2 | head -20
  else
    echo "ok   map sweep: $(printf '%s\n' "$out" | grep -E '^swept' | tail -1)"
  fi
fi
[ $failed -eq 0 ] && echo "ALL PASSED" || echo "SOME FAILED"
exit $failed
