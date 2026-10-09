#!/bin/bash
# Run Godot with a time limit, killing it on the first script error (headless runs can hang on one).
# usage: tools/dev/run.sh <logfile> <maxsec> <godot args...>
log=$1; max=$2; shift 2
cd "$(dirname "$0")/../.."
godot "$@" > "$log" 2>&1 &
pid=$!
for _ in $(seq 1 $((max * 4))); do
	sleep 0.25
	kill -0 $pid 2>/dev/null || break
	if grep -q "SCRIPT ERROR\|Parse Error" "$log"; then sleep 1; kill $pid 2>/dev/null; echo "[killed on error]"; break; fi
done
kill $pid 2>/dev/null && echo "[killed after ${max}s]"
grep -v "^Godot Engine\|^$" "$log" | tail -40
