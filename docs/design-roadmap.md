# Close the Gap: prototype roadmap

Companion to the [lead design direction](lead-design.md). These are scoped prototype briefs, not promises that the features already exist. Effort labels are relative: S uses an established system; M crosses several systems; L adds a substantial content or technical burden. No calendar estimate is implied.

Implementation status: the [demo update](demo-update.md) implements the paired rules plus optional relay pressure, weather, tracks, reflector, tripwire, observation, western handline, ready room, full matches, local journal and saved human recordings. The owner explicitly authorized these prototypes on 2 November 2026. Human playtesting and additional biome/content work remain future decisions; bot outcomes do not establish enjoyment.

## Priority order

| Priority | Prototype | Purpose | Effort | Main dependencies |
| --- | --- | --- | --- | --- |
| P0 | Shared knife contract and paired-role sets | Make the rules match the intended ambush and compare equal role opportunities. | S–M | Match rules, combat resolution, feedback, replay ruleset ID. |
| P0 | Human observation/debrief instrumentation | Learn why choices fail instead of optimizing one bot matchup. | S–M | Existing replay, trace and friend-session tools. |
| P1 | One pebble distraction | Add an active attention/deception decision with counterplay. | M | World sound/bird events, authoritative projectile, filtered perception, replay events. |
| P1 | Shot/reload commitment and cue clarity | Give firing an understandable cost and a useful response window. | M | Shared weapon state, animation/audio, ammunition UI, bot execution. |
| P1 | One forest sightline pass | Make the seven outlooks trade strengths rather than duplicate the best two. | M | Measured route/visibility audit and human observations. |
| P2 | Optional short round-end evidence review | Make losses teach a counterplay and support rematches. | S–M | Existing recorded dual POVs; no live information leak. |
| P2 | Small practice encounter for each role | Teach one clue/action/counteraction chain and the real combat contract. | M | Stable core rules and cue vocabulary. |
| P3 | Relay-pressure variant | Test whether a contestable task improves stalemates without replacing the ambush. | M | P0–P1 human results and explicitly versioned mode rules. |
| P3 | Surface sound and shared gusts | Add timing and route choices through the environment. | M | A readable base mix; equivalent human/bot audibility. |
| Later | Tracks, reflector, alarm, another biome | Add one new inference at a time. | M–L | Evidence of a missing decision and performance headroom. |

## Slice 1: a fair, understandable paired duel

**Build:** an experimental kill-only ruleset. Keep the initial 150-second cap, expiry as draw, and two-round sets with roles exchanged before a set result. Keep the currently released rules available for comparison. Decide and implement the same rear/front knife contract for all participants. Do not silently restrict only the bot.

**Instrument:** record `build_id`, `ruleset_id`, `map_revision`, seed, actor role, permitted observation events, actions, results, route progress and source hashes. Keep ground-truth capture separate from bot inputs. Record what a player could know at the moment of a decision.

**Verify:** timeout draw and set outcomes; a 1:1 pair remains a draw; a third round cannot secretly grant one person an extra defender turn. Validate rear/front attack rules on the authoritative host and remote client. Preserve old replay behavior through explicit versions. Run the existing hidden-state invariance checks.

**Human gate:** observe a small exploratory set of friend pairs, with each participant playing both roles. Six to ten pairs is a practical recruitment target, not statistical proof. Watch the first pair without coaching. Ask what each person was trying to do, what they believed and why they died. If they cannot explain the goal or basic counterplay, fix comprehension before expanding equipment.

**Decision:** retain or revise the control from actual play. Increased draws or unchanged passive behavior means the timer change did not solve the decision problem. Do not call a near-even win rate proof of enjoyment.

## Slice 2: one complete deception encounter

**Build:** a finite pebble throw with a real trajectory and impact. The landing event can create an audible cue and disturb appropriate nearby wildlife. Bots and people receive the same observable event; the opponent does not receive owner identity, current thrower position or a fake/real label. A visible trajectory may support a legitimate inference.

**Give the defender a response:** maintain the original lane, inspect the disturbance, widen observation, or reposition. No response is mandatory. A deception that simply forces an AI to turn is not a finished mechanic.

**Verify:** occluded silent movement still leaves decisions unchanged; sound behind a wall cannot become visual certainty; a stone cannot carry hidden thrower coordinates through its event payload. Test depleted supply, thrown objects during death/disconnect, reliable impact replication, and replay reconstruction.

**Human gate:** can an attacker formulate and attempt a deception? Can a defender describe a reason to believe or doubt it? Does the cue create an interesting interpretation rather than indistinguishable spam? Keep or reject the mechanic from those observations.

## Slice 3: firing has consequences

**Build:** test a small rifle magazine, committed reload and clear bolt/reload sounds. Prototype values belong in one rules configuration. Tune the aimed handgun alongside it so it remains a loud option with a cost. Keep lethality as the first control rather than adding large health pools.

**Map work:** audit each crossing from every outlook at real eye heights. For each dominant view, identify the decision it removes and change one geometry/cover family at a time. Give Saddle hide a transfer role and East crag a specific lane, rather than allowing both to dominate the whole encounter. Retain physically connected retreats and rear approaches.

**Verify:** every supported transfer with actual movement/collision; no shot through solid cover; no unearned perception through foliage; correct ammunition/reload ownership; stable frame times during actual shooting and bird reactions. Keep bot execution changes distinct from map changes in the analysis.

**Human gate:** after a shot, does the opponent gain usable evidence and a meaningful action? Can the shooter profit from holding a good read as well as from moving? Are unused outlooks tactically different or merely worse? If a position is still dominant, more towers will not solve it.

## Slice 4: optional relay ruleset

Only prototype this if the paired duel still produces unwanted stalls. It changes the original kill-only win condition and must remain labeled as a separate mode during evaluation.

Starting test specification:

- Three fixed stations, each requiring a short interaction to sabotage or restore. Start with four seconds to sabotage and five to repair; values are placeholders.
- Each station may be sabotaged once per round, limiting repeated repair chores. A restored station remains restored.
- Two simultaneously offline stations start a 30-second repair deadline. Restoring enough stations to leave fewer than two offline cancels it.
- At deadline expiry, two or more offline stations give the stalker an infiltration victory. Either lethal attack ends the round immediately.
- The base round cap remains 150 seconds. Without an active repair deadline, expiry is a draw. If a deadline is active, finish that deadline: repair after the base cap ends the round as a draw; otherwise infiltration wins. This caps the round at 180 seconds.
- Station interaction and disruption are represented in the world through visible changes and local sound. Do not broadcast the hidden user's position or an exact station ping to an unaware bot.
- An unseen enemy's proximity cannot pause progress or create a contested icon. Moving, losing legitimate access or taking direct damage may interrupt an interaction. Physical handle use needs a clear animation and authoritative, recoverable state.

The defender can cover a likely station, intercept a route, repair while the attacker is elsewhere, or use the suspected ambush to reverse the hunt. The attacker can commit to sabotage, abort it, or use the repair opportunity for the knife. A hidden nearby opponent does not automatically invalidate an earned objective result.

**Reject if:** people primarily run a checklist; repair feels compulsory rather than tactical; interaction time dominates useful observation; or the variant makes the original rear approach irrelevant. An objective victory is a deliberate mode difference, not something to disguise as a kill.

## Player learning and access

Start with two short practice situations, using real rules and recognizable scenery. Teach a route choice, one physical clue, a committed attack and a recovery. Avoid a long text tutorial or revealing the hidden opponent with arrows.

Use the existing replay for an optional short review after the round closes. Separate observations from ground truth on the timeline. Let players skip immediately to a role-swapped rematch. Do not carry omniscient review information into live spawning or planning.

Test controller/mouse remapping, readable text, subtitle/caption legibility, volume levels, reduced camera motion and the distinction between their own noise and enemy detection. A self-noise indicator cannot use the hidden opponent's true distance. Captions may translate audible category/coarse direction, not add tracking information.

## Measurement sheet

| Question | Evidence | Avoid this shortcut |
| --- | --- | --- |
| Can people form a plan? | Unguided first round, stated intention and observed route/action. | More button presses means more engagement. |
| Is uncertainty productive? | Which clue changed a belief, whether a deception was understood, useful hypotheses after a loss. | Longer searching means more tension. |
| Does each role have agency? | Choices described, viable alternatives tried, reasonable recovery opportunities. | A 50:50 bot win rate proves fairness. |
| Is a death explainable? | Player's account compared with permitted observations and the completed-round replay. | The global trace shows an enemy existed, so the player should have known. |
| Is relocation useful? | Reasons for moving, changed firing coverage, successful holds as well as retreats. | Count movement regardless of why it happened. |
| Is a rematch desirable? | Voluntary rematch/role swap and a stated reason to try a different plan. | Session length alone proves retention. |
| Does it run well? | Representative frame-time distribution on Windows, network loss/latency cases and recorded playback. | Average fps or a smooth offline movie proves every live situation is smooth. |

Use bot cohorts for functional invariants, path coverage, information contracts, resource limits and reproducible regressions. Use humans for readability, anticipation, fairness, social value and enjoyment. Compare skill levels and roles; do not pool unrelated builds or shorten countdowns in a supposedly matched baseline.

## Finish condition for the next playable slice

One forest, one shared weapon/knife contract, equal role opportunities, one complete deception/counterplay, a readable loss, a quick rematch and measured Windows performance. The observation boundary and old recordings remain intact. Human findings determine the next addition; an unvalidated feature backlog is not a shipping requirement.
