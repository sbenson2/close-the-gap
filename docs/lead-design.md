# Close the Gap: lead design direction

2 November 2026. Design direction and proposals. The [duel update](duel-update.md) records the implemented first slice; later candidates below remain experiments.

## Direction

Build a compact duel in which two friends learn to read, mislead and outmaneuver each other. The stalker closes through terrain and uncertainty; the sniper manages attention, firing angles and the risk of being found. The memorable outcome should be a decision someone can describe: a false bird alarm, an exposed shot, a patient crossing, a correctly read flank, or an unseen rear approach.

Keep the knife, aimed handgun, elevated hidden sniper, connected forest overlooks and living environment. Develop the consequences of those existing actions before increasing the number of weapons, players or maps. My recommended first milestone is a fair paired-role duel with a clear clue language, one physical distraction and a useful round-end review. An objective-pressure mode is a separate experiment.

The following are design calls and hypotheses. They are not attributed to the user as prior approvals, and none is presented as a proven engagement improvement.

## What the brief already establishes

- Windows, Godot, two friends, eventual Steam integration, and the existing free/open-source connection prototype.
- A stalker whose intended ambush is quiet and from behind; a sniper who hides on high ground and can change positions.
- Knife and aimed handgun for the stalker; rifle for the sniper. No smoke grenades.
- A dense, believable forest with rocks, shrubs, tall grass, animals and birds that can supply clues.
- Bots use direct sight and approximate sound only, with fading memory. No hidden coordinates, enemy-spawn prior or information sharing between brains.
- Smooth presentation matters. The current short Windows split-screen measurement is a useful baseline, not a sustained performance guarantee.

Proposed audience: two friends willing to learn each other's habits, with bot practice as support. Proposed session: a short paired-role encounter followed by a quick rematch; a longer multi-pair session is optional. These are my working assumptions, not established audience research.

## Current evidence and contradictions

The code and recorded study provide a concrete starting point:

| Observed implementation | Design implication and uncertainty |
| --- | --- |
| 150-second rounds; sniper wins timeout; rifle is lethal and currently has no ammunition limit. | Waiting is mechanically safe for the defender. That incentive exists regardless of why the bots lose. It does not prove humans will enjoy or exploit the same strategy. |
| First to three wins with roles alternating each round. | An odd-length match can give one person an extra turn in the stronger role. Use complete role pairs when evaluating fairness. |
| Human knife hits currently deal lethal damage from any angle; bots voluntarily require a rear attack. | The advertised ambush and the actual shared weapon rules differ. Decide and teach one contract for humans and bots before interpreting comparative results. |
| Seven outlooks are physically reachable, but all twelve final bot rounds favored the sniper and most visits were to Saddle hide/East crag. | This flags restricted policy choices, possible dominant positions and exposed approaches. It is not a measured human win probability. |
| Bots have bounded visibility work, real cover tests, private memory and counterfactual information tests. | Preserve these foundations. Better play cannot be purchased by handing a bot hidden state. |
| A fifteen-second native 1080p split-screen sample averaged 71.0 fps, with a 17.70 ms 95th-percentile frame. | There is limited measured headroom. New foliage, cameras, weather and AI must justify their cost. |
| Existing replays, dual POVs, raw traces and Windows builds are available. | Use the debrief and measurement tools already built. Another large simulation batch alone will not establish tension or fun. |

Code anchors: [rules](../scripts/rules.gd), [combat resolution](../scripts/main.gd), [bot decisions](../scripts/bot_controller.gd), [perception](../scripts/bot_senses.gd). Current evidence: [map verification](mountainside-design.md) and [final cohort coverage](../artifacts/mountainside/analysis/coverage.json). The earlier [design snapshot](design.md) describes older prototype stages; this document proposes the next direction rather than overwriting that history.

Plausible causes of the twelve-to-zero bot result include the incentive structure, overly broad sightline coverage, strong rifle execution, a narrow stalking policy, and the human/bot knife-rule mismatch. Isolate those factors. Do not diagnose the whole game from one controller matchup.

## Design pillars

**Information has a cost.** Looking for a shot narrows attention. Firing creates evidence. Fast movement gives time and spends quiet. A distraction risks being read as a distraction. Costs must be visible or audible and consistent.

**Every strong position has a meaningful weakness.** An overlook may have range, protection, access or concealment; it should not lead in all four. The stalker needs a plausible route to its rear, and the sniper needs a usable retreat rather than an arbitrary movement order.

**Both roles make plans.** Quiet waiting can be tense when it follows a hypothesis. It becomes empty when no useful action or new inference is possible. A sniper should choose what to watch, not sweep every direction continuously; a stalker should choose how to approach, not follow a compulsory corridor.

**Losses teach something.** A death may be surprising, but the completed round should contain evidence that explains it. Understanding a missed clue should make a rematch appealing.

These pillars are our synthesis. Motivation research associates agency and competence with enjoyment, while uncertainty research offers reasons to examine curiosity and learning; neither proves this specific design will work. See the evidence limits in [engagement research](design-research/engagement.md).

## The moment-to-moment loop

| Beat | Stalker decision | Sniper decision | Resulting evidence |
| --- | --- | --- | --- |
| Observe | Read terrain, an old shot direction, a visible glint or disturbed wildlife. | Select a lane, distinguish an ordinary animal event from a useful clue. | Partial information with an uncertain age. |
| Prepare | Pick a quieter route, wait for cover or place a distraction. | Hold a screened position, use a wider observation view or move to another angle. | Sometimes nothing new; observation still has an opportunity cost. |
| Commit | Cross a gap, climb, draw the handgun or close for the knife. | Peek, settle the rifle, fire or let a doubtful target pass. | A glimpse, noise, missed shot or visible movement. |
| Recover | Break sight, revise the route, use ammunition deliberately. | Reload, watch the likely counter-route, relocate through cover. | The old position may be known; the new one is not. |
| Resolve | Finish the rear approach or accept a failed attempt. | Read the final approach or get caught looking at the wrong place. | A decisive result or a legitimate timeout draw in the control variant. |

Example, not a scripted sequence: a stalker throws a stone toward a crow tree, crosses the opposite gully during a gust, then pauses after hearing a rifle shot from a different ridge. The sniper can follow the alarm, distrust it, or change angles. Either can be wrong. The system should support that story without deciding its winner.

## Core rules I would prototype first

### Paired-role duel

Preserve the existing lethal duel as the control. Keep the current round cap initially, but make expiry a draw in this experimental ruleset. Play two rounds before awarding a set result, with each person taking each role. A split pair is a draw; do not resolve it with one extra sniper turn. Offer rematch or another complete pair.

This removes the direct reward for passive timeout defense while preserving kill-only victory. It may increase draws. If people still spend long stretches without a plan, a draw rule alone has failed; do not quietly stack more timers onto it.

Decide the knife rule explicitly. My preferred test is a lethal rear knife attack, a less decisive frontal interruption, and the handgun as the loud emergency option. The exact frontal damage/stagger requires a small combat test. Human and bot attacks must use the same authoritative rules; bots may choose stricter tactics, but must not be the only participants bound by the intended ambush rule.

### Weapon commitment

Keep the rifle dangerous. Test a small magazine and a clearly audible reload rather than making opponents into damage sponges. A starting test might use three loaded rounds with a reserve, but its size is an experiment, not a production balance value. Show the consequence of firing and the vulnerability of reloading. Limited ammunition alone will not cure waiting.

Keep the aimed handgun. Its sound, limited ammunition and shorter useful range should make it a deliberate exposure decision. Test whether it creates a believable recovery option or simply replaces stalking with a second ranged duel. Avoid spending weeks on attachment statistics before answering that question.

Aim settling, scope movement and recoil should be controllable, readable weapon behavior. Do not secretly force misses because one player is ahead. Bot difficulty may vary reaction, execution and planning; it must never vary access to hidden information.

### One distraction

Start with a thrown pebble. It makes an actual impact at its landing point, may disturb nearby wildlife and can be seen in flight. Give the stalker a small finite supply. The defender can investigate, hold the original lane or look for a follow-up crossing. A cue identifies the event, not the thrower's current position or whether the throw was a trick.

This is the first added verb because it creates a decision for both players using existing sound, birds, cover and memory. It has a much smaller production cost than ropes, destructible trees or a new weapon family.

## Optional objective-pressure experiment

If the paired kill-only control produces excessive stalemates, test a separate relay ruleset. This deliberately changes the pure elimination contract; it is not a silent revision of the user's original duel.

Proposed starting rules: three fixed relay stations sit on different approaches. The stalker can sabotage two, using short, audible interactions. The sniper can restore a station through another committed interaction. Completing the second sabotage starts a short repair deadline; if no station is restored before it expires, the stalker wins by infiltration. Either player's lethal attack ends the round immediately. Starting interaction/deadline values are placeholders for a test, not final numbers.

The purpose is to create an ambush opportunity: the sniper chooses interception, repair or hunting the attacker; the stalker chooses finishing the pressure action or lying in wait for the response. Limit the number of reversals and interaction burden. If the round becomes a repetitive repair circuit, reject the variant.

There is no invisible contest radius. Hidden proximity cannot stop an interaction, light a warning or pause the deadline. Direct damage or an observable physical interruption may break the action. Local machine sounds and visible station lights supply positional evidence; there is no map ping identifying the station user. Public time/phase may communicate match progress without naming a hidden player's location.

Reject this experiment if people stop pursuing the ambush fantasy, if repair dominates the defender's time, or if objective wins feel like an unrelated chore. Keep the paired duel available even if this variant succeeds. Comparables illustrate why pressure can matter, not that relays are the correct answer: [comparison and trade-offs](design-research/comparables.md).

## Make the seven outlooks earn their place

The current route graph is connected; the next map pass should differentiate its decisions. The table is a proposed job for each location, not a claim that the present geometry achieves it.

| Outlook | Intended strength | Necessary weakness | Stalker counter-route |
| --- | --- | --- | --- |
| Fern blind | Screened view of one lower western crossing. | Limited range and poor eastern coverage. | Use the stream/gully-side cover and pass its rear shoulder. |
| Split-pine lookout | A useful western climb angle. | Noticeable wood movement and an exposed side transfer. | Reach it from the upper trail rather than its watched front. |
| Crown nest | Long observation, readable landmark. | Silhouette exposure and a vulnerable rear approach. | Use the reverse slope and terrain breaks. |
| Saddle hide | Protected transfer hub. | Weak direct valley dominance; attention divided across exits. | Force a choice at the junction, then use the unobserved branch. |
| East crag | Strong eastern lane and an oblique shot. | It must not also dominate both other climbs and its own rear. | A screened upper crossing must reach its back. |
| Hunter's stand | A local east-side ambush. | Restricted view and identifiable structure noise. | Approach beneath the relevant sightline and around its screened side. |
| Moss spur | Forward information and a short-range surprise. | Little protection from a bypassing flank. | Choose a longer covered bypass or exploit the user's retreat. |

Audit every main crossing from all outlooks, at standing and crouched eye height. Count how many angles can see it and whether an alternate route changes that set. A longer path is not an alternate if it is watched by exactly the same positions.

Do not reward movement with mandatory relocation instructions. Make the old angle less reliable after a shot and give the player a worthwhile destination. Prefer a few recognizable landmarks and short areas of uncertain contact over an increasingly large forest with more walking.

Secret starting choices are a later small experiment: choose a perch/entry from a few valid options. Do not show that selection to the opponent, supply it to bots as a prior, or derive it predictably from a public map seed. Preserve safe initial observation time.

## Forest mechanics and sensory language

Give the forest a small, consistent vocabulary: ordinary birds, alarmed birds, leaf movement, wood footfalls, stone impacts, gun reports and visible glints. Animals can create ambiguity, but the world must not be a constant wall of equally urgent alarms.

Crytek's published Hunt accounts make useful practitioner references for material occlusion, distinguishable source/state sounds and weather that changes opportunities. They do not establish settings for this game. [Audio design](https://www.huntshowdown.com/news/hunt-audio-readability-realism-and-consistency), [weather design](https://www.huntshowdown.com/news/behind-the-storm-technical-design-of-thundershower-in-hunt-showdown).

I would order the additions as follows:

1. Reliable existing shot/bird/footstep cues and the pebble.
2. Surface-specific movement sound, physical brush rustle and one clear glint rule.
3. Short shared wind windows that change movement audibility for everyone.
4. Fading visible tracks in selected mud patches, if people want more forensic pursuit.
5. Rain or snow only after the quiet-weather duel is readable and performance is measured.

A footprint is evidence of a past passage, not a live trail arrow. A glint must be seen. A bird must react to a plausible event, not a secret proximity tag. Decoys cannot carry a hidden `is_fake` or owner field into the opponent's brain. Full cue rules and information safeguards are in [field systems](design-research/field-systems.md).

## Engagement, learning and reasons to return

**Before the first real duel:** teach one complete encounter in a small practice space. The stalker tries a quiet crossing and rear approach; the sniper learns the difference between a hint and a confirmed target, then shoots and relocates. Teach the actual combat rule and reload behavior. A novice should understand the goal and one useful counterplay before facing a friend.

**During a round:** show own health, ammunition, stance, interaction and emitted noise clearly. A noise indicator must derive from the player's action and surface, not the hidden enemy's distance. Do not give a live “enemy has not seen you” guarantee. Accessible captions can reproduce audible cue categories and coarse direction without granting extra detection.

**After a round:** offer an optional short review using the existing dual-POV replay. Show the last relevant clue, old firing position, crossing and attack. Allow the players to compare what they believed with what happened after the round closes. The default response should be a quick rematch, not a long score-screen ritual.

**Across sessions:** reward better judgment, map knowledge and adapting to a friend. A field journal, personal challenges and noncompetitive cosmetic expression can support that. Essential equipment and winning information stay available from the start. Cosmetic changes must not improve camouflage or alter the competitive silhouette. No equipment-stat grind, paid power or daily obligation is needed for this game.

Ryan, Rigby and Przybylski's work links perceived autonomy, competence and relatedness with enjoyment/future-play measures; its populations and short-term measures do not prove retention for this duel. Kumari, Deterding and Freeman's qualitative work motivates investigating learnable uncertainty. The practical recommendation is to give people understandable choices and satisfying discoveries, then observe whether they want another round. [Motivation study](https://doi.org/10.1007/s11031-006-9051-8), [uncertainty study](https://eprints.whiterose.ac.uk/149801/1/fp1369_kumariA.pdf).

## Expansion catalogue and cut line

| Candidate | Decision it might add | Cost/risk | Decision now |
| --- | --- | --- | --- |
| Pebble distraction | Follow the alarm or watch the crossing? | Small projectile, sound, bird and replay integration. | First new mechanic. |
| Distinct reload/bolt commitment | Fire now or preserve concealment? | Weapon/audio/animation and shared rule testing. | Early prototype. |
| Local surface sound | Fast route or quiet route? | Material tagging, mix and sensory consistency. | Early polish. |
| End-of-round evidence review | Which assumption failed? | Existing replay can be extended. | Early learning feature. |
| Optional relay pressure | Repair, intercept or hunt; sabotage or ambush? | New victory condition and level authoring. | Separate experiment. |
| Shared gusts | Cross now or wait? | Audio rules must match visuals and bot hearing. | Next after cue validation. |
| Mud tracks/broken vegetation | Investigate old evidence or distrust it? | Decay, visibility, memory, network and render budgets. | Later small-area test. |
| Binocular observation | Broad observation or rifle readiness? | Input clarity and an extra tool to teach. | Later, if wide observation is missing. |
| A visible mechanical alarm | Inspect, avoid or deliberately trigger it? | Can leak hidden proximity if designed carelessly. | Later, one type maximum. |
| Decoy reflector | Is the glint a body or a lure? | Readable counter-tell, ownership filtering and art. | Later, after pebble is understood. |
| Rope/climbing shortcut | Take a risky route to a new rear angle? | New movement, collision and navigation layers. | Defer until route demand is established. |
| Snow or quarry variant | Different tracking or movement-sound grammar. | A new tactical layout, not just new textures. | Later map, after one forest works. |
| Larger squads/co-op campaign | Different social and combat game. | Major scope change and lost 1v1 identity. | Outside this direction. |
| Loot extraction, crafting, perk trees | Persistent economy and equipment choices. | Risks replacing the short duel with chores and power progression. | Outside the first product. |
| Full destruction/ballistic simulation | More physical possibilities. | Performance, networking, navigation and readability burden. | No current justification. |

## Production direction

Use the current Godot architecture, free authored assets and existing friend flow. Keep a cohesive grounded forest rather than mixing more asset styles. Prioritize useful hard cover, believable paths, clear silhouettes, stable animation and readable sound before visual density. Retain the existing display/body typography and restrained interface identity.

Future mechanics need canonical world events for replay and networking. Keep administrative ground truth separate from the observations allowed into bots. Add map/ruleset revisions before changing terrain beneath an older recording. Preserve the original recordings and released builds.

Keep the prototype friends-first. Steam invites/lobbies are a later distribution and session layer; they are not a solution to the game's decision loop. Avoid building public matchmaking, ranked play and account progression before friend pairs want repeated matches.

## Next build and decision gates

The exact work order and acceptance criteria are in [design roadmap](design-roadmap.md).

1. Establish shared knife rules, paired-role scoring and better telemetry on one existing map.
2. Test readable cue/counterplay with one pebble and useful shot/reload consequences.
3. Run human pairs, isolate dominant sightlines and misleading feedback, and revise one variable family at a time.
4. Test relay pressure only if the kill-only control still stalls. Keep or reject it from observed play.
5. Add one environmental layer and then one second map when the first loop earns rematches.

Success is not an arbitrary 50:50 bot result. We need people in both roles to find useful choices, understand a loss, carry out a plan and voluntarily want another round. A mechanic that increases interaction count while feeling compulsory has failed this direction.

## Research basis

The linked notes distinguish developer accounts, research findings and our proposals. Primary comparisons include Rebellion's Sniper Elite materials, Bethesda's Deathloop invasion guidance and changes, and Chris Hecker's SpyParty manual. They are different games and production contexts. Detailed mechanics and transfer limits: [comparables](design-research/comparables.md). Motivation, uncertainty, playtesting and evidence limits: [engagement](design-research/engagement.md). Forest and sensory model: [field systems](design-research/field-systems.md).
