# Ouch! workspace guidance

## UI work

- Read `STYLE.md` before changing the game's UI. For Shop, inspection, crate, season, or reward surfaces, also read `SHOP_REDESIGN_PLAN.md`.
- The approved candy Backpack is the visual baseline. Reuse `src/shared/UI/Tokens.luau`, `Motion.luau`, and the shared candy components. Keep palette and geometry decisions in the shared sources.
- Keep decorative rotation separate from unrotated content and scrollers. Preserve readable labels and at least 44 px input targets.
- Rarity uses the existing Common/Rare/Legendary/Exclusive tiers with named ribbons. Ownership, selection, premium access, and price are distinct states.
- Preserve catalog IDs, probabilities, prices, ownership, and purchase/equip/claim behavior unless the task explicitly changes them.
- For visual reference, use the actual Studio galleries in `.review/candy-backpack/` and `.review/candy-shop/`. Read each validation report before assuming a state has been visually checked.
- Update `STYLE.md` when intentionally extending the shared design system so subsequent work has the same reference.
