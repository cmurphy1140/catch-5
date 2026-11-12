#!/usr/bin/env python3
"""Run a one-at-a-time simulator smoke test for Catch 5, safely.

- A cross-process lock (fcntl.flock) lets only one job touch a simulator at a
  time, even across separate agent processes. The OS releases the lock if the
  process dies, even from kill -9, so a crashed job can't jam the queue.
- The memory check runs while holding the lock, so two jobs can't both see
  "30% free" and both boot.
- Refuses to boot unless macOS memory pressure is normal with MIN_FREE_PCT free,
  or if another simulator is already booted (an orphan from an earlier run).
- A watchdog shuts the device down if pressure goes critical mid-run.
- Reuses the device if it's already booted; shuts down only what it booted.
- Cleans up the log stream, app and device on success, error, Ctrl+C,
  SIGTERM or a closed terminal.

Only jobs that go through this script share the lock: scripts/run-simulator.sh
and the iOS Simulator panel boot devices on their own.

Exit codes: 0 OK, 1 the app failed, 2 refused to run (not safe right now).

Usage:
  python3 scripts/sim_guard.py [--app work/simulator-build/CatchFive.app]
      [--bundle-id com.cardgame.catchfive] [--device "Catch 5 iPhone"]
"""
import argparse
import contextlib
import fcntl
import json
import os
import plistlib
import re
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

LOCK_PATH = "/tmp/sim_guard.lock"
LOCK_WAIT_SECONDS = 600
CMD_TIMEOUT = 180   # no single simctl call may hang forever while holding the lock
BOOT_TIMEOUT = 300
MIN_FREE_PCT = 20   # refuse to boot below this system-wide free percentage


class Refused(RuntimeError):
    """Not safe to run right now. Nothing was booted."""


def run(*args, timeout=CMD_TIMEOUT, check=True):
    return subprocess.run(args, capture_output=True, text=True,
                          timeout=timeout, check=check)


def simctl(*args, **kw):
    return run("xcrun", "simctl", *args, **kw)


# --- the semaphore -----------------------------------------------------------

@contextlib.contextmanager
def sim_lock(path=LOCK_PATH, wait=LOCK_WAIT_SECONDS):
    """Cross-process semaphore of size 1. Waits up to `wait` seconds."""
    fd = os.open(path, os.O_CREAT | os.O_RDWR, 0o644)
    deadline = time.monotonic() + wait
    try:
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() > deadline:
                    raise Refused(
                        f"another simulator job has held the lock for over {wait}s")
                time.sleep(min(2, wait / 4))
        yield
    finally:
        os.close(fd)  # closing the descriptor releases the lock


# --- memory gate -------------------------------------------------------------

def memory_refusal(level, free_pct, min_free_pct=MIN_FREE_PCT):
    """Why booting is unsafe, or None. level: 1 normal, 2 warning, 4 critical."""
    # Measured 2026-10-21 on this 8 GB Mac: one boot from warning at 27% free went
    # critical in 33 s while free still read 26%, so warning blocks whatever free says.
    if level is not None and level >= 2:
        return "memory pressure is " + ("critical" if level >= 4 else "warning")
    if free_pct is not None and free_pct < min_free_pct:
        return f"only {free_pct}% memory free (need {min_free_pct}%)"
    return None


def pressure_level():
    r = run("sysctl", "-n", "kern.memorystatus_vm_pressure_level", check=False)
    return int(r.stdout.strip()) if r.returncode == 0 and r.stdout.strip().isdigit() else None


@contextlib.contextmanager
def pressure_watchdog(on_critical, interval=2, read_level=pressure_level):
    """The gate only looks before boot; this calls on_critical once if pressure goes critical mid-run."""
    tripped, stop = threading.Event(), threading.Event()

    def watch():
        while not stop.wait(interval):
            level = read_level()
            if level is not None and level >= 4:
                tripped.set()
                on_critical()
                return

    t = threading.Thread(target=watch, daemon=True)
    t.start()
    try:
        yield tripped
    finally:
        stop.set()
        t.join(timeout=interval + 70)


def require_memory_headroom(min_free_pct=MIN_FREE_PCT):
    level = pressure_level()
    r = run("memory_pressure", "-Q", check=False)
    m = re.search(r"free percentage:\s*(\d+)%", r.stdout)
    reason = memory_refusal(level, int(m.group(1)) if m else None, min_free_pct)
    if reason:
        raise Refused(reason + "; not booting a simulator")


# --- device lifecycle --------------------------------------------------------

def list_devices():
    data = json.loads(simctl("list", "devices", "available", "-j").stdout)
    return [d for devs in data["devices"].values() for d in devs]


@contextlib.contextmanager
def booted_device(name):
    devices = list_devices()
    matches = [d for d in devices if d["name"] == name]
    if not matches:
        raise Refused(f'no available simulator named "{name}"')
    dev = next((d for d in matches if d["state"] == "Booted"), matches[-1])
    udid = dev["udid"]

    orphans = [d["name"] for d in devices
               if d["state"] == "Booted" and d["udid"] != udid]
    if orphans:
        raise Refused(
            "other simulators are still booted: " + ", ".join(orphans)
            + ". Run `xcrun simctl shutdown all` first.")

    we_booted = dev["state"] != "Booted"
    if we_booted:
        require_memory_headroom()
    shutdown = lambda: simctl("shutdown", udid, check=False, timeout=60)  # noqa: E731
    with pressure_watchdog(shutdown) as tripped:
        try:
            simctl("bootstatus", udid, "-b", timeout=BOOT_TIMEOUT)  # boot if needed, wait until ready
            yield udid
        except (RuntimeError, subprocess.SubprocessError) as e:
            if tripped.is_set() and not isinstance(e, Refused):
                raise Refused("memory pressure went critical mid-run; the simulator was shut down") from e
            raise
        finally:
            if we_booted and not tripped.is_set():
                shutdown()
        if tripped.is_set():
            raise Refused("memory pressure went critical mid-run; the simulator was shut down")


@contextlib.contextmanager
def log_stream(udid, process_name, out_path):
    """`log stream` never exits on its own, so it is always killed on the way out."""
    with open(out_path, "w") as f:
        proc = subprocess.Popen(
            ["xcrun", "simctl", "spawn", udid, "log", "stream", "--style", "compact",
             "--predicate", f'process == "{process_name}"'],
            stdout=f, stderr=subprocess.STDOUT)
        try:
            yield
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()


def is_running(udid, bundle_id):
    out = simctl("spawn", udid, "launchctl", "list", check=False).stdout
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 3 and bundle_id in parts[2] and parts[0] != "-":
            return True
    return False


# --- smoke test --------------------------------------------------------------

def _exit_on_signal(signum, _frame):
    raise SystemExit(128 + signum)  # lets every `finally` above run


def main():
    p = argparse.ArgumentParser(description="One-at-a-time simulator smoke test")
    p.add_argument("--app", default="work/simulator-build/CatchFive.app",
                   help="path to the built .app")
    p.add_argument("--bundle-id", default="com.cardgame.catchfive")
    p.add_argument("--device", default="Catch 5 iPhone")
    p.add_argument("--out", default="work/sim-shots",
                   help="output folder (keep it out of iCloud-synced folders)")
    p.add_argument("--settle", type=float, default=4.0,
                   help="seconds to wait after launch before the screenshot")
    args = p.parse_args()

    for sig in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, _exit_on_signal)

    app = Path(args.app)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    with open(app / "Info.plist", "rb") as f:
        exe = plistlib.load(f)["CFBundleExecutable"]
    log_path = out / "app.log"

    try:
        with sim_lock(), booted_device(args.device) as udid, \
                log_stream(udid, exe, log_path):
            simctl("install", udid, str(app))
            try:
                for i in (1, 2):  # launch, then relaunch
                    simctl("launch", udid, args.bundle_id)
                    time.sleep(args.settle)
                    simctl("io", udid, "screenshot", str(out / f"launch{i}.png"))
                    if not is_running(udid, args.bundle_id):
                        raise RuntimeError(
                            f"app was not running after launch {i}; see {log_path}")
                    simctl("terminate", udid, args.bundle_id, check=False)
            finally:
                simctl("terminate", udid, args.bundle_id, check=False)
    except Refused as e:
        print(f"REFUSED: {e}", file=sys.stderr)
        return 2
    except (RuntimeError, subprocess.SubprocessError) as e:
        detail = getattr(e, "stderr", "") or ""
        print(f"FAILED: {e}\n{detail}".rstrip(), file=sys.stderr)
        return 1

    fatal = [l for l in log_path.read_text(errors="replace").splitlines()
             if re.search(r"Fatal error|EXC_|crash", l, re.I)]
    if fatal:
        print("WARNING: possible crash lines in the log:", *fatal[:10],
              sep="\n  ", file=sys.stderr)
        return 1
    print(f"OK: launched and relaunched cleanly. Screenshots and log in {out}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
