# Economy release specification — R11

9 September 2026. **Source-derived baseline, with a separate observed Studio price sensitivity; not measured player behavior or release acceptance.** R11 changes no runtime prices, product/pass IDs, rewards, pools or season definitions. Source before/after commercial values are identical. This analysis does not justify arbitrary repricing or a retention claim.

Reproduce from the workspace with `lune run src/scripts/lune/probe-economy-release.luau`. The [probe](../src/scripts/lune/probe-economy-release.luau) writes [complete tables](../.review/production/2026-09-09-batch1/r11/tables.md) and [machine-readable results, assumptions and SHA-256 source hashes](../.review/production/2026-09-09-batch1/r11/economy.json). It loads actual config and pure modules through the existing Lune loader. Evidence revision is `8cdd931bd36a8994b84db257ad7593b666c9510e` plus the individually hashed working-tree sources; other production work is concurrent. The probe uses no players, platform calls, purchases, persisted profiles or device measurements.

**Observed effective-state caveat:** the lead agent (`/root`) inspected the lobby Studio Play client and recorded [ConfigState](../.review/production/2026-09-09-batch1/config-live-lobby.json): Effects base **750**, Dodgeballs/Hammers **500**, featured discount **15%**. The lead also observed Effects featured UI **637 WAS 750**, consistent with floor rounding. This differs from the source Effects price of 500, so the baseline tables below do **not** describe the effective current Studio Effects economy. The snapshot identifies place `130584867985467`, observation timestamp `1788946741` and engine-reported Play `placeVersion = 0`; it is not proof of a published place version or published commercial settings. The R11 delegate did not perform that Studio inspection. The separate sensitivity below assumes the source pools, pity, refunds and earning rules still apply; reconcile intended effective settings with the owner before release. No setting was changed.

## Pacing and first rewards

[Progression config](../src/config/Progression/Data.luau) starts profiles at 1,000 Bonks. Qualifying completed matches pay 75 Bonks/25 XP, wins add 100/100, qualifying eliminations 10/20, catches 15/15. [Participation](../src/shared/Game/Economy/Participation.luau) requires 15 active seconds, an elimination or three catches for completion/win eligibility; actions cap at eight per opponent, 40 eliminations and 24 catches per match. [ProgressionService](../places/arena/server/Modules/ProgressionService.luau) excludes NoContest completion rewards. Scenarios below assume eligible ordinary completions and qualifying actions below caps; ties, departures, failed grants and NoContest are excluded.

[Existing passes](../src/config/Economy/GamePasses.luau) give 1.5× match Bonks and 2× match XP. The probe calls [Boosts](../src/shared/Game/Economy/Boosts.luau) on each possible win/loss award before averaging, preserving integer rounding. Daily, quest and season currency receive no assumed multiplier here.

Every row below is a hypothetical input cohort, **not telemetry, a forecast or an assertion that these win/action rates occur together**. Effective minutes per match = round + result/loading overhead + `(1 − same-arena replay fraction) × global queue/transport time`. All four input terms, actions and win distributions need measurement. Replay overhead is folded into the stated results term. These are per-player examples; they are not a population-wide win distribution.

| Cohort | Round / queue / results min | Same-arena replay | Elims / catches | Win probability | Bonks/h | XP/h | Bonks/h with boost |
| --- | --- | ---: | --- | ---: | ---: | ---: | ---: |
| New | 6 / 1.5 / 0.5 | 0% | 0 / 0 | 5% | 600 | 225 | 896 |
| Casual | 5 / 1 / 0.5 | 25% | 2 / 1 | 20% | 1,248 | 960 | 1,872 |
| Skilled | 4 / 1 / 0.5 | 75% | 6 / 3 | 40% | 2,779 | 2,905 | 4,168 |
| Completionist | 4 / 1 / 0.5 | 90% | 4 / 2 | 25% | 2,217 | 2,087 | 3,320 |

In the source-price baseline, the initial wallet immediately funds two 500-Bonks crates, or one 1,000-Bonks Common direct item if offered. It funds only **one Effects open at either observed Studio price, 750 or 637**. An empty crate inventory guarantees that the first roll is new; desirability and equip/claim comprehension are unmeasured. After spending the initial wallet, one 500-Bonks crate takes 50.0 / 24.0 / 10.8 / 13.5 match-only earning minutes for the four unboosted scenarios; multiply those times by 1.5 for the observed Effects base price. A desired Rare (2,500) costs another 150.0 / 72.1 / 32.4 / 40.6 minutes from the untouched initial wallet; Legendary (10,000) takes 900.0 / 432.7 / 194.3 / 243.5 minutes. These are currency affordability calculations from mean income, not stochastic acquisition-time guarantees.

[Shop rotation](../src/shared/Game/Economy/ShopRotation.luau) currently has 72 eligible items and draws up to three unowned offers per 24-hour period. Desired-item wait is additional and unmodeled; affordability does not guarantee availability. Defaults, AlwaysAvailable colors, hidden costume components and Exclusive items are excluded by the actual eligibility rule. Full outfits use atomic component ownership through [CosmeticsLogic](../src/shared/Game/Economy/CosmeticsLogic.luau).

[Daily rewards](../src/config/DailyRewards.luau) total 1,625 per seven successful claims: 100/125/150/200/250/300/500. [DailyRewardLogic](../src/shared/Game/DailyReward/DailyRewardLogic.luau) allows one claim per UTC date and advances the cycle without resetting it after missed days. 232.14 Bonks per claim is the long-run cycle average, not a guaranteed daily grant to inactive players. [Quests](../src/config/Progression/Quests.luau) select three; all three configured rewards sum to 350–650 depending on selection, and completion/claim rates are unknown. The ten definitions average 165 each; 495 assumes uniform selection and full completion and is not a measured award rate. For a session of `h` hours, add only its actual claimed daily/quest/season currency divided by `h` to the match-only Bonks/h; do not count a grant repeatedly across sessions.

## Crates, targets and collection exhaustion

[Source crate config](../src/config/Economy/Crates.luau) sets 500 each, with 1/5/10 opens and no batch discount. [Source featured rotation](../src/config/Economy/Shop.luau) alternates Dodgeballs and Effects; its baseline price is 425 while featured. **Hammer is absent from that source rotation.** Pools are derived from category membership excluding Exclusive rarity; no pool or cosmetic was added in R11. Observed Studio Effects prices differ as documented above.

[CrateOdds](../src/shared/Game/Economy/CrateOdds.luau) and [CrateRolls](../src/shared/Game/Economy/CrateRolls.luau) provide every modeled probability and pity transition. A Rare counter of four forces Rare next; a Legendary counter of 24 forces Legendary, taking precedence if both are due. Legendary also resets the Rare counter. Thus the guarantee is **Rare or better within five opens**, and **Legendary within 25**, independently per crate. A forced Rare roll has no Legendary chance on that roll. Neither rule guarantees a particular item, and ownership does not improve its odds.

There are 115 reachable counter states per current crate. Exact probability propagation, to residual target-survival probability below `1e-12`, gives the following cold-pity results for one specified unowned item. Each item within its rarity is equiprobable. Net costs include actual duplicate refunds while acquiring other items from an initially empty pool; opens stop immediately on the target, so these costs assume single opens and exclude batch overshoot. Full upfront funds remain necessary for any selected batch.

| Crate | Common / Rare / Legendary items | Target Common: mean opens | Target Rare: mean opens | Target Legendary: mean opens / p90 | Legendary mean net Bonks, base |
| --- | --- | ---: | ---: | --- | ---: |
| Dodgeballs | 9 / 9 / 9 | 13.77 | 29.95 | 123.27 / 278 | 52,188 |
| Effects | 4 / 4 / 3 | 5.94 | 13.18 | 41.09 / 89 | 17,678 |
| Hammers | 10 / 10 / 10 | 15.34 | 33.32 | 136.96 / 310 | 57,962 |

The full tables include medians/p95, Rare-due `(4,4)` and Legendary-due `(0,24)` starting states, featured costs and the all-but-target-owned case. For example, Dodgeball Legendary mean opens decrease from 123.27 to 110.57 when Legendary is due; pity still chooses among nine Legendary items. For a named target, current direct prices are substantially below these mean random-acquisition costs, subject to actual offer availability. This is a useful purchasing distinction to communicate; it is not evidence that either price is optimal.

For fully owned inventories, cold first-roll refunds are 95 (405 net base, 330 featured). Stateful long-run rarity frequencies are **63.06197% Common, 29.63674% Rare, 7.30129% Legendary**. The corresponding mean refund is **105.19124**, leaving **394.80876 net base** or **319.80876 featured** per open. At 100 opens from empty ownership, mean net base costs/open are 433.24 Dodgeballs, 414.86 Effects and 435.65 Hammers. Mean distinct items at 100 are 22.69/27, 10.78/11 and 24.67/30, respectively. Fully owned inventories have zero novelty and remain a positive currency sink.

Expected duplicate refunds at a fixed horizon use linearity: rarity drop counts minus expected newly acquired items, multiplied by each rarity's refund. Expected net cost until a target uses absorbing-state rarity counts minus first-acquisition refunds, with competing target/item hazards for other rarities. This retains the correlation between pity and target survival. It does not substitute stationary odds into a geometric model. The cached transition simulator independently checks nine target means and net costs within five sample standard errors.

Collection exhaustion is separately labeled **Monte Carlo**: 5,000 runs/crate, seed 20260909, source-derived state transitions, initially empty ownership, fixed pool, no external grants. Mean full-pool opens (standard error) are 348.16 (1.98) Dodgeballs, 76.67 (0.57) Effects and 403.17 (2.29) Hammers; p90 is 532/127/611. These are simulated quantities, not observed frustration or engagement. Season/direct/pass grants change starting ownership, increase duplicates and reduce remaining collection work; they do not change target roll probability. The modeled pools contain no composed outfits or defaults, and the probe fails explicitly if that assumption changes.

## Observed Studio Effects price sensitivity

The lead's snapshot also reports daily shop rotation 86,400 seconds, featured/bundle rotation 604,800 seconds, three offers and empty VariantId. These match the source inputs used here. The model records the complete reported observation separately from its source baseline; the observation does not verify effective pools, payout rules, fulfillment or published state.

Hold all non-price rules constant. Expected net target cost at price `p` is `source net cost + (p − 500) × expected opens`. The price change leaves acquisition probabilities and number of opens unchanged. Net costs below start with empty ownership and cold pity, and stop at the named target without batch overshoot. The full JSON also recalculates all-but-target-owned costs.

| Effects metric, Bonks | Source base 500 | Source featured 425 | Observed base 750 | Observed featured 637 |
| --- | ---: | ---: | ---: | ---: |
| Common target mean net | 2,812.75 | 2,367.22 | 4,297.83 | 3,626.57 |
| Rare target mean net | 6,021.90 | 5,033.76 | 9,315.68 | 7,826.89 |
| Legendary target mean net | 17,678.26 | 14,596.61 | 27,950.42 | 23,307.40 |
| Fully owned cold first-roll net | 405.00 | 330.00 | 655.00 | 542.00 |
| Fully owned stateful long-run net/open | 394.81 | 319.81 | 644.81 | 531.81 |

Featured 637 follows `floor(750 × 0.85)`, so the difference from source featured 425 is 212 per open. These are recomputable consequences of the reported prices, not a recommendation to adopt either configuration. Review the existing effective setting and its intended owner-approved price; do not silently overwrite it from the source baseline.

## Season timing and continuity

**Source-confirmed date discrepancy:** [S1 config](../src/config/Progression/Seasons.luau) sets `StartsAt = 1788307200`, which is **2 September 2026 00:00 UTC**, despite its September 1 comment and the earlier production baseline. The actual 42-day window ends **14 October 2026 00:00 UTC**. These values and the `S1`/`SeasonPassS1` identities remain unchanged. Product copy and the intended calendar need reconciliation before advertising the window; R11 does not move an already-defined season.

Tier thresholds are `600n + 8n²`; tier 25 requires 20,000 XP. Currency totals 3,300 free plus 10,100 premium, with five free and eleven premium cosmetic grant entries. First free currency is tier 2 at 1,232 XP; first free cosmetic is tier 4 at 2,528 XP. In the Casual scenario these take 1.28 and 2.63 match hours; Double XP halves both. Premium entitlement itself supplies no XP multiplier.

| Unboosted cohort | Hours to tier 25 | Minutes/day, join Sept 12 UTC | Minutes/day, join Sept 26 UTC |
| --- | ---: | ---: | ---: |
| New | 88.89 | 166.7 | 296.3 |
| Casual | 20.83 | 39.1 | 69.4 |
| Skilled | 6.88 | 12.9 | 22.9 |
| Completionist | 9.58 | 18.0 | 31.9 |

September 12 at 00:00 UTC leaves 32 days; the actual launch hour is unconfirmed. Double XP halves the time requirement. No XP is assumed from daily/quest/season Bonks. The config comment's approximately 1,650 XP/h and 12-hour completion are design assumptions; this sensitivity demonstrates why they cannot stand in for observed player pacing. A later join can be unable to finish under a particular play budget; no completion promise follows from the model.

## Verification and remaining acceptance

The headless probe passes 20 checks: source transition/refund agreement, nine statistical cross-checks, daily same-day/midnight/missed-day behavior, season start-inclusive/end-exclusive selection, full-tier free/premium claim enumeration, and discount rounding agreement with the lead's observed Effects featured price. Checks use the actual pure functions; this is narrower than service/persistence verification. Formatting and scoped lint pass. [Validation log](../.review/production/2026-09-09-batch1/r11/validation.txt) records the final run.

Still required under R11: actual claim/equip/persistence behavior; completed-unclaimed quests at UTC rollover; season rollover with unclaimed free/premium and cosmetic rewards; offline historical-season entitlements; receipts arriving on either side of season end; published purchase benefit verification; actual queue/round/action/win/replay/claim/ownership measurements. Retain archived season definitions and existing product identities as required by the current source contract. No S2 is configured; the pure selector returns no active season at S1 end. Other transaction-package evidence may cover specific service cases, but this model does not claim them passed.

Decision: **preserve current values while measuring the missing inputs**; correct the calendar description against the intended commercial window through the release owner, and ensure the store distinguishes random collection progress from a chosen direct item. Desired-item wait, duplicate-heavy late collections and low-action season pacing are concrete measurement priorities. Existing catalogue visual/functionality and boundary acceptance remain separate release work; R11 analysis alone does not establish launch readiness.
