#!/usr/bin/env bash
# todo.sh - simple to-do tracker (Day 2: add command only)
set -e

# file to store tasks
TASK_FILE="$(pwd)/tasks.txt"
mkdir -p "$(dirname "$TASK_FILE")"
touch "$TASK_FILE"

usage() {
  cat <<USAGE
Usage:
  $0 add "task description" [priority]

Examples:
  $0 add "Finish assignment" high
  $0 add "Buy groceries"    # default priority = medium
USAGE
}

cmd="$1"
shift || true

if [ "$cmd" = "add" ]; then
  desc="$1"
  priority="${2:-medium}"   # default priority
  if [ -z "$desc" ]; then
    echo "Error: missing description"
    usage
    exit 1
  fi
  if [[ "$desc" == *"|"* ]]; then
    echo "Error: '|' character is not allowed in description."
    exit 1
  fi
  ts="$(date '+%F %T')"
  # store as: status|priority|description|created_ts
  echo "[ ]|$priority|$desc|$ts" >> "$TASK_FILE"
  echo "Added: $desc (priority: $priority)"
else
  usage
fi
