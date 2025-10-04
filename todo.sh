#!/usr/bin/env bash
# todo.sh - simple to-do tracker
# Day 8: add + list + done + delete + logging + auto commit + colors + help

set -e

TASK_FILE="$(pwd)/tasks.txt"
LOG_DIR="$(pwd)/logs"
LOG_FILE="$LOG_DIR/actions.log"

mkdir -p "$LOG_DIR"
touch "$TASK_FILE" "$LOG_FILE"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

usage() {
  cat <<USAGE
To-Do Tracker Usage:
  $0 add "task description" [priority] [--commit]
  $0 list
  $0 done N [--commit]
  $0 delete N [--commit]
  $0 help

Examples:
  $0 add "Finish assignment" high --commit
  $0 list
  $0 done 2
  $0 delete 1
USAGE
}

log_action() {
  echo "$(date '+%F %T') | $1 | $2" >> "$LOG_FILE"
}

auto_commit() {
  msg="$1"
  git add todo.sh .gitignore logs/.gitkeep
  git commit -m "$msg" || true
  git push origin main || true
}

list_tasks() {
  if [ ! -s "$TASK_FILE" ]; then
    echo "No tasks available."
    return
  fi

  awk -F'|' -v RED="$RED" -v GREEN="$GREEN" -v YELLOW="$YELLOW" -v RESET="$RESET" '
  {
    status=$1; priority=$2; desc=$3; ts=$4;
    color=RESET
    if(priority=="high") color=RED
    else if(priority=="medium") color=YELLOW
    else if(priority=="low") color=GREEN

    symbol=(status=="[x]") ? GREEN"✔"RESET : RED"✘"RESET
    printf "%2d. %s %-40s (priority:%s%s%s) — %s\n",
           NR, symbol, desc, color, priority, RESET, ts
  }' "$TASK_FILE"
}

mark_done() {
  n="$1"
  total=$(wc -l < "$TASK_FILE")
  if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
    echo "Error: invalid task number."
    exit 1
  fi

  awk -v n="$n" -F'|' 'NR==n{$1="[x]"}{print $1 "|" $2 "|" $3 "|" $4}' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
  echo -e "Marked task $n as ${GREEN}done${RESET}."
  log_action "DONE" "Task $n"
}

delete_task() {
  n="$1"
  total=$(wc -l < "$TASK_FILE")
  if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
    echo "Error: invalid task number."
    exit 1
  fi

  awk -v n="$n" 'NR!=n{print}' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
  echo -e "Deleted task $n."
  log_action "DELETE" "Task $n"
}

cmd="$1"
shift || true
commit_flag=false

for arg in "$@"; do
  if [ "$arg" = "--commit" ]; then
    commit_flag=true
    set -- "${@/--commit/}"
  fi
done

case "$cmd" in
  add)
    desc="$1"
    priority="${2:-medium}"
    if [ -z "$desc" ]; then
      echo "Error: missing description"
      usage
      exit 1
    fi
    ts="$(date '+%F %T')"
    echo "[ ]|$priority|$desc|$ts" >> "$TASK_FILE"
    echo -e "Added: ${YELLOW}$desc${RESET} (priority: $priority)"
    log_action "ADD" "$desc (priority:$priority)"
    $commit_flag && auto_commit "Auto: added task '$desc'"
    ;;
  list)
    list_tasks
    ;;
  done)
    mark_done "$1"
    $commit_flag && auto_commit "Auto: marked task $1 done"
    ;;
  delete)
    delete_task "$1"
    $commit_flag && auto_commit "Auto: deleted task $1"
    ;;
  help|"")
    usage
    ;;
  *)
    echo "Unknown command: $cmd"
    usage
    ;;
esac
