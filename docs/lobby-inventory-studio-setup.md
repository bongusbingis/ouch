# Lobby inventory Studio setup

Add the following authored instances to both the lobby and arena places before testing weapon cards or starting an arena match.

## Cosmetic carriers

Create `ReplicatedStorage > Assets > Cosmetics > Templates` and add:

- `DodgeballBase` (`MeshPart`)
  - `MeshId`: `rbxassetid://126364964183882`
  - `Size`: `2, 2, 2`
  - `CanCollide`, `CanTouch`, and `CanQuery`: `false`
  - Preserve the default dodgeball's authored sounds, attachments, and effects.
- `HammerBase` (`MeshPart`)
  - `MeshId`: `rbxassetid://95803748037612`
  - `SurfaceAppearance` (`SurfaceAppearance`)
    - `ColorMap`: `rbxassetid://91752383385405`
    - `MetalnessMap`: `rbxassetid://90467888299989`
    - `NormalMap`: `rbxassetid://92363631418304`
    - `RoughnessMap`: `rbxassetid://130600379811137`
  - `CanCollide`, `CanTouch`, and `CanQuery`: `false`
  - Preserve the default hammer's dimensions and `GripAttachment` when present.

Future shape-changing or PBR skins require another `MeshPart` carrier in this folder and another entry in `Cosmetics.VisualTemplates`. Color and `TextureID` skins reuse one of the existing carriers.

## Inventory templates

Under `ScreenGui > BaseClip > Views > Inventory`:

- `Tabs > TabTemplate` must be an `ImageButton` containing a white `UIStroke` named `SelectedStroke` with `Enabled = false`.
- `Main > CategoriesHolder > CategoryContent > ItemCard` must be an `ImageButton` containing:
  - An `ImageLabel` named `Background`.
  - A `TextLabel` named `ItemName`.
  - A `GuiObject` named `Checkmark` with `Visible = false`.
- `Main > CategoriesHolder > Spacer` must be a transparent `GuiObject` template with `Visible = false`.
- `ItemCard` must contain `ViewportFrame` (`ViewportFrame`). Its preview camera and world are created and cleaned up by the client renderer.

Trail cards render their dodgeball in the viewport and simulate unsupported Roblox trail/particle effects with a procedural UI ribbon overlay. The ribbon reads the existing `TrailCosmetics` colors and is created and cleaned up by the client renderer.

Keep `TabTemplate`, `CategoryHeader`, `CategoryContent`, `Spacer`, and `ItemCard` hidden. Their clones are made visible by the inventory controller.
