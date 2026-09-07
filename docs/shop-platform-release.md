# Shop platform release

Read-only Marketplace inspection on 2026-09-06, from arena place `121997450145716` in universe `10464667217`. `GetDeveloperProductsAsync` confirms all eight configured developer products belong to this universe. This is a configuration record, not a source of player prices: the client continues to fetch Marketplace metadata and the native prompt confirms the final charge.

## Existing developer products

| Product | Product ID | Observed Robux | Sale state |
|---|---|---|---|
| Pocket Stash · 500 Bonks | 3709429022 | 49 | On sale |
| Bonks Stack · 1,100 Bonks | 3709429164 | 99 | On sale |
| Bonks Haul · 2,500 Bonks | 3709429259 | 199 | On sale |
| Mega Vault · 5,500 Bonks | 3709429349 | 399 | On sale |
| Dodgeball Crate | 3709429401 | 39 | On sale |
| Hammer Crate | 3709429455 | 39 | On sale |
| Effects Crate | 3709429563 | 39 | On sale |
| Season 1 Premium Pass | 3711055761 | 399 | On sale |

Keep these identities and grants. The observed season price is 399, despite the older GDD's 499 proposal. Do not alter a real product's price from an outdated design table. The Hammer Crate platform description currently says “Open one hammer create”; the intended description is “Open one Hammer Crate.”

## Passes requiring sale configuration

| Config key | Pass ID | Observed platform name | Sale state | Fulfillment |
|---|---|---|---|---|
| Showtime | 1970065084 | new | Off sale | Showtime Twirl, Flex and Bounce victory emotes |
| SplatStarter | 1968922292 | Starter Kit | Off sale | Starlight impact effect |
| DoubleXP | 1952133523 | Double XP | Off sale | 2× match XP |
| BonksBoost | 1955640877 | Bonks Boost | Off sale | 1.5× match Bonks |

All four pass metadata responses identify the experience's group `d$troy` (group target `291738800`). Off-sale responses contain no purchasable price. Existing owners still receive their entitlements; the shop cannot prompt a new buyer while a pass is off sale.

Creator Hub configuration is authorized but awaiting authenticated access. Proposed launch settings: Starlight Effect 49 Robux, Double XP 199, Bonks Boost 249, Showtime 149. The first three follow the existing GDD's pass tier proposals. Showtime's price is a proposal for three cosmetic emotes, not an observed or configured price. Rename platform pass `1968922292` to **Starlight Effect** to match its actual single-effect grant, and `1970065084` to **Showtime**. The implementation reads actual player availability and prices from Marketplace. No sale settings have been changed by this task.

## New, fully specified offers

| Offer | Platform type | Exact contents | Proposed Robux |
|---|---|---|---|
| Foam League Starter Set | Developer product | `FoamLeague` complete outfit, `DodgeBall3` blue ball, `StarPop` elimination effect | 149 |
| Effect Collection | Game pass | `Prismatic`, `Galaxy`, `Starlight` impact effects | 149 |

Suggested descriptions match the game's concrete grant definitions:

- **Foam League Starter Set:** “The complete Foam League outfit, a blue dodgeball and the Star Pop elimination effect.”
- **Effect Collection:** “Prismatic, Galaxy and Starlight impact effects. All three, yours to equip.”
- **Showtime:** “Celebrate your way with three exclusive victory emotes. Play them on your result card and every podium you earn.”
- **Starlight Effect:** “Starlight impact effect. Make every hit sparkle.”
- **Double XP:** “Earn 2x XP from every match, forever.”
- **Bonks Boost:** “Earn 1.5x Bonks from every match, forever.”

The starter product grants atomically owned outfit components through the complete-look definition; it does not add a second outfit-owned flag. Existing bundle items use the disclosed rarity-based duplicate refund. Pass reconciliation restores missing entitlements without paying duplicate refunds. Effect Collection deliberately overlaps Starlight; the details panel discloses all contents and existing ownership.

These two offers currently have no platform ID and are `Hidden` for the base release. Their configured grants and identities remain intact. Activation requires creating them in this universe, recording the returned IDs in `Products`/`GamePasses`, and setting the corresponding product and bundle status to `Active`. Do this only after the authored assets and fulfillment checks pass. IDs must come from Roblox, never placeholders.

## QA and publication gates

- The user owns the final launch prices and platform sale settings. Player prices remain regional and Marketplace-owned; these proposals must never become a code fallback.
- Preserve the running game's existing currency product prices and season product identity. The user confirmed Effects Crate should follow the same balance as the other crates: remove the live `Crates.EffectsCrate.BonksPrice = 750` override in Creator Hub. All three baked prices are 500, with the same featured-discount rule. The override has not been removed by this task; do not add a code exception that bypasses live configuration.
- Save the reviewed Studio assets and validate both complete places before publication. Authoring recipes alone do not persist CSG geometry.
- Set arena place capacity to 20. The current arena Edit model has 20 general and 10 spawn markers per team, validated for supporting ground and headroom; source admission and matchmaking also cap at 20. Both places use `LandscapeSensor` orientation.
- Schedule the next season before Season 1 ends on October 13, 2026. S1 is active at this check; no successor is configured. Preserve the S1 definition, product identity, and archived progress when adding it.
- Use designated QA accounts for real purchases. No real Robux purchase has been made during this implementation. Fixture receipt tests prove grant/retry behavior, not platform billing, regional-account pricing, or cross-server recovery.
- Validate purchase → owned inventory → equip → match → results → return/rejoin in both places, including a different observer client. Run both saved-place cloud suites before production publication.
