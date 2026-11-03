"""Package local evidence without model downloads, videos or private invites."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / 'artifacts/mountainside'
study = json.loads((EVIDENCE / 'final-study/results.json').read_text())
replay = ROOT / 'replays/mountain-session.json'
recording = json.loads(replay.read_text())
digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert study['controller_sha256'] == recording['controller_sha256'] == digest(ROOT / 'scripts/bot_controller.gd')
assert study['map_sha256'] == recording['map_sha256']
for name, checksum in study['map_sha256'].items():
    assert checksum == digest(ROOT / f'scripts/{name}.gd'), name
video = json.loads((EVIDENCE / 'video-verification.json').read_text())
assert video['replay_sha256'] == digest(replay)

destination = ROOT.parent / 'Close-the-Gap-Mountainside-Data.zip'
allowed = {'.json', '.jsonl', '.csv', '.md', '.gd', '.py', '.log', '.txt', '.png'}
with zipfile.ZipFile(destination, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(EVIDENCE.rglob('*')):
        if path.is_file() and path.suffix in allowed and path.name != 'package-verification.json':
            archive.write(path, path.relative_to(ROOT))
    for name in ('arena', 'forest', 'mountainside', 'bot_controller', 'bot_senses', 'bot_tactics', 'main', 'rules', 'interface'):
        path = ROOT / f'scripts/{name}.gd'
        archive.write(path, path.relative_to(ROOT))
    for path in [replay, ROOT / 'docs/mountainside-design.md', ROOT / 'docs/bot-tuning.md', ROOT / 'LICENSE',
                 ROOT / 'CREDITS.md', ROOT / 'assets/models/SOURCES.json', ROOT / 'assets/models/birds/LICENSE.txt']:
        archive.write(path, path.relative_to(ROOT))
    for path in sorted((ROOT / 'docs/images').glob('mountainside-*.png')):
        archive.write(path, path.relative_to(ROOT))
    for name in ('run_bot_study.gd', 'record_bot_study.gd', 'analyze_bot_study.py', 'draw_mountainside_plan.py',
                 'package_mountain_data.py', 'check_game.py', 'verify_movie.py', 'test_mountain_network.py'):
        archive.write(ROOT / 'tools' / name, Path('tools') / name)
    for name in ('mountainside', 'mountain_bots', 'bot_information', 'bot_awareness', 'mountain_peer'):
        archive.write(ROOT / f'tests/test_{name}.gd', f'tests/test_{name}.gd')
print(destination, destination.stat().st_size, digest(destination))
