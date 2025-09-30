#!/usr/bin/env bash
# todo.sh - simple to-do tracker (Day 3: add + list)

set -e

TASK_FILE="$(pwd)/tasks.txt"
mkdir -p "$(dirname "$TASK_FILE")"
touch "$TASK_FILE"

usage() {
  cat <<USAGE
Usage:
  $0 add "task description" [priority]
  $0 list

Examples:
  $0 add "Finish assignment" high
  $0 list
USAGE
}

list_tasks() {
  if [ ! -s "$TASK_FILE" ]; then
    echo "No tasks available."
    return
  fi

  awk -F'|' '{
    status=$1; priority=$2; desc=$3; ts=$4;
    printf "%2d. %s %-40s (priority:%s) — %s\n", NR, status, desc, priority, ts
  }' "$TASK_FILE"
}

cmd="$1"
shift || true

case "$cmd" in
  add)
    desc="$1"
    priority="${2:-medium}"   # default priority
    if [ -z "$desc" ]; then
      echo "Error: missing description"
      usage
      exit 1
    fi
    if [[ "$desc" == *"|"* ]]; then
      echo "Error: '|' not allowed in description."
      exit 1
    fi
    ts="$(date '+%F %T')"
    echo "[ ]|$priority|$desc|$ts" >> "$TASK_FILE"
    echo "Added: $desc (priority: $priority)"
    ;;
  list)
    list_tasks
    ;;
  *)
    usage
    ;;
esac

