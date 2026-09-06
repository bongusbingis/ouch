# Bonks balance and pass implementation

This amendment supplements the production audit without changing its original findings. It covers earning, spending, acquisition, fulfillment, and purchase presentation. Numerical earn scenarios are design estimates, not retention or conversion evidence. All Robux prices come from client MarketplaceService product information; there are no configured Robux prices or fallback amounts.

## Balance changes

| Lever | Before | Implemented | Reason |
|---|---:|---:|---|
| New-profile Bonks | 2,500 | 1,000 | Two immediate crate choices or one guaranteed Common purchase, while leaving goals for play. Existing balances are untouched. |
| Match completion | 50 | 75 | More progress for a player learning the game or playing a supporting role. |
| Win bonus | 150 | 100 | Keeps winning valuable while reducing the earning gap between winners and beginners. |
| Elimination / catch | 10 / 15 | Unchanged | Retains visible rewards for attacking and defensive skill. |
| Dodgeball / Hammer crate | 500 / 500 | Unchanged | Clear, consistent entry cost. |
| Effects crate | 750 | 500 | Same rarity/pity structure and one cosmetic per opening. Its smaller pool does not justify an additional earning barrier. |
| Common guaranteed item | 1,200 | 1,000 | A new player can choose a specific starter cosmetic. |
| Rare guaranteed item | 3,500 | 2,500 | A reachable medium-term target, equal to five ordinary crate openings. |
| Legendary guaranteed item | 12,000 | 7,500 | Maintains an aspirational goal without pushing a specific-item collector toward repeated random purchases. |
| Duplicate refunds | 50 / 150 / 400 | Unchanged | Repeats provide some progress without making repeated purchases self-funding. |
| Featured discount | 15% | Unchanged | Same discount for all users in the same configured cohort; all crate cards must display the server's current price. |
| Batch quantity | 1 / 5 / 10 | Unchanged | Exact price multiples; no concealed bulk discount or better odds. |
| Rotating categories | Empty outfit/emote inventory only | Stocked weapon/effect categories plus future outfits/emotes | Provides guaranteed purchases now, including for players who cannot use paid random items. |

Live-config crate bounds narrow from 500–1,000 to 500–900 because the cheapest guaranteed item now costs 1,000. The existing tests verify the relationship at every allowed price/discount extreme. The price of chasing one specific item remains higher in expectation than buying that same offered item directly. Rotation excludes Exclusives and does not reroll remaining offers after a purchase. A previously stored empty selection may populate once content becomes available.

The starting balance is template data for new profiles only. No balances, owned items, stable cosmetic IDs, existing product grant quantities, or earned season rewards are reduced.

## Earning pace

The model assumes a completed match. Wins are averaged over many matches; fractional results below are expectations, not fractional runtime awards.

| Scenario | Elims | Catches | Win rate | Before Bonks/match | New Bonks/match | Matches per 500-Bonk crate |
|---|---:|---:|---:|---:|---:|---:|
| Beginner FFA | 1 | 0 | 5% | 67.5 | 90 | 5.56 |
| Regular FFA | 5 | 2 | 10% | 145 | 165 | 3.03 |
| Regular TDM | 5 | 2 | 50% | 205 | 205 | 2.44 |
| Strong FFA | 12 | 3 | 30% | 260 | 270 | 1.85 |

At an illustrative four-minute match cycle, a regular FFA player earns a crate in about 12 minutes and a regular TDM player in about 10 minutes, before quests, login rewards, season rewards, or refunds. Actual matches vary: baked FFA and TDM time caps are five and six minutes respectively, plus start/results/vote time. Queue and teleport time add further overhead. Measure real session pace before making another price change.

Bonks Boost gives 1.5 times match Bonks. It does not multiply currency packs, daily rewards, quests, duplicate refunds, or season rewards. Multiplication is applied once when an award is resolved; retries replay the resolved amount. Rounding down means the regular FFA example averages approximately 247 Bonks per match with the pass, not a promise of fractional currency.

## Other currency sources

- Daily login cycle: 1,625 Bonks across seven claims, approximately 232 per day when all are claimed. It does not require winning.
- Daily quests: three selected from ten definitions. The average combined reward is 495 Bonks if all three are completed; actual selection ranges from 350 to 650. This is not guaranteed income for every session.
- Season 1 free track: 3,300 Bonks across completed tiers.
- Season 1 premium track: an additional 10,100 Bonks if fully completed; purchase alone does not instantly award all tiers.
- The season cap remains 20,000 XP. Regular FFA/TDM estimates yield approximately 121/98 completed matches without Double XP. Double XP halves the XP work, subject to per-match performance and rounding.
- Existing currency product quantities remain 500, 1,100, 2,500 and 5,500. Product IDs continue to identify the same grant across delayed receipts. Regional pricing can alter value-per-Robux ordering, so static “best value” claims were removed.
- A paid crate receipt that cannot legally deliver a random reward uses the existing guaranteed Bonks substitution. Policy lookup outages defer the receipt instead of substituting because of a temporary error.

A regular FFA player completing six matches, the average quest set, and the average daily claim earns about 1,717 Bonks before seasonal income. Repeating that pattern for seven days gives roughly 12,000 Bonks: about 24 ordinary crate openings or a Legendary plus a Rare and two Commons. This intentionally makes a complete visual collection a longer-term goal while allowing noticeable weekly progress.

## Crates and duplicate sink

Current pools contain 27 dodgeballs (nine per rarity), 30 hammers (ten per rarity), and 11 Effects Crate rewards (four Common, four Rare, three Legendary). Effects currently means ten hit effects and one knockout sound; the empty Trail slot remains supported for future content and is not advertised as a current reward.

Base rarity weights remain 70/24/6. Rare-or-better is guaranteed by five opens and Legendary by 25. If both thresholds trigger, Legendary takes precedence. A guarantee may still award an owned item; the item list explicitly shows the resulting Bonks refund.

A reproducible 100,000-opening simulation of the actual CrateRolls module, starting with every item owned, produced 63.312% Common, 29.536% Rare, and 7.152% Legendary after pity. This yields an average repeat refund of approximately 104.57 Bonks. A normal opening therefore consumes approximately 395.43 Bonks net for a fully owned collection; a featured 425-Bonk opening consumes approximately 320.43. A new collection refunds less. No individual duplicate refund exceeds the minimum allowed featured crate cost, so there is no currency farming loop.

The simulation is a balance estimate. The UI displays the exact next-open probability model, not these aggregate simulated frequencies.

## Existing passes

| Pass | Identity | Implemented entitlement | Runtime behavior |
|---|---|---|---|
| Splat Starter Kit | 1968922292 | Starlight impact effect | Grant once; restore missing entitlement on join; no repeated Bonks refunds. |
| Double XP | 1952133523 | 2× match XP | Applies to career and original-season match XP through the award owner; no combat advantage. |
| Bonks Boost | 1955640877 | 1.5× match Bonks | Applies once to the resolved match award; unrelated currency sources are unchanged. |
| Effect Collection | Platform ID not supplied | Prismatic, Galaxy, Starlight | Concrete preview configuration; cannot prompt until a real ID is provided and activated. Existing Starlight owners retain it without a duplicate payout. |

GamePassService verifies platform ownership after purchase and on join. Lookup outages retry while the player remains connected. Partial cosmetic grants retry missing items and accept already-owned items as fulfilled. EntitlementService derives the greatest applicable multiplier per type, rather than multiplying overlapping passes. Unknown boost ownership keeps the award pending in PlayerData instead of silently underpaying it.

Earlier commented concepts (Founder's Pack, Hammer Cosmetics, Character Costumes, Elimination Emotes) have no platform IDs and no complete authored grant definitions. They are not existing purchasable products. Dead commented catalog blocks were removed. Their concepts remain outside the active storefront rather than inventing asset IDs or selling empty entitlements. Future activation must name exact authored items and categories; the active-pass validator rejects an empty grant without a real progression benefit.

All three real passes currently report off sale in Marketplace. Existing owners can still reconcile; new purchase availability needs Creator Dashboard configuration. The code does not change sale status, regional settings, or platform prices.

## Storefront behavior

The redesigned crate dialog keeps the current cyan panels, bright rarity colors, chunky controls, and typography. It replaces the cautionary introduction with reward-focused copy, a rarity-grouped item list, repeat outcomes, and the player's next-opening odds and guarantees. Rewards can be selected for the existing item presentation. It keeps single/batch Bonks purchases and single Robux opening.

Robux amounts come from GetProductInfoAsync in the player's client. Missing, loading, failed and off-sale metadata produce no substitute price. The metadata cache is session-local and refreshes on a later shop refresh after five minutes. Roblox's own purchase prompt confirms the charged amount. Static category icons and generic impact/sound badges are existing presentation assets, not exact recordings of each effect.

The existing policy owner supplies the shop's availability projection. Unknown or restricted paid-random eligibility blocks both Bonks and Robux crate entry points; server validation remains authoritative. Guaranteed rotating cosmetics remain useful in these cases.

Mobile acceptance targets landscape. Portrait architecture remains intact at the user's request.

## Release steps and measurement

1. Change or remove the live Crates.EffectsCrate.BonksPrice override, currently 750, when releasing the 500-Bonk balance. Keeping the override intentionally keeps the old price. Label any experimental cohort through Shop.VariantId.
2. Configure the three existing passes for sale with their intended platform prices/descriptions. Test each using Roblox's Dynamic Price Check with at least two price/location settings. No source-code price edits are needed.
3. Create an Effect Collection pass only if that planned offer should launch, then supply its ID and activate the concrete grant definition.
4. Run real receipt retry/duplicate purchase QA, regional/policy account checks, and cross-place rejoin recovery in an isolated staging experience. Studio fixtures do not prove platform billing behavior.
5. Run the full saved-place cloud suites before publishing; current Studio Play runs exclude tests that explicitly require a non-running empty cloud server.
6. Review seven-day and 28-day cohorts: median time to first chosen cosmetic, earn/spend per active hour, wallet distribution, duplicate share, quest completion, repeat purchase failures, pass grant latency, and paid versus unpaid retention. Separate new/existing players and pass ownership.
7. Revisit balance if typical engaged players cannot afford a first meaningful choice within one session, if large unspent balances grow without desired purchases, or if the earn gap by win rate becomes excessive. Change one labeled lever at a time and compare actual player behavior.

Roblox sources: [regional and client-side dynamic pricing](https://create.roblox.com/docs/production/monetization/regional-pricing), [paid random item disclosures and per-user restrictions](https://create.roblox.com/docs/production/monetization/paid-random-items).
