# Demo v0.1.0-demo.1

Windows x64, Godot 4.7.2. The release contains the verified game executable/PCK, original project and engine notices, and asset credits. The source tag includes required assets and recordings.

## Features

Three maps; two-player friend invites with direct/relay connection attempts; mutual ready room; paired two- or six-round sets; Classic mode; optional relay sabotage/repair; weather and surface sound; fading mud tracks; reflector, tripwire, binoculars and western handline; practice and two weapon lessons; field guide; keyboard remapping and captions; local journal; round reviews and saved dual-view human recordings.

Invite transport pins the host certificate and authenticates the expiring invite over DTLS before accepting gameplay RPCs. The host owns physical interaction, inventory, damage and scoring. Build IDs reject mismatched demo versions. Reliable results own match completion; objective revisions reject stale snapshots. Replay formats 1/2/3 retain their recorded rules and map revision.

## Verification

The existing demo passed 31 source suites, with 384 counted Godot checks, rules checks and five Python analysis tests. Pack checks used an empty resource directory and checked all 401 PCK entries and hashes. Native Windows tests exercised six rounds, both readiness states, sabotage/repair, field equipment, guest rematch, human recording save/playback, actual release-executable startup and packaged UI captures.

| Bot cohort | Rounds | Sniper wins | Stalker wins | Unfinished | High-ground violations |
| --- | --- | --- | --- | --- | --- |
| Relay / rain | 12 | 6 | 6 | 0 | 0 |
| Paired / gusts | 12 | 7 | 5 | 0 | 0 |

Each cohort used six seeds and both role assignments, normal countdowns and 4 Hz telemetry. The separate featured record contains five rounds. Its third round was selected by index, independently of outcome, and rendered as a 61.917-second 1080p/60 fps video with audio. Full decoding checked all 3,715 frames; a checked one-second scene crop contained 60 distinct images.

A 15.01-second native Windows single-view rain run averaged 94.63 fps on an i9-9900 / RTX 4060 (p95 13.22 ms; maximum 17.52 ms). Repeated split-screen rain runs were near 68 fps; the first cold run included a 1.13-second hitch. These are short measurements, not a sustained or locked-60 guarantee. The recording is rendered offline at constant 60 fps.

[Machine-readable verification](demo-verification.json) includes the measurements, cohort summaries and immutable PCK hash. Public release packaging changes documentation and notices, while retaining the tested executable/PCK and gameplay video bytes. No local logs, private session files or agent handoffs are published.

## Limits

Direct and relay friend transport are provided through the independently operated Noray community test service at foxssake.studio. Its availability is outside this project. Source public-relay tests and final-pack local encrypted-relay, wrong-secret and certificate checks passed. Two physical PCs on separate home networks remain unverified. The final Windows pack has not received a new public-service test.

Local movement is predicted; remote actor poses update at 20 Hz, with no historical hit rewind. Latency can affect shot feel. The host is trusted; this is not a competitive anti-cheat system. Bot outcomes do not establish human enjoyment, fairness or learnability. Final speaker/headphone listening remains a human check.

Historical local release bundles and raw development logs are not distributed here. Historical gameplay recordings are retained in the source and game pack for replay compatibility.
