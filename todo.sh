#!/usr/bin/env bash
# todo.sh - robust To-Do Tracker (fixed sorting + features)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TASK_FILE="$ROOT/tasks.txt"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/actions.log"
TMP_SORT="$ROOT/.tmp_tasks_sorted"

mkdir -p "$LOG_DIR"
touch "$TASK_FILE" "$LOG_FILE"

# Colors (works in Git Bash)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

usage() {
  cat <<USAGE
Usage:
  $0 add "task description" [priority] [--commit]
  $0 list [--sort priority|status]
  $0 done N [--commit]
  $0 delete N [--commit]
  $0 help

Examples:
  $0 add "Finish assignment" high --commit
  $0 list --sort priority
  $0 list --sort status
  $0 done 2
  $0 delete 1
USAGE
}

log_action() {
  echo "$(date '+%F %T') | $1 | $2" >> "$LOG_FILE"
}

auto_commit() {
  msg="$1"
  git -C "$ROOT" add todo.sh .gitignore logs/.gitkeep || true
  git -C "$ROOT" commit -m "$msg" || true
  git -C "$ROOT" push origin main || true
  git -C "$ROOT" restore --quiet "$TASK_FILE" || true
}

# Normalize tasks file: remove CR, trim whitespace for each field
_normalize_tasks_file() {
  if [ -f "$TASK_FILE" ]; then
    sed -i 's/\r$//' "$TASK_FILE" 2>/dev/null || true
    awk -F'|' 'BEGIN{OFS="|"} {for(i=1;i<=NF;i++){gsub(/^[ \t]+|[ \t]+$/,"",$i)} print}' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
  fi
}

# Format and print a tasks file (line format: status|priority|desc|ts)
_print_from_file() {
  n=1
  while IFS='|' read -r status priority desc ts; do
    # normalize priority lowercase
    pr="$(echo "$priority" | tr '[:upper:]' '[:lower:]')"
    # choose color
    if [ "$pr" = "high" ]; then color="$RED"; elif [ "$pr" = "medium" ]; then color="$YELLOW"; else color="$GREEN"; fi
    # choose symbol
    if [ "$status" = "[x]" ]; then symbol="${GREEN}✔${RESET}"; else symbol="${RED}✘${RESET}"; fi
    # print nicely
    printf "%2d. %b %-40s (priority:%b%s%b) — %s\n" "$n" "$symbol" "$desc" "$color" "$pr" "$RESET" "$ts"
    n=$((n+1))
  done < "$1"
}

list_tasks() {
  sort_mode="${1:-}"
  _normalize_tasks_file
  if [ ! -s "$TASK_FILE" ]; then
    echo "No tasks available."
    return
  fi

  case "$sort_mode" in
    priority)
      # create lines with priority rank then sort numerically by that rank
      awk -F'|' '{
        p=tolower($2); gsub(/^[ \t]+|[ \t]+$/,"",p);
        if(p=="high") r=1; else if(p=="medium") r=2; else r=3;
        print r "|" $0
      }' "$TASK_FILE" | sort -t'|' -k1,1n -s | cut -d'|' -f2- > "$TMP_SORT"
      _print_from_file "$TMP_SORT"
      rm -f "$TMP_SORT"
      ;;
    status)
      # status rank: undone=1 done=2; then priority inside
      awk -F'|' '{
        st=$1; p=tolower($2); if(st=="[ ]") sr=1; else sr=2;
        if(p=="high") pr=1; else if(p=="medium") pr=2; else pr=3;
        print sr "|" pr "|" $0
      }' "$TASK_FILE" | sort -t'|' -k1,1n -k2,2n -s | cut -d'|' -f3- > "$TMP_SORT"
      _print_from_file "$TMP_SORT"
      rm -f "$TMP_SORT"
      ;;
    *)
      _print_from_file "$TASK_FILE"
      ;;
  esac
}

add_task() {
  desc="$1"
  priority="${2:-medium}"
  # normalize priority
  priority="$(echo "$priority" | tr '[:upper:]' '[:lower:]')"
  if [[ "$desc" == *"|"* ]]; then
    echo "Error: '|' not allowed in description."
    exit 1
  fi
  _normalize_tasks_file
  ts="$(date '+%F %T')"
  echo "[ ]|$priority|$desc|$ts" >> "$TASK_FILE"
  echo "Added: $desc (priority: $priority)"
  log_action "ADD" "$desc (priority:$priority)"
}

mark_done() {
  n="$1"
  _normalize_tasks_file
  total=$(wc -l < "$TASK_FILE")
  if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
    echo "Error: invalid task number."
    exit 1
  fi
  awk -v n="$n" -F'|' 'NR==n{$1="[x]"}{print $1 "|" $2 "|" $3 "|" $4}' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
  echo "Marked task $n as done."
  log_action "DONE" "Task $n"
}

delete_task() {
  n="$1"
  _normalize_tasks_file
  total=$(wc -l < "$TASK_FILE")
  if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$total" ]; then
    echo "Error: invalid task number."
    exit 1
  fi
  awk -v n="$n" 'NR!=n{print}' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
  echo "Deleted task $n."
  log_action "DELETE" "Task $n"
}

# parse args, support --commit anywhere
cmd="${1:-}"
shift || true
commit_flag=false
ARGS=()
for a in "$@"; do
  if [ "$a" = "--commit" ]; then commit_flag=true; else ARGS+=("$a"); fi
done
set -- "${ARGS[@]}"

search_tasks() {
  keyword="$1"
  _normalize_tasks_file
  if [ -z "$keyword" ]; then
    echo "Error: please provide a search term."
    return
  fi

  if [ ! -s "$TASK_FILE" ]; then
    echo "No tasks available."
    return
  fi

  # Case-insensitive search
  matches=$(grep -i "$keyword" "$TASK_FILE" || true)
  if [ -z "$matches" ]; then
    echo "No tasks found matching \"$keyword\"."
    return
  fi

  echo "$matches" > "$ROOT/.tmp_search"
  echo "Search results for \"$keyword\":"
  _print_from_file "$ROOT/.tmp_search"
  rm -f "$ROOT/.tmp_search"
}


case "$cmd" in
  add)
    add_task "$1" "$2"
    $commit_flag && auto_commit "Auto: added task '$1'"
    ;;
  list)
    list_tasks "$1"
    ;;
  done)
    mark_done "$1"
    $commit_flag && auto_commit "Auto: marked task $1 done"
    ;;
  delete)
    delete_task "$1"
    $commit_flag && auto_commit "Auto: deleted task $1"
    ;;
  search)
    search_tasks "$1"
    ;;
  help|"")
    usage
    ;;
  *)
    echo "Unknown command: $cmd"
    usage
    ;;
esac
