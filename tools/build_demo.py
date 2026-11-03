"""Build and test one immutable Windows game pack after source checks pass."""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import tempfile

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/demo'
GODOT=os.environ.get('GODOT','godot')
PACK=ROOT/'builds/windows/CloseTheGap.pck'
ISOLATED=Path(tempfile.mkdtemp(prefix='demo-pack-root-'))

def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()

def run(name,command,timeout):
    log=OUT/(name+'.log')
    with log.open('w') as output:
        process=subprocess.Popen(command,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
        try: code=process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid,signal.SIGKILL);process.wait();code=-1
    lines=log.read_text(errors='replace').splitlines()
    errors=[line for line in lines if line.startswith(('ERROR:','SCRIPT ERROR:','FAIL:'))]
    print(json.dumps(dict(step=name,exit=code,errors=errors,summary=[line for line in lines if '_RESULT' in line])),flush=True)
    if code or errors: raise SystemExit(1)

started=time.monotonic()
while True:
    state=OUT/'play-verification.json'
    phases=json.loads(state.read_text()) if state.exists() else []
    phase=next((item for item in phases if item['phase']=='regression-release'),None)
    if phase:
        assert phase['exit']==0 and not phase['errors'],'Source checks failed'
        break
    if time.monotonic()-started>900: raise TimeoutError('Source checks did not finish within fifteen minutes')
    time.sleep(2)
manifest=json.loads((OUT/'source-manifest.json').read_text())
assert all(digest(ROOT/path)==expected for path,expected in manifest.items()),'Runtime changed after freeze'
run('release-export',[GODOT,'--headless','--path',str(ROOT),'--export-release','Windows',str(ROOT/'builds/windows/CloseTheGap.exe')],300)
run('pack-contents',[sys.executable,'tools/inspect_demo_pack.py'],60)
pack_hash=digest(PACK)
(OUT/'pack-before-checks.json').write_text(json.dumps(dict(pack_sha256=pack_hash,exe_sha256=digest(ROOT/'builds/windows/CloseTheGap.exe')),indent=2)+'\n')
for name in ['demo_pack','duel_slice','featured_session','bot_information']:
    run('pack-'+name,[GODOT,'--headless','--fixed-fps','60','--path',str(ISOLATED),'--main-pack',str(PACK),'--script',str(ROOT/f'tests/test_{name}.gd')],90)
run('pack-network',[sys.executable,'tools/test_mountain_network.py','--godot',GODOT,'--pack',str(PACK),'--suite','demo','--out',str(OUT/'pack-network')],100)
assert digest(PACK)==pack_hash,'Pack changed during verification'
(OUT/'pack-verified.json').write_text(json.dumps(dict(pack_sha256=pack_hash,source_manifest_sha256=digest(OUT/'source-manifest.json')),indent=2)+'\n')
print('DEMO_BUILD_VERIFICATION_COMPLETE',flush=True)
