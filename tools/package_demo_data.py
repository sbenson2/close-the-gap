"""Package the final evidence, preserving earlier release bundles."""
import hashlib,json,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];FOLDER=ROOT/'artifacts/demo'
assert (FOLDER/'verification.json').is_file()
DEST=ROOT.parent/'Close-the-Gap-Demo-Data.zip'
paths=[*sorted(FOLDER.rglob('*')),ROOT/'replays/demo-session.json',ROOT/'docs/demo-update.md',ROOT/'docs/demo-plan.md',ROOT/'docs/demo-handoff.md']
with zipfile.ZipFile(DEST,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for p in paths:
        if p.is_file(): archive.write(p,Path('close-the-gap')/p.relative_to(ROOT))
with zipfile.ZipFile(DEST) as archive: assert archive.testzip() is None
print(json.dumps(dict(file=str(DEST),bytes=DEST.stat().st_size,sha256=hashlib.sha256(DEST.read_bytes()).hexdigest())))
