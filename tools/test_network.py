#!/usr/bin/env python3
"""Bounded integration check using two real Godot processes over loopback UDP."""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
args = parser.parse_args()
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
    probe.bind(("127.0.0.1", 0))
    port = probe.getsockname()[1]
with tempfile.TemporaryDirectory(prefix="close-the-gap-net-") as directory:
    processes = []
    logs = []
    try:
        for role in ("host", "guest"):
            path = ROOT / "artifacts" / f"network-{role}.log"
            log = path.open("w")
            logs.append(log)
            cmd = [args.godot, "--headless", "--path", str(ROOT), "--script",
                   "res://tests/test_network_peer.gd", "--", role, directory, str(port)]
            processes.append(subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT))
        deadline = time.monotonic() + 65
        while any(p.poll() is None for p in processes) and time.monotonic() < deadline:
            time.sleep(0.2)
        for p in processes:
            if p.poll() is None:
                p.terminate()
                raise SystemExit("FAIL: network test exceeded 65 seconds; see artifacts/network-*.log")
        for log in logs:
            log.flush()
        for role in ("host", "guest"):
            path = ROOT / "artifacts" / f"network-{role}.log"
            lines = path.read_text().splitlines()
            print("\n".join(line for line in lines if line.startswith(("PASS", "FAIL", "NETWORK_RESULT", "SCRIPT ERROR", "ERROR:"))))
        raise SystemExit(0 if all(p.returncode == 0 for p in processes) else 1)
    finally:
        for p in processes:
            if p.poll() is None:
                p.kill()
                p.wait()
        for log in logs:
            log.close()
