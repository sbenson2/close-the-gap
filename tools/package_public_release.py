"""Package a public release from tracked source and the verified player pack.
Local logs, credentials, machine-specific handoffs and raw session archives are excluded.
"""
import hashlib,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/publication/release'
OUT.mkdir(parents=True,exist_ok=True)
REPO='sbenson2/close-the-gap'
def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()
def main():
    verification=json.loads((ROOT/'docs/demo-verification.json').read_text())
    pack=ROOT/'builds/windows/CloseTheGap.pck'
    assert sha(pack)==verification['pack_sha256'],'Use the verified game pack'
    tracked=set(filter(None,subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')))
    destination=OUT/'Close-the-Gap-Demo-Windows.zip'
    with zipfile.ZipFile(destination,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for name in ['CloseTheGap.exe','CloseTheGap.pck','Godot-LICENSES.txt']:
            archive.write(ROOT/'builds/windows'/name,'Close-the-Gap/'+name)
        for name in ['README.md','START-HERE.txt','LICENSE','CREDITS.md']:
            assert name in tracked
            archive.write(ROOT/name,'Close-the-Gap/'+name)
        for name in sorted(tracked):
            if name.startswith(('third_party/','docs/')) or (name.startswith('assets/') and 'LICENSE' in Path(name).name):
                target='asset-licenses/'+name if name.startswith('assets/') else name
                archive.write(ROOT/name,'Close-the-Gap/'+target)
        archive.write(ROOT/'assets/models/SOURCES.json','Close-the-Gap/asset-licenses/SOURCES.json')
    source=OUT/'Close-the-Gap-Demo-Godot.zip'
    subprocess.run(['git','archive','--format=zip','--prefix=close-the-gap/','--output',str(source),'HEAD'],cwd=ROOT,check=True)
    video=ROOT.parent/'Close-the-Gap-Demo-60fps.mp4'
    original=json.loads((ROOT/'artifacts/demo/video-validation.json').read_text())
    assert sha(video)==original['sha256']
    # Release analysis includes only generated bot gameplay; no raw networking logs.
    with zipfile.ZipFile(OUT/'Close-the-Gap-Demo-Analysis.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for label in ['relay-final','paired-final']:
            folder=ROOT/'artifacts/demo'/label
            for name in ['results.json','trace.jsonl','analysis/summary.json','analysis/rounds.csv']:
                archive.write(folder/name,label+'/'+name)
        archive.write(ROOT/'replays/demo-session.json','replays/demo-session.json')
        archive.write(ROOT/'docs/demo-verification.json','verification.json')
    public_report=OUT/'Close-the-Gap-Demo-Verification.json'
    public_report.write_bytes((ROOT/'docs/demo-verification.json').read_bytes())
    files=[*sorted(OUT.glob('*.zip')),public_report,video]
    reports=[]
    for path in files:
        if path.suffix=='.zip':
            with zipfile.ZipFile(path) as archive:
                assert archive.testzip() is None
                assert not any('/handoff' in n.lower() or '/artifacts/' in n or n.endswith('.pem') or n.endswith('.key') for n in archive.namelist())
                if path==destination: assert hashlib.sha256(archive.read('Close-the-Gap/CloseTheGap.pck')).hexdigest()==verification['pack_sha256']
        reports.append(dict(file=path.name,bytes=path.stat().st_size,sha256=sha(path)))
    (OUT/'SHA256SUMS.txt').write_text(''.join(r['sha256']+'  '+r['file']+'\n' for r in reports))
    (ROOT/'artifacts/publication/release-files.json').write_text(json.dumps(reports,indent=2)+'\n')
    print(json.dumps(reports,indent=2))
if __name__=='__main__':main()
