#!/usr/bin/env bash
# Runs the balance harness in parallel shards and writes docs/BALANCE_REPORT.md.
# Usage: tools/run_sim.sh [runs_per_policy=10000] [shards=8] [difficulty=normal]
set -e
RUNS=${1:-10000}; SHARDS=${2:-8}; DIFF=${3:-normal}
GODOT=${GODOT:-godot}
cd "$(dirname "$0")/.."
USERDIR=$("$GODOT" --headless --path . -s res://tools/print_user_dir.gd 2>/dev/null | tail -1)
rm -f "$USERDIR"/sim_shard*.json
for i in $(seq 0 $((SHARDS-1))); do
  "$GODOT" --headless --path . -s res://tools/run_node.gd -- --script=res://tests/sim/sim_harness.gd --runs=$RUNS --difficulty=$DIFF --shard=$i --shards=$SHARDS --out=user://sim_shard$i.json > /dev/null 2>&1 &
done
wait
"$GODOT" --headless --path . -s res://tools/run_node.gd -- --script=res://tests/sim/sim_report.gd --in=user://sim_shard*.json
