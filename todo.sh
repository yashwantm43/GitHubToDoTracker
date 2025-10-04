#!/usr/bin/env bash
# todo.sh - simple to-do tracker (add + list + done + delete + logging + auto commit)

set -e

TASK_FILE="$(pwd)/tasks.txt"
LOG_DIR="$(pwd)/logs"
LOG_FILE="$LOG_DIR/actions.log"

mkdir -p "$(dirname "$TASK_FILE")"
mkdir -p "$LOG_DIR"
touch "$TASK_FILE" "$LOG_FILE"

usage() {
  cat <<USAGE
Usage:
  $0 add "task description" [priority] [--commit]
  $0 list
  $0 done N [--commit]
  $0 delete N [--commit]

Examples:
  $0 add "Finish assignment" high --commit
  $0 done 2 --commit
  $0 delete 1
USAGE
}

log_action() {
  action="$1"
  detail="$2"
  echo "$(date '+%F %T') | $action | $detail" >> "$LOG_FILE"
}

auto_commit() {
  msg="$1"
  # Add only code + config files, ignore runtime files
  git add todo.sh .gitignore logs/.gitkeep
  git commit -m "$msg" || true
  git push origin main || true

  # Reset ignored files so they don’t block future pulls
  git restore tasks.txt || true
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

mark_done() {
  n="$1"
  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "Error: provide a valid task number."
    exit 1
  fi
  total=$(wc -l < "$TASK_FILE")
  if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
    echo "Error: invalid task number."
    exit 1
  fi

  awk -v n="$n" -F'|' 'NR==n{$1="[x]"}{print $1 "|" $2 "|" $3 "|" $4}' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
  echo "Marked task $n as done."
  log_action "DONE" "Task $n"
}

delete_task() {
  n="$1"
  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    echo "Error: provide a valid task number."
    exit 1
  fi
  total=$(wc -l < "$TASK_FILE")
  if [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
    echo "Error: invalid task number."
    exit 1
  fi

  awk -v n="$n" 'NR!=n{print}' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
  echo "Deleted task $n."
  log_action "DELETE" "Task $n"
}

cmd="$1"
shift || true
commit_flag=false

# check for optional --commit
for arg in "$@"; do
  if [ "$arg" = "--commit" ]; then
    commit_flag=true
    set -- "${@/--commit/}"   # remove flag from args
  fi
done

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
  *)
    usage
    ;;
esac
