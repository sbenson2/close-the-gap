"""Native Windows checks restricted to local files and loopback networking."""
from concurrent.futures import ThreadPoolExecutor
import json,secrets,tempfile
from pathlib import Path
from windows_console import run_hidden,windows,local_appdata,native_godot
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'artifacts/demo'
PACK=ROOT/'builds/windows/CloseTheGap.pck'
ENGINE=native_godot()
results=[]
def check(name,command,seconds):
    log=OUT/('windows-'+name+'.log')
    code=run_hidden(command,log,seconds)
    lines=log.read_text(errors='replace').splitlines()
    result=dict(test=name,exit=code,errors=[s for s in lines if s.startswith(('ERROR:','SCRIPT ERROR:','FAIL:'))],summary=[s for s in lines if '_RESULT' in s or 'DEMO_SINGLE_PERFORMANCE' in s or 'DEMO_CAPTURE' in s])
    print(json.dumps(result),flush=True)
    return result
with tempfile.TemporaryDirectory(prefix='demo-local-checks-',dir=local_appdata()/'Temp') as folder:
    base=[ENGINE,'--headless','--fixed-fps','60','--path',windows(folder),'--main-pack',windows(PACK)]
    for name in ['demo_pack','demo_recording']:
        results.append(check('pack-'+name,base+['--script',windows(ROOT/f'tests/test_{name}.gd')],90))
    port=str(42000+secrets.randbelow(10000))
    def peer(side):
        return check('local-'+side,[ENGINE,'--headless','--path',windows(folder),'--main-pack',windows(PACK),'--script',windows(ROOT/'tests/test_demo_peer.gd'),'--',side,windows(folder),port],90)
    with ThreadPoolExecutor(max_workers=2) as pool: results.extend(pool.map(peer,['host','guest']))
    results.append(check('release-live',[str(ROOT/'builds/windows/CloseTheGap.exe'),'--headless','--fixed-fps','60','--quit-after','2400','--','--live'],90))
    common=[ENGINE,'--path',windows(folder),'--main-pack',windows(PACK),'--disable-vsync','--resolution','16x16','--position','-16000,-16000','--audio-driver','Dummy']
    results.append(check('packed-capture',common+['--script',windows(ROOT/'tools/capture_demo.gd'),'--',windows(OUT/'packed-captures')],115))
    # This profiler's report path is relative to the empty project, so copy it out.
    results.append(check('single-performance',common+['--script',windows(ROOT/'tools/profile_demo_single.gd'),'--',windows(OUT/'windows-performance-single.json')],90))
    candidates=[Path(folder)/'artifacts/demo/windows-performance-single.json', ROOT/'builds/windows/artifacts/demo/windows-performance-single.json']
    for candidate in candidates:
        if candidate.exists():
            (OUT/'windows-performance-single.json').write_bytes(candidate.read_bytes());break
(OUT/'windows-checks.json').write_text(json.dumps(results,indent=2)+'\n')
raise SystemExit(0 if all(item['exit']==0 and not item['errors'] for item in results) else 1)
