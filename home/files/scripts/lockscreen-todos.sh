#!/usr/bin/env bash
# Unchecked todos from the dedicated TODO note, rendered as Pango markup for
# a hyprlock label. Colors match the lock screen theme. Lines are truncated
# and the list capped so the right-anchored label never grows wide enough to
# reach the center glass panel.

TODO_FILE="$HOME/Documents/obsidian/Templates/TODO.md"
MAX_SHOWN=10
MAX_LEN=40
TODO_RE='^[[:space:]]*[-*] \[ \][[:space:]]*[^[:space:]]'

pango_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

clean() { # strip "- [ ]", unwrap wikilinks, trim, drop empties
  sed -E -e 's/^[[:space:]]*[-*] \[ \][[:space:]]*//' \
    -e 's/\[\[([^]|]*\|)?([^]]+)\]\]/\2/g' \
    -e 's/[[:space:]]+$//' |
    sed '/^$/d'
}

tasks=$(grep -E "$TODO_RE" "$TODO_FILE" 2>/dev/null | clean)

if [ -n "$tasks" ]; then
  total=$(printf '%s\n' "$tasks" | wc -l)
  extra=0
  [ "$total" -gt "$MAX_SHOWN" ] && extra=$((total - MAX_SHOWN))
  printf '<span foreground="#33ccff" size="large"><b>待辦事項</b></span> <span foreground="#66788c">· %s</span>\n\n' "$total"
  while IFS= read -r line; do
    [ "${#line}" -gt "$MAX_LEN" ] && line="${line:0:MAX_LEN}…"
    printf '<span foreground="#d8f0ff">%s</span>\n' "$(printf '%s' "$line" | pango_escape)"
  done <<<"$(printf '%s\n' "$tasks" | head -n "$MAX_SHOWN")"
  [ "$extra" -gt 0 ] && printf '<span foreground="#66788c">… 還有 %s 項</span>\n' "$extra"
else
  printf '<span foreground="#00ff99"><b>✓ 全部完成</b></span>\n'
fi
