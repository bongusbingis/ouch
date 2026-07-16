# Economy UI prototype runtime setup

Shop and Inventory are functional, unstyled prototypes created dynamically by `EconomyPrototypeUI`. No `game.rbxl`, `StarterGui`, or Studio asset changes are required for this pass.

The builder runs before `MenuManager.start()` and creates missing instances under the local player's runtime hierarchy:

```text
PlayerGui
├── MainGui
│   └── BaseClip
│       └── Views
│           ├── Shop
│           │   ├── Title
│           │   ├── Cash
│           │   ├── Status
│           │   └── Holder
│           │       └── List
│           └── Inventory
│               ├── Title
│               ├── Status
│               └── Holder
│                   └── List
└── EconomyPrototypeTemplates
    └── EconomyItem
        ├── ItemName
        ├── Details
        ├── State
        └── Action
```

The builder is idempotent: it reuses correctly typed instances and fills in missing prototype descendants. `EconomyPrototypeLayout` reapplies structural `AnchorPoint`, `Position`, `Size`, and `ZIndex` values to the generated views and rows.

All sidebar menus, including Shop and Inventory, continue to clone the existing Studio-authored `ReplicatedStorage > Assets > UI > Templates > ButtonTemplate` through `ButtonElement`. The prototype builder does not replace or restyle sidebar buttons.

## Assumptions and current scope

- `MainGui > BaseClip > Views` and the existing sidebar `ButtonTemplate` remain part of the established Studio UI infrastructure.
- Shop lists cash-purchasable entries in `Config.Crates`; the current server has no direct cosmetic-purchase API.
- Inventory lists owned entries from the `GameProfile` Replica and equips or unequips through `EquipCosmetic`.
- Shop and Inventory remain globally reachable for testing because there is no authoritative replicated lobby-membership restriction.
- No `UIAspectRatioConstraint` is applied to flexible text/list panels. Add one only to a future fixed-shape thumbnail or preview component.

## Functional verification

1. Enter Play mode and inspect `Players > LocalPlayer > PlayerGui`; both generated views and the row template should be present.
2. Test with mouse and phone emulation. Confirm Shop and Inventory sidebar buttons open, toggle closed, and switch views.
3. Confirm Shop displays replicated Cash, lists cash crates, reports errors, and reports successful rolls or duplicate refunds.
4. Confirm successful crate rolls appear in Inventory without rejoining.
5. Confirm owned cosmetics equip and unequip and visibly update their row state.
6. Confirm long text wraps without overlapping the action button at the smallest supported phone viewport.
