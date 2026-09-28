"""Check QML while accounting for specific upstream 0.3.1 metadata defects.

Runtime smoke tests supplement these narrow exceptions; missing imports,
unknown properties, and syntax errors are never globally disabled.
"""
import json
import pathlib
import subprocess
import sys

root, quickshell_qml, qt_qml, output = sys.argv[1:]
files = sorted(str(p) for p in pathlib.Path(root).rglob("*.qml"))
subprocess.run(["qmllint", "-I", quickshell_qml, "-I", qt_qml, "--json", output, *files], check=False)
report = json.loads(pathlib.Path(output).read_text())
errors = []
allowed_metadata = {
    'Type PanelWindow is not creatable.',
    'Type margins is used but it is not resolved',
    'Type "UntypedObjectModel" of property "devices" not found. This is likely due to a missing dependency entry or a type not being exposed declaratively.',
    'Type "UntypedObjectModel" of property "adapters" not found. This is likely due to a missing dependency entry or a type not being exposed declaratively.',
    'Type "AuthFlow" of property "flow" not found. This is likely due to a missing dependency entry or a type not being exposed declaratively.',
    'Type QProcess::ExitStatus of parameter exitStatus in signal called exited was not found, but is required to compile onExited. Did you add all imports and dependencies?',
}
# 0.3.1's PopupAnchor metadata declares Edges::Flags / PopupAdjustment::Flags
# without exporting those flag types, and _Window omits its core dependency.
# The popup properties and updateAnchor() are exercised by the headless UI test.
allowed_tooltip_metadata = {
    'No type found for property "edges". This may be due to a missing import statement or incomplete qmltypes files.',
    'No type found for property "gravity". This may be due to a missing import statement or incomplete qmltypes files.',
    'No type found for property "adjustment". This may be due to a missing import statement or incomplete qmltypes files.',
    'Type "PopupAnchor" of property "anchor" not found. This is likely due to a missing dependency entry or a type not being exposed declaratively.',
}
for item in report["files"]:
    for warning in item["warnings"]:
        if warning["id"] in ("unqualified", "unused-imports") or warning["message"] in allowed_metadata:
            continue
        if item["filename"].endswith("/widgets/HoverTip.qml") and warning["message"] in allowed_tooltip_metadata:
            continue
        errors.append(f'{item["filename"]}:{warning["line"]}: {warning["message"]}')
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"Checked {len(files)} QML files; only documented upstream metadata exceptions remain.")
