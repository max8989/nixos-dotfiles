#!/usr/bin/env bash
# Unchecked Obsidian todos rendered as Pango markup for a hyprlock label.
# Mirrors the queries on "00 Home/Home.md":
#   path:"40 Daily" / "10 Projects" / "20 Areas" with task-todo:""
# Colors match the lock screen theme (neon cyan / green / ice text).

VAULT="$HOME/Documents/obsidian"
PER_SECTION=5
MAX_LEN=48

pango_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

tasks_in() { # <dir> — every unchecked "- [ ]" item, wikilinks unwrapped
  [ -d "$1" ] || return 0
  find "$1" -name '*.md' -print0 | sort -z |
    xargs -0 -r grep -h -E '^[[:space:]]*[-*] \[ \]' 2>/dev/null |
    sed -E -e 's/^[[:space:]]*[-*] \[ \][[:space:]]*//' \
      -e 's/\[\[([^]|]*\|)?([^]]+)\]\]/\2/g' \
      -e 's/[[:space:]]+$//' |
    sed '/^$/d'
}

section() { # <dir> <title>
  local all total shown line extra=0
  all=$(tasks_in "$VAULT/$1")
  [ -n "$all" ] || return 0
  total=$(printf '%s\n' "$all" | wc -l)
  shown=$(printf '%s\n' "$all" | head -n "$PER_SECTION")
  [ "$total" -gt "$PER_SECTION" ] && extra=$((total - PER_SECTION))
  printf '<span foreground="#33ccff"><b>▍%s</b></span>\n' "$2"
  while IFS= read -r line; do
    [ "${#line}" -gt "$MAX_LEN" ] && line="${line:0:MAX_LEN}…"
    printf '<span foreground="#00ff99">☐</span> <span foreground="#d8f0ff">%s</span>\n' \
      "$(printf '%s' "$line" | pango_escape)"
  done <<<"$shown"
  [ "$extra" -gt 0 ] && printf '<span foreground="#66788c">  … 還有 %s 項</span>\n' "$extra"
  printf '\n'
}

out=$(
  section "40 Daily" "每日任務"
  section "10 Projects" "專案"
  section "20 Areas" "領域"
)

if [ -n "$out" ]; then
  printf '<span foreground="#33ccff" size="large"><b>待辦事項</b></span>\n\n'
  printf '%s\n' "$out"
else
  printf '<span foreground="#00ff99"><b>✓ 全部完成</b></span>\n'
fi
