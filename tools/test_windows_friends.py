"""Requires explicit approval: two native Windows peers use the public Noray relay."""
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,tempfile
from pathlib import Path
from windows_console import run_hidden,windows,local_appdata,native_godot
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/demo';PACK=ROOT/'builds/windows/CloseTheGap.pck'
ENGINE=native_godot()
with tempfile.TemporaryDirectory(prefix='demo-public-friends-',dir=local_appdata()/'Temp') as folder:
    def peer(side):
        log=OUT/('windows-public-'+side+'.log')
        command=[ENGINE,'--headless','--path',windows(folder),'--main-pack',windows(PACK),'--script',windows(ROOT/'tests/test_friend_peer.gd'),
                 '--',side,windows(folder),'relay','foxssake.studio','8890','8809','normal']
        code=run_hidden(command,log,75)
        lines=log.read_text(errors='replace').splitlines()
        return dict(side=side,exit=code,errors=[s for s in lines if s.startswith(('ERROR:','SCRIPT ERROR:','FAIL:'))],summary=[s for s in lines if s.startswith('FRIEND_RESULT')])
    with ThreadPoolExecutor(max_workers=2) as pool: results=list(pool.map(peer,['host','guest']))
report=dict(platform='Windows',route='encrypted relay',service='foxssake.studio:8890',pack_sha256=hashlib.sha256(PACK.read_bytes()).hexdigest(),peers=results)
(OUT/'windows-public-friends.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report),flush=True)
raise SystemExit(0 if all(p['exit']==0 and not p['errors'] and p['summary'] for p in results) else 1)
