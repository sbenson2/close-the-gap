# Close the Gap: readable forest and sensory systems

Research date: 2 November 2026. These are primary developer accounts, not controlled evidence that a mechanic will improve this game. Proposed adaptations below are our design hypotheses. This note supplements [comparables](comparables.md) and [engagement](engagement.md).

## Evidence

**Crytek, Hunt audio team, 26 September 2018.** The developers organize audio around readability, realism and consistency. They describe distance attenuation and material-dependent occlusion, and use recognizable sounds to communicate source type and state. Their examples include animals, weapons and environmental sound traps. This is a historical production account of Hunt, not a requirement to reproduce its technology. [Developer article](https://www.huntshowdown.com/news/hunt-audio-readability-realism-and-consistency).

**Crytek, Thundershower development account, 15 August 2025.** Rain varies in intensity, changes visibility and masks some movement sounds. The team also discusses retaining important sound readability. The transferable idea is a shared environmental opportunity, rather than a cosmetic weather overlay. Their emitter implementation and production scale are unnecessary here. [Developer article](https://www.huntshowdown.com/news/behind-the-storm-technical-design-of-thundershower-in-hunt-showdown).

**Martin Walsh, Game AI Pro 2, 2015, chapter 28.** The Blacklist perception/awareness chapter describes a richer perception model than a binary vision cone. It is a practitioner account for a different game. Close the Gap should borrow the discipline of explicit perception and awareness states while retaining its stricter prohibition on hidden target knowledge. It should not import contextual assumptions about the opponent's current location. [Author's chapter](https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter28_Modeling_Perception_and_Awareness_in_Tom_Clancy%27s_Splinter_Cell_Blacklist.pdf).

## Proposed field grammar

| Evidence | What a player can reasonably infer | What remains uncertain | Counterplay and implementation constraint |
| --- | --- | --- | --- |
| Distant rifle report | A weapon fired in a broad direction; a previously safe angle may be occupied. | Current nest, whether the shooter has moved, exact range. | Shooter changes position; attacker can investigate the old direction. Terrain/audio occlusion applies to both people and bots. |
| Scope reflection | An optical surface is visible at a place and moment. | Whether it is a real firing position, a decoy, or still occupied. | Stop aiming, change angle, use cover. A bot must physically see the reflection, not read a remote `scoped` flag. |
| Startled crow burst | A disturbance happened near a visible/audible flock. | Its cause and the disturber's current position. | Quiet route, deliberate distraction, or a patient second observation. Avoid automatic bird reactions to a silent player behind solid cover. |
| Pebble impact | Something struck that surface. | Thrower's identity and location. | Watch the likely follow-up route instead of assuming the impact is the target. Bots receive an anonymous coarse sound area. |
| Mud print or broken twig | Something passed this visible location earlier. | Identity, exact age, next route. | Change surface or double back. Tracks decay and have a strict render/network budget. Bots inspect visible evidence rather than query a global track database. |
| Wood/stone/brush footsteps | Movement interacted with a recognizable surface nearby. | Exact position behind cover; whether it continues. | Slow down, change route, use an audible gust. A self-noise display measures emitted sound, never distance to a hidden opponent. |
| A wind gust | A short, shared change in sound and vegetation. | Whether either player exploited it. | Time a crossing or watch it more carefully. Both players and the bot hearing layer use the same masking rules. |

The first prototype should use one distraction and the existing shot/bird cues. Tracks and weather are follow-on systems, not prerequisites.

## Information contract for new mechanics

1. A quiet, occluded opponent cannot change a decision unless they cause an observable world event. Position, orientation, stance and velocity remain private to the engine-side perception calculation.
2. A sound cue may identify a source category and an uncertain area. It must not carry the emitter actor, owner ID, current transform or a reliable real-versus-decoy flag into decision code.
3. A visual cue requires a real view and line of sight. Effects hidden by terrain cannot become HUD pings or bot observations.
4. Fading memory and inference are legitimate. New information is required to update a hidden target; prediction must not silently become live tracking.
5. An interaction meter must not pause because an unseen enemy is within a contest radius. That would reveal presence through UI. Direct damage, a physical collision or an observable interaction may interrupt it.
6. Public match phase and time are distinct from positional intelligence. Proposed objectives should not broadcast which hidden player is at which station. Local lights, machine sounds and direct observation provide that evidence.
7. An omniscient replay is allowed after the round closes. It is a learning tool, separate from live player or AI inputs.

## Readability and access

Keep a small vocabulary of cue shapes and sounds. A bird alarm, ordinary bird call, rifle report and mechanical interaction need distinct identities. Do not continuously fill the mix with equally loud wildlife. Captions can show the category and coarse direction of sounds that the player could actually hear; they must not supply extra range, hidden identity or precise coordinates. Test captions, stereo output and different volume levels with people rather than treating headphone use as a prerequisite.

Use persistent landmarks for navigation and restrained effects for moments of consequence. Foliage should support observation and route choice; more leaves are not automatically more useful cover. This is a project recommendation, not a claim established by the cited accounts.
