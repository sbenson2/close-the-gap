# Close the Gap: engagement and fair competition research

Research date: 2026-11-02. Scope: the existing tight asymmetric 1v1 duel (hidden elevated sniper versus stalking knife/pistol player), alternating roles, seven forest overlooks, 150-second round limit, friend play first. This is design research, not evidence that any proposed change is already fun or balanced.

## Executive direction

The strongest version of *Close the Gap* is a short, legible mind game: the stalker learns the mountain and reads imperfect clues; the sniper chooses when to reveal and whether to hold or relocate after a shot. Engagement should come from improving a personal model of the opponent and map, then expressing that model under pressure. Mastery and friend rematches are the proposed reasons to return.

The current 150-second survival win is a likely engagement risk: it can reward passive defense and make the stalker’s search feel futile. Treat this as a hypothesis to test, not a conclusion from the current bot cohort. The [lead synthesis](../lead-design.md) recommends a paired-role, timeout-draw control first; the released survival rules remain available as a baseline. Stronger late-round evidence and objectives are alternatives to evaluate only if the control still stalls.

## Evidence table

| Finding and provenance | Evidence type and limits | Implication for this game |
| --- | --- | --- |
| Perceived autonomy and competence predicted enjoyment and future-play preference in short lab play; in a survey of 730 MMO players, autonomy, competence and relatedness each independently predicted enjoyment/intended future play. Intuitive controls related to competence and presence. **Ryan, Rigby & Przybylski, 2006, *Motivation and Emotion*.** [DOI](https://doi.org/10.1007/s11031-006-9051-8) | Peer-reviewed empirical work; the authors’ copy was read (abstract, selected methods, discussion). Participants were mostly undergraduates in short lab sessions plus a self-selected MMO sample, with short-term outcomes. | Give both roles meaningful choices with immediate, trustworthy feedback. Stalker route, timing and weapon choice should matter; sniper hide, peek and relocation should matter. Avoid opaque “the game decided” deaths. |
| A qualitative interview study found moment-to-moment gameplay uncertainty linked mainly to curiosity and competence, with uncertainty arising from the game, player, and outcome. **Kumari, Deterding & Freeman, 2019, CHI PLAY ’19.** [DOI](https://doi.org/10.1145/3311350.3347148) | Peer-reviewed grounded theory; only the Crossref/ACM abstract was available and read, so the individual uncertainty categories are not relied on. This is qualitative, not a balance prescription. | Keep uncertainty bounded and learnable: crows, shot direction, foliage movement and glints should narrow a search without becoming exact coordinates. After a round, players should be able to explain what clue changed their belief. |
| A predictive-processing theory proposes that enjoyment can follow reducing uncertainty faster than expected; it explicitly connects this to balanced challenge and learning, but reports no new data. **Deterding et al., 2022, *Frontiers in Psychology*.** [DOI](https://doi.org/10.3389/fpsyg.2022.924953) | Theory paper; useful hypothesis, not causal proof. | Tune for “I learned something” moments: a missed shot teaches a lane, a bird disturbance reveals a likely approach, a successful flank confirms a route. Avoid long periods where neither role gets new information. |
| Interesting decisions involve trade-offs, situation dependence, style expression and persistence; choices that always have one answer or are random are uninteresting. Meier also recommends multiple time scales and fewer choices when choice overload appears. **Meier, 2012, GDC, “Interesting Decisions.”** [GDC Vault](https://gdcvault.com/play/1015756/Interesting) | Practitioner talk from Firaxis, consulted through the game-development skill's registered summary. Its transcript/captions were not read directly in this task. These are contextual design lessons, not controlled research. | Make the existing choices carry readable opportunity costs: quiet crouched movement versus speed/noise; handgun ammunition versus saving the rear-knife attempt; sniper shot now versus safer relocation. Do not add a large gadget/loadout tree. |
| Multiplayer layout needs frequent playtests because unintended sightlines can feel unfair; players need to understand why they died. **Beinke-Schwartz, 2017, GDC Level Design Workshop.** [GDC Vault](https://gdcvault.com/play/1024304/Level-Design-Workshop-Singleplayer-vs) | Practitioner account across multiplayer shooters; URL is the cited session landing page. | Every lethal shot should have a plausible explanation in the replay/feedback: silhouette, glint, sound direction, or a known lane. Audit seven overlooks for spawn-to-shot sightlines, safe approach alternatives, and readable landmarks. |
| Battlefield V AutoPlayers were used for scenarios ranging from 64-player soak tests to specific scripted test cases. **Gillberg, 2019, GDC.** [GDC Vault](https://gdcvault.com/play/1025905/AI-for-Testing-The-Development) | Practitioner talk; the official session overview was checked. The overview does not establish whether the bots played like humans, and is not evidence of human enjoyment. | Keep the current 12/0 sniper bot cohort as functional evidence only. Bots can verify sight rules, route completion, weapon limits, timeout handling and network state; only people can establish tension, fairness, readability and social replay value. |
| Santa Monica’s *God of War* playtesting process used measurable goals, unguided first play, telemetry/video cross-checks and iterative fixes; the talk is explicitly about how testing affected development. **Dearien, Keeker & Shroff, 2019, GDC.** [GDC Vault](https://gdcvault.com/play/1025978/Playtesting-God-of-War) | Practitioner report on one shipped game. The official session overview and skill registry summary were consulted; the full transcript was not read directly in this task. It is not a universal sample-size rule. | Run paired role sessions with no coaching, then ask “what did you believe and why?” Combine round events with video and post-round interviews; do not infer enjoyment from win rate or survival time alone. |
| Automated playtesting research shows synthetic agents can cover varied designer-defined behaviors, but no human players were involved and usefulness depends on the written goals. **Holmgård et al., 2019, IEEE Transactions on Games.** [DOI](https://doi.org/10.1109/TG.2018.2808198) | Peer-reviewed method; its MiniDungeons domain and agent assumptions differ from this game. | Maintain two scorecards: bot functional coverage (deterministic and reproducible) versus human experience (qualitative fairness/tension plus role-level outcomes). Never call the bot win distribution a balance result. |

## Design implications (strongest recommendations)

1. **Make the duel a belief-revision loop.** Each side should repeatedly form a hypothesis, take a bounded risk, receive a readable result, and update. Sound gives approximate evidence; direct sight can identify an actual visible position; memory becomes stale. A post-round timeline can show “heard movement / bird flight / shot direction / confirmed sight” without exposing hidden state during play. This is a design interpretation of the uncertainty research (Kumari; Deterding), not an experimentally established mechanic.

2. **Turn downtime into authored tension, not empty waiting.** The sniper may hold a hide, but the round should periodically create a decision: peek for a shot, move after firing, or accept a riskier lane. The stalker should always have a next useful action: scout a landmark, choose between two cover routes, pause to listen, or commit to a rear approach. If a player cannot name a useful next hypothesis for ~10–15 seconds, test shorter clues, stronger late-round search pressure, or a clearly signaled final phase before adding content. This timing is a design test threshold, not a sourced universal.

3. **Teach both roles through a low-stakes, information-rich first round.** Onboarding should demonstrate one complete clue chain (noise → bird/approximate direction → investigation → sight/shot) and one clear counterplay (relocate after firing; break line of sight). Use a short practice with fixed, visible examples, then the real alternating match. Avoid hidden bot advantages, exact target arrows, or a tutorial that teaches behavior humans cannot reproduce.

4. **Balance around agency and explanation, not symmetry.** Asymmetric roles need not have equal verbs or identical win rates, but each death must be attributable to a decision and understandable evidence. Keep the handgun as a pressure/confirmation tool rather than a second primary game; keep knife rear-only for the intended ambush. First test the existing economy (six-round magazine, 12 reserve, reload) against human decisions before adding equipment.

5. **Build replay value from mastery and social rematches.** Alternate roles every round, preserve the same compact map pool, and let players discover route, timing and opponent tendencies. Use optional post-round review (shot lane, approximate clue chain, time spent exposed) as learning feedback, not a progression grind. Cosmetics or unlocks should not alter detection, damage, ammunition, or access to winning information; a friend duel’s healthy loop is “rematch because we learned something,” not “rematch to earn power.”

### Anti-camping experiment: sabotage pressure versus kill-only control

The research considered several pressure mechanisms. The final test order is defined in the [lead brief](../lead-design.md) and [roadmap](../design-roadmap.md):

- **Kill-only control:** two rounds with roles exchanged, 150-second cap, expiry as a draw. Keep the released survival rules available for comparison. Both roles may hold a good position; neither receives a compulsory movement order.
- **Optional sabotage-pressure variant:** only if the control still produces unwanted stalemates. Three physical stations, limited sabotage/repair interactions, two offline stations starting a repair deadline, and an explicit infiltration victory if the deadline expires. Either lethal attack ends the round. This deliberately changes the kill-only contract. The roadmap specifies the complete bounded rules; do not combine it with a separate forced-relocation or timer-bypass rule.

Treat the variant as a hypothesis test. Interactions require real physical access and produce local visible/audible evidence; hidden enemy proximity cannot block them or create a contested indicator. Reject it if players describe the objects as a checklist, if it dilutes the ambush fantasy, or if it creates a dominant opener. A simpler alternative considered was more consequential local wildlife/noise evidence, without another interaction. Neither alternative is required for the first slice.

Diagnose with paired within-match comparisons, not an arbitrary target win rate: time-to-first-useful-clue, time spent in a declared search/hold state, number of meaningful location changes, timeout share, first-shot explanation rate, perceived agency/fairness, “I had a next action” responses, and rematch requests. These metrics can locate camping, confusion, or boredom; only player testimony and observed behavior can support claims about fun.

## Human playtest and telemetry plan

### Bot functional coverage (separate report)

For fixed seed/map/spawn fixtures, record: out-of-bounds and stuck time; illegal sight detections; exact-vs-approximate clue use; reaction-delay violations; route/cover completion; shot, reload and ammunition invariants; knife rear-angle invariant; round transitions; timeout handling; and network authority/prediction disagreements. Use bots to explore many seeds and compare policy changes. Report counts and failing traces, not “fun” or balance.

### Human experience and fair-competition sessions

Run 6–10 pairs initially, each playing at least one round in each role, with no coaching during the first match. Record build, map, seed, role, outcome, round duration, first confirmed sight, first shot, clue events, relocations, exposed crossings, damage source, disconnects, and whether a player requested a rematch. After each round ask:

- What did you think the other player knew, and what changed that belief?
- Which clue or sound was useful, misleading, or impossible to interpret?
- When did you feel you had a plan? When did you feel there was no useful action?
- For each death: what do you think caused it, and what could you do differently?

Review paired video with the event timeline. Primary early signals are explanation quality, role comprehension, perceived agency, tension during search, and willingness to swap roles/rematch. Treat win rate and timeout rate as balance clues only; segment by role, map, experience, and whether the player understood the rules. Compare bot and human traces explicitly; do not pool them.

## Anti-patterns to reject

- **Passive-clock sniper:** a 150-second timeout that is safest when doing nothing, with no escalating searchability or relocation pressure.
- **Bot-as-balance:** interpreting 12–0 or any bot cohort as evidence that a human role is overpowered; scripted agents optimize their controller and can miss human reads.
- **Unexplainable lethal information:** hidden global target coordinates, exact sound pings, rear vision, spawn priors, or shots with no plausible cue.
- **Choice inflation:** adding gadgets, perks, progression, or modes before the two roles’ existing decisions produce distinct, learnable outcomes.
- **Grind or paid power:** retention systems that delay fair rematches or sell competitive information/damage/ammunition advantages.
- **Feedback noise:** decorative effects that obscure the direction, timing, or cause of a shot, bird disturbance, hit, reload, or round transition.
- **Metric theater:** optimizing session length, survival time, or raw win rate while ignoring whether players understood the encounter and wanted a rematch.

## Sources

- Richard M. Ryan, C. Scott Rigby & Andrew Przybylski, “The Motivational Pull of Video Games: A Self-Determination Theory Approach,” *Motivation and Emotion* 30(4), 2006. https://doi.org/10.1007/s11031-006-9051-8
- Shringi Kumari, Sebastian Deterding & Jonathan Freeman, “The Role of Uncertainty in Moment-to-Moment Player Motivation: A Grounded Theory,” CHI PLAY ’19. https://doi.org/10.1145/3311350.3347148 (abstract only)
- Sebastian Deterding et al., “Mastering uncertainty: A predictive processing account of enjoying uncertain success in video game play,” *Frontiers in Psychology* 13, 2022. https://doi.org/10.3389/fpsyg.2022.924953
- Sid Meier, “Interesting Decisions,” GDC 2012. https://gdcvault.com/play/1015756/Interesting
- Elisabeth Beinke-Schwartz, “Level Design Workshop: Singleplayer vs. Multiplayer Level Design: A Paradigm Shift,” GDC 2017. https://gdcvault.com/play/1024304/Level-Design-Workshop-Singleplayer-vs
- Jonas Gillberg, “AI for Testing: The Development of Bots that Play ‘Battlefield V’,” GDC 2019. https://gdcvault.com/play/1025905/AI-for-Testing-The-Development
- Ed Dearien, Kevin Keeker & Jeet Shroff, “Playtesting ‘God of War’,” GDC 2019. https://gdcvault.com/play/1025978/Playtesting-God-of-War
- Christoffer Holmgård et al., “Automated playtesting with procedural personas through MCTS with evolved heuristics,” *IEEE Transactions on Games*, 2019. https://doi.org/10.1109/TG.2018.2808198
