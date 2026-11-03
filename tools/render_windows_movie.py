"""Render the saved duel offline with native Windows Godot, then encode MP4."""
import argparse
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import time
from windows_console import TEMP, native_godot, windows as native_windows

ROOT = pathlib.Path(__file__).resolve().parents[1]
JOB = TEMP
GODOT = native_godot('Godot.exe')
ARTIFACTS = ROOT / 'artifacts'


def windows(path):
    return native_windows(path)


def run_logged(args, log, timeout):
    started = time.monotonic()
    if pathlib.Path(args[0]).suffix.lower() == '.exe':
        from windows_console import run_hidden
        code = run_hidden(args, log, timeout)
        print(json.dumps({'exit': code, 'elapsed': round(time.monotonic() - started, 2), 'log': str(log)}), flush=True)
        if code:
            print(log.read_text(errors='replace')[-3000:])
            raise SystemExit(code)
        return
    with log.open('w') as output:
        process = subprocess.Popen(args, stdout=output, stderr=subprocess.STDOUT)
        last_progress = ''
        while True:
            try:
                code = process.wait(timeout=15)
                break
            except subprocess.TimeoutExpired:
                progress = [line for line in log.read_text(errors='replace').splitlines() if line.startswith('MOVIE_PROGRESS')]
                if progress and progress[-1] != last_progress:
                    last_progress = progress[-1]
                    print(last_progress, flush=True)
                if time.monotonic() - started > timeout:
                    process.kill()
                    process.wait()
                    raise TimeoutError(f'Timed out after {timeout}s: {log}')
    print(json.dumps({'exit': code, 'elapsed': round(time.monotonic() - started, 2), 'log': str(log)}), flush=True)
    if code:
        print(log.read_text(errors='replace')[-4000:])
        raise SystemExit(code)


def prepare():
    JOB.mkdir(parents=True, exist_ok=True)
    stage = JOB / 'project'
    stage.mkdir(exist_ok=True)
    for folder in ['scripts', 'assets', 'replays', 'tools']:
        shutil.copytree(ROOT / folder, stage / folder, dirs_exist_ok=True)
    for name in ['main.tscn', 'default_bus_layout.tres', 'icon.svg']:
        shutil.copy2(ROOT / name, stage / name)
    shutil.copytree(ROOT / '.godot/imported', stage / '.godot/imported', dirs_exist_ok=True)
    for name in ['uid_cache.bin', 'global_script_class_cache.cfg']:
        source = ROOT / '.godot' / name
        if source.exists():
            shutil.copy2(source, stage / '.godot' / name)
    config = (ROOT / 'project.godot').read_text()
    for key, value in [('viewport_width', 16), ('viewport_height', 16), ('window_width_override', 16), ('window_height_override', 16)]:
        config = re.sub(r'(window/size/' + key + r'=)\d+', rf'\g<1>{value}', config)
    config += '\n[editor]\nmovie_writer/fps=60\nmovie_writer/mix_rate=48000\nmovie_writer/video_quality=0.85\nmovie_writer/ogv/encoding_speed=4\n'
    (stage / 'project.godot').write_text(config)
    ffmpeg = JOB / 'ffmpeg.exe'
    if not ffmpeg.exists():
        shutil.copy2(pathlib.Path.home() / '.local/share/close-the-gap-tools/ffmpeg-windows/ffmpeg.exe', ffmpeg)
    ffmpeg.chmod(0o755)
    # Godot starts the encoder with a pipe; invoking the console binary here
    # directly can bring Windows Terminal in front of the user's application.
    print('STAGED ' + windows(stage), flush=True)


def render(probe, *, preview=False, selection=None):
    stage = JOB / 'project'
    seconds = 30 if preview else (3 if probe else 600)
    name = 'asset-preview' if preview else ('probe' if probe else 'gameplay')
    start = '55' if preview else ('61' if probe else '0')
    replay_argument = []
    if selection is not None:
        selected = json.loads(selection.read_text())
        source = pathlib.Path(selected['replay']).resolve()
        assert hashlib.sha256(source.read_bytes()).hexdigest() == selected['replay_sha256']
        staged = stage / source.relative_to(ROOT)
        assert hashlib.sha256(staged.read_bytes()).hexdigest() == selected['replay_sha256']
        assert selected['frames'] == selected['end_tick'] - selected['start_tick'] > 0
        replay_argument = ['res://' + source.relative_to(ROOT).as_posix()]
        seconds = selected['frames'] / 60
        start = str(selected['start_tick'] / 60)
        name = selected.get('output_stem', 'middle-round')
        assert name in {'middle-round', 'mountain-round', 'duel-round', 'demo-round'}
    run_logged([GODOT, '--path', windows(stage), '--script', 'res://tools/render_movie.gd',
                '--write-movie', windows(JOB / (name + '.avi')), '--fixed-fps', '60',
                '--disable-vsync', '--resolution', '16x16', '--position', '-16000,-16000',
                '--audio-driver', 'Dummy', '--', start, str(seconds),
                windows(JOB / 'ffmpeg.exe'), windows(JOB / (name + '-video.mp4'))] + replay_argument,
               ARTIFACTS / (name + '-render.log'), max(180, seconds * 6 + 60) if selection else (240 if preview else (180 if probe else 3600)))
    metadata = json.loads((stage / 'movie-result.json').read_text())
    (ARTIFACTS / (name + '-render.json')).write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(metadata), flush=True)
    log = (ARTIFACTS / (name + '-render.log')).read_text(errors='replace')
    print('\n'.join(line for line in log.splitlines() if any(key in line for key in ['OpenGL', 'Vulkan', 'MOVIE_', 'ERROR', 'Movie Writer', 'Recording'])), flush=True)
    assert metadata['frames'] == round(seconds * 60)
    assert abs(metadata['end'] - metadata['start'] - seconds) < 0.0001
    mux(name, seconds, metadata['first_drawn_frame'] + 1)


def mux(name, seconds, warmup):
    ffmpeg = str(JOB / 'ffmpeg.exe')
    output = JOB / ('Close-the-Gap-60fps.mp4' if name == 'gameplay' else name + '.mp4')
    audio_start = warmup * 800
    audio_end = audio_start + round(seconds * 48000)
    run_logged([ffmpeg, '-hide_banner', '-y', '-i', windows(JOB / (name + '-video.mp4')),
                '-i', windows(JOB / (name + '.avi')), '-map', '0:v', '-map', '1:a', '-af',
                f'atrim=start_sample={audio_start}:end_sample={audio_end},asetpts=PTS-STARTPTS',
                '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k',
                '-metadata', "title=Close the Gap - Crow's Ridge" if name == 'mountain-round' else 'title=Close the Gap - Recorded forest bot session',
                '-movflags', '+faststart', windows(output)],
               ARTIFACTS / (name + '-encode.log'), 180)
    if name == 'gameplay':
        destination = ROOT.parent / output.name
        shutil.copy2(output, destination)
        print('VIDEO_READY ' + str(destination), flush=True)
    elif name == 'asset-preview':
        destination = ROOT.parent / 'Close-the-Gap-Assets-60fps.mp4'
        shutil.copy2(output, destination)
        print('VIDEO_READY ' + str(destination), flush=True)
    elif name in {'middle-round', 'mountain-round', 'duel-round', 'demo-round'}:
        destination = ROOT.parent / ('Close-the-Gap-Demo-60fps.mp4' if name == 'demo-round' else 'Close-the-Gap-Duel-60fps.mp4' if name == 'duel-round' else 'Close-the-Gap-Mountainside-60fps.mp4' if name == 'mountain-round' else 'Close-the-Gap-Middle-Round-60fps.mp4')
        shutil.copy2(output, destination)
        print('VIDEO_READY ' + str(destination), flush=True)


def inspect_probe():
    ffmpeg = str(JOB / 'ffmpeg.exe')
    run_logged([ffmpeg, '-hide_banner', '-y', '-i', windows(JOB / 'probe.mp4'),
                '-vf', r'select=eq(n\,60),scale=960:-2', '-frames:v', '1',
                windows(JOB / 'probe-frame.png')], ARTIFACTS / 'probe-frame.log', 60)
    shutil.copy2(JOB / 'probe-frame.png', ARTIFACTS / 'movie-probe.png')
    print((ARTIFACTS / 'probe-encode.log').read_text(errors='replace')[-1400:])


def verify():
    from verify_movie import inspect
    output = JOB / 'Close-the-Gap-60fps.mp4'
    destination = ROOT.parent / output.name
    report = inspect(destination)
    video = next(track for track in report['tracks'] if track['kind'] == 'vide')
    assert video['samples'] == 36000 and video['constant_fps'] == 60
    assert video['seconds'] == 600 and (video['width'], video['height']) == (1920, 1080)
    assert any(track['kind'] == 'soun' for track in report['tracks'])
    ffmpeg = str(JOB / 'ffmpeg.exe')
    run_logged([ffmpeg, '-hide_banner', '-xerror', '-hwaccel', 'cuda',
                '-hwaccel_output_format', 'cuda', '-i', windows(output),
                '-map', '0:v:0', '-an', '-f', 'null', '-'],
               ARTIFACTS / 'gameplay-decode.log', 180)
    decoded = re.findall(r'frame=\s*(\d+)', (ARTIFACTS / 'gameplay-decode.log').read_text(errors='replace'))
    assert decoded and int(decoded[-1]) == 36000
    run_logged([ffmpeg, '-hide_banner', '-i', windows(output), '-vn',
                '-af', 'volumedetect', '-f', 'null', '-'],
               ARTIFACTS / 'gameplay-audio.log', 120)
    audio = (ARTIFACTS / 'gameplay-audio.log').read_text(errors='replace')
    levels = re.findall(r'(?:mean|max)_volume: [^\r\n]+', audio)
    assert levels and not any('max_volume: -inf' in line for line in levels)
    report['decoded_frames'] = int(decoded[-1])
    report['audio_levels'] = levels
    with output.open('rb') as source:
        source_hash = hashlib.file_digest(source, 'sha256').hexdigest()
    with destination.open('rb') as copy:
        copy_hash = hashlib.file_digest(copy, 'sha256').hexdigest()
    assert source_hash == copy_hash
    report['sha256'] = copy_hash
    for second in [61.8, 80, 599]:
        image = JOB / f'frame-{second}.png'
        run_logged([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-ss', str(second),
                    '-i', windows(output), '-vf', 'scale=960:-2', '-frames:v', '1',
                    windows(image)], ARTIFACTS / f'frame-{second}.log', 30)
        shutil.copy2(image, ARTIFACTS / image.name)
    (ARTIFACTS / 'gameplay-validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'probe', 'preview', 'study', 'render', 'inspect', 'verify'])
    parser.add_argument('--selection', type=pathlib.Path, default=ARTIFACTS / 'ai-upgrade/analysis/round-selection.json')
    args = parser.parse_args()
    if args.action == 'prepare':
        prepare()
    elif args.action == 'inspect':
        inspect_probe()
    elif args.action == 'verify':
        verify()
    elif args.action == 'study':
        render(False, selection=args.selection)
    else:
        render(args.action == 'probe', preview=args.action == 'preview')
