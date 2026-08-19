#!/usr/bin/env bash
# Unchecked Obsidian todos rendered as Pango markup for a hyprlock label.
# Scope matches the waybar todo counter (waybar/scripts/todos.sh): the whole
# vault minus template/archive/system dirs — grouped like the query sections
# on "00 Home/Home.md". Colors match the lock screen theme.
#
# NOTE: the todo regex + exclusions must stay in sync with
# waybar/scripts/todos.sh and todo-menu.sh.

VAULT="$HOME/Documents/obsidian"
PER_SECTION=5
MAX_LEN=48
TODO_RE='^[[:space:]]*[-*] \[ \][[:space:]]*[^[:space:]]'

EXCLUDES=(
  --exclude-dir='Templates' --exclude-dir='90 Archive'
  --exclude-dir='99 System' --exclude-dir='Obsidian'
  --exclude-dir='Assets' --exclude-dir='.obsidian' --exclude-dir='.git'
  --exclude='SETUP.md' --exclude='README.md'
  --exclude='CLAUDE.md' --exclude='AGENTS.md'
)

pango_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

clean() { # strip "- [ ]", unwrap wikilinks, trim, drop empties
  sed -E -e 's/^[[:space:]]*[-*] \[ \][[:space:]]*//' \
    -e 's/\[\[([^]|]*\|)?([^]]+)\]\]/\2/g' \
    -e 's/[[:space:]]+$//' |
    sed '/^$/d'
}

label() { # grep -Z "file\0task" lines → "note-name<TAB>cleaned task"
  local file task
  while IFS= read -r -d '' file && IFS= read -r task; do
    task=$(printf '%s\n' "$task" | clean)
    [ -n "$task" ] || continue
    printf '%s\t%s\n' "$(basename "$file" .md)" "$task"
  done
}

tasks_in() { # <dir> — unchecked todos from one vault section
  [ -d "$1" ] || return 0
  find "$1" -name '*.md' -print0 | sort -z |
    xargs -0 -r grep -HZ -E "$TODO_RE" 2>/dev/null | label
}

tasks_other() { # everything the bar counts that no section above covers
  grep -rZ --include='*.md' "${EXCLUDES[@]}" \
    --exclude-dir='40 Daily' --exclude-dir='10 Projects' \
    --exclude-dir='20 Areas' --exclude-dir='01 Inbox' \
    --exclude-dir='30 Resources' \
    -E "$TODO_RE" "$VAULT" 2>/dev/null | label
}

render() { # <title>; "note-name<TAB>task" lines on stdin
  local all total shown note line extra=0
  all=$(cat)
  [ -n "$all" ] || return 0
  total=$(printf '%s\n' "$all" | wc -l)
  shown=$(printf '%s\n' "$all" | head -n "$PER_SECTION")
  [ "$total" -gt "$PER_SECTION" ] && extra=$((total - PER_SECTION))
  printf '<span foreground="#33ccff"><b>▍%s</b></span>\n' "$1"
  while IFS=$'\t' read -r note line; do
    [ "${#line}" -gt "$MAX_LEN" ] && line="${line:0:MAX_LEN}…"
    printf '<span foreground="#66788c">%s</span> <span foreground="#d8f0ff">%s</span>\n' \
      "$(printf '%s' "$note" | pango_escape)" "$(printf '%s' "$line" | pango_escape)"
  done <<<"$shown"
  [ "$extra" -gt 0 ] && printf '<span foreground="#66788c">  … 還有 %s 項</span>\n' "$extra"
  printf '\n'
}

out=$(
  tasks_in "$VAULT/10 Projects" | render "專案"
  tasks_in "$VAULT/40 Daily" | render "每日任務"
  tasks_in "$VAULT/20 Areas" | render "領域"
  tasks_in "$VAULT/01 Inbox" | render "收件匣"
  tasks_in "$VAULT/30 Resources" | render "資源"
  tasks_other | render "其他"
)

if [ -n "$out" ]; then
  # Same total the waybar counter shows.
  count=$(grep -rn --include='*.md' "${EXCLUDES[@]}" -E "$TODO_RE" \
    "$VAULT" 2>/dev/null | wc -l)
  printf '<span foreground="#33ccff" size="large"><b>待辦事項</b></span> <span foreground="#66788c">· %s</span>\n\n' "$count"
  printf '%s\n' "$out"
else
  printf '<span foreground="#00ff99"><b>✓ 全部完成</b></span>\n'
fi
