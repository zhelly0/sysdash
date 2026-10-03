#!/usr/bin/env python3
"""Print the visible width of the bottom Plasma panel on the widget's screen.

Asks plasmashell through its scripting D-Bus API. Prints nothing if there is
no bottom panel or its width can't be known (e.g. "fit content" mode).
"""
import shutil
import subprocess
import sys

# Plasma insets a floating panel's visible background by this much per side.
FLOAT_MARGIN = 8

SCRIPT = """
var out = "";
panels().forEach(function (p) {
    if (out || p.location != "bottom" || p.screen != %d) return;
    var w = 0;
    if (p.lengthMode == "fill") w = screenGeometry(p.screen).width;
    else if (p.lengthMode == "custom") w = p.maximumLength;
    if (w) out = String(w - (p.floating ? 2 * %d : 0));
});
print(out);
"""


def evaluate(script):
    for tool in ("qdbus6", "qdbus-qt6", "qdbus"):
        if shutil.which(tool):
            cmd = [tool, "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", script]
            return subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
    if shutil.which("gdbus"):
        cmd = ["gdbus", "call", "--session", "--dest", "org.kde.plasmashell", "--object-path", "/PlasmaShell",
               "--method", "org.kde.PlasmaShell.evaluateScript", script]
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=5).stdout
        return out.strip().removeprefix("('").removesuffix("',)")
    return ""


def main():
    screen = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    try:
        out = evaluate(SCRIPT % (screen, FLOAT_MARGIN)).strip()
    except (OSError, subprocess.SubprocessError):
        return
    if out.isdigit():
        print(out)


if __name__ == "__main__":
    main()
