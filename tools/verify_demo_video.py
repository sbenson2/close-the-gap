"""Validate movie timing, complete decode, audio and sixty distinct image samples."""
import hashlib,json,re
from pathlib import Path
from windows_console import run_hidden,windows,TEMP
from verify_movie import inspect
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'artifacts/demo'
VIDEO=ROOT.parent/'Close-the-Gap-Demo-60fps.mp4'
FFMPEG=str(TEMP/'ffmpeg.exe')
selection=json.loads((OUT/'round-selection.json').read_text());report=inspect(VIDEO)
track=next(t for t in report['tracks'] if t['kind']=='vide')
assert track['samples']==selection['frames'] and track['constant_fps']==60 and (track['width'],track['height'])==(1920,1080)
assert abs(track['seconds']-selection['seconds'])<.0001 and any(t['kind']=='soun' for t in report['tracks'])
def run(name,args,seconds=120):
    log=OUT/('video-'+name+'.log')
    code=run_hidden([FFMPEG,'-hide_banner','-y',*args],log,seconds)
    assert code==0,(name,code,log.read_text(errors='replace')[-1000:])
    return log.read_text(errors='replace')
decoded=run('decode',['-xerror','-i',windows(VIDEO),'-map','0:v:0','-an','-progress','pipe:1','-f','null','-'])
frames=re.findall(r'^frame=(\d+)\s*$',decoded,re.M)
assert frames and int(frames[-1])==selection['frames']
audio=run('audio',['-i',windows(VIDEO),'-vn','-af','volumedetect','-f','null','-'])
levels=re.findall(r'(?:mean|max)_volume: [^\r\n]+',audio)
assert levels and not any('max_volume: -inf' in s for s in levels)
motion=run('motion',['-ss','7','-i',windows(VIDEO),'-frames:v','60','-an','-vf','crop=880:760:40:120,scale=320:240','-f','framemd5','-'])
hashes=[line.rsplit(',',1)[-1].strip() for line in motion.splitlines() if re.match(r'^0,\s*\d+,',line)]
assert len(hashes)==60 and len(set(hashes))>=55,(len(hashes),len(set(hashes)))
run('frame',['-ss','12','-i',windows(VIDEO),'-vf','scale=1000:-2','-frames:v','1',windows(OUT/'movie-frame.png')],30)
report.update(sha256=hashlib.sha256(VIDEO.read_bytes()).hexdigest(),decoded_frames=int(frames[-1]),audio_levels=levels,motion=dict(samples=len(hashes),distinct=len(set(hashes)),crop='left POV without HUD',start_second=7))
(OUT/'video-validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report),flush=True)
