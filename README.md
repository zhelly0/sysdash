# SysDash

A KDE Plasma 6 desktop widget that shows CPU, GPU, memory, storage and network
stats with temperatures, laid out as a horizontal strip that sits nicely above
a bottom taskbar.

- CPU usage gauge, clock, load, per-thread bars, package/core temperatures
- NVIDIA GPU usage, clock, fan, power, VRAM and temperature (read via NVML, no `nvidia-smi` needed)
- RAM (with cache), swap and RAM stick temperatures (DDR5 `spd5118` sensors)
- Per-drive usage and NVMe temperature, plus a read/write graph for the system drive
- Network throughput graph and uptime
- History graphs for every section

Colors follow your Plasma color scheme by default, and the background can use
the same theme graphics as your panel so the two match.

## Settings

Right-click the widget → **Configure SysDash…**

- **Appearance:** refresh rate, graph history length, animations, width
  (auto, fixed, or *match the bottom taskbar*), auto-centering, sitting a
  set gap above the taskbar, spacing, text size,
  background style (match taskbar / Plasma widget / custom color, opacity and
  corner radius / none), section tile tint and radius
- **Sections:** show or hide each section and almost every element in it
- **Colors:** theme colors or custom per-section colors, temperature
  thresholds, graph line width and fill

## Requirements

- KDE Plasma 6
- Python 3 (standard library only)
- Optional: NVIDIA proprietary driver for GPU stats (`libnvidia-ml.so.1`)

Temperatures are read straight from `/sys/class/hwmon`. AMD (`k10temp`) and
Intel (`coretemp`) CPUs are supported.

## Install

The folder name must match the plugin id:

```sh
git clone https://github.com/zhelly0/sysdash ~/.local/share/plasma/plasmoids/com.milton.sysdash
```

Then right-click the desktop → **Add Widgets…** → search for **SysDash**. If it
doesn't show up, restart Plasma: `systemctl --user restart plasma-plasmashell`.

To update: `git pull` in that folder and restart Plasma.

## License

GPL-3.0, see [LICENSE](LICENSE).
