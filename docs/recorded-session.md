# Recorded forest bot session

The bundled recording contains ten simulated minutes of normal forest bot play. The simulation ran with Godot's headless display at 60 physics ticks per second; no graphical bot session was run. The subsequent private captures render the recording with AI and gameplay physics disabled.

## Watch

Extract the updated Windows ZIP and open `CloseTheGap.exe`. The recording opens automatically with both first-person POVs. Pause/resume, drag the timeline, select 0.5×/1×/2×/4× speed, or restart. Playback pauses at the end. The first attack is at about 01:02. Choose **Live bots** for a new autonomous match, or **Menu** for practice and friend invites. No network connection is required to watch.

## Actual recorded run

- Duration: 600 simulated seconds.
- Samples: 12,008 saved states at 20 Hz, with extra states at round changes.
- Events: 31 attacks and bird disturbances, timestamped at 60 Hz.
- Completed rounds: 10; seven knife wins and three rifle wins. Three complete first-to-three matches, then part of a fourth.
- Bot 1 won all ten completed rounds. The fixed seed restarts across rematches, so openings repeat. This was a reproducible session, not learning, training or evidence of human balance.
- File: `replays/forest-session.json` (7,516,795 bytes).
- SHA-256: `24cdca394d542af057cff6051f8394c8323bcbde19b72b48ab89b01da16f7553`.

Movement, velocity, aim, posture, weapons, ammunition, health, cooldowns, scores, results and behavior labels are recorded. Replay interpolates positions/aim between samples and uses the original event stream for combat effects and bird cues. Wildlife and bird animation clocks are also stored. It restores round actors and scores on seeking without running AI, rerolling outcomes or accepting player movement input.

Cosmetic rendering is reconstructed by the current game build; this is not a pixel-identical video. Wind and engine rendering details are not an authoritative part of the recording. State timing is 20 Hz; attack timing is retained at simulation ticks, including damage between samples. Replay format version 1 is intended for this build. Preserve this recording when changing maps or replay schemas.

## Verify or record another session

```sh
godot --headless --fixed-fps 60 --path . --script res://tests/test_replay.gd
godot --headless --fixed-fps 60 --path . --script res://tools/record_bot_session.gd -- 600 res://artifacts/another-session.json
```

The second command records a separate session without replacing the bundled one. The runner uses ordinary countdowns, role swaps, round limits, scoring and rematches. It has no graphical rendering. The executed run had an external 180-second wall-time limit and completed successfully. Per-round output is in `artifacts/recorded-session.log`; tests and summary are local artifacts excluded from the source download.

Native Windows Godot 4.7.2 has now rendered the replay with the RTX 4060. A three-second encoded sample contains 180 distinct 1080p frames with constant 60 fps timing and audible game audio. This verifies native replay rendering, while live gameplay performance and subjective audio quality still require playtesting. See [video-export.md](video-export.md) for the separate MP4 export and its evidence. The source and Windows ZIPs include the recording; no external service is needed for playback.
