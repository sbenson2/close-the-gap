Current information boundary: decision code has no opponent reference or game roster and starts with zero positional confidence. `bot_senses.gd` releases only verified sight samples and quantised sound areas; observed motion is estimated from sightings. Hidden movement cannot update targeting memory or decision randomness. See [mountainside verification](mountainside-design.md) for the counterfactual tests and current map data.

# Bot duel and high-ground design

The launch view is a recorded five-round forest session; Live bots starts a local bot duel with two first-person cameras in one shared world. It has pause, restart, map selection and a return to the normal multiplayer menu. Neither pane accepts player movement input. Roles swap after each round and matches restart after a win.

The stalker's objective is to stay unseen, reach the sniper from behind and kill with the knife. Its bot stays crouched, scores covered flank paths, adapts to a newly observed rear approach and searches possible hiding places and does not start handgun fights. The handgun remains available to human stalkers. The bot follows a rear approach before closing on a perceived opponent and refuses frontal knife attacks. Being spotted or killed remains possible; the bot has no invisibility or exemption from ordinary hit checks.

The sniper is confined to high ground by the shared character simulation, including host authority and guest prediction. Pine Hollow rises 18 metres from the southern clearing to the northern ridge. Wooded outer approaches, rock screens and a clear rear crossing support the knife flank. East Yard has screened side ramps joining a rear bridge, alongside the existing central ramp. Both roles use the same physical collision as human players.

Each brain owns its own sight, last seen location, observed facing, reaction delay and navigation state. Sight requires a pitch-aware forward cone (narrowed while scoped) and a physical ray to the chest or head, and shrubs can conceal the target. There is no automatic vision behind the head at close range. Visual memory ages independently from approximate footstep, bird and gunshot clues. A recent sound cannot bypass first-sight reaction delay or replace a fresh confirmed visual position. Crouched movement stays silent to movement/bird sensors. Neither brain reads a hidden opponent's true location to aim or navigate. Known map routes and the initial perch are map knowledge.

The spectator shows behavior labels and whether the sniper has spotted the stalker during this round. This information is for the observer, not an extra sensor supplied to the knife bot. Separate render layers hide each camera's own body and the other bot's first-person weapon. Both viewports share one simulation; the root viewport's unused third 3D rendering is disabled while watching.

## Latest AI direction — 2026-11-02

The sniper should hide on the allowed high ground: select concealed firing positions, hold an approach, peek for a shot and relocate under cover. This behavior is implemented with reachable cover/peek pairs, committed watches and bounded plan repair. Static candidates initialize for either practice role; reachable observation cover remains a fallback if no firing hide qualifies. The stalker should adapt its covered approach to observed clues and seek an unseen rear knife finish. See [bot AI research and implementation priorities](bot-ai-research.md) for the original audit and primary sources; [gameplay study](ai-gameplay-study.md) records implementation, experiments and results.

## Research used

- Official Quake III Arena source, `code/game/ai_dmq3.c`, at `dbe4ddb10315479fc00086f08e25d968b4b43c49`: inspected `BotAimAtEnemy` and `BotCheckAttack`, including reaction gates, remembered enemy information and physical shot traces. This informed bounded perception and attack checks, not this game's stealth objective. [id Software source](https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/game/ai_dmq3.c).
- Official Godot demos at `b761b4cd5718a7118f2c95eb55f181d0a5f004f1`, `viewport/dynamic_split_screen` and `viewport/3d_in_2d`: inspected camera/view ownership. The implementation uses Godot 4.7 SubViewport containers and distinct cameras in the shared world. [Official demos](https://github.com/godotengine/godot-demo-projects/tree/b761b4cd5718a7118f2c95eb55f181d0a5f004f1/viewport), [SubViewport documentation](https://docs.godotengine.org/en/4.7/classes/class_subviewport.html).
- The game-development skill's summary of Damian Isla's Halo 2 talk informed separating perceived knowledge from world truth and displaying readable behavior. This is a practitioner's account of that game, not evidence that this prototype is enjoyable. The linked GDC page redirected to maintenance during verification; the talk itself was not watched here.

Complete official source was available, so binary decompilation was unnecessary. No Quake code or assets were copied into this MIT project. The controller, geometry and spectator implementation were written for this game.

## Checks and limits

The focused stealth test places a crouched stalker behind an unaware sniper, verifies that rear proximity does not grant vision, rejects a frontal knife attempt and resolves an actual unseen rear knife elimination. Physics tests traverse the forest slope and yard side approach. Full bot rounds test the actual sensors, movement, attacks, score and role rotation; these are separate from the focused setup.

Map switching exposed old solid cells retained by AStarGrid2D when its dimensions did not change. Both role grids now clear before rebuilding. A regression check compares the forest route before and after visiting the yard.

See [verification.md](verification.md) for the final round sample and test results. Automated bot outcomes do not establish human balance, stealth readability or game feel. Separate-home-network and native Windows playtests remain outstanding.

## Sources

- id Software, official Quake III Arena source release, 2005: [source](https://github.com/id-Software/Quake-III-Arena/blob/dbe4ddb10315479fc00086f08e25d968b4b43c49/code/game/ai_dmq3.c).
- Godot contributors, Godot 4.7 documentation and official demos: [SubViewport](https://docs.godotengine.org/en/4.7/classes/class_subviewport.html), [demos](https://github.com/godotengine/godot-demo-projects/tree/b761b4cd5718a7118f2c95eb55f181d0a5f004f1/viewport).
- Damian Isla, GDC 2005, Managing Complexity in the Halo 2 AI: https://gdcvault.com/play/1020270/Managing-Complexity-in-the-Halo

## Implemented tactical limits

Each risk-aware route traces at most 256 expensive visibility samples. Uncomputed costs are conservative and local to that query; later plans refine the cached field. Static map navigation stays unchanged. On a captured slow forest request, three runs fell from 84.364–96.452 ms to 4.952–6.052 ms, with the same route point count. These are headless CPU measurements, not live FPS.

The sniper scores covered positions and separate useful peeks, holds a watch, checks lanes briefly, and chooses new cover after a shot. The stalker preserves authored approaches as fallbacks, switches to an observed rear once on the ridge/deck, and checks additional concealed observation points after firing perches have been searched. No bot reads its opponent brain's visibility flag or uses a hidden transform for tactical planning.
