# Extend the Ouch! candy redesign through the Shop and economy UI

## The brief in one paragraph

Carry the approved Backpack design into the Shop and every connected inspection, crate, season, and reward surface. Use the same cream panels, plum outlines, puffy candy controls, playful sticker titles, clear rarity ribbons, and restrained celebration. Give the Shop its own composed storefront: featured offers at the top, different card proportions, and sections arranged beside one another wherever space allows. Rows and columns must respond to available width and actual content. Keep the active season pass in the top featured area. Preserve the existing catalog, prices, ownership, purchase handling, rewards, and navigation behavior.

This is the implementation plan. The approved Backpack in [STYLE.md](STYLE.md) and the [before/after gallery](.review/candy-backpack/index.html) are the visual baseline. This extends that design system; it does not reopen the original style choices.

## 1. What exists today

- The supplied Shop screenshot has a cyan outer panel and blue scroll well, a top passes row, and a composed arrangement of Featured, Crates, For You, and Bonks. The new candy navigation is already present.
- `ShopPage` uses `ShopLayout` to measure cards and pack sections onto twelve tracks. It already supports different card classes, overflow, limited offers, countdowns, and a Bonks scroll shortcut.
- One current limitation is that when any section cannot retain its preferred span, `resolveSpans` makes every section full width. The redesign should support an intermediate two-column composition before falling back to a narrow layout.
- The current `ShopViewModel` already places the active season pass first in the passes collection. Make that priority explicit in the featured layout, so it does not depend on its position within a section that can overflow.
- `ShopDetailsModal` serves Shop items, Backpack inspection, bundles, permanent passes, crate contents, and reward inspection. Season products route into `SeasonPassModal`.
- Crate odds already include item rarity, current and base probabilities, ownership, duplicate refunds, and guarantee information. Reveals support single and multiple results, skipping, inspection, equipping, and opening again.
- Season rewards already distinguish Free and Premium tracks, tier requirements, claimable rewards, and claimed rewards. Shared notifications cover purchase success, errors, pending purchases, and recovery.

The redesign must preserve this useful structure and make these connected screens feel like one product.

## 2. Scope

| Surface | Planned treatment |
| --- | --- |
| Shop page | Candy frame and title, wallet, Get Bonks shortcut, responsive featured area and section composition, loading/error/empty states |
| Shop cards | Distinct featured, pass, cosmetic, crate, and currency compositions using one visual recipe |
| Item inspection | Shared shell, large preview, rarity and ownership, description, contents selection, prices, equip and Backpack actions |
| Crate inspection and odds | Rarity groups, per-item chances, refunds, guarantees, quantity actions, selection and preview |
| Crate opening and results | Candy opening animation, single/batch result layouts, duplicate reporting, skip, inspect, equip, and replay controls |
| Season pass and rewards | Featured entry, progress, Free/Premium tabs, tier rewards, preview, claim and premium actions |
| Connected economy UI | Purchase notifications and confirmations, pending/recovery messages, daily reward modal, daily/season entry cards, wallet and progress controls |
| Full-scene effect/sound preview | Matching title and controls, loading/error states, reliable return to inspection |
| Shop surroundings | Approved pastel backdrop and existing candy navigation; carry the podium/nameplate treatment through where the world character remains visible |

“Other UI” means the shared controls and reward surfaces encountered in this flow. A full redesign of Settings, party management, quests, or the match HUD is outside this pass. Any of those screens affected by a shared component change still receive a regression check.

## 3. Visual rules and tokens

Reuse `src/shared/UI/Tokens.luau` and `Motion.luau`. Extend them only where the Shop needs a new reusable measurement or role.

| Family | Direction |
| --- | --- |
| Background | Sky `#9ED9FF` to lilac `#C9C2FF` to pink `#F9C6EC`; faint original Ouch! swirl and sparse confetti |
| Surfaces | Cream `#FFF9F2`, white `#FFFFFF`, pastel well `#EAF1FF` |
| Outlines and text | Plum Ink `#2E2A4A`, secondary InkSoft `#4A4470` |
| Actions | Pink primary; white secondary; cyan supporting controls; yellow selection and claim-ready accents |
| Premium | Gold/crown sticker for premium access; label it explicitly so it cannot be confused with rarity |
| Shape | Existing 28 px panel radius, 20 px card radius, pill controls, 6/4 px primary outlines, 6 px lip |
| Depth | Fill, top highlight, darker bottom lip, rounded outline; hard shadow on outer panels and floating controls, no drop shadows inside wells |
| Typography | Existing Fredoka One display and Builder Sans ExtraBold labels; 52 title, 30 section, 22 label, 20 body, minimum 18 logical px at the reference scale |
| Wonk | Slightly tilted decorative frames and titles; straight card grids and scrolling containers; sticker badges can tilt farther |

Add named Shop tokens for card size limits, section spans, gaps, featured proportions, modal preview allocation, footer spacing, and odds/reward card minimums. Keep one authoritative value for each setting instead of duplicating the palette or geometry in `UIConfig` and `Tokens`.

Long names wrap and their containers grow. Important labels, prices, odds, and requirements must remain readable rather than shrinking to fit. Larger preferred text sizes must trigger reflow.

### Rarity: preserve the decision already approved

Use the existing tiers and Backpack ribbon treatment throughout:

| Tier | Ribbon color |
| --- | --- |
| Common | Mint `#A1E4D9` |
| Rare | Yellow `#FFD54A` |
| Legendary | Coral `#FF718F` |
| Exclusive | Grape `#A667FF` |

Keep the item's surface pale so the art and interaction states stay clear. Rarity is a named ribbon, with an optional matching accent behind a large preview. Outfit color options remain real swatches. Currency packs and mixed bundles get a product-type badge, not an invented rarity. Selecting a crate outcome must not make that outcome appear guaranteed.

## 4. The Shop's own layout

### 4.1 Header and surroundings

- Cream `PanelFrame` with a pink SHOP title sticker overlapping the top edge.
- Wallet as a readable puffy chip beside a pink GET BONKS control. Preserve its scroll-to-Bonks behavior.
- Keep the title and wallet outside the scrolling content. On narrow screens, allow a second header row instead of compressing the balance.
- Use the approved pastel surroundings when the Shop is active. Keep world decoration subordinate to the wider storefront, and suppress nameplate collisions on portrait screens.

### 4.2 Featured area

Give the active season pass a dedicated position at the beginning of the featured area. It appears exactly once in the storefront, uses the existing product ID and season route, and stays visible as an entry to rewards after premium is owned.

The season card shows the season name, representative existing artwork, tier/progress when available, premium ownership, and a clear VIEW REWARDS action. Purchasing premium remains an explicit action in the season modal.

Place active starter offers, bundles, and featured offers beside it on wide screens. Keep their existing availability and countdowns. Additional featured offers wrap within this area before the general catalog. Without an active season, remove the season offer and let the remaining cards occupy the space. An already-open expired season modal shows its real unavailable/ended state.

### 4.3 Desktop composition

Use twelve tracks with measured spans. An illustrative composition is:

```text
SHOP                                      [BONKS] [GET BONKS]

[ SEASON PASS : 4 tracks ][ FEATURED / BUNDLE : 8 tracks     ]
[ PASSES : 8 tracks                       ][ FOR YOU : 4    ]
[ CRATES : 4 tracks      ][ BONKS : 8 tracks                 ]
```

This describes emphasis and neighboring blocks, not fixed pixel rows. Featured blocks can divide their space between multiple offers; sections can extend over multiple card rows. The packer uses measured heights to fill usable space while preserving section identity and a predictable reading order.

- Featured cards use a wide artwork-and-copy split where it fits.
- Cosmetics and crates use taller cards with generous art.
- Permanent passes use a compact showcase grid.
- Bonks packs use short, wide cards with the amount immediately visible.
- Headers and countdowns belong to their blocks; countdowns wrap below the title if necessary.

### 4.4 Responsive behavior

Calculate layout from the usable scroll width after safe areas, padding, and scrollbar space. Final thresholds come from the minimum readable card sizes and live visual checks.

1. **Wide:** multiple neighboring blocks on the twelve-track composition.
2. **Medium / 4:3:** two lanes where both blocks meet their minimum widths. A block that needs more room spans both lanes without forcing the whole shop into one column.
3. **Phone portrait:** season first, then the remaining featured offers, then the catalog. Use two cards per row wherever art, labels, and targets fit; otherwise use a full-width card, including a horizontal compact variant where useful.
4. **Short landscape:** reduce decorative and preview height, retain readable copy and reachable actions, and keep vertical scrolling available.

Rows derive from the number of cards. Missing sections leave no reserved holes. One-card and many-card sections both work. Unknown future sections remain reachable through the existing fallback ordering. Preserve the Bonks anchor, selection, and scroll position across ordinary updates; ticking countdowns must not rearrange the storefront.

## 5. Component-by-component specification

### 5.1 Shop cards and purchase controls

Build on `ShopCard`, `ShopPreview`, and `ShopPriceButton` using the same surface recipe as `PuffyButton` and `ItemTile`. Share presentation primitives without forcing commercial cards into the Backpack's square proportions or equip behavior.

- Large existing artwork; clear name; separate rarity/product badge and ownership sticker.
- Price and currency icon together. A supplied discount shows the current price and a legible previous-price line.
- Owned items retain full-color previews and remain inspectable. OWNED is an information state, not a disabled-looking card.
- Card activation opens the existing inspection flow. Bonks purchases, Robux prompts, and crate openings keep their existing explicit action points.
- Stable hitboxes; matching hover/focus outline and press squash. Avoid nested card and action buttons activating the same operation twice.

### 5.2 Shared modal shell

- Ink-tinted dim layer, cream puffy panel, overlapping title sticker, pastel content well, and consistent Close/Back controls.
- Preserve `ModalSurface` safe-area and full-viewport input ownership. Tilt only decoration; content and scrollers stay unrotated.
- Desktop inspection places a large preview beside details or contents. Portrait puts a compact preview above the details; the season flow retains its existing reward-to-preview navigation.
- Reserve space for an action footer. Wrap actions into additional rows when needed and measure that height before sizing the scroll area. At very short heights, use a compact composition that keeps every action reachable.
- Keep full item/product names in the modal. Give long titles their own measured band rather than colliding with Close.
- Maintain modal focus ownership, Escape/controller Back, return focus, and suspended underlying input.

### 5.3 Item, bundle, and pass inspection

- Show the selected item's large preview, name, rarity ribbon, and real ownership/equip state.
- Use pale, puffy content selectors for bundles, outfits, and emote collections. Distinguish included pieces and preserve existing selection restrictions.
- Keep descriptions, bundle ownership/refund information, product prices, and availability visible.
- Pink primary action; cream secondary BACKPACK or BACK; a labeled equipped check state.
- Reuse the candy effect icon treatment and existing PLAY EFFECT / PLAY SOUND audition flow. Sound playback stays explicit.
- Returning from an audition restores the item and scroll/selection context. Opening inspection from the Backpack or a crate reward uses this same design.

### 5.4 Crate contents, rarity, and odds

Treat the crate modal as a readable contents browser with an explicit opening footer.

- Group outcomes by existing rarity, with matching ribbons and straight responsive grids.
- Each outcome shows its name, preview, probability, and owned state. Selecting it changes the preview without changing the purchase action.
- Show current probabilities from the existing view model; show base probabilities when they differ. Never substitute global rarity weights for actual item odds.
- Only summarize a group as “X% each” or one duplicate refund when all entries share that value. Otherwise retain individual values.
- Give guarantee information a distinct, readable strip near the opening controls. Preserve Rare+ and Legendary wording and server-derived remaining counts.
- Preserve all configured open quantities, total costs, Bonks/Robux distinction, balance/shortfall, pending states, and existing purchase-availability rules.
- On narrow screens, let odds scroll while the measured action area remains accessible. Information about odds or refunds must not depend on hover.

### 5.5 Crate opening and results

- Replace mismatched surfaces and glow styling with a candy squash/pop, crisp rays, and a small confetti burst using existing artwork.
- Preserve the existing short reveal timing and skip behavior. Higher rarity can change the accent and amount of decoration, without a longer wait.
- Single result: large art, name, rarity, acquisition/duplicate status, and actions.
- Batch result: a prominent selected/best reward plus a responsive result grid. Every result stays accessible.
- A duplicate keeps its item identity and adds an explicit DUPLICATE / +N BONKS label. The refund must not replace the item name.
- Keep Inspect, Equip, Backpack, Close, and Open Again where applicable. Open Again displays its count and total cost and respects current affordability/pending state.
- Inspecting a reward and returning restores the same batch and selection. Celebrate only a confirmed result or equip.

### 5.6 Season pass and rewards

- Use the shared modal frame, a season title sticker, numbered tier badge, and striped candy progress bar.
- Free and Premium become `TabPill` controls. Premium access uses a crown/gold accent; cosmetic rarity remains a separate ribbon.
- Preserve tier order and reward identity. Show locked-by-tier, premium-required, ready-to-claim, and claimed as distinct labeled states.
- Reward tiles use the shared preview, selection, and badge language. A progress lock must not make a reward look already owned.
- Keep reward preview, premium purchase, and claim actions separate. Show the existing claim count and pending state.
- Handle initial loading, no active season, ended season, maximum tier, and all rewards claimed without blank panels or misleading actions.
- Match the season entry/status card on the Lobby so both entry points lead into the same visual flow.

### 5.7 Notifications, daily rewards, and supporting UI

- Apply the modal shell and puffy buttons to purchase success, error, confirmation, delayed delivery, and crate-recovery messages. Preserve their meaning and actions.
- Processing messages show activity and readable status; success alone receives celebratory decoration.
- Daily rewards use the same numbered stickers, reward previews, and claim-state language. Restyle their Lobby entry card as well.
- Align wallet chips, Bonks labels, countdowns, progress bars, and loading/retry states with the shared type and palette.
- Roblox-owned purchase prompts remain platform UI. All custom screens leading into and returning from them should match.

## 6. Interaction states and motion

| State | Treatment |
| --- | --- |
| Default | Pale surface, clear art/name, named rarity or product badge |
| Hover / focus | Yellow outline and restrained lift; preview animation only where useful |
| Pressed | Visual squash to the existing 0.94 scale, stable hitbox |
| Selected preview | Yellow selection ring; no ownership implication |
| Owned | Explicit OWNED/check sticker; inspection remains available |
| Equipped | Existing pink ring and yellow check treatment |
| Locked reward | Lock sticker plus the actual tier/premium requirement |
| Unaffordable / unavailable | Clear shortfall or reason; purchasing unavailable while inspection stays useful |
| Pending | PROCESSING, OPENING, or CLAIMING label; guard repeat activation |
| Newly granted / claimed | Brief stamp and confetti after confirmation |
| Duplicate | Item identity plus explicit refund label |

Reuse the established open, hover, press, and stamp timings. Stagger only visible cards, cap the delay, and do not restart entrance animations on a price/countdown tick. Stop off-screen emote/effect previews. Respect reduced motion across cards, progress decoration, modal transitions, and reveals. Keep existing sound assets and playback rules.

## 7. Implementation sequence

1. **Capture the baseline and state coverage.** Record the current Shop, inspection variants, crate odds/results, season rewards, and connected notifications. Extend existing stories/fixtures for long names, unusual card counts, and transaction/reward states.
2. **Extend shared presentation.** Reuse `PanelFrame`, `PuffyButton`, `TabPill`, `Badge`, `Well`, and candy headers. Extract a reusable title sticker from `BackpackTitle` while preserving its approved appearance. Add a shared rarity ribbon where needed.
3. **Build the storefront composition.** Update `ShopPage`, `ShopLayout`, Shop sizing configuration, and card variants. Promote the existing season product into an explicit featured placement without duplicating it or breaking `byId` lookup and existing season navigation.
4. **Restyle inspection and odds.** Update `ShopDetailsModal`, `CrateOddsGrid`, previews, and price controls; preserve the controller's callbacks and modal stack.
5. **Complete reward flows.** Update `SeasonPassModal`, `SeasonRewardsPanel`, `CrateRevealModal`, opening decoration, and effect-preview controls.
6. **Carry the style through adjacent surfaces.** Update notifications, daily/season entry cards, daily reward modal, and economy chips/progress controls. Extend Shop backdrop activation and check shared callers in Lobby and Arena.
7. **Validate and document.** Capture responsive results, test the layout and interactions, update `STYLE.md`, and deliver the review gallery.

Keep catalog and server economy logic intact. Add meaningful tests around layout changes and any presentation-data reshaping; use stories and visual checks for reversible styling. Keep instance names and bindings depended on by other scripts, or provide an explicit compatibility mapping.

## 8. Validation and deliverables

### Layout and visual checks

- Capture the Shop at 1920×1080, 1440×1080, phone portrait, and short landscape. Include both the top featured area and lower catalog.
- Capture item inspection, bundle/pass inspection, crate odds, single/batch rewards, season rewards, and notification/daily reward variants. Include portrait checks for every modal family.
- Exercise zero/one/many offers, missing promotions, more permanent passes than fit one row, and an inactive season. Verify no overlap, lost cards, duplicate season entry, unreachable actions, or persistent empty lane.
- Check long names, large balances/prices, preferred text sizing, and lengthy status/guarantee text. Check clipping while scrolling and during hover animation.
- Compare the Backpack and shared Lobby/Arena callers for regressions.

### Behavior checks

- Verify Shop card → inspection → preview → return, and crate result → inspection → return.
- Verify Get Bonks scrolling, countdown expiry refresh, correct currency/quantity/total, owned and pending behavior, equip, season tabs, and claim-state rendering.
- Use existing story/test fixtures for purchases, duplicate results, bulk openings, recovery, and claim success/failure. Live visual testing need not spend currency or Robux.
- Test mouse, keyboard/controller focus, Back/Escape, touch-sized targets, and reduced motion. Distinguish device simulation from physical hardware testing in the report.
- Run appropriate layout/view-model tests, the existing test suite, formatting/lint, both place builds, and a live Studio error/text-fit check after implementation.

### Deliverables

1. Restyled storefront with content-driven rows/columns and an explicit top season feature.
2. Matching inspection, odds, reveal, season, notification, and connected reward UI wired to existing behavior.
3. Reusable token/component extensions and updated `STYLE.md`.
4. Before/after gallery under `.review/candy-shop/`, including responsive and modal captures.
5. Short recordings covering storefront navigation/inspection and fixture-driven crate/season states, with simulated states clearly identified.
6. A concise validation report listing checks completed and any remaining device coverage.

## 9. Acceptance checklist

- [ ] Shop and related modals visibly belong to the approved Backpack design.
- [ ] Wide and medium layouts contain neighboring blocks with varied card proportions.
- [ ] Reflow is driven by usable width, readable content, and item count.
- [ ] The active season pass appears once, at the top with featured offers, including when premium is owned.
- [ ] Every offer and reward remains reachable across supported screen sizes.
- [ ] Rarity, ownership, selection, premium access, and price are distinguishable without color alone.
- [ ] Odds, base odds, guarantees, refunds, prices, and purchase states preserve their actual meaning.
- [ ] Modals preserve focus, Back behavior, selection, and return context.
- [ ] Labels fit at supported text sizes; action targets are at least 44 logical px.
- [ ] No scrolling leaks from rotated decoration; no new pure-black surfaces, blurred glows, glass, or thin primary outlines.
- [ ] Motion respects reduced-motion preferences and stops when hidden.
- [ ] The Ouch! logo, swirl, characters, and authored item assets remain; no Fall Guys assets or new sound assets are introduced.
- [ ] Backpack and shared-screen regression checks pass.

## 10. Decisions carried forward

The approved candy direction, existing four rarity tiers, named ribbons, faint swirl plus confetti, built-in fonts, and existing sounds are settled. The Shop may change composition to improve hierarchy and responsiveness, as requested. Purchase mechanics and reward rules remain as implemented. No additional style decision is needed to begin this plan.


## 11. Implementation and validation record

The implementation was carried out under this spec. See [SHOP_REDESIGN_PROGRESS.md](SHOP_REDESIGN_PROGRESS.md), [STYLE.md](STYLE.md), and the [validation report](.review/candy-shop/VALIDATION.md) for the delivered components, actual screenshots, and coverage. The checklist above is the intended acceptance standard; it is not a claim that every fixture/device state was visually verified. In particular, the Studio tool's React capability restriction blocked transaction-driven fixture rendering.
