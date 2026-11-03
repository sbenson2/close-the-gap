#!/usr/bin/env python3
"""Bounded headless integration test. Invite files are private and never printed."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import json
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
parser.add_argument("--pack", type=Path, help="Test the exported game pack instead of source resources")
parser.add_argument("--relay", action="store_true")
parser.add_argument("--local", action="store_true", help="Use the local-only Noray protocol test fixture")
parser.add_argument("--block-direct", action="store_true", help="Force the fixture to exercise automatic relay fallback")
parser.add_argument("--wrong-secret", action="store_true", help="Reject an invalid secret, then recover with the correct invite")
parser.add_argument("--wrong-certificate", action="store_true", help="Reject a mismatched host certificate, then recover")
parser.add_argument("--close-tree", action="store_true", help="Close the host application while connected")
parser.add_argument("--service-host")
parser.add_argument("--service-port", type=int, default=8890)
parser.add_argument("--registrar-port", type=int, default=8809)
args = parser.parse_args()
run_name = ("local" if args.local else "public") + ("-relay" if args.relay else "-auto")
if args.block_direct:
    run_name += "-fallback"
if args.wrong_secret:
    run_name += "-bad-secret"
if args.wrong_certificate:
    run_name += "-bad-certificate"
if args.close_tree:
    run_name += "-close-tree"
with tempfile.TemporaryDirectory(prefix="ctg-private-invite-") as folder:
    processes = []
    logs = []
    fixture = None
    try:
        if args.local:
            command = [sys.executable, str(ROOT / "tools" / "noray_fixture.py"), folder]
            if args.block_direct:
                command.append("--block-direct")
            fixture = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            setup_deadline = time.monotonic() + 3
            while not Path(folder, "service.json").exists() and time.monotonic() < setup_deadline:
                time.sleep(0.05)
            service = json.loads(Path(folder, "service.json").read_text())
            args.service_host, args.service_port, args.registrar_port = service["host"], service["port"], service["registrar"]
        for side in ("host", "guest"):
            log = (ROOT / "artifacts" / f"friends-{run_name}-{side}.log").open("w")
            logs.append(log)
            command = [args.godot, "--headless"]
            if args.pack:
                command += ["--main-pack", str(args.pack.resolve()), "--script", str(ROOT / "tests" / "test_friend_peer.gd")]
            else:
                command += ["--path", str(ROOT), "--script", "res://tests/test_friend_peer.gd"]
            command += ["--", side, folder, "relay" if args.relay else "fallback" if args.block_direct else "direct" if args.local else "auto"]
            if args.service_host:
                command += [args.service_host, str(args.service_port), str(args.registrar_port)]
            else:
                command += ["foxssake.studio", "8890", "8809"]
            command += ["wrong-secret" if args.wrong_secret else "wrong-certificate" if args.wrong_certificate else "normal"]
            if args.close_tree:
                command.append("close-tree")
            processes.append(subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT))
        limit = time.monotonic() + 60
        while any(p.poll() is None for p in processes) and time.monotonic() < limit:
            time.sleep(0.2)
        for p in processes:
            if p.poll() is None:
                raise SystemExit("FAIL: friend integration exceeded 60 seconds; see artifacts/friends-*.log")
        for log in logs:
            log.flush()
        unexpected_errors = False
        for side in ("host", "guest"):
            content = (ROOT / "artifacts" / f"friends-{run_name}-{side}.log").read_text()
            print("\n".join(line for line in content.splitlines() if line.startswith(("PASS", "FAIL", "FRIEND_RESULT", "SCRIPT ERROR", "ERROR:"))))
            for line in content.splitlines():
                if "SCRIPT ERROR" in line or "WARNING:" in line or "ERROR:" in line:
                    if not (args.wrong_certificate and line.startswith("ERROR: TLS handshake error:")):
                        unexpected_errors = True
        raise SystemExit(0 if all(p.returncode == 0 for p in processes) and not unexpected_errors else 1)
    finally:
        for p in processes:
            if p.poll() is None:
                p.kill()
                p.wait()
        for log in logs:
            log.close()
        if fixture is not None:
            fixture.terminate()
            fixture.wait(timeout=3)
