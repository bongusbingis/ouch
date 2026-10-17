# Cosmic Arcade — first fitted 3D version

Created for your custom CharacterRig, which uses an R15 skeleton.

## Included files

- `CosmicArcade.blend`: editable Blender scene, outfit, actual source-mesh mannequin, cameras and lights.
- `CosmicArcade_Outfit.fbx`: outfit only, 10 separate meshes, embedded palette texture.
- `CosmicArcade_Outfit.glb`: portable 3D preview/export of the outfit only.
- `CosmicArcade_Palette.png`: the outfit's color texture; included separately as an import fallback.
- `CosmicArcade_Front.png` / `CosmicArcade_Back.png`: renders of the actual generated 3D geometry on an source-mesh mannequin.
- `CosmicArcade_Attach.luau`: optional ModuleScript to position and weld imported pieces to their respective R15 body parts. Includes a CreatePreview function that makes a separate character copy.
- `CosmicArcade_Fit.json`: measured dimensions and per-piece mounting information.

## What is complete

The helmet has an open face; the jacket and backpack move with UpperTorso. Sleeves, forearm cuffs, shin gaiters, and shoes are separate pieces for the corresponding R15 parts. The exported model contains no body meshes, scripts, lights, or cameras. The texture is packed into the Blender file and embedded in the exports.

This is an actual editable 3D prototype, not just the concept image. It simplifies the original concept into rigid costume components. It is not skinned layered clothing and is not prepared for Marketplace submission.

## Fit limits

The original Blender 5.2 file was opened successfully using Steam Blender 5.2.2. All 15 source body meshes match the Roblox character dimensions. The costume has been aligned with these meshes and adjusted for rest-pose surface clearance. The blue mannequin uses the actual source geometry with a simple blue material; the original Substance Painter textures were not needed or modified.

No animation or collision test has been performed in Studio. Shoulder gaps, jacket clearance, boot clearance, and head clearance need checking on a separate character copy. Very deep bends may require geometry adjustments. The mounting adapter is designed for this character's measured size, not arbitrary R15 body scales.

Your original RBXM file and Studio character were not changed. No assets were uploaded or published, and no playtest was started.

## Import and fit in Studio

1. Work in a separate test place or use a duplicate of CharacterRig.
2. Use Studio's 3D Importer with `CosmicArcade_Outfit.fbx`. Keep all ten meshes separate and preserve the `CA_...` names. Keep geometry axes intact; do not recenter/rotate individual pieces. The intended forward direction is Roblox -Z, and up is +Y.
3. Inspect the importer preview before completing import. Importing meshes may upload new assets to Roblox; this has not been done for you.
4. If colors are missing, use the supplied palette texture. Each mesh uses one palette material and one UV layer.
5. Name the imported model `CosmicArcade_Imported`. Create a ModuleScript named `CosmicArcade` containing the supplied adapter.
6. To create a fitting copy using the adapter, call `CreatePreview(characterModel, importedOutfitModel)` from your own setup code. It leaves the original character untouched. Example, after you have created those exact objects:

```lua
local costume = require(game.ServerStorage.CosmicArcade)
local preview = costume.CreatePreview(
    workspace.CharacterRig,
    workspace.CosmicArcade_Imported
)
```

The adapter resets each mesh to its intended dimensions, aligns it to the corresponding body part, and welds it without collision or added mass. It assumes the imported mesh axes are preserved. The preview root is anchored for static fitting. The adapter has been reviewed but has not been run in your game.

7. Inspect front, side, and back. Then, on a disposable test copy, check idle, run, jump, throw/catch, and extreme arm/ankle bends before integrating the outfit into gameplay. Test code and animations only when you choose to do so.

## Editing in Blender

The `COSMIC ARCADE - export pieces` collection contains the ten outfit objects. Each carries an `R15_Target` custom property. `ACTUAL SOURCE BODY - reference only` is for layout reference and should not be exported. Edit the outfit objects, keeping their names and orientation. Recompute the fit data if geometry bounds change.

## Geometry count

43,160 triangles total across 10 pieces. This is a prototype; optimize after fit approval.
