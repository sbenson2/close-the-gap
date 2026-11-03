# Gameplay video export

The completed deliverable is an MP4 of the existing ten-minute bot recording, with both first-person viewpoints, at 1920×1080 and constant 60 fps. The simulation and its outcomes are preserved.

- Windows: `%USERPROFILE%\Videos\Close-the-Gap-60fps.mp4`.
- Workspace: `../Close-the-Gap-60fps.mp4`.
- Size: 1,728,512,098 bytes.
- SHA-256: `6d2946a97f47508dd588413ea81abe96648b532a531fea746e49f40e5b80d078`.

## Windows hardware

This workspace is WSL2 on a Windows desktop. Linux Godot sees a software renderer, but native Windows Godot 4.7.2 uses the NVIDIA GeForce RTX 4060. Do not infer that the Windows host lacks a GPU from missing Linux GPU device nodes. Native Godot is installed at `%LOCALAPPDATA%\Programs\Godot\Godot.exe`.

## Export path

`tools/render_windows_movie.py` stages an isolated copy in `%LOCALAPPDATA%\Temp\CloseTheGapMovie-20261102`. It leaves the normal game's project settings intact. Native Godot runs offscreen with its window unable to take focus.

`tools/render_movie.gd` loads the saved recording with gameplay simulation disabled, advances it with Godot's fixed 60 fps movie clock, and renders a 1920×1080 child viewport. It removes playback controls while retaining both POVs and their HUDs, including across round changes. Each complete RGB frame is sent through a blocking pipe to native FFmpeg's NVIDIA H.264 encoder. Blocking applies backpressure rather than discarding frames.

Godot's built-in MovieWriter records a separate 16×16 AVI to preserve its offline audio mixer and fixed clock. Its video is discarded. This avoids spending CPU time compressing a full-resolution JPEG intermediary. After rendering, FFmpeg trims the audio's warmup samples, encodes stereo AAC at 48 kHz, and muxes it with the existing H.264 stream without another video encode. The MP4 header is moved to the front for seeking and streaming.

Native FFmpeg comes from the SHA-256-verified `imageio-ffmpeg` 0.6.0 Windows wheel, with its license beside the downloaded executable under `~/.local/share/close-the-gap-tools/ffmpeg-windows`. The staging paths in the helper describe this machine; adjust them if moving the export job elsewhere.

```sh
python3 tools/render_windows_movie.py prepare
python3 tools/render_windows_movie.py probe
python3 tools/render_windows_movie.py inspect
python3 tools/render_windows_movie.py render
python3 tools/verify_movie.py ../Close-the-Gap-60fps.mp4 600
python3 tools/render_windows_movie.py verify
```

Each render has a wall-time timeout. The full render is limited to one hour. Progress is logged every 900 frames, with replay time; completion records the first/last drawn frame, number of frames, replay endpoints, and output size. The MP4 verifier reads actual sample tables and checks dimensions, duration, frame count, constant timestamps, and presence of audio. Merely setting an MP4's fps label is insufficient.

## Verified sample

- Native renderer: NVIDIA GeForce RTX 4060, Godot 4.7.2 GL Compatibility.
- Replay interval: 61–64 seconds, including the first knife attack.
- Video: 1920×1080, 180 samples over exactly three seconds; every sample advances by 256 ticks in a 15,360 Hz timebase (60 fps).
- All 180 decoded frames have distinct hashes.
- Audio: stereo 48 kHz AAC; measured mean −29.9 dB and peak −6.0 dB.
- Both POVs were inspected from the encoded video. No playback controls appear.
- Logs: `artifacts/probe-render.log`, `probe-encode.log`, `probe-render.json`, `probe-validation.json`; preview `artifacts/movie-probe.png`.

These checks establish the export pipeline. They do not establish live game frame rates, human balance, or enjoyment. The saved bot session remains a 20 Hz state recording with 60 Hz event timing; replay interpolates movement and aim for the 60 fps render.

## Completed full video

`artifacts/gameplay-render.json` records 36,000 frames, starting at zero and ending at 600 seconds. `gameplay-validation.json` verifies an actual MP4 sample table of 36,000 samples, each 256 ticks in a 15,360 Hz timebase: exactly 60 fps for 600 seconds. Native FFmpeg decoded all 36,000 frames without errors (`gameplay-decode.log`). Full audio decoded successfully, with mean −43.5 dB and peak −6.1 dB (`gameplay-audio.log`). Workspace and staging copies have identical SHA-256 hashes. Frames at 61.8, 80 and 599 seconds were inspected, including the changed roles and final scene; playback controls remain hidden.

The MP4 was copied to Windows Videos and opened in Media Player. `tools/play_windows_video.ps1` locates its UWP frame window and verifies foreground activation. Windows' media-session API identifies the exact video title, starts playback, and reports `Playing`; see `artifacts/windows-video-launch.log`. The accessibility tree was unreliable for playback state, so it is not used as the final evidence.

Run the reviewed PowerShell launcher from the Windows temporary folder: Windows treats a script opened directly over WSL's UNC path as remote and may reject it as unsigned. No execution-policy change is needed. Use the accompanying `play_windows_video.vbs` with `wscript.exe` to keep console launches from bringing Windows Terminal back in front. Its three arguments are the local PS1 path, video path, and result JSON path; an optional fourth argument requests restart from the beginning. It only controls the media session whose title matches this video. The ordinary game build is unchanged by these export tools.

Engine references: [Godot 4.7 MovieWriter](https://docs.godotengine.org/en/4.7/classes/class_moviewriter.html), [OS.execute_with_pipe](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-execute-with-pipe).

## Updated asset preview

`Close-the-Gap-Assets-60fps.mp4` is a separate 30-second preview of the imported art, reconstructed from replay seconds 55–85. The original ten-minute video is preserved. Generate only this shorter preview with `python3 tools/render_windows_movie.py prepare` then `python3 tools/render_windows_movie.py preview`. Both POVs and stereo game audio are included; graphical rendering stays offscreen.

## Current AI middle round

`Close-the-Gap-Middle-Round-60fps.mp4` contains the complete third round of a five-round headless session. It is 91.8 seconds at1920×1080/60fps (5508 frames) with stereo audio. Selection is by middle index, independent of outcome. The full session remains in `replays/ai-session.json`; the original600-second recording/video are preserved.

Reproduce using the recording/study commands in [gameplay study](ai-gameplay-study.md), then `python3 tools/render_windows_movie.py prepare` and `python3 tools/render_windows_movie.py study --selection artifacts/ai-upgrade/analysis/round-selection.json`. The helper verifies source/staged replay hashes, and rendering uses explicit replay/tick bounds. No AI decisions are rerun while exporting.
