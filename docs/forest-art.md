# Pine Hollow environment update

The forest keeps its existing 18-metre slope, ridge, covered flanks and rear approach. The environment now layers curved grass, pinnate ferns, brambles, saplings, fallen leaves, small branches, root flares, moss-toned stones, mushrooms and old stumps over the existing trees and cover. Forest-floor and bark textures supply surface detail. The pine canopy uses open irregular boughs; broadleaf crowns and bushes use individual folded leaves in place of solid spheres.

Grass height and density fall on trails, spawn clearings and the ridge. Small leaf litter and twigs continue through those areas so paths do not become empty strips of flat ground. Larger plants cluster around trunks and in patches. Stumps have matching collision and navigation footprints and are placed outside the established routes. Tiny ground debris is decorative. Existing shrubs retain their concealment volumes and the same rules apply to both bots.

The scene contains 292 trees, 12,686 foliage instances, including 1,897 tall grass tufts, plus 7,200 leaf-litter clusters, 800 branches, 434 loose stones, 296 mushrooms, 206 root flares and four old stumps. Tall grass patches have ground-level concealment volumes; standing heads can remain visible above them. Counts describe the deterministic layout, not unique meshes or a performance guarantee.

## Wildlife and bird clues

Ten original procedural animals—four deer, two foxes and four rabbits—follow ground navigation paths, walk with animated legs, pause to graze and follow the slope. They are decorative, without combat hitboxes. The shared round clock controls patrol positions during active play; pause stops them. They continue moving between rounds.

Fifty-one birds perch in seventeen tree flocks. Nearby uncrouched movement above 3.2 m/s or jumping startles birds within six metres; sprinting above 7 m/s reaches ten metres. Crouched movement is quiet. Gunfire disturbs birds within 20 metres for the handgun or 38 metres for the rifle; knife swings do not. Flocks fly away, return and have a 30-second alarm cooldown. An original spatial synthesized alarm accompanies the burst; audible quality has not been assessed here.

The host decides disturbances and replicates a tree-flock index, a coarse flight direction, the round index and the event time. Guests cannot invoke the authority-only event as the host. Flight directions are quantized so multiple messages do not encode an exact player location. Late events for other rounds are ignored. The sniper bot can turn toward the disturbed trees, but the clue does not set visual detection or authorize firing without line of sight. There is no exact player marker. Either player's noise can disturb birds; the source's own bot does not treat its noise as an enemy clue.

The added detail uses its own fixed random seed. It does not perturb the older tree/cover random stream, and peers construct the same forest. Reusable meshes have individual scale, rotation and color variation. Detail instances are grouped into 24-metre patches. Wind bends plant tips while keeping their bases anchored, with a position-dependent phase shared consistently between both POVs. These choices are implementation decisions, not claims of a measured speed increase.

## Decompilation reference

Studied the published OpenGOAL Jak 1 decompilation at commit `c7db3c9adb1664b9150c7508eac666a5395735b3`:

- `goal_src/jak1/engine/gfx/shrub/shrubbery-h.gc`: the decompiled shrub types distinguish reusable prototypes, transformed instances, instance colors and grouped drawing data. This informed using shared plant meshes with transform/color variation.
- `goal_src/jak1/engine/gfx/background/wind-h.gc`: wind data supplies foliage motion, and a position/time hash chooses wind variation. This informed varying breeze phase across the forest instead of moving every plant in unison.

The inspected source explicitly marks the reconstructed sections as `DECOMP BEGINS`. No Jak executable was run or newly decompiled, and no Jak code, textures, meshes or level data were copied into this project. The published reconstruction was used as a design reference; the Godot implementation and procedural geometry are original.

Sources: [OpenGOAL shrub decompilation](https://github.com/open-goal/jak-project/blob/c7db3c9adb1664b9150c7508eac666a5395735b3/goal_src/jak1/engine/gfx/shrub/shrubbery-h.gc), [OpenGOAL wind decompilation](https://github.com/open-goal/jak-project/blob/c7db3c9adb1664b9150c7508eac666a5395735b3/goal_src/jak1/engine/gfx/background/wind-h.gc).

## Texture provenance

Six unmodified 1K JPG maps are included: diffuse and OpenGL normal maps for Poly Haven's [Forest Leaves 02](https://polyhaven.com/a/forest_leaves_02), [Bark Brown 02](https://polyhaven.com/a/bark_brown_02) and [Rock Boulder Dry](https://polyhaven.com/a/rock_boulder_dry). They are [CC0](https://polyhaven.com/license); a notice is included in `assets/forest/LICENSE.txt` and desktop bundles. Powered by Poly Haven. There is no live asset download or API dependency in the game.

The result is a more natural, detailed prototype environment. It is not a claim of photorealism. Native Windows appearance and frame rate still require a Windows playtest. Current render and gameplay evidence is recorded in verification.md.
