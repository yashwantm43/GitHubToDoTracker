set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
TASK_FILE="$ROOT/tasks.txt"
LOG_DIR="$ROOT/logs"

LOG_FILE="$LOG_DIR/actions.log"
mkdir -p "$LOG_DIR"
touch "$TASK_FILE" "$LOG_FILE"
RED='\033[0;31m'
GREEN='\033[0;32m'

YELLOW='\033[1;33m'

RESET= '\033[0m'
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
_normalize_tasks_file() {
  if [ -f "$TASK_FILE" ]; then
    sed -i 's/\r$//' "$TASK_FILE" 2>/dev/null || true
    awk -F'|' 'BEGIN{OFS="|"} {for(i=1;i<=NF;i++){gsub(/^[ \t]+|[ \t]+$/,"",$i)} print}' "$TASK_FILE" > "$TASK_FILE.tmp" && mv "$TASK_FILE.tmp" "$TASK_FILE"
  fi
}

_render_awk='-v RED="'"$RED"'" -v GREEN="'"$GREEN"'" -v YELLOW="'"$YELLOW"'" -v RESET="'"$RESET"'" \
{ status=$1; priority=tolower($2); desc=$3; ts=$4; \
  color=RESET; if(priority=="high") color=RED; else if(priority=="medium") color=YELLOW; else color=GREEN; \
  symbol=(status=="[x]") ? GREEN "✔" RESET : RED "✘" RESET; \
  printf "%2d. %s %-40s (priority:%s%s%s) — %s\n", NR, symbol, desc, color, priority, RESET, ts }'

list_tasks() {
  sort_mode="$1"
  _normalize_tasks_file

  if [ ! -s "$TASK_FILE" ]; then
    echo "No tasks available."
    return
  fi

  case "$sort_mode" in
    priority)
      # rank: high=1, medium=2, low=3; stable sort
      awk -F'|' '{ pri=tolower($2); if(pri=="high") r=1; else if(pri=="medium") r=2; else r=3; print r "|" $0 }' "$TASK_FILE" \
        | sort -t'|' -k1,1n -s \
        | cut -d'|' -f2- \
        | awk -F'|' $ _render_awk
      ;;
    status)
      # status rank: undone=1, done=2; then priority rank inside
      awk -F'|' '{ st=$1; pri=tolower($2); if(st=="[ ]") sr=1; else sr=2; if(pri=="high") pr=1; else if(pri=="medium") pr=2; else pr=3; print sr "|" pr "|" $0 }' "$TASK_FILE" \
        | sort -t'|' -k1,1n -k2,2n -s \
        | cut -d'|' -f3- \
        | awk -F'|' $ _render_awk
      ;;
    *)
      awk -F'|' $ _render_awk "$TASK_FILE"
      ;;
  esac
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
add_task() {
  desc="$1"
  priority="${2:-medium}"
  priority="$(echo "$priority" | tr '[:upper:]' '[:lower:]')"
  _normalize_tasks_file
  ts="$(date '+%F %T')"
  echo "[ ]|$priority|$desc|$ts" >> "$TASK_FILE"
  echo -e "Added: ${YELLOW}$desc${RESET} (priority: $priority)"
  log_action "ADD" "$desc (priority:$priority)"
}
cmd="${1:-}"
shift || true
commit_flag=false
ARGS=()
for a in "$@"; do
  if [ "$a" = "--commit" ]; then commit_flag=true; else ARGS+=("$a"); fi
done
set -- "${ARGS[@]}"

case "$cmd" in
  add) add_task "$1" "$2"; $commit_flag && auto_commit "Auto: added task '$1'";;
  list) list_tasks "$1";;
  done) mark_done "$1"; $commit_flag && auto_commit "Auto: marked task $1 done";;
  delete) delete_task "$1"; $commit_flag && auto_commit "Auto: deleted task $1";;
  help|"") usage;;
  *) echo "Unknown command: $cmd"; usage; exit 1;;
esac
