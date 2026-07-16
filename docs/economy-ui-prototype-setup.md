# Economy UI prototype Studio setup

The code owns behavior and clones reusable rows. Studio owns the provisional UI instances. Do not rewrite `game.rbxl` from repository tooling.

Everything in this document is a functional prototype. Leave Roblox default colors and fonts in place. Do not add `UICorner`, `UIGradient`, images, icons, shadows, strokes, decorative dividers, or animation objects.

## Assumptions and current scope

- Shop lists the cash-purchasable entries in `Config.Crates`. The server has no direct cosmetic-purchase API, so the prototype does not invent one.
- Inventory lists owned entries from the `GameProfile` Replica and equips or unequips them through `EquipCosmetic`.
- Shop and Inventory are globally reachable through the existing sidebar so their behavior can be tested. There is currently no replicated lobby-membership state or server-side lobby-only economy restriction. Add that policy separately before treating lobby-only access as authoritative.
- Empty thumbnail fields are intentionally ignored during this unstyled pass.

## Coordinate ownership

- `Shop` and `Inventory` are centered relative to their immediate `Views` parent. Ensure `Views` itself fills `BaseClip`: `AnchorPoint = Vector2.new(0, 0)`, `Position = UDim2.fromScale(0, 0)`, and `Size = UDim2.fromScale(1, 1)`.
- All sidebar menus, including Shop and Inventory, clone the existing `ButtonTemplate` through `ButtonElement`. Its existing sizing and interaction behavior remain authoritative; the `UIListLayout` under `Hud > Side` owns final button positions.
- `EconomyItem` fills the width of its `Holder`. The holder's `UIListLayout` owns each row's final position, and row children use the row as their coordinate basis.
- The prototype code reapplies every structural `AnchorPoint`, `Position`, `Size`, and `ZIndex` below when it mounts. Match these values in Studio to prevent a one-frame layout change.

## Reusable templates

Do not create another sidebar template. Shop and Inventory use the existing `ReplicatedStorage > Assets > UI > Templates > ButtonTemplate` used by the other sidebar menus.

Create `ReplicatedStorage > Assets > UI > Templates > EconomyItem` as a `Frame`.

- Keep default colors.
- Set `Visible = false`, `AnchorPoint = Vector2.new(0, 0)`, `Position = UDim2.fromScale(0, 0)`, `Size = UDim2.new(1, 0, 0, 88)`, and `ZIndex = 11`.
- Add these direct children:

| Name | Class | AnchorPoint | Position | Size | ZIndex |
|---|---|---|---|---|---|
| `ItemName` | `TextLabel` | `Vector2.new(0, 0)` | `UDim2.fromScale(0, 0)` | `UDim2.fromScale(0.7, 0.25)` | 12 |
| `Details` | `TextLabel` | `Vector2.new(0, 0)` | `UDim2.fromScale(0, 0.25)` | `UDim2.fromScale(0.7, 0.25)` | 12 |
| `State` | `TextLabel` | `Vector2.new(0, 0)` | `UDim2.fromScale(0, 0.5)` | `UDim2.fromScale(0.7, 0.25)` | 12 |
| `Action` | `TextButton` | `Vector2.new(0, 0)` | `UDim2.fromScale(0.72, 0.2)` | `UDim2.fromScale(0.28, 0.6)` | 12 |

Keep default colors and fonts on every child. Set the three labels to `TextWrapped = true`. Set `Action.TextWrapped = true`. Add a `UITextSizeConstraint` to each text object with `MinTextSize = 10` and `MaxTextSize = 22`; this is for phone readability, not visual styling.

## Shop view

Create `StarterGui > MainGui > BaseClip > Views > Shop` as a `Frame`.

- Set `Visible = false`, `AnchorPoint = Vector2.new(0.5, 0.5)`, `Position = UDim2.fromScale(0.5, 0.5)`, `Size = UDim2.fromScale(0.86, 0.82)`, `ClipsDescendants = true`, and `ZIndex = 10`.
- Keep default colors.
- Add a `UISizeConstraint` with `MinSize = Vector2.new(280, 240)` and `MaxSize = Vector2.new(960, 720)`.
- Add these direct children:

| Name | Class | AnchorPoint | Position | Size | ZIndex |
|---|---|---|---|---|---|
| `Title` | `TextLabel` | `Vector2.new(0, 0)` | `UDim2.fromScale(0, 0)` | `UDim2.fromScale(1, 0.1)` | 11 |
| `Cash` | `TextLabel` | `Vector2.new(0, 0)` | `UDim2.fromScale(0, 0.1)` | `UDim2.fromScale(1, 0.1)` | 11 |
| `Status` | `TextLabel` | `Vector2.new(0, 0)` | `UDim2.fromScale(0, 0.2)` | `UDim2.fromScale(1, 0.1)` | 11 |
| `Holder` | `ScrollingFrame` | `Vector2.new(0, 0)` | `UDim2.fromScale(0, 0.3)` | `UDim2.fromScale(1, 0.7)` | 11 |

Set `Title.Text = "Shop (PROTOTYPE)"`. Set each view label to `TextWrapped = true` and add a `UITextSizeConstraint` with `MinTextSize = 10` and `MaxTextSize = 22`. Set `Holder.AutomaticCanvasSize = Enum.AutomaticSize.Y`, `Holder.CanvasSize = UDim2.fromScale(0, 0)`, and `Holder.ScrollingDirection = Enum.ScrollingDirection.Y`. Add a `UIListLayout` under `Holder` with `SortOrder = Enum.SortOrder.LayoutOrder` and `Padding = UDim.new(0, 8)`. Fixed row heights and offset padding avoid circular scale sizing inside the automatic canvas.

## Inventory view

Create `StarterGui > MainGui > BaseClip > Views > Inventory` as a `Frame`.

- Set `Visible = false`, `AnchorPoint = Vector2.new(0.5, 0.5)`, `Position = UDim2.fromScale(0.5, 0.5)`, `Size = UDim2.fromScale(0.86, 0.82)`, `ClipsDescendants = true`, and `ZIndex = 10`.
- Keep default colors. Add a `UISizeConstraint` with `MinSize = Vector2.new(280, 240)` and `MaxSize = Vector2.new(960, 720)`.
- Add these direct children:

| Name | Class | AnchorPoint | Position | Size | ZIndex |
|---|---|---|---|---|---|
| `Title` | `TextLabel` | `Vector2.new(0, 0)` | `UDim2.fromScale(0, 0)` | `UDim2.fromScale(1, 0.1)` | 11 |
| `Status` | `TextLabel` | `Vector2.new(0, 0)` | `UDim2.fromScale(0, 0.1)` | `UDim2.fromScale(1, 0.1)` | 11 |
| `Holder` | `ScrollingFrame` | `Vector2.new(0, 0)` | `UDim2.fromScale(0, 0.2)` | `UDim2.fromScale(1, 0.8)` | 11 |

Set `Title.Text = "Inventory (PROTOTYPE)"`. Set each view label to `TextWrapped = true` and add the same `UITextSizeConstraint` used by Shop. Configure `Holder` and its `UIListLayout` exactly like Shop.

Do not put a `UIAspectRatioConstraint` on either full view or on text rows: those regions must change proportions between portrait and landscape. A ratio constraint is appropriate when a fixed-shape thumbnail or item-preview region is added later; attach it to that preview region itself, relative to the row or view that owns it.

## Functional verification

1. Test in Studio with both a mouse client and a phone emulator.
2. Confirm the plain Shop and Inventory sidebar buttons open, toggle closed, switch between views, and show `[Selected]` while active.
3. Confirm Shop shows replicated Cash, lists every cash crate, reports insufficient Cash visibly, and shows the rolled item or duplicate refund after a successful open.
4. Confirm a successful crate roll adds a new item to Inventory without rejoining.
5. Confirm every owned item can be equipped and unequipped, and that its row visibly changes between `Owned` and `Equipped`.
6. Confirm long status, category, and item text wraps without overlapping the action button at the smallest supported phone viewport.
7. Confirm no prototype instance contains aesthetic styling objects or non-default colors/fonts.
