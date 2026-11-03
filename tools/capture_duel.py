#!/usr/bin/env python3
"""Render on a private authenticated X display, never the user's desktop."""
import argparse
import os
from pathlib import Path
import resource
import socket
import struct
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
(ROOT / "artifacts").mkdir(exist_ok=True)
parser = argparse.ArgumentParser()
parser.add_argument("--godot", required=True)
parser.add_argument("--xvfb", required=True)
parser.add_argument("--quick", action="store_true")
parser.add_argument("--wildlife", action="store_true")
parser.add_argument("--replay-at", type=float)
args = parser.parse_args()
tools_root = Path(args.xvfb).resolve().parents[2]
env = os.environ.copy()
env["LD_LIBRARY_PATH"] = str(tools_root / "usr/lib/x86_64-linux-gnu") + ":" + env.get("LD_LIBRARY_PATH", "")
env["PATH"] = str(tools_root / "usr/bin") + ":" + env["PATH"]
env["XKB_BINDIR"] = str(tools_root / "usr/bin")
server = None
game = None

def limits():
    resource.setrlimit(resource.RLIMIT_FSIZE, (262144, 262144))

with tempfile.TemporaryDirectory(prefix="ctg-private-display-") as folder:
    display = "195"
    auth = Path(folder) / "authority"
    def field(value):
        return struct.pack(">H", len(value)) + value
    auth.write_bytes(struct.pack(">H", 256) + field(socket.gethostname().encode()) + field(display.encode()) + field(b"MIT-MAGIC-COOKIE-1") + field(os.urandom(16)))
    auth.chmod(0o600)
    env["XAUTHORITY"] = str(auth)
    env["DISPLAY"] = ":" + display
    with (ROOT / "artifacts/private-display.log").open("w") as xlog, (ROOT / "artifacts/duel-render.log").open("w") as glog:
        try:
            server = subprocess.Popen([args.xvfb, ":" + display, "-screen", "0", "1440x900x24", "-nolisten", "tcp", "-pn", "-auth", str(auth), "-noreset"], env=env, stdout=xlog, stderr=subprocess.STDOUT, preexec_fn=limits)
            ready = False
            end = time.monotonic() + 6
            while time.monotonic() < end and server.poll() is None:
                try:
                    with socket.socket(socket.AF_UNIX) as probe:
                        probe.connect("\0/tmp/.X11-unix/X" + display)
                    ready = True
                    break
                except OSError:
                    time.sleep(0.05)
            if not ready:
                raise SystemExit("Private display failed; see the bounded artifacts/private-display.log")
            command = [args.godot, "--path", str(ROOT), "--audio-driver", "Dummy", "--script", "res://tests/capture_duel.gd"]
            if args.quick:
                command += ["--", "--quick"]
            if args.wildlife:
                command += (["--wildlife"] if args.quick else ["--", "--wildlife"])
            if args.replay_at is not None:
                command += (["--replay-at=" + str(args.replay_at)] if args.quick or args.wildlife else ["--", "--replay-at=" + str(args.replay_at)])
            game = subprocess.Popen(command, env=env, stdout=glog, stderr=subprocess.STDOUT)
            if game.wait(timeout=80):
                raise SystemExit("Render failed; see artifacts/duel-render.log")
            print("Captured both POVs on private display; desktop was not used")
        finally:
            for process in (game, server):
                if process and process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
