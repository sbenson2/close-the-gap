# Verification record

Current update: Godot 4.7.2 on Linux x86_64, 2026-11-02. Windows x64 remains the delivery target.

## Bot duel, stealth and high ground

- Bot duel: 19 checks, zero failures. Two independent brains, distinct first-person cameras sharing one world, no human movement input, real movement, pause, cleanup, opening spawn cover, sight/occlusion/memory, real combat, role swaps, match completion and automatic rematch with rebound cameras.
- High ground: eight checks, zero failures. Real physics movement on the slope; sniper sprint/jump confinement on the ridge and loading deck; sniper navigation confinement; eighteen metres between forest spawns; an actual stalker climb to the ridge; and a crouched climb up the screened yard ramp across the rear bridge.
- Focused stealth: five checks, zero failures. Knife-only crouched approach, no frontal knife attempt, no close-range rear vision, real rear knife elimination and zero sniper sightings during that elimination.
- Gameplay: 20 checks, zero failures. Movement, jump, crouch collision, central ramp, knife/rifle rays, cooldowns, scoring, role changes, timeout, rematch and cleanup.
- Forest and handgun: 23 checks, zero failures. Deterministic geometry, foliage density, connected routes, map switching without retained navigation obstacles, handgun aiming/damage/ammunition/reload, role restrictions and empty ammunition.
- Rules: 12 assertions, zero failures. Invite codec: 13 checks, zero failures. Connection lifecycle: eight checks, zero failures.
- Two real local ENet peers: 25 checks, zero failures, including host-enforced sniper confinement, movement, selected map, invalid input rejection, aiming, ammunition/reload, knife/rifle combat, scoring, swaps, rematch and disconnect.

The focused rear-attack setup and the complete autonomous round sample are different evidence. Full rounds use ordinary sensors, physics and hit tests; no forced attack or winner is supplied. Before the forest art/wildlife update, a sample used seeds 71, 114 and 201, with both starting roles for each map (12 rounds total):

| Map | Knife wins | Rifle wins | Timeouts | Median round | Knife wins with zero sniper sightings |
| --- | ---: | ---: | ---: | ---: | ---: |
| Pine Hollow | 3 | 3 | 0 | 44.92 s | 0 |
| East Yard | 6 | 0 | 0 | 49.86 s | 6 |

The forest bot attempted rear approaches but was seen during each winning run. The yard sample demonstrates complete unseen approaches; it does not establish a balanced matchup. These are small deterministic bot samples, not human playtests. Final records are in artifacts/bot-matches-final.json.

Rendering was captured at 1000 × 625 using OpenGL compatibility on Mesa llvmpipe, in an authenticated private virtual display with TCP disabled. Both actual first-person views, their different weapons, behavior labels, the stalker's detection status and shared controls were inspected. The user's desktop was not used. The driver reports unsupported V-Sync; the final capture has no script errors, resource-leak errors or engine errors. Rendering this scene does not establish performance on a Windows GPU or subjective game feel. Audio was not listened to.

## Friend connection evidence

The implementation uses Noray rendezvous and direct UDP attempts with relay fallback. Game traffic uses certificate-validated DTLS and an expiring private invitation challenge before gameplay RPCs are accepted. The host PC owns the simulation. LAN/direct-IP is explicitly separate and unencrypted.

Earlier source checks passed local direct encrypted P2P, forced automatic relay fallback, rejection of an incorrect secret and rejection of a mismatched host certificate, followed by a valid join. Certificate-rejection runs intentionally produce native TLS errors. Direct disconnect checks exposed an immediate-close receive error; the existing bounded disconnect drain resolves it. These networking components were not changed for the bot update.

Public-service tests use only this game's own two temporary peers. Private invitation data and keys are not printed. Temporary invite files are removed. No service or website was deployed and the game was not published or shared externally.

## Export and limits

The Windows x64 release exported successfully with the official Godot 4.7.2 template, without export warnings or errors. Exported-pack and packaging checks are recorded below. Tests under Linux using the Windows PCK validate the exported resources and scripts; they do not execute the native Windows program. Neither Windows nor Wine is available here.

Still unverified: native Windows execution, two humans on separate home networks, sustained packet loss or long-session recovery, subjective stealth readability/balance/game feel, Windows frame rate and audible output. The Noray community testing service has no production availability guarantee.

Commands are in README.md. Detailed local logs and measurements are in artifacts/ and excluded from the source archive. Research and the stealth design are in bot-tuning.md.

## Windows pack before the forest art/wildlife update

All five affected runtime suites passed against the exported Windows PCK using the Linux Godot engine from outside the source directory: bot duel 19, high ground eight, stealth five, gameplay 20, forest/handgun 23; 75 checks total with zero failures and no engine or script errors.

Two separate processes using that same exported pack completed the public Noray encrypted relay test: 11 checks, zero failures. This covers authenticated joining, room locking, authoritative movement, combat/score, map replication and disconnect cleanup. No private invite data was printed.

The Windows ZIP contains the executable, adjacent PCK, README, research/design/verification notes, Godot notices, original asset licenses and Noray notices. Both ZIPs pass CRC integrity checks. The executable is a Windows x64 PE32+ GUI application and the PCK has a valid Godot header. Native Windows execution remains unverified.

## Forest foliage, wildlife and bird clues

The current scene has 292 trees and 12,686 foliage instances, including 1,897 tall grass tufts; smaller roots, leaf litter, branches, mushrooms, loose stones and stumps add ground detail. Ten animals walk/graze on deterministic paths and 51 birds perch in tree flocks. Geometry and native asset provenance are recorded in forest-art.md.

- Forest/handgun: 23 checks; high ground/climbs: eight; stealth: five; bot duel: 19; existing gameplay: 20. All passed on the updated source without engine/script errors. Wildlife and bird behavior: 19 checks, zero failures, covering walking, leg animation, terrain-following, pause, quiet crouching, noisy movement, jumps, bird flight/return, cooldowns, gunfire, approximate bot knowledge, stale event rejection and cleanup.
- Two actual local multiplayer peers: 28 checks, zero failures, including host-authoritative bird disturbances, event replication and the same disturbed tree on both peers. Existing movement, weapons, damage, scoring and disconnect checks remain passing.
- The current terrain and animals were rendered and inspected through both actual game cameras on an authenticated private display. The wildlife close-up deliberately stages the cameras and a bird disturbance for visual inspection; it is not a claim of an unstaged bot encounter. The normal app still opens directly into the autonomous duel.
- An early dense prototype hit the 80-second software-render capture limit. An eight-frame profile showed 5,489,126 submitted primitives. Reducing plant mesh detail, using local canopy batches and limiting distant microdetail reduced a comparable initial view to 1,672,637 primitives. FPS stayed low on llvmpipe; this is evidence of lower geometry workload, not a Windows frame-rate claim. The later wildlife/scope inspection view is a different camera and cannot be compared directly. All private capture windows and displays were closed afterward.

The six CC0 texture maps and original bird alarm audio import successfully. The Windows export completes without warnings/errors. Final pack checks and archives are refreshed for this revision. Native Windows execution, Windows frame rate and audible quality remain unverified.

The final exported Windows PCK passes wildlife/birds 19, forest/handgun 23, high-ground traversal eight, stealth five and bot-duel 19: 74 checks with zero failures. The pack also passed an 11-check encrypted relay match through the local Noray fixture. This verifies exported resources and the friend path under Linux Godot, not native Windows execution or a new public-service test. The project source regression suites additionally include 20 passing existing gameplay checks.

Headless rendering does not expose useful MultiMesh transform reads here. Flight/return tests therefore check the logical world positions supplied to the render batches; private OpenGL captures independently inspect the rendered scene. The wildlife preview uses staged cameras for that inspection. The normal application launch configuration remains the autonomous split-screen duel.

## Recorded bot session and replay

A normal-rule, ten-minute forest session ran using the headless display with fixed 60 Hz physics. It completed ten rounds and recorded 12,008 state samples plus 31 attacks/bird events. Three matches completed; the final match was partial at the 600-second recording boundary. The immutable recording hash and actual outcomes are in recorded-session.md. No AI ran in the graphical replay captures.

Replay tests: 17 checks, zero failures. They cover the complete file, both POVs, no authoritative simulation/input, exact saved states across round changes and rematches, interpolation, pause, recorded attacks and exact damage between samples, no new AI shots, speed, end-of-recording stop, timestamp/transform rejection and missing-file cleanup. JSON's numeric representation required explicit integer validation; exact seek boundaries use a small floating-point tolerance. Both issues have regression coverage.

The recorded session was reconstructed at 01:01.8 in the private OpenGL display, with both original player POVs, the recorded behavior/score, timeline, pause, restart and speed controls inspected. This was a seek into the actual headless recording, not staged actor positions or a rerun of AI. The viewer starts with the bundled recording; fresh live bots remain available.

The replay viewer exports successfully for Windows. Its exported PCK, including the bundled 7.2 MB recording, passed all 17 replay checks when launched from outside the source directory using Linux Godot. This verifies the actual exported data and scripts, not native Windows execution. Source bot-duel, wildlife, gameplay and connection-lifecycle regression suites also pass.

The final multiplayer regression exposed a test race: the guest released scope immediately after writing a file marker, before the host necessarily observed scoped input. The harness now holds scope until host acknowledgement and bounds the host's wait. The assertion still requires actual replicated scope state. No gameplay input or authorization rule was weakened.

The corrected two-process network harness passes all 28 checks with both peers reporting zero failures. The updated Windows and source archives include the unchanged recorded-session data, controls, documentation and final handoff; CRC and content checks pass. No app window was placed on the user's desktop.


## Native Windows gameplay video (2026-11-02)

Native Godot 4.7.2 rendered the saved forest session with the RTX 4060 and direct NVENC H.264 encoding. The final MP4 is 1920×1080, 600 seconds and 36,000 frames at constant 60 fps. Actual sample tables and all decoded frames passed validation; full audio decoded with peak −6.1 dB. Both POVs and changed roles were inspected in the encoded video. The original recording hash is unchanged.

The file is `../Close-the-Gap-60fps.mp4` and `%USERPROFILE%\Videos\Close-the-Gap-60fps.mp4`. Native Windows media controls confirmed the exact title, successful restart, normal speed, Playing status and foreground Media Player. See `artifacts/gameplay-validation.json`, `windows-video-playback.log` and `docs/video-export.md`. These are video/native replay checks, not a live game performance measurement.

## Imported asset update — 2026-11-02

This section supersedes earlier statements that native Windows rendering was unavailable. The desktop is Windows with an i9-9900 and RTX 4060; Linux tools run under WSL2. Native Windows Godot uses the RTX 4060.

Clean source import and the Windows release export complete with zero engine errors or warnings. Eleven source suites passed: rules (zero failures); gameplay 20; forest/handgun 23; bot duel 19; high ground 8; stealth 5; wildlife/birds 19; replay 17; invites 13; connection lifecycle 8; model assets 69. That is 201 counted checks plus the rules suite. The actual two-peer LAN integration test passed 28 checks with zero failures/errors.

The model suite verifies all registry resources, skeletal human locomotion, hip lowering during crouch, visible derived first-person forearms, lit finite weapon meshes, skeletal animal motion, crow instances and finite flat-floor/container fitting. All 69 model checks also pass against the exported Windows PCK from outside the source project, with zero runtime errors.

An exact baseline comparison confirms unchanged solid-obstacle descriptors, concealment regions, tree perches, stalker route and all 12,686 foliage placements. No simulation or network rules were changed for this art replacement. The existing recording is unchanged.

Native Windows offscreen 1080p split-screen captures were inspected for both forest POVs, iron sights, imported wildlife and the yard. A six-second uncapped replay sample on the RTX 4060 rendered 371 frames, averaging 61.76 fps, median 16.182 ms and p95 17.253 ms. Some frames exceed 16.67 ms; this is a short performance sample, not a guaranteed minimum for live matches. Audible quality and human gameplay balance remain unverified.

Attribution/license copies and original download SHA-256 hashes are supplied with the source and Windows bundles. See [asset replacement](asset-replacement.md). Detailed evidence: `artifacts/asset-research/final-tests.json`, `final-network.log`, `final-import.log`, `final-export.log`, `pack-models.log`, `world-comparison.json` and `artifacts/asset-performance.json`.

The actual Windows release executable also passes a headless startup check using its adjacent PCK, normal replay startup and 180 fixed simulation frames; no engine/script errors (`native-release-smoke.log`). The release intentionally rejects editor-style path overrides, so the native executable check uses its normal entry point.

Updated-art video: exactly 30 seconds, 1920×1080, 1,800 video samples at constant 60 fps. All frames decoded successfully with native FFmpeg; stereo AAC decoded with mean −39.5 dB, peak −6.3 dB. Size 85,252,061 bytes; SHA-256 `47df35c4798b2c5cec5352672e22cc80183655abce4eab3ca015c355faf70d9e`. Encoded encounter and swapped-role frames were visually inspected. Evidence: `artifacts/asset-research/preview-timing.json`.

Both refreshed ZIPs pass full CRC integrity checks. The Windows bundle contains the x64 PE executable, valid adjacent Godot PCK, credits, source manifest and all seven model-family license notices. Every source-archive runtime model matches its recorded SHA-256 hash. Original replay SHA-256 is unchanged.

## Concealed bot AI and measured session — 2026-11-02

Current source: 234 counted Godot checks plus the rules suite and four Python analysis tests across 16 suites; zero failures/errors. New featured-session checks verify the actual five-round recording and preserve the original 600-second replay. Exported Windows PCK: model69/tactics14/featured6 checks pass. The actual native Windows release boots its featured replay and completes a live bot combat round headlessly, with zero errors. LAN28 checks pass.

177 completed rounds across development/validation/recording; the final representative comparison uses normal startup timing, an eight-round original-code baseline and 48 upgraded rounds (12 seeds, both maps, both role assignments). All 48 resolve by combat with no sampled high-ground violations. Forest: stalker10/sniper14, five unseen knife finishes. Yard: sniper24/stalker0, a remaining balance limitation. See [full study](ai-gameplay-study.md) for interpretation and methodology.

Selected middle round: third of five, chosen by index before observing outcomes; replay ticks10788–16296, 91.8s, 5508 constant-60-fps video frames at1920×1080, full decode verified, 180/180 unique motion samples, stereo audio decoded. The encoded encounter/result were inspected. Native RTX4060 rendering remained offscreen. Detailed source-policy hashes, raw traces, CSV, selection and frame/audio evidence are in the AI data bundle.
