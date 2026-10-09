#!/bin/bash
# Import new files, then run the rule tests (which also load every script).
# usage: tools/dev/check.sh   (prints TESTS PASSED on success)
cd "$(dirname "$0")/../.."
d=$(mktemp -d)
godot --headless --path . --import > "$d/import.log" 2>&1
grep -E "SCRIPT ERROR|Parse Error" "$d/import.log"
tools/dev/run.sh "$d/tests.log" 120 --headless --path . res://tests/run_tests.tscn | grep -E "TESTS|FAIL|not ok|SCRIPT ERROR|Parse Error|killed|CHECK"
