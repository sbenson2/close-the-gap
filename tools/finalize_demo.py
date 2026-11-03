"""Collect verified release evidence; refuses incomplete or changed runtime inputs."""
import hashlib,json,re,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'artifacts/demo'
def digest(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()
def read(path): return json.loads((OUT/path).read_text())
phases=read('play-verification.json')
assert len(phases)==6 and all(p['exit']==0 and not p['errors'] for p in phases)
suites=read('regression-release/results.json')
assert len(suites)==31 and all(p['exit']==0 and not p['errors'] and p['summary'] for p in suites)
manifest=read('source-manifest.json')
assert all(digest(ROOT/path)==sha for path,sha in manifest.items())
pack=read('pack-verified.json');assert digest(ROOT/'builds/windows/CloseTheGap.pck')==pack['pack_sha256']
contents=read('pack-contents.json');assert contents['all_entry_hashes_valid'] and not contents['development_files']
native=read('windows-checks.json');assert len(native)==7 and all(p['exit']==0 and not p['errors'] for p in native)
assert 'ROUND_READY' in (OUT/'windows-release-live.log').read_text()
assert (OUT/'windows-performance-single.json').is_file()
for name in ['pack-local-friends.log','local-certificate-final.log','local-security-final.log','pack-network.log']:
    text=(OUT/name).read_text()
    issues=[line for line in text.splitlines() if line.startswith(('FAIL:','SCRIPT ERROR:','ERROR:'))]
    if name=='local-certificate-final.log':
        assert 'tampered private invite is rejected before gameplay' in text
        issues=[line for line in issues if not line.startswith('ERROR: TLS handshake error:')]
    assert 'failures=0' in text and not issues,(name,issues)
old={
 'Close-the-Gap-Duel-Windows.zip':'06538f391e7f83786e4361f292e218de9c13cf44d819be1eddca8d1d1bd76f94',
 'Close-the-Gap-Duel-Godot.zip':'5a3370cb4083ea66de91310bac4beb2e0c85fd30d5e2bd0833eee3bf1eed35d7',
 'Close-the-Gap-Duel-60fps.mp4':'1af56cdd458dcbd5214dc0bd70080dab85160172dd647ffee8ab3e0420fb0198',
 'Close-the-Gap-Mountainside-60fps.mp4':'ae60e8ec5fe4828d905aeb54a3113cbdae0ef31190304d762f94dc19266ff610'}
for name,sha in old.items(): assert digest(ROOT.parent/name)==sha,name
assert digest(ROOT/'replays/duel-session.json')=='85b01e33591671ba41f7c3a9cfaff25e9d222a4a4911c440461073b1ccebb342'
with zipfile.ZipFile(ROOT.parent/'Close-the-Gap-Godot.zip') as archive:
    for name in ['mountain-session.json','ai-session.json','forest-session.json']:
        assert archive.read('close-the-gap/replays/'+name)==(ROOT/'replays'/name).read_bytes(),name
video=read('video-validation.json');assert digest(ROOT.parent/'Close-the-Gap-Demo-60fps.mp4')==video['sha256']
public_path=OUT/'windows-public-friends.json'
public=json.loads(public_path.read_text()) if public_path.exists() else {'status':'not run; automatic approval review requires explicit permission for this destination','earlier_source_test':'public-friends.log: host 6/0; guest 5/0'}
if public_path.exists(): assert all(p['exit']==0 and not p['errors'] for p in public['peers']) and public['pack_sha256']==pack['pack_sha256']
counts=sum(int(n) for s in suites for line in s['summary'] for n in re.findall(r'checks=(\d+)',line))
report=dict(build_id='demo-20261102',source=dict(suites=len(suites),counted_godot_checks=counts,python_tests=5,unchanged_runtime_files=len(manifest)),pack=pack,pack_directory=dict(files=contents['files'],entry_hashes_valid=True,development_files=[]),native=native,public_relay=public,video=video,performance=read('windows-performance.json'),single_view_performance=read('windows-performance-single.json'),cold_performance=read('windows-performance-cold.json'),cohorts={label:read(label+'/analysis/summary.json') for label in ['relay-final','paired-final']},legacy_releases_preserved=old,legacy_recordings_preserved=True)
(OUT/'verification.json').write_text(json.dumps(report,indent=2)+'\n')
rows=[]
for label in ['relay-final','paired-final']:
    data=report['cohorts'][label]['upgraded']['maps']['mountain']
    rows.append(f"| {label} | {data['rounds']} | {data['wins']} | {data['unfinished']} | {data['high_ground_violations']} | {data['stalker_stalled_seconds']:.2f} |")
notes='''\n## Release evidence\n\nSource: 31 suites, %d counted Godot checks, rules with zero failures, plus five Python analysis tests. The immutable PCK contains %d entries, all entry hashes validated and no development test/tool files. Pack tests also run from an empty resource directory to prevent source files masking missing export content. Native Windows completed the full six-round host/guest test, guest-initiated rematch, human-recording save/playback, packaged UI captures and the actual release executable's headless live startup.\n\n| Cohort | Rounds | Wins by role | Unfinished | High-ground violations | Stalker stalled seconds |\n| --- | --- | --- | --- | --- | --- |\n%s\n\nThese are separate current-rule cohorts, with six seeds and both assignments per seed, normal countdowns and 4 Hz traces. They are not pooled with older map/rule studies. The featured record contains five completed rounds, 5,166 state samples and 89 events. Its complete middle round is a 61.917-second 1080p video: 3,715 decoded constant-60-fps frames, non-silent audio, and 60 distinct images in the checked one-second scene crop. The raw recordings and cohorts are in the data bundle.\n\nSingle-view native performance and both warm/cold split-screen results are in `verification.json`; each is a short sample. The public source relay test passed. A new public Windows-pack retest was blocked by automatic approval review pending destination-specific permission; local encrypted-relay, certificate and secret-rejection checks passed. This does not establish connectivity between two separate home networks.\n'''%(counts,contents['files'],'\n'.join(rows))
if public_path.exists(): notes=notes.replace('The public source relay test passed. A new public Windows-pack retest was blocked by automatic approval review pending destination-specific permission;', 'Both native Windows peers passed the public encrypted-relay test using this PCK after explicit approval;')
p=ROOT/'docs/demo-update.md';text=p.read_text();text=text.split('\n## Release evidence')[0]+notes;p.write_text(text)
print(json.dumps(dict(source_suites=len(suites),godot_checks=counts,pack_sha256=pack['pack_sha256'],native_checks=len(native),legacy_preserved=True)),flush=True)
