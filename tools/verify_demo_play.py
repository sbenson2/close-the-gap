"""Bounded release play checks. Source stays frozen while this runs."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'artifacts/demo'
GODOT = os.environ.get('GODOT', 'godot')
phases = []

def run(name, command, timeout):
    log = OUT / (name + '.log')
    started = time.monotonic()
    with log.open('w') as stream:
        process = subprocess.Popen(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            code = -1
    lines = log.read_text(errors='replace').splitlines()
    errors = [line for line in lines if line.startswith(('ERROR:', 'SCRIPT ERROR:', 'FAIL:'))]
    result = dict(phase=name, exit=code, seconds=round(time.monotonic()-started,2), errors=errors)
    phases.append(result)
    (OUT/'play-verification.json').write_text(json.dumps(phases,indent=2)+'\n')
    print(json.dumps(result),flush=True)
    if code or errors: raise SystemExit(1)

def game(script, arguments):
    return [GODOT,'--headless','--fixed-fps','60','--path',str(ROOT),'--script','res://tools/'+script,'--',*arguments]

run('record-five-rounds',game('record_bot_study.gd',['mountain','res://replays/demo-session.json','5','--relay','--rain']),600)
run('regression-release',[sys.executable,'tools/check_game.py','--godot',GODOT,'--out','artifacts/demo/regression-release'],900)
for label, flags in [('relay-final',['--relay','--rain']),('paired-final',[])]:
    folder='artifacts/demo/'+label
    run(label,game('run_bot_study.gd',['res://'+folder,'6','71','--mountain',*flags]),600)
    command=[sys.executable,'tools/analyze_bot_study.py','--study',folder+'/results.json','--out',folder+'/analysis']
    if label == 'relay-final': command+=['--replay','replays/demo-session.json']
    run(label+'-analysis',command,30)
selection=OUT/'relay-final/analysis/round-selection.json'
data=json.loads(selection.read_text());data['output_stem']='demo-round'
selection.write_text(json.dumps(data,indent=2)+'\n')
print('DEMO_PLAY_VERIFICATION_COMPLETE',flush=True)
