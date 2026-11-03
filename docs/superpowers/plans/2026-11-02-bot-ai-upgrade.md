# Concealed sniper and adaptive stalker implementation plan

> For agentic workers: use executing-plans inline, with a fresh final review. Track steps below and evidence in artifacts/ai-upgrade/progress.md.

Goal: implement the researched two-role AI, test many complete rounds headlessly, analyze telemetry, and render the third round of a five-round session at 1080p60.

Architecture: retain the host-authoritative movement/combat and compact role controller. Separate sensed evidence and tactical spatial queries; tactical navigation uses private cost grids over existing role walkability. Existing replay state/event format remains compatible.

Tech stack: Godot 4.7.2 GDScript, Python 3 analysis/orchestration, native Windows Godot/RTX 4060 and FFmpeg/NVENC for video.

Spec: docs/bot-ai-research.md and the user's instructions to implement, test extensively, record a middle round and retain analysis data.

## Global constraints

- Windows is the primary build. Keep graphical work offscreen/unfocused.
- Sniper hides on restricted high ground; stalker sneaks with knife and seeks a rear finish.
- Decisions consume observed/remembered information; physical sensors may query the world. No hidden opponent lookup in tactical planning.
- Preserve combat rules, maps, art, old replay/video, encrypted friend transport and replay compatibility.
- Bound experiments; compare identical seeds/maps/settings. No live server, publication or foreground playback.

## Review focus

- Cues arriving just before vision must not cancel acquisition delay.
- Loss of sight must not enable tracking/aiming at a hidden transform.
- Hides must be reachable and useful, with safe fallback if no perfect hide exists.
- Weighted routes and replans must preserve map/high-ground restrictions and avoid stalling or state churn.
- A recording stopped at a round boundary must remain complete/valid, and its selected video round must correspond to saved telemetry.

### 1. Baseline and fair perception

Files: tools/run_bot_study.gd; tests/test_bot_awareness.gd; scripts/bot_controller.gd.
Interfaces: existing game.start_bot_duel(level), brain.tick(delta); preserve visible/last_known/memory_age for older consumers. Add typed cue metadata and independent visual age.
- [x] Add bounded headless study telemetry and run eight baseline rounds across both maps/two seeds/two role assignments.
- [x] Add tests showing out-of-pitch sight and sound-before-sight reaction failures; run RED.
- [x] Implement full view-direction sensing and independent cue/visual memory; run GREEN and prior stealth/wildlife tests.

### 2. Concealed tactical positions

Files: scripts/bot_tactics.gd; scripts/bot_controller.gd; tests/test_bot_tactics.gd.
Interfaces: tactics.choose_hide(threat, previous) -> dictionary containing hide/peek/score; tactics.route(from,to,knowledge,role) -> PackedVector2Array. It receives no enemy object.
- [x] Add real-world tests requiring reachable covered high-ground positions, useful peek lanes, hold behavior and cue-directed gaze without pursuit off the ridge; run RED.
- [x] Implement candidate filtering/scoring, committed hides, peek/withdraw/reposition and bounded search; run GREEN.

### 3. Adaptive stealth routes and recovery

Files: scripts/bot_tactics.gd; scripts/bot_controller.gd; tests/test_bot_tactics.gd.
- [x] Add a fixture with exposed short and covered alternate paths, plus stale knowledge and failed movement cases; run RED.
- [x] Implement exposure-aware path costs, alternate flank/perch searches, short safe crossing waits, and bounded recovery; preserve the rear knife gate.
- [x] Run GREEN and gameplay/high-ground/bot suites.

### 4. Simulation, analysis and middle-round recording

Files: tools/run_bot_study.gd; tools/analyze_bot_study.py; tools/record_bot_study.gd; scripts/replay_recorder.gd; tests/test_replay.gd.
- [x] Test early recorder completion and record-data validity before implementing explicit finish().
- [x] Run 48 upgraded rounds using 12 seeds × two maps × two role assignments; save per-round metrics plus sampled traces. Fix demonstrated failures with focused tests and rerun affected cases; freeze the final policy for its measured batch.
- [x] Record five consecutive forest rounds, select round three by index (not outcome), and preserve full replay, telemetry and selection metadata.
- [x] Analyze exposure, hide time, detections, paths/stalls, attacks, rear finishes, outcomes, timings and AI query cost; state limits.

### 5. Video, Windows build and review

Files: tools/render_movie.gd; tools/render_windows_movie.py; scripts/main.gd; docs; Windows/source bundles.
- [x] Support explicit replay/start/duration/output for the existing native rendering pipeline; preserve old files.
- [x] Render selected complete middle round at constant 60 fps with two POVs/audio; verify dimensions, sample count/timing, full decode and selected encoded frames.
- [x] Set the new session as the normal app replay after validation; preserve old session access.
- [x] Run all relevant source suites and actual two-peer network checks, export Windows, check packaged runtime and native startup, refresh licenses/docs/archives.
- [x] Obtain one fresh read-only review, address important findings with RED→GREEN evidence, and verify final archive CRC/content.

Finish condition: documented AI behavior implemented; focused and regression tests pass; 48-round final telemetry analyzed; valid five-round session and authentic third-round 1080p60 video delivered; current Windows/source ZIPs verified. Human balance/fun remains a playtest question.

Completion note: representative comparison was repeated with normal countdowns; earlier accelerated batches retained as exploratory. Final counts and limits are in docs/ai-gameplay-study.md. No Git commits were possible because the workspace has no Git repository.
