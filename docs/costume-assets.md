# Costume asset authoring

The six complete looks use separately authored `Head`, `Body`, and `Feet` component Models under `ReplicatedStorage.Assets.Cosmetics.Costumes`. Keep the same hierarchy in lobby and arena.

| Outfit prefix | Head | Body | Feet | Render parts |
|---|---|---|---|---|
| FoamLeague | Open sports helmet, padded ear covers, racing stripe | Cobalt sports suit, padded target badge | Cream trainers, cobalt soles | 14 |
| RainHopper | Open frog hood, raised eye details | Yellow rainwear, cream snaps, green pockets | Yellow boots, green soles | 20 |
| SnackStack | Bun hat, filling band, three sesame details | Coral diner wear, cream apron and pocket | Bun-colored shoes, cocoa soles | 16 |
| OrbitRookie | Open flight helmet, dark collar, communications pads | Navy flight suit, control panel, shoulder pads | Cream boots, navy soles | 17 |
| SundaeSprinter | Continuous cream swirl and cherry | Strawberry suit, sundae badge and wafer detail | Cream trainers, strawberry soles | 13 |
| PartyRoyal | Rounded inflatable crown and jewel | Plum ceremonial suit, cream collar, gold sash | Plum shoes, gold soles | 13 |

For example, the first outfit resolves `FoamLeagueHead`, `FoamLeagueBody`, and `FoamLeagueFeet`. Component IDs are stable catalog identities. Do not rename them to change display text.

## Mounts and geometry

Every render BasePart has a `BodyPart` string attribute naming an existing R15 part, a `BodySize` Vector3 recording that authoring target’s exact size, and a direct `BodyMount` Attachment. In the authoring pose:

```luau
BodyMount.CFrame = renderPart.CFrame:ToObjectSpace(targetBodyPart.CFrame)
```

At runtime:

```luau
renderPart.CFrame = targetBodyPart.CFrame * BodyMount.CFrame:Inverse()
```

Render parts are massless and noncollidable, with touch/query disabled. The source components are anchored; the shared appearance factory owns live attachment behavior. They add no Humanoids, body joints, collision geometry, or gameplay scripts.

The torso and footwear use exact-size clones of the matching blob meshes with `CoversBody=true`. Each outfit covers UpperTorso, LowerTorso, both UpperLegs, both LowerLegs, and both Feet. All three leg segments contribute to the short blob foot silhouette. The shared appearance factory hides those original visual surfaces while the garment is mounted and restores their original transparency on removal; it never changes physics or body colors. Enlarged torso overlays and a waist gusset were rejected after close pose review because they produced a bulge. The original face, arms, and hands remain exposed.

The loaded player is uniformly 1.0177694559 times the authoring template. Runtime garment size and mount offsets derive from the target body Size divided by `BodySize`; the source rig and gameplay scale are unchanged. Rounded detail parts carry authored `SpecialMesh` Sphere children at unit scale so all three parent Size axes control their proportions. Native nonuniform Ball Parts were rejected because they rendered incorrect detail and shoe proportions.

Helmet shells, crown, and preview backdrop use durable Studio CSG geometry. The vanilla swirl is the published mesh `rbxassetid://73959401212970`, authored at `2.04 × 1.43 × 2.04` studs; it uses the same plain cream material as the capsule. Its generated texture is intentionally unused. The remaining MeshParts clone the existing authored R15 meshes. Gameplay does not create EditableMeshes or run the authoring recipes.

The Studio-only reconstruction module is [author-costume-capsule.luau](../src/scripts/studio/author-costume-capsule.luau). Its `outfits(ids)` and `previewScene()` methods run against the open place's authored rig. Execute it only in Studio Edit context, as a temporary ModuleScript or through the Studio authoring tools; it is not mapped into gameplay. Existing generated models carry `AuthoringVersion`; reconstruction refuses to replace a same-named model without that marker.

## Effect preview stage

`ReplicatedStorage.Assets.Cosmetics.PreviewScene` is a Model with these direct BasePart children:

| Child | Contract |
|---|---|
| Origin | Invisible, at local origin; Model PrimaryPart |
| ImpactMarker | Invisible, at `(0, 3, 0)` |
| CameraMarker | Invisible, at `(0, 12, -34)`, aimed at ImpactMarker |
| Ground | Round plum floor, 84-stud diameter |
| Backdrop | Curved dark backdrop, sized to fill the camera view |
| ImpactPlatform | Restrained raised disc at the center |
| PlatformRim | Pink accent around the center disc |

`CameraFieldOfView` is 55. All stage parts are anchored, with collision/touch/query disabled. Markers are the runtime contract; the larger inert floor and backdrop prevent the surrounding sky from leaking around the scene at wide aspect ratios. The runtime relocates its local clone through Origin.

## Verification and persistence

The close fit review uses the exact authored blob mesh dimensions, one outfit per native Studio screenshot, and front/side/back views. A 15-joint pose combines 35 degrees of waist bend, raised shoulders, flexed elbows, 80 degrees of knee bend, and ankle rotation. Fitted source surfaces preserve the original mesh joint boundaries under those movements. The stage was reviewed through its actual camera framing.

These inspections do not replace live animation, ragdoll, respawn, six-color, team-readability, remote-observer, mobile, or multiplayer checks. The ordinary source test suite cannot prove imported mesh permissions in a published server. Verify that the swirl loads in both places' published QA versions.

CSG is persisted with the Studio-authored place, not by the reconstruction module. Save/publish the reviewed Studio content through Studio and import only through the repository's existing place-pull workflow. Do not edit place binaries with repository tooling. `AssetService:CreateAssetAsync` returned “CreateAssetAsync and CreateAssetVersionAsync are not available yet” in the connected Studio context; this is why the capsule uses saved Studio CSG and the mesh generation tool's durable published output.
