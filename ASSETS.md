# Third-party assets

Everything the game ships that was not authored here. All of it is **CC0**
(public domain dedication) — no attribution is required by any of these
licences, and it is recorded anyway so the provenance of every object in the
game can be traced back to its source without guessing.

The rule this register exists to enforce: **every placeable thing in the game
is either a scanned CC0 mesh listed below, or a model built in this repository
that clears the detail bar.** `tools/asset_audit.py` fails while anything is
neither.

## Sources

| Source | Licence | Used for |
|---|---|---|
| [Poly Haven](https://polyhaven.com) | CC0 1.0 | PBR material sets, HDRI skies, scanned props and furniture |
| [Quaternius](https://quaternius.com) | CC0 1.0 | furniture, interiors, characters |
| [Kenney](https://kenney.nl) | CC0 1.0 | nature, fences, roads, city props, sports |

## Materials

Downloaded by `tools/polyhaven_tex.py`, which multiplies Poly Haven's separate
ambient-occlusion map into the colour map (Roblox `MaterialVariant` has no AO
slot) and resamples every map to 1024 square. Registered by
`tools/material_registry.py` into `src/MaterialService/*.model.json`, where
`StudsPerTile` is derived from the real-world size Poly Haven recorded for the
scan, at 3.7 studs to the metre.

| Variant | Poly Haven slug | Real size | Used for |
|---|---|---|---|
| SchoolCoursedStone | `castle_wall_slates` | 2.5 m | every exterior wall of the school |
| SchoolAshlar | `sandstone_blocks_04` | 3.0 m | quoins, string courses, window surrounds |
| SchoolSlateRoof | `roof_slates_03` | 3.0 m | pitched roofs |
| SchoolCourtPaving | `medieval_blocks_05` | 2.0 m | the Great Court and the paths |
| SchoolTarmac | `asphalt_02` | 3.0 m | parking, roads, the bike track |
| SchoolBrick | `brick_wall_001` | 3.0 m | the brick outbuildings |
| SchoolPlaster | `plastered_wall_02` | 2.23 m | interior walls |
| SchoolStone | `marble_01` | 1.5 m | polished interior floors |
| SchoolWood | `wood_floor` | 1.7 m | timber floors |
| SchoolTile | `floor_tiles_02` | 4.0 m | washrooms, labs |
| SchoolCeiling | `ceiling_interior` | 2.0 m | ceilings |
| SchoolLocker | `blue_metal_plate` | 2.5 m | lockers |
| SchoolShingle | `roof_slates_02` | 3.0 m | outbuilding roofs |
| SchoolLawn | `leafy_grass` | 2.0 m | grass |

## Sky

`kloppenheim_02_puresky` (Poly Haven, CC0), reprojected into six cube faces by
`tools/polyhaven_sky.py --night` and graded back down to night. Poly Haven's
tonemapped JPEG is the HDRI lifted until a human can see what is in it, so the
grade puts a steep curve on luminance to return the sky to the value a night
sky actually has while leaving the moon and the stars alone.

## Models

316 prop kinds, all CC0 meshes, generated into
`src/ServerScriptService/Services/PropService.luau` and
`src/ReplicatedStorage/Config/PropSizes.luau` by `tools/prop_registry.py` — so
no Roblox asset id is ever typed by hand. The registry in that file is the
authoritative kind-to-slug mapping; the notable recent additions are:

| Kind | Slug | Source | Why |
|---|---|---|---|
| StreetLamp | `street_lamp_01` | Poly Haven | replaced 38 lamps that were a cylinder with a cube on top |
| StreetLampShort | `street_lamp_02` | Poly Haven | the shorter path and avenue lamps |
| WallLantern | `Lantern_01` | Poly Haven | entrance-bay and porch lanterns |
| DeskLamp | `industrial_pipe_lamp` | Poly Haven | the last prop kind with no mesh behind it |

## Built here

Objects with no CC0 source are built, and built to the bar: at least six parts,
real shape variety, and materials that are what the thing is actually made of.
The globe in the headmaster's office is the worked example — foot, bead, stem,
cradle, a tilted axis at the 23.4 degrees a globe really sits at, the sphere,
a meridian in two halves and the north pin.
