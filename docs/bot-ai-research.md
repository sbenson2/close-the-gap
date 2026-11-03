# Better bot AI for Close the Gap

Research completed 2026-11-02 using the game-development and research skills. This note preserves the pre-implementation audit; the implemented upgrade and measured experiments are documented in [gameplay study](ai-gameplay-study.md). This is a code audit and research recommendation; runtime behavior, builds, recordings and videos were not changed. No new matches or human playtests were run for this research.

## Intended encounter

The latest user requirement is **the sniper should hide**. The sniper stays on allowed high ground, chooses a concealed firing position, watches useful approaches, peeks when a shot is worthwhile, and relocates under cover after firing or when threatened. The knife stalker observes clues, chooses a covered approach, waits through dangerous crossings, and tries to finish unseen from behind. Both bots must act on their own observations and remembered estimates.

AI sensors for shot/glint clues must validate audibility or visibility and retain uncertainty; raw global combat events must not become exact target coordinates. Hiding must remain discoverable through ordinary gameplay: a visible silhouette, scoped glint, a shot or audible movement can reveal useful clues. The stalker must not receive a hidden sniper transform or the sniper brain's detection flag. Map knowledge can identify possible perches, not the opponent's current hiding spot. The existing rule awarding the sniper a 150-second timeout win makes passive survival attractive; evaluate whether rounds remain tense and searchable before proposing any scoring changes.

## What the current code does

These are inspected facts, not conclusions from a fresh playthrough.

| Area | Current implementation | Consequence to investigate |
| --- | --- | --- |
| Stalker route | One of two fixed five-point flanks; crouches throughout. `scripts/bot_controller.gd:126` | Cannot choose a safer crossing or repair a flank based on fresh observations. |
| Sniper movement | Fixed three-point patrol, plus a sinusoidal downhill scan. `bot_controller.gd:158`, `:180` | Does not implement the requested concealed ambusher. |
| Perception | Horizontal cone and two chest/head rays, followed by binary shrub concealment. `bot_controller.gd:99`; `scripts/arena.gd:72` | No vertical view-cone check or scoped-view adjustment. The new vegetation's visible concealment should be checked against the sensor volumes. |
| Memory | Sight, noisy movement and bird clues share `last_known` and `memory_age`. `bot_controller.gd:115`, `:122`, `:151` | An approximate clue overwrites the same storage used for a sighting. Distinguish visual acquisition time from sound/clue time. |
| Reaction | New sight resets reaction only when shared `memory_age > 0.65`. `bot_controller.gd:111` | Recent hearing can bypass a fresh visual reaction delay. Add a focused regression fixture before changing it. |
| Escape | Taking damage requests cover. `bot_controller.gd:61` | Rifle hits deal 100 damage (`scripts/main.gd:555`), so a healthy stalker cannot use a successful rifle hit as its first retreat signal. |
| Cover | Eight nearby candidate points; a single blocked ray and distance term. `bot_controller.gd:230` | Cannot distinguish a concealed firing perch, a safe retreat, and cover with no useful view. |
| Navigation | Separate role-specific AStarGrid2D grids, currently without tactical weights. `scripts/arena.gd:320`, `:390` | Reuse walkability/high-ground restrictions; add tactical costs without replacing character movement. |

The older `artifacts/bot-matches-final.json` has 12 rounds: forest 3 stalker/3 sniper wins; yard 6 stalker wins with zero sniper sightings. Yard durations cluster around 49.75–49.93 seconds and all have sniper patrol counter 117. This is an investigation clue, not current balance evidence: the artifact predates the current controller file and is only three seeds per map. Possible patrol churn and repeated routes need a fresh trace before diagnosis.

## Findings from primary sources

1. **Perception needs understandable awareness.** Martin Walsh's Splinter Cell: Blacklist session overview frames perception as visual, audible and contextual awareness, and stresses consistent player feedback. Only the public overview was reviewed; no claim here depends on watching its recording. For this game, the application is a readable progression from a vague bird clue to investigation, confirmed sight, and a search after contact is lost. [Walsh, Ubisoft, GDC 2014](https://gdcvault.com/play/1021236/Modeling-AI-Perception-and-Awareness).

2. **Keep observations separate from execution.** Orkin's F.E.A.R. architecture paper describes sensors depositing facts in working memory, with decisions using that memory and commands sent to execution subsystems. It also describes distributing and caching expensive queries. The paper is a production account, not proof that its full planning architecture is needed here. Apply a small observation record—source, estimated position, uncertainty radius, time—and independent sight/hearing ages to the existing controller. [Orkin, AIIDE 2005, pp. 1–3](https://cs.uky.edu/~sgware/reading/papers/orkin2005agent.pdf).

3. **A stealth route should account for exposure.** The authors' public abstract describes paths that reduce exposure to moving patrols, use cover and vary speed by area in a known static environment. Only that abstract was reviewed. Our proposed adaptation is to compare approaches using cover and the sniper's *believed* viewing sectors, then wait or reroute when a crossing is risky. It must not use the hidden sniper's true aim. [Mendonça, Bernardino and Fonseca Neto, BRACIS 2015](https://www.microsoft.com/en-us/research/publication/stealthy-path-planning-using-navigation-meshes/).

4. **Choose tactical positions by filtering, then scoring.** Matthew Jack's chapter describes the CryEngine Tactical Position Selection approach used in Crysis 2: generate candidate points, reject unsuitable ones, score the remainder, and inspect why a point won. The chapter is a practitioner framework rather than a comparative benchmark. For a hiding sniper, filter for reachable high ground, body concealment, a usable muzzle/eye line and an escape route; score lane coverage, exposure, travel distance and the information in recent clues. A foliage-hidden body and an unobstructed rifle line require separate checks. [Jack, Game AI Pro, chapter 26, pp. 337–339](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter26_Tactical_Position_Selection.pdf).

5. **Bot experiments establish reproducible behavior, not enjoyment.** The Battlefield V session overview describes AutoPlayers for scripted cases and large soak tests. Only the overview was reviewed. Apply that distinction here: deterministic fixtures can verify concealment, cue handling, route recovery and role limits; human sessions must judge fairness, tension and whether the hidden sniper can be found. [Gillberg, Electronic Arts, GDC 2019](https://gdcvault.com/play/1025905/AI-for-Testing-The-Development).

6. **The current Godot pathfinder supports weighted cells.** `set_point_weight_scale()` multiplies a destination cell's segment cost; changing weights does not require `update()`. Calling `update()` clears both weights and solidity, and enabling jump mode ignores weight scaling. Preserve these constraints if prototyping exposure costs. The existing map has a single height function per X/Z location, so its current grid remains a practical first experiment. [Godot 4.7 AStarGrid2D documentation](https://docs.godotengine.org/en/4.7/classes/class_astargrid2d.html).

## Recommended implementation order

**First: reliable observations and a hiding sniper.** Keep current physical sight/attack checks, rear knife condition and authoritative high-ground constraints. Separate visual memory from sound/bird estimates and test visual acquisition delay. Add concealed perch candidates and explicit commitments: select hide → hold and watch an approach → investigate a cue from concealment → peek for a confirmed shot → fire → withdraw or relocate through cover. If no valid firing hide exists, select reachable covered observation space and retry when evidence changes. Movement and destination need separate scores: a safe destination does not justify crossing an exposed route.

The sniper should aim a search at an estimated area, with a radius that grows as information ages. A bird clue should select a viewing direction or a vantage overlooking that area; clamping the clue's coordinates onto the ridge is not itself a tactical-position decision. Track which nearby sectors were checked and vary the next one; do not mechanically track an unseen stalker.

**Second: an adaptive stealth approach.** Keep the authored left/right routes as fallbacks. Score candidate transitions by expected exposure time, distance, concealment and movement noise; use observed facing when available, and uncertainty when it is stale. Apply a bird/noise penalty only when the candidate movement can trigger the existing rules: crouched players do not disturb birds through movement. Keep a per-bot tactical cost layer over shared static walkability. A simple nonnegative cost is `segment_length × (1 + exposure_penalty + noise_penalty)`. Sample at crouched body height and validate the complete candidate route. Start with a small candidate set and bounded cached queries rather than recomputing the entire forest every frame.

Add explicit hold/look actions before open crossings and a rear approach once the sniper has been located. Retreat can be triggered by an observed rifle turning toward the stalker, a missed shot or other available evidence; it cannot depend on reading the sniper's internal sight flag. A correctly occluded enemy transform remains unavailable to tactical decisions.

**Third: stable choices and difficulty.** Keep a chosen hide/route for a short commitment interval; interrupt it for meaningful danger, failed movement or stronger evidence. Use seeded tie-breaking among similarly good options. Tune observation delay, search thoroughness, memory decay and willingness to cross risk independently. A compact role controller with scored tactical choices is the recommended starting architecture; a full GOAP or learned policy is not a prerequisite. This is our scope judgment, not a finding established by the sources.

## Evaluation before calling it better

Begin with small deterministic scenarios on both maps, using the existing test/recording tools. For each changed policy, preserve the previous one as a comparison and fix the seed, spawn, map and settings. Expand the seed set only after focused cases work.

- **Hiding:** sniper remains in bounds, is concealed from sampled plausible approach points, retains a useful viewing/shot lane, and holds still when no new evidence requires movement. An entirely sealed hide should not score as a useful firing perch.
- **Fair sensing:** no rear or out-of-view visual detection; physical cover blocks sight; a noisy/bird cue creates an approximate search area, never a firing target. Hearing immediately before first sight must not cancel the intended reaction delay.
- **Search:** after the stalker breaks contact, the sniper checks remembered areas and plausible exits, retires searched empty areas, and eventually settles into a new concealed watch. It must not follow changes in an unseen target transform.
- **Approach:** compare time exposed, exposed crossing count, rear-knife success, timeouts and route diversity. Include a case where the shortest path is exposed but a covered alternative exists, and a case where the selected route becomes blocked.
- **Execution:** log evidence type/age/radius, selected action and score terms, movement progress, failed paths, ray/path queries, state changes and outcome. Check overlapping arrival thresholds and repeated goal changes if the historical yard patrol pattern reproduces.
- **Presentation:** inspect short dual-POV recordings of the new runs; the existing ten-minute replay cannot demonstrate changed decisions. Then use human playtests to judge discoverability and tension. More wins alone are not the objective.

The first reviewable milestone should be a sniper that demonstrably chooses and holds concealed high-ground positions, reacts fairly to clues, and still provides opportunities for an unseen rear approach. Measure that before adding broader search/planning complexity.

## Sources

- Martin Walsh, Ubisoft, GDC 2014: [Modeling AI Perception and Awareness in Splinter Cell: Blacklist](https://gdcvault.com/play/1021236/Modeling-AI-Perception-and-Awareness) — public session overview.
- Jeff Orkin, AIIDE 2005: [Agent Architecture Considerations for Real-Time Planning in Games](https://cs.uky.edu/~sgware/reading/papers/orkin2005agent.pdf) — paper.
- Matheus R. F. Mendonça, Heder S. Bernardino and Raul Fonseca Neto, BRACIS 2015: [Stealthy Path Planning Using Navigation Meshes](https://www.microsoft.com/en-us/research/publication/stealthy-path-planning-using-navigation-meshes/) — public abstract.
- Matthew Jack, Game AI Pro, 2013: [Tactical Position Selection: An Architecture and Query Language](https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter26_Tactical_Position_Selection.pdf) — chapter 26.
- Jonas Gillberg, Electronic Arts, GDC 2019: [AI for Testing: The Development of Bots that Play Battlefield V](https://gdcvault.com/play/1025905/AI-for-Testing-The-Development) — public session overview.
- Godot contributors, 4.7 documentation: [AStarGrid2D](https://docs.godotengine.org/en/4.7/classes/class_astargrid2d.html) — API contracts.
