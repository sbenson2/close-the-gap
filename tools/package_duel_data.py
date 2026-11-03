"""Bundle the new local evidence without replacing earlier releases or movies."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FOLDER = ROOT / 'artifacts/design-slice'
DESTINATION = ROOT.parent / 'Close-the-Gap-Duel-Data.zip'

if __name__ == '__main__':
    results = json.loads((FOLDER / 'release-regression/results.json').read_text())
    assert all(item['exit'] == 0 and not item['errors'] for item in results), 'Source checks must pass first'
    paths = [*sorted(FOLDER.rglob('*')), ROOT / 'replays/duel-session.json',
             ROOT / 'docs/duel-update.md', ROOT / 'docs/duel-handoff.md',
             ROOT / 'docs/lead-design.md', ROOT / 'docs/design-roadmap.md']
    with zipfile.ZipFile(DESTINATION, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in paths:
            if path.is_file() and path != DESTINATION:
                archive.write(path, Path('close-the-gap') / path.relative_to(ROOT))
    with zipfile.ZipFile(DESTINATION) as archive:
        assert archive.testzip() is None
    print(json.dumps({'file':str(DESTINATION),'bytes':DESTINATION.stat().st_size,
                      'sha256':hashlib.sha256(DESTINATION.read_bytes()).hexdigest()}))
