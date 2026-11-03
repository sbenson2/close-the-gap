"""Bounded two-process mountainside replication check on loopback only."""
import argparse
from pathlib import Path
import socket
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--godot', required=True)
parser.add_argument('--suite', choices=('mountain', 'duel', 'demo'), default='mountain')
parser.add_argument('--out', type=Path)
parser.add_argument('--pack', type=Path)
args = parser.parse_args()
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
    probe.bind(('127.0.0.1', 0))
    port = probe.getsockname()[1]
out = args.out or ROOT / 'artifacts/mountainside'
out.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='ctg-mountain-network-') as folder:
    processes, logs = [], []
    try:
        for role in ('host', 'guest'):
            log = (out / f'network-{role}.log').open('w')
            logs.append(log)
            command = [args.godot, '--headless', '--path', folder if args.pack else str(ROOT)]
            if args.pack: command += ['--main-pack', str(args.pack.resolve())]
            script = str(ROOT / f'tests/test_{args.suite}_peer.gd') if args.pack else f'res://tests/test_{args.suite}_peer.gd'
            processes.append(subprocess.Popen(command + ['--script', script, '--', role, folder, str(port)], stdout=log, stderr=subprocess.STDOUT))
        for process in processes:
            process.wait(timeout=75 if args.suite == 'demo' else 45)
        for log in logs:
            log.flush()
        errors = []
        for role in ('host', 'guest'):
            lines = (out / f'network-{role}.log').read_text().splitlines()
            for line in lines:
                if line.startswith(('PASS:', 'FAIL:', 'MOUNTAIN_PEER_RESULT', 'DUEL_PEER_RESULT', 'DEMO_PEER_RESULT', 'SCRIPT ERROR:', 'ERROR:')):
                    print(line)
                if line.startswith(('FAIL:', 'SCRIPT ERROR:', 'ERROR:')):
                    errors.append(line)
        raise SystemExit(0 if not errors and all(p.returncode == 0 for p in processes) else 1)
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
        for log in logs:
            log.close()
