"""Apply the shared Jade palette to the pinned GTK/Kvantum theme assets.

Replace complete colour tokens in one pass, including RGB CSS and the trailing
alpha used by Kvantum. Never rewrite binary assets or cascade substitutions.
"""
import json
from pathlib import Path
import re
import sys

root, mapping_file, old_name, new_name = sys.argv[1:]
colors = json.loads(Path(mapping_file).read_text())
pattern = re.compile(r"#[0-9a-f]{6}(?:[0-9a-f]{2})?\b|rgba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+(?:\s*,\s*[\d.]+)?\s*\)", re.I)
replaced = set()


def recolor(match):
    token = match.group()
    if token.startswith("#"):
        key = token[:7].lower()
        if key in colors:
            replaced.add(key)
            return colors[key] + token[7:]
    else:
        channels = re.findall(r"[\d.]+", token)
        key = "#" + "".join(f"{int(n):02x}" for n in channels[:3])
        if key in colors:
            replaced.add(key)
            rgb = [str(int(colors[key][i:i + 2], 16)) for i in (1, 3, 5)]
            return token.split("(")[0] + "(" + ", ".join(rgb + channels[3:]) + ")"
    return token


count = 0
for path in Path(root).rglob("*"):
    if path.is_file() and path.suffix in (".css", ".svg", ".kvconfig", ".theme", ".xml"):
        original = path.read_text()
        updated = pattern.sub(recolor, original).replace(old_name, new_name)
        if updated != original:
            path.write_text(updated)
            count += 1
assert {"#1e1e2e", "#89b4fa"} <= replaced, "Upstream theme palette changed; review Jade mappings"
print(f"Recoloured {count} theme assets using {len(replaced)} palette colours")
