#!/usr/bin/env python3
"""Collect system stats for the SysDash plasmoid and print them as JSON.

Rates (CPU %, disk and network throughput) are computed against the
previous sample, which is cached in $XDG_RUNTIME_DIR between runs.
"""
import ctypes
import glob
import json
import os
import re
import time

STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "sysdash_state.json")


def read(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def hwmon(name):
    """Return {label: °C} for every hwmon device with the given name."""
    out = []
    for d in sorted(glob.glob("/sys/class/hwmon/hwmon*")):
        if read(f"{d}/name") != name:
            continue
        temps = {}
        for t in sorted(glob.glob(f"{d}/temp*_input")):
            label = read(t.replace("_input", "_label")) or os.path.basename(t)[:-6]
            v = read(t)
            if v is not None:
                temps[label] = int(v) / 1000
        out.append(temps)
    return out


def cpu_name():
    with open("/proc/cpuinfo") as f:
        for line in f:
            if line.startswith("model name"):
                name = re.sub(r"\b\d+-Core\b|@.*", " ", line.split(":", 1)[1])
                for junk in ("(R)", "(TM)", "CPU", "Processor", "AMD", "Intel"):
                    name = name.replace(junk, " ")
                return " ".join(name.split())
    return "CPU"


def cpu_times():
    times = {}
    with open("/proc/stat") as f:
        for line in f:
            if not line.startswith("cpu"):
                break
            name, *vals = line.split()
            vals = list(map(int, vals))
            idle = vals[3] + vals[4]
            times[name] = (sum(vals[:8]), idle)
    return times


def meminfo():
    m = {}
    with open("/proc/meminfo") as f:
        for line in f:
            k, v = line.split(":")
            m[k] = int(v.split()[0]) * 1024
    return m


def net_bytes():
    rx = tx = 0
    with open("/proc/net/dev") as f:
        for line in f.readlines()[2:]:
            iface, data = line.split(":", 1)
            iface = iface.strip()
            if iface == "lo" or iface.startswith(("veth", "docker", "virbr", "br-")):
                continue
            vals = data.split()
            rx += int(vals[0])
            tx += int(vals[8])
    return rx, tx


def disk_sectors():
    out = {}
    with open("/proc/diskstats") as f:
        for line in f:
            p = line.split()
            if p[2].startswith("nvme") and p[2].endswith("n1"):
                out[p[2]] = (int(p[5]), int(p[9]))
    return out


def mounts():
    """Map block device (e.g. nvme0n1) -> first mountpoint of its partitions."""
    def rank(mnt):  # lower is better: "/" first, /boot last
        return 0 if mnt == "/" else 2 if mnt.startswith("/boot") else 1

    out = {}
    with open("/proc/mounts") as f:
        for line in f:
            dev, mnt = line.split()[:2]
            if not dev.startswith("/dev/nvme"):
                continue
            disk = os.path.basename(dev).split("p")[0]
            mnt = mnt.replace("\\040", " ")
            if disk not in out or rank(mnt) < rank(out[disk]):
                out[disk] = mnt
    return out


class _Util(ctypes.Structure):
    _fields_ = [("gpu", ctypes.c_uint), ("memory", ctypes.c_uint)]


class _Mem(ctypes.Structure):
    _fields_ = [("total", ctypes.c_ulonglong), ("free", ctypes.c_ulonglong), ("used", ctypes.c_ulonglong)]


def nvidia():
    try:
        nv = ctypes.CDLL("libnvidia-ml.so.1")
    except OSError:
        return None
    if nv.nvmlInit_v2() != 0:
        return None
    try:
        h = ctypes.c_void_p()
        if nv.nvmlDeviceGetHandleByIndex_v2(0, ctypes.byref(h)) != 0:
            return None
        u = ctypes.c_uint()
        g = {}
        name = ctypes.create_string_buffer(96)
        if nv.nvmlDeviceGetName(h, name, 96) == 0:
            g["name"] = name.value.decode().replace("NVIDIA GeForce ", "")
        if nv.nvmlDeviceGetTemperature(h, 0, ctypes.byref(u)) == 0:
            g["temp"] = u.value
        util = _Util()
        if nv.nvmlDeviceGetUtilizationRates(h, ctypes.byref(util)) == 0:
            g["usage"] = util.gpu
        mem = _Mem()
        if nv.nvmlDeviceGetMemoryInfo(h, ctypes.byref(mem)) == 0:
            g["vramUsed"], g["vramTotal"] = mem.used, mem.total
        if nv.nvmlDeviceGetPowerUsage(h, ctypes.byref(u)) == 0:
            g["power"] = u.value / 1000
        if nv.nvmlDeviceGetEnforcedPowerLimit(h, ctypes.byref(u)) == 0:
            g["powerLimit"] = u.value / 1000
        if nv.nvmlDeviceGetClockInfo(h, 0, ctypes.byref(u)) == 0:
            g["clock"] = u.value
        if nv.nvmlDeviceGetFanSpeed(h, ctypes.byref(u)) == 0:
            g["fan"] = u.value
        return g
    finally:
        nv.nvmlShutdown()


def main():
    now = time.monotonic()
    try:
        with open(STATE) as f:
            prev = json.load(f)
    except (OSError, ValueError):
        prev = {}
    dt = max(now - prev.get("t", 0), 0.1)

    cur_cpu = cpu_times()
    prev_cpu = prev.get("cpu", {})

    def usage(name):
        if name not in prev_cpu:
            return 0.0
        dtot = cur_cpu[name][0] - prev_cpu[name][0]
        didle = cur_cpu[name][1] - prev_cpu[name][1]
        return round(100 * (1 - didle / dtot), 1) if dtot > 0 else 0.0

    cores = sorted((k for k in cur_cpu if k != "cpu"), key=lambda k: int(k[3:]))
    freqs = [int(v) / 1000 for v in (read(p) for p in glob.glob("/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq")) if v]

    # AMD reports Tctl/Tccd via k10temp, Intel reports "Package id 0" via coretemp.
    k10 = (hwmon("k10temp") or [{}])[0]
    core = (hwmon("coretemp") or [{}])[0]
    cpu_temp = k10.get("Tctl", core.get("Package id 0"))
    ccd_temp = k10.get("Tccd1")
    igpu = (hwmon("amdgpu") or [{}])[0]
    dimms = [t.get("temp1") for t in hwmon("spd5118")]

    m = meminfo()
    rx, tx = net_bytes()
    sectors = disk_sectors()
    mnt = mounts()

    disks = []
    for blk in sorted(sectors):
        model = read(f"/sys/block/{blk}/device/model", blk)
        temp = None
        for h in glob.glob(f"/sys/block/{blk}/device/hwmon*/temp1_input"):
            temp = int(read(h)) / 1000
        r, w = sectors[blk]
        pr, pw = prev.get("disk", {}).get(blk, (r, w))
        d = {
            "name": model,
            "temp": temp,
            "read": (r - pr) * 512 / dt,
            "write": (w - pw) * 512 / dt,
        }
        if blk in mnt:
            try:
                st = os.statvfs(mnt[blk])
                d["mount"] = mnt[blk]
                d["total"] = st.f_blocks * st.f_frsize
                d["used"] = (st.f_blocks - st.f_bfree) * st.f_frsize
            except OSError:
                pass
        disks.append(d)

    prx, ptx = prev.get("net", (rx, tx))
    load = read("/proc/loadavg", "0 0 0").split()[:3]

    data = {
        "cpu": {
            "name": cpu_name(),
            "usage": usage("cpu"),
            "cores": [usage(c) for c in cores],
            "freq": round(sum(freqs) / len(freqs)) if freqs else 0,
            "freqMax": round(max(freqs)) if freqs else 0,
            "temp": cpu_temp,
            "ccd": ccd_temp,
            "load": [float(x) for x in load],
        },
        "gpu": nvidia(),
        "igpu": {"temp": igpu.get("edge")},
        "mem": {
            "total": m["MemTotal"],
            "used": m["MemTotal"] - m["MemAvailable"],
            "cache": m.get("Cached", 0) + m.get("Buffers", 0),
            "swapTotal": m["SwapTotal"],
            "swapUsed": m["SwapTotal"] - m["SwapFree"],
            "dimmTemps": [t for t in dimms if t is not None],
        },
        "disks": disks,
        "net": {"down": max(rx - prx, 0) / dt, "up": max(tx - ptx, 0) / dt},
        "uptime": float(read("/proc/uptime", "0").split()[0]),
    }

    try:
        with open(STATE, "w") as f:
            json.dump({"t": now, "cpu": cur_cpu, "net": (rx, tx), "disk": sectors}, f)
    except OSError:
        pass

    print(json.dumps(data))


if __name__ == "__main__":
    main()
