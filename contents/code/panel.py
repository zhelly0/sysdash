#!/usr/bin/env python3
"""Print the bottom Plasma panel's visible geometry on a screen as JSON.

Asks plasmashell through its scripting D-Bus API and prints e.g.
{"screenWidth": 5120, "width": 1472, "top": 1386}. "width" is 0 when it
can't be known ("fit content" mode); without a bottom panel, "top" is the
screen height.
"""
import json
import shutil
import subprocess
import sys

# Plasma insets a floating panel's visible background by this much per side.
FLOAT_MARGIN = 8

SCRIPT = """
var screen = %d, margin = %d;
var geo = screenGeometry(screen);
var out = { screenWidth: geo.width, width: 0, top: geo.height };
var done = false;
panels().forEach(function (p) {
    if (done || p.location != "bottom" || p.screen != screen) return;
    done = true;
    var inset = p.floating ? margin : 0;
    var w = 0;
    if (p.lengthMode == "fill") w = geo.width;
    else if (p.lengthMode == "custom") w = p.maximumLength;
    out.width = w ? w - 2 * inset : 0;
    out.top = geo.height - p.height - inset;
});
print(JSON.stringify(out));
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
        out = json.loads(evaluate(SCRIPT % (screen, FLOAT_MARGIN)))
    except (OSError, subprocess.SubprocessError, ValueError):
        return
    print(json.dumps(out))


if __name__ == "__main__":
    main()
