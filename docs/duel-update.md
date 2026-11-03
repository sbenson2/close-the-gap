# Paired duel update

2 November 2026. Windows x64 / Godot 4.7.2. Current build ID: `duel-20261102`. These are implemented changes following the [lead design](lead-design.md).

## Play

Extract `Close-the-Gap-Duel-Windows.zip` and run `CloseTheGap.exe` beside its PCK. The app opens a new five-round split-POV recording. Choose Live bots for a fresh duel, or Menu for friend play and practice. Select Paired duel or Classic in the host/practice rules picker.

- Paired duel: two rounds with exchanged roles, a 150-second cap, expiry as draw. A split pair is a drawn set; an extra defender turn cannot decide it.
- Shared knife rules: rear hit kills, front hit deals 35 damage. Frontal recovery is 1.05 seconds for the attacker versus a 0.45-second defender interruption, leaving counterplay. Humans and bots use the same host resolution.
- Rifle: three loaded rounds and nine reserve. R starts a committed 2.8-second reload; aiming and fast movement are restricted during it. Misses consume ammunition. The handgun retains its six-round magazine and twelve reserve.
- G throws one of three pebbles. Each uses an imported rock model, an actual ballistic path, collision and a single impact. Nearby birds can react. Throws and impacts replicate and reconstruct in recordings.
- Sound reaches bot decisions as anonymous approximate areas, without owner identity or decoy labels. A distraction does not force a response. Reloads are audible nearby. Own-noise text uses only the player's action/movement.
- Practice offers safe rear-approach and rifle/reload encounters. A completed set offers a skippable event review and immediate rematch. The review is a factual event list, not a new cinematic kill-cam.
- New bot sets change their deterministic plan seed. Bots reload finite rifles and can create lateral pebble disturbances using their own route/map knowledge.

Classic retains lethal knife hits from any angle, unlimited rifle ammunition, sniper timeout wins and first-to-three scoring. Earlier recordings remain untouched and use their recorded legacy interpretation.

## Map and information boundaries

Crow's Ridge revision `ridge_v2` adds rock shoulder screens at Moss spur, Saddle hide and East crag. Moss has fewer sampled cross-approach sightlines; Saddle emphasizes transfer and side peeks. The other overlooks, two quiet climbs and connected high contour remain. All seven overlooks are tested through actual capsule movement. The audit is a set of particular rays, not proof that a perch can never see a route.

Recordings store map revision and ruleset. Old mountainside recordings load `ridge_v1`; starting a new game restores the current revision. Replay format 2 records rifle resources, throws, impacts, reloads, draws and completed-round events; format 1 remains supported.

Bots still receive direct sight, approximate sound and fading private memory. No opponent spawn prior or hidden transform enters decision code. No objective proximity flags, detection guarantees or automatic player reveals were added.

## Measured gameplay and presentation

The fixed-policy cohort contains twelve normal-timing rounds: six seeds, both assignments. Sniper won eight and stalker four; three stalker knife finishes had no sniper sighting. All rounds completed by combat. There were no high-ground violations or unresolved route arrivals. Sampled transient requested-movement stalls totaled 3.75 seconds for stalkers and 2.5 for snipers. Median round duration was 45.67 seconds.

The bots visited three outlooks in this cohort. Physical reachability of seven positions does not establish varied AI use or distinct tactical value. Several gameplay families changed together, so the previous 12–0 cohort cannot isolate which change caused a result. Analysis rejects policy comparisons across different rules or terrain revisions.

Native Windows live split-screen, RTX 4060, 1920×1080, fifteen seconds: average 71.8 fps, median 13.75 ms, p95 16.57 ms, maximum 20.33 ms. This is a short sample, not a guaranteed minimum frame rate.

The current video is `Close-the-Gap-Duel-60fps.mp4`: third round of five, selected by index, 58.383 seconds, 3503 constant-60-fps frames and stereo audio. Full decoding passed; a three-second scene-only crop contained 180 distinct frames. The selection includes countdown and round transition. The saved five rounds contain both rifle and rear-knife outcomes.

Evidence: [cohort report](../artifacts/design-slice/analysis/report.md), [raw results](../artifacts/design-slice/cohort/results.json), [sightline audit](../artifacts/design-slice/sightlines.json), [Windows frame times](../artifacts/design-slice/windows-performance.json), [video validation](../artifacts/design-slice/video-validation.json), [source hashes](../artifacts/design-slice/source-hashes.json).

## Verification and known limits

Source regressions cover both rule versions, physical navigation, sensory counterfactuals, combat resources, lessons, review access and legacy/new playback. Two real loopback clients exercise the new rules, reload/impact replication, timeout/set results and rematches; classic networking remains covered. Exported-pack checks and native Windows execution verify the deliverable rather than source alone.

Encrypted friend checks use a local Noray fixture for relay fallback and certificate rejection/recovery. The initial fixture still assumed Pine Hollow coordinates while the default had become Crow's Ridge; selecting its intended forest fixed that test. A connected application shutdown also exposed an existing attempt to add a drain node to a busy root. Teardown now closes the peer before releasing its connection state; an isolated relay shutdown check verifies guest cleanup. An initial direct shutdown test fell back during setup and is retained as a failed route-specific run, not claimed as passing direct-path evidence.

The offline MovieWriter exits with two GLES3 texture cleanup messages even after explicit viewport teardown. Both the full movie and a three-second cleanup probe exited successfully; the full MP4 passes decoding, timing, motion and audio checks. Native live performance and interface captures do not show those messages. The writer warning remains a tooling issue to investigate, not a claim of a clean renderer shutdown.

Human enjoyment, sustained performance and a fresh session across two separate home networks are not established by these checks. Relay objectives, wind/track systems and complete differentiation of seven nests remain behind the roadmap's human evaluation gates. No public service was deployed.

## Reproduce

Use the installed Godot path in place of `godot` below:

```sh
python3 tools/check_game.py --godot /path/to/godot --out artifacts/design-slice/release-regression
python3 tools/test_mountain_network.py --godot /path/to/godot --suite duel --out artifacts/design-slice/network
godot --headless --fixed-fps 60 --path . --script res://tools/run_bot_study.gd -- res://artifacts/design-slice/cohort 6 71 --mountain
godot --headless --fixed-fps 60 --path . --script res://tools/record_bot_study.gd -- mountain res://replays/duel-session.json 5
python3 tools/analyze_bot_study.py --study artifacts/design-slice/cohort/results.json --replay replays/duel-session.json --out artifacts/design-slice/analysis
godot --headless --path . --export-release Windows builds/windows/CloseTheGap.exe
python3 tools/package.py --platform windows --label Duel
```

The optional native movie pipeline is `tools/render_windows_movie.py prepare`, then `study --selection artifacts/design-slice/analysis/round-selection.json`. It uses the existing Windows Temp staging area and NVENC; it does not open a player or focus its offscreen window. Earlier delivered movies and release archives are preserved.
