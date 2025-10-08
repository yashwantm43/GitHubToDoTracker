#!/usr/bin/env bash
# todo.sh - Git-based To-Do Tracker (Final Version - Day 12)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TASK_FILE="$ROOT/tasks.txt"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/actions.log"
TMP_SORT="$ROOT/.tmp_tasks_sorted"

mkdir -p "$LOG_DIR"
touch "$TASK_FILE" "$LOG_FILE"

# Colors for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

# -------------------------
# HELP / USAGE
# -------------------------
usage() {
  echo -e "${YELLOW}To-Do Tracker Commands:${RESET}"
  echo "  ./todo.sh add \"desc\" [priority] [--commit]"
  echo "  ./todo.sh list [--sort priority|status|--done|--pending|--high]"
  echo "  ./todo.sh search \"keyword\""
  echo "  ./todo.sh done N [--commit]"
  echo "  ./todo.sh delete N [--commit]"
  echo "  ./todo.sh backup"
  echo "  ./todo.sh export csv"
  echo "  ./todo.sh help"
}

# -------------------------
# UTILITIES
# -------------------------
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

_normalize_tasks_file() {
  if [ -f "$TASK_FILE" ]; then
    sed -i 's/\r$//' "$TASK_FILE" 2>/dev/null || true
    awk -F'|' 'BEGIN{OFS="|"} {
      for(i=1;i<=NF;i++){gsub(/^[ \t]+|[ \t]+$/,"",$i)}
      print
    }' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
  fi
}

# -------------------------
# DISPLAY HELPERS
# -------------------------
_print_from_file() {
  n=1
  while IFS='|' read -r status priority desc ts; do
    [ -z "$status" ] && continue
    pr="$(echo "$priority" | tr '[:upper:]' '[:lower:]')"
    if [ "$pr" = "high" ]; then color="$RED"
    elif [ "$pr" = "medium" ]; then color="$YELLOW"
    else color="$GREEN"; fi
    if [ "$status" = "[x]" ]; then symbol="${GREEN}✔${RESET}"
    else symbol="${RED}✘${RESET}"; fi
    printf "%2d. %b %-40s (priority:%b%s%b) — %s\n" \
      "$n" "$symbol" "$desc" "$color" "$pr" "$RESET" "$ts"
    n=$((n+1))
  done < "$1"
}

show_summary() {
  total=$(wc -l < "$TASK_FILE" | tr -d ' ')
  done_count=$(grep -c '^\[x\]' "$TASK_FILE" || true)
  pending=$(( total - done_count ))
  echo ""
  echo -e "📋 ${YELLOW}Total:${RESET} $total | ${GREEN}Done:${RESET} $done_count | ${RED}Pending:${RESET} $pending"
}

# -------------------------
# CORE COMMANDS
# -------------------------
add_task() {
  desc="$1"
  priority="${2:-medium}"
  priority="$(echo "$priority" | tr '[:upper:]' '[:lower:]')"
  if [[ "$desc" == *"|"* ]]; then
    echo "Error: '|' not allowed in description."
    exit 1
  fi
  _normalize_tasks_file
  ts="$(date '+%F %T')"
  echo "[ ]|$priority|$desc|$ts" >> "$TASK_FILE"
  echo -e "Added: ${YELLOW}$desc${RESET} (priority: $priority)"
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
  echo -e "Marked task $n as ${GREEN}done${RESET}."
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
  echo -e "Deleted task $n."
  log_action "DELETE" "Task $n"
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
      awk -F'|' '{
        p=tolower($2)
        if(p=="high") r=1; else if(p=="medium") r=2; else r=3
        print r "|" $0
      }' "$TASK_FILE" | sort -t'|' -k1,1n | cut -d'|' -f2- > "$TMP_SORT"
      _print_from_file "$TMP_SORT"
      rm -f "$TMP_SORT"
      ;;
    status)
      awk -F'|' '{
        st=$1; p=tolower($2)
        if(st=="[ ]") sr=1; else sr=2
        if(p=="high") pr=1; else if(p=="medium") pr=2; else pr=3
        print sr "|" pr "|" $0
      }' "$TASK_FILE" | sort -t'|' -k1,1n -k2,2n | cut -d'|' -f3- > "$TMP_SORT"
      _print_from_file "$TMP_SORT"
      rm -f "$TMP_SORT"
      ;;
    --done)
      grep '^\[x\]' "$TASK_FILE" > "$TMP_SORT" || true
      _print_from_file "$TMP_SORT"
      rm -f "$TMP_SORT"
      ;;
    --pending)
      grep '^\[ \]' "$TASK_FILE" > "$TMP_SORT" || true
      _print_from_file "$TMP_SORT"
      rm -f "$TMP_SORT"
      ;;
    --high)
      grep -i 'high' "$TASK_FILE" > "$TMP_SORT" || true
      _print_from_file "$TMP_SORT"
      rm -f "$TMP_SORT"
      ;;
    *)
      _print_from_file "$TASK_FILE"
      ;;
  esac
  show_summary
}

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

  matches=$(grep -i "$keyword" "$TASK_FILE" || true)
  if [ -z "$matches" ]; then
    echo "No tasks found matching \"$keyword\"."
    return
  fi

  echo "$matches" > "$ROOT/.tmp_search"
  echo -e "${YELLOW}Search results for \"$keyword\":${RESET}"
  _print_from_file "$ROOT/.tmp_search"
  rm -f "$ROOT/.tmp_search"
  show_summary
}

# -------------------------
# NEW FEATURES (Day 12)
# -------------------------
backup_tasks() {
  mkdir -p "$ROOT/backups"
  filename="tasks-$(date '+%Y%m%d-%H%M%S').txt"
  cp "$TASK_FILE" "$ROOT/backups/$filename"
  echo "Backup saved to backups/$filename"
  log_action "BACKUP" "$filename"
}

export_csv() {
  mkdir -p "$ROOT/backups"
  csvfile="$ROOT/backups/tasks-$(date '+%Y%m%d-%H%M%S').csv"
  awk -F'|' 'BEGIN{OFS=","; print "Status,Priority,Description,Timestamp"} {print $1,$2,$3,$4}' "$TASK_FILE" > "$csvfile"
  echo "Exported tasks to $csvfile"
  log_action "EXPORT" "$csvfile"
}

# -------------------------
# COMMAND ROUTER
# -------------------------
cmd="${1:-}"
shift || true
commit_flag=false
ARGS=()
for a in "$@"; do
  if [ "$a" = "--commit" ]; then commit_flag=true; else ARGS+=("$a"); fi
done
set -- "${ARGS[@]}"

case "$cmd" in
  add)
    add_task "$1" "${2:-}"
    $commit_flag && auto_commit "Auto: added task '$1'"
    ;;
  list)
    list_tasks "${1:-}"
    ;;
  search)
    search_tasks "${1:-}"
    ;;
  done)
    mark_done "$1"
    $commit_flag && auto_commit "Auto: marked task $1 done"
    ;;
  delete)
    delete_task "$1"
    $commit_flag && auto_commit "Auto: deleted task $1"
    ;;
  backup)
    backup_tasks
    ;;
  export)
    export_csv
    ;;
  help|"")
    usage
    ;;
  *)
    echo "Unknown command: $cmd"
    usage
    ;;
esac
