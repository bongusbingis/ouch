# Crate Purchase & Opening Flow — Refinement Audit

**Scope:** the complete crate journey — discovery in the shop grid → details/odds
modal → purchase (Bonks and Robux paths) → server roll & grant → reveal →
dismissal — plus every UI, UX, and interaction surface it touches.

**Method:** end-to-end trace of `ShopCard` → `ShopViewModel.crateCard` →
`ShopDetailsModal` → `EconomyMenuController` → `ShopClient.openCrate` →
`CrateService.openWithBonks` / `openFromReceipt` → `CrateRolls.roll` /
`CrateOdds.build` → `CrateOpened` → `ShopViewModel.reveal` →
`CrateRevealModal`, plus the config that drives it (`Crates`, `Cosmetics`,
`Products`, `Shop`, `Inventory`).

**Live surface today:** only `DodgeballCrate` is `CatalogStatus = "Active"`
(`src/config/Crates.luau:54-62`). `HammerCrate` and `EffectsCrate` are
`Preview` and cannot be opened. Its pool is 9 items: 4 Common @ 17.5%,
3 Rare @ 8%, 2 Legendary @ 3% — summing to exactly 100%.

**Baseline:** 447 tests passing, `stylua`/`selene` clean. No files were modified
to produce this report.

---

## Executive summary

The **correctness and economic integrity of this flow is genuinely good** — the
roll is pure and server-side, odds disclosure is mathematically exact,
pity is correctly implemented, and the double-delivery of the reveal payload is
properly deduplicated. I found no way to cheat a crate, no double-charge, and no
double-grant.

**The gap is almost entirely in the reveal moment itself.** A crate opening —
the single highest-emotion beat in the whole economy — currently resolves as an
un-animated, silent modal that pops into existence fully-formed. Meanwhile the
*details* modal that precedes it (a far lower-stakes surface) has a spring
entrance animation. That inversion is the headline finding.

Secondary themes: the odds disclosure is cramped to ~3 visible rows of 9 on
phones, pity progress is tracked and replicated but never shown, and several
error states resolve to a misleading generic message.

---

## Findings

### HIGH

**CR-01 — The reveal has no animation, no sound, and no rarity escalation; the
details modal that precedes it does**
- **Category:** UX / core game feel
- **Confidence:** High
- **Evidence:** `src/shared/UI/Components/CrateRevealModal.luau` imports only
  `React`, `InventoryConfig`, `ResponsiveText`, `ShopPriceButton`,
  `ShopPreview` — no `ReactSpring`, no `Motion`, no `useReducedMotion`, no
  `UIFeedback`. Contrast `ShopDetailsModal.luau:43-48`, which *does* run a
  `ReactSpring.useSpring` on `Scale`/`Rotation` with `Motion.Modal`.
  `UIFeedback` (`src/shared/UI/Services/UIFeedback.luau:87-121`) exposes only
  `hover`/`click`/`notification` — there is no crate-open or rarity cue in
  `src/config/UI.luau:14`.
- **What the player experiences:** they press a button, and the answer is
  simply *there*. No suspense, no build, no "oh —" moment. A Legendary and a
  Common duplicate arrive with identical presentation weight; the only
  difference is the panel tint (`ImageColor3`, line 55) and one line of text.
- **Why this matters most:** every other part of this flow is built to a high
  standard, which makes the flat reveal the weakest link in the chain the
  player actually remembers. Loot-box payoff is the product.
- **Recommended direction:** a short (~1.2–2.0s) staged reveal — panel
  entrance spring, a hold/anticipation beat, then the item resolving with
  rarity-scaled treatment (Common: quick and light; Legendary: longer hold,
  bigger scale punch, distinct sound). Reuse the existing `Motion`/
  `ReactSpring` + `useReducedMotion` pattern already established in
  `ShopDetailsModal`/`NotificationModal` rather than a new mechanism, and add
  `Crate` entries to `Config.UI.Feedback` for the audio. **Must** honour
  `useReducedMotion` and must be skippable (see CR-02).
- **Scope:** Medium. **Risk:** Low — additive, presentation-only.

**CR-02 — There is no skip and no repeat-open; every open costs a full
navigation round-trip**
- **Category:** UX / flow friction
- **Confidence:** High
- **Evidence:** `CrateRevealModal.luau:121` offers exactly one action,
  `"AWESOME!"` → `props.OnClose` → `closeReveal` →
  `shopClient.clearReveal()` (`EconomyMenuController.luau:262-264`). After
  dismissal the player is returned to the shop grid with the details modal
  also closed (`purchaseSelectedBonks` cleared it at
  `EconomyMenuController.luau:272`), so opening a second crate requires:
  find card → tap → details modal → tap Bonks → reveal → dismiss. Six
  interactions per open.
- **Impact:** the natural behaviour for a crate ("open a few in a row") is the
  most punished path in the UI. Once CR-01 adds an animation this gets worse,
  not better, unless a skip exists.
- **Recommended direction:** add an "OPEN AGAIN — {price} BONKS" secondary
  action on the reveal (disabled when unaffordable / crate inactive), and make
  the reveal animation skippable by tap/click/`ButtonA` on first input. A
  10× open is a larger product decision, not a refinement — see Questions.
- **Scope:** Small–Medium. **Risk:** Low, but note the repeat-open button
  re-enters a real spend path, so it needs the same `pending`/affordable
  gating the details modal already applies.

### MEDIUM

**CR-03 — Odds disclosure is cramped to roughly 3 of 9 rows on a phone**
- **Category:** UI / responsive / compliance-adjacent
- **Confidence:** High
- **Evidence:** the odds list is a `ScrollingFrame` at
  `ShopDetailsModal.luau:198-207`, `Size = UDim2.fromScale(0.48, 0.32)` inside
  a panel that is `UDim2.fromScale(0.62, 0.68)` of the screen (line 145). Rows
  are a fixed `UDim2.new(1, -6, 0, 27)` (line 81) with `Padding = UDim.new(0, 3)`
  (line 72) → 30px per row. Effective list height = `0.32 × 0.68 × screenH`:

  | Screen | List height | Rows visible (of 9) |
  |---|---|---|
  | 1920×1080 | 235px | ~7.8 |
  | 1024×768 (tablet) | 167px | ~5.5 |
  | 844×390 (phone landscape) | 85px | **~2.8** |

- **Impact:** Roblox's paid-random-item policy requires odds to be *disclosed*;
  they are, and correctly (see the positives section). But a phone player must scroll a
  ~85px box to read 9 outcomes, which is disclosure that technically exists and
  practically doesn't. This is the same class of issue as the Shop sizing work
  already done — the modals were not part of that pass.
- **Recommended direction:** the modal already has a `compact` precedent to
  copy from `ShopPage` (`React.Change.AbsoluteSize` breakpoint). Either give
  the odds list more of the panel on small widths, or group rows by rarity
  (3 rows instead of 9 — "COMMON 70% ▾") with per-item detail on expand.
- **Scope:** Medium. **Risk:** Low.

**CR-04 — None of the three modals has an aspect-ratio constraint, so panels
distort by ~2× across supported devices**
- **Category:** UI / responsive
- **Confidence:** High
- **Evidence:** `CrateRevealModal.luau:58` (`0.4 × 0.54`),
  `ShopDetailsModal.luau:145` (`0.62 × 0.68`),
  `NotificationModal.luau:133` (`0.361782 × 0.196247`) — none carries a
  `UIAspectRatioConstraint`. Resulting panel aspect ratios:

  | Screen | Reveal panel | Details panel |
  |---|---|---|
  | 1280×1024 (5:4) | 0.93 | 1.22 |
  | 1024×768 (4:3) | 0.99 | 1.22 |
  | 1920×1080 (16:9) | 1.32 | 1.62 |
  | 844×390 (phone) | 1.60 | 1.97 |
  | 2560×1080 (21:9) | 1.76 | **2.16** |

- **Impact:** the reveal panel swings from portrait-ish (0.93) to landscape
  (1.76) — a 1.9× aspect swing. The 9-slice background stretches gracefully,
  but the scale-positioned contents (a 3D `ShopPreview` viewport at
  `0.68 × 0.46` of the panel, `CrateRevealModal.luau:77-80`) do not; the item
  preview is squashed or stretched depending on device. On 21:9 the details
  modal becomes a 2.16 letterbox with its two columns pulled far apart.
- **Recommended direction:** the fix pattern is already in the codebase from
  the Shop work — `UIAspectRatioConstraint` with
  `AspectType = FitWithinMaxSize`. Reveal reads best near 1.1–1.25 (it is a
  portrait-ish "card"); details near 1.6.
- **Scope:** Small. **Risk:** Low, but needs a visual pass per device since
  it changes composition, not just size.

**CR-05 — `rate_limited` is missing from `SHOP_ERRORS`, so opening crates
quickly shows a message implying a failed charge**
- **Category:** UX / error messaging
- **Confidence:** High
- **Evidence:** `OpenCrate` is rate-limited to 2/sec
  (`src/server/Modules/CrateService.luau:236`). On limit,
  `Network.withRateLimit` returns `nil, "rate_limited"`
  (`src/shared/Network.luau:112-116`), which `ShopClient.openCrate` surfaces as
  `false, "rate_limited"` (`ShopClient.luau:305-309`). `SHOP_ERRORS`
  (`EconomyMenuController.luau:43-58`) has no `rate_limited` key, so it falls
  through to `"THE PURCHASE COULD NOT BE COMPLETED."` (line 162).
  `EQUIP_ERRORS` (line 34) *does* define `rate_limited` — so this is an
  inconsistency, not a deliberate choice.
- **Impact:** a player opening crates in quick succession sees a hard failure
  message that reads like a payment problem, with no indication that simply
  waiting a second resolves it. Worst-case they believe they were charged.
- **Recommended fix:** one line —
  `rate_limited = "You are opening crates too quickly. Try again in a moment."`
- **Scope:** Trivial. **Risk:** None.

**CR-06 — Pity progress is tracked, persisted, and replicated, but never
shown to the player**
- **Category:** UX / retention
- **Confidence:** High
- **Evidence:** the counter lives at `data.Crates.Pity[crateId]`
  (`src/server/Modules/CrateService.luau:61`, template at
  `src/config/Data.luau:25-27`) and is part of the profile Replica the owning
  client already receives (`EconomyStore.snapshot` returns `replica.Data`
  wholesale, `EconomyStore.luau:36-41`). The details modal shows only the
  static threshold — `"LEGENDARY GUARANTEED BY 25 OPENS"` via
  `pityText` (`ShopDetailsModal.luau:23-35`, sort at line 30) — never "18 / 25".
- **Impact:** the strongest retention hook the crate system has is invisible.
  "7 more opens until guaranteed Legendary" is materially more motivating than
  a static rule, and the data is already sitting on the client.
- **Recommended fix:** thread `crate.Pity` progress into `crateCard`
  (`ShopViewModel.luau:213` already passes `pity = crate.Pity`; the
  per-player counter would come from `args.economyData.Crates.Pity[crateId]`)
  and render as `"LEGENDARY IN {threshold - current} OPENS"` or a small
  progress bar.
- **Scope:** Small–Medium. **Risk:** Low. Note this is *presentation of an
  existing guarantee*, not a new one — no economy change.

**CR-07 — `pityTriggered` reaches the client and is then thrown away**
- **Category:** UX / wasted signal
- **Confidence:** High
- **Evidence:** `CrateRolls.roll` computes `pityTriggered`
  (`CrateRolls.luau:91`), `CrateService` puts it in the `CrateOpened` payload
  (`CrateService.luau:92`, re-sent at `:100`), and it is spec-tested
  (`src/shared/Tests/CrateRolls.spec.luau:88,129`). But
  `ShopViewModel.reveal` (`ShopViewModel.luau:493-504`) does not copy it into
  the reveal view model, so `CrateRevealModal` cannot access it.
- **Impact:** the one moment where the game could say **"PITY! GUARANTEED
  LEGENDARY"** — the single best-feeling beat available — is silently
  discarded one function short of the UI. This pairs directly with CR-01.
- **Recommended fix:** add `pityTriggered = result.pityTriggered` to the
  reveal view model and render a banner when non-nil.
- **Scope:** Trivial. **Risk:** None.

**CR-08 — "Can't afford" is a dead end; no route to buy Bonks**
- **Category:** UX / conversion
- **Confidence:** High
- **Evidence:** when unaffordable, the Bonks button renders
  `NEED {price} BONKS` and is **disabled**
  (`ShopDetailsModal.luau:125` for the text, `:247` for `Enabled = card.affordable and not card.pending`).
  Bonks *are* purchasable — four packs exist at
  `src/config/Products.luau:35,45,55,65` (500 / 1100 / 2500 / 5500) — but nothing
  links to them. The player must dismiss the modal, find the Bonks section,
  buy, then re-navigate back to the crate.
- **Impact:** the exact moment of highest purchase intent terminates in an
  inert grey button. This is the clearest conversion loss in the flow.
- **Recommended direction:** make the disabled state actionable — tapping
  `NEED 500 BONKS` routes to the Bonks packs (ideally pre-selecting the
  smallest pack that covers the gap). Keep it a *route*, not an embedded
  purchase, so the existing Robux prompt path stays the only spend surface.
- **Scope:** Medium. **Risk:** Low mechanically; worth a product sanity-check
  that this reads as helpful rather than pushy (see Questions).

**CR-09 — `NotificationModal` renders behind the crate modals and can steal
gamepad focus to an unreachable button**
- **Category:** UI / layering + input
- **Confidence:** Medium (layering proven; reachability is narrow)
- **Evidence:** `ReactRoot` sets `ZIndexBehavior = Sibling`
  (`src/shared/UI/Services/ReactRoot.luau:17`). Inside the `Modals` frame
  (`ArenaMenu.luau:491-495`), the siblings are `NotificationModal`
  (root `ImageLabel` at `NotificationModal.luau:121-135` — **no `ZIndex`
  set**, so it defaults to 1), `ShopDetailsModal` (ZIndex 101), and
  `CrateRevealModal` (ZIndex 111). Both crate modals also lay a full-screen
  `Active = true` backdrop, which blocks input beneath them.
- **Trigger:** buy a Bonks pack with Robux while a crate reveal is still open
  → `StorePurchaseGranted` → `acceptGrant` → the grant `useEffect`
  (`EconomyMenuController.luau:142-155`) fires `notifications.notify`. The
  notification mounts *behind* the reveal, is input-blocked by the reveal's
  backdrop, and its selection effect (`NotificationModal.luau:84-102`) sets
  `GuiService.SelectedObject` to a button the player cannot see or reach.
- **Impact:** on gamepad, focus is lost to an invisible control; the player
  can appear soft-stuck until they dismiss the reveal blindly.
- **Recommended fix:** give the notification root an explicit `ZIndex` above
  both crate modals (it is the most urgent surface, so it should win), and
  have `closeTopLayer` account for it. Note `closeTopLayer`
  (`EconomyMenuController.luau:301-313`) currently ranks reveal > card >
  notification, which matches the *current* z-order but would need to invert
  alongside this fix.
- **Scope:** Small. **Risk:** Medium — changing modal z-order affects every
  screen that uses notifications, not just crates. Verify against the party /
  matchmaking notification paths too.

### LOW

**CR-10 — `previousSelection` can be clobbered by its own button, losing
gamepad focus on close**
- **Category:** Input / gamepad
- **Confidence:** Medium
- **Evidence:** `ShopDetailsModal.luau:50-52` and `CrateRevealModal.luau:24-26`
  store `previousSelection.current = GuiService.SelectedObject` **unconditionally**
  in the open branch. `NotificationModal.luau:86-88` guards this with
  `if previousSelection.current == nil then` — so the guard exists in the
  codebase and was simply not applied to the two crate modals. The effects are
  keyed on `{ card }` / `{ reveal }`, and both are freshly-allocated tables:
  `selectedShopCard` is `shopModel.byId[...]` which rebuilds whenever
  `shopSnapshot` changes identity (every `update()` in `ShopClient` clones
  state), and `crateReveal` is a `useMemo` over `shopSnapshot.reveal`.
- **Trigger:** any `ShopClient.update()` while the details modal is open —
  e.g. a `ShopStateChanged` push, or a pending flag flipping — re-runs the
  effect, which stores the modal's *own* button as `previousSelection`. On
  close, focus is restored to a destroyed instance and gamepad selection is
  dropped.
- **Note:** the main purchase path is *not* affected —
  `purchaseSelectedBonks` clears `selectedShopCardId` before the async action
  runs, so the effect takes the close branch first.
- **Recommended fix:** apply the same `if previousSelection.current == nil`
  guard used by `NotificationModal`.
- **Scope:** Trivial. **Risk:** None.

**CR-11 — A duplicate with a zero refund would render "+0 BONKS"**
- **Category:** UI / latent
- **Confidence:** High (that the guard is missing), High (that it is currently
  unreachable)
- **Evidence:** `CrateRevealModal.luau:43` unconditionally formats
  `DUPLICATE • +{reveal.bonksRefund} BONKS`. `bonksRefund` comes from the
  rolled rarity's `DupeBonks` (`CrateRolls.luau:89`).
- **Currently unreachable:** the only rarity with `DupeBonks = 0` is
  `Exclusive`, which also has `Weight = 0`
  (`src/config/Cosmetics.luau:65-69`), and `CrateOdds.build` skips
  zero-weight rarities entirely (`CrateOdds.luau:40-42`). So no live crate can
  produce this. Flagged because the coupling is implicit — adding any
  positive-weight rarity with `DupeBonks = 0` surfaces the bug immediately.
- **Recommended fix:** branch to a plain `"DUPLICATE"` when
  `bonksRefund <= 0`.
- **Scope:** Trivial. **Risk:** None.

**CR-12 — Pity entries are listed alphabetically rather than by rarity**
- **Category:** UI / copy
- **Confidence:** High
- **Evidence:** `pityText` sorts names with `table.sort(names)`
  (`ShopDetailsModal.luau:30`), so `{ Rare = 5, Legendary = 25 }` renders as
  `"LEGENDARY GUARANTEED BY 25 OPENS  •  RARE GUARANTEED BY 5 OPENS"` — the
  rarer, further-away guarantee first, and the nearer one second. Ordering by
  rarity weight (or by threshold ascending) reads more naturally. The sort is
  at least deterministic, so this is polish, not a bug.
- **Scope:** Trivial. **Risk:** None.

**CR-13 — Odds `ScrollingFrame` omits scrollbar sizing its sibling sets**
- **Category:** UI / minor visual
- **Confidence:** Medium
- **Evidence:** `ShopDetailsModal.luau:198-207` sets no `ScrollBarThickness`
  (defaults to 12) and no `VerticalScrollBarInset`. `ShopPage.luau:183,185`
  sets both. The percentage column is right-aligned at
  `Position 0.72 / Size 0.25` (`ShopDetailsModal.luau:112-113`), ending at
  0.97 of the container — so a 12px scrollbar can overlap the odds
  percentages, which are the numbers being disclosed.
- **Scope:** Trivial. **Risk:** None.

**CR-14 — `CrateOdds.build` is recomputed on every roll**
- **Category:** Performance / hygiene
- **Confidence:** High
- **Evidence:** `CrateRolls.roll` calls `CrateOdds.build` on every invocation
  (`CrateRolls.luau:35`), which allocates buckets and runs two `table.sort`s.
  The model is a pure function of static config and never changes at runtime.
- **Impact:** negligible at real crate-open rates (bounded to 2/sec/player by
  the rate limit) — flagged only because the client rebuilds the same model on
  every shop re-render too (`ShopViewModel.luau:172-174`), which is inside a
  `useMemo` but still re-runs whenever `shopSnapshot` churns. Not worth fixing
  on its own; worth memoising if the shop model is ever profiled.
- **Scope:** Small. **Risk:** Low — but note that memoising must key on
  config identity, and `Config.Crates` is a live-overridable table.

### INFO / observations, not defects

**CR-15 — The reveal fires before the Bonks debit is applied**
`CrateService.openWithBonks` calls `rollAndGrant` (which fires `CrateOpened`,
line 103) at line 159, and debits at line 170. Nothing yields between them, so
this is not a race — but the client can render the reveal one replication frame
before its balance updates. Cosmetic only; noted so it isn't mistaken for a
bug later. The arithmetic is correct in both branches (a duplicate credits the
refund at line 65 *before* the debit, netting correctly).

**CR-16 — A player who owns the whole pool gets guaranteed duplicates with no
warning**
`DodgeballCrate` has 9 items. A player owning all 9 will receive a duplicate
refund on every single open, forever, and nothing in the details modal says so.
This is currently a small population (the pool is small and cheap to complete
relative to the 500-Bonks price), so it is an observation rather than a
finding — but it becomes a real fairness/perception issue as soon as pools stay
small while play time grows. Worth a "YOU OWN ALL ITEMS — OPENS RETURN BONKS
ONLY" state on the card.

**CR-17 — Only one crate is live**
`HammerCrate` and `EffectsCrate` are `Preview`
(`src/config/Crates.luau:63,75`) and show as `"COMING SOON"`
(`ShopCard.luau:39`). The whole crate surface is currently one crate, which
is worth knowing before investing heavily in crate-specific UI polish.

---

## What is already well-built (preserve this)

- **The reveal payload is double-delivered and correctly deduplicated.**
  `CrateOpened` fires from the server *and* `openWithBonks` returns the same
  result; `ShopClient.acceptReveal` gates on `openId` via `seenOpens`
  (`ShopClient.luau:81-86`), so the reveal never double-fires regardless of
  which arrives first. This is exactly the right guard and it is easy to get
  wrong.
- **Odds disclosure is mathematically exact.** `CrateOdds.allocate`
  (`CrateOdds.luau:76-110`) uses largest-remainder allocation specifically so
  displayed percentages sum to exactly 100 — the naive per-item rounding
  approach does not (9 items at 11.11% sums to 99.99). This is a compliance
  requirement met deliberately, with spec coverage.
- **One probability model drives both rolling and disclosure.**
  `CrateRolls.roll` and `crateCard`'s odds list both call `CrateOdds.build`,
  so the advertised odds are provably the rolled odds — they cannot drift.
- **Pity is correct.** The reset rule (`CrateRolls.luau:70-80`) resets *every*
  guarantee whose rarity is at-or-worse than what dropped, so a Legendary
  correctly satisfies the Rare guarantee too. Rarest-due wins when two
  guarantees come due together. Spec-covered at
  `src/shared/Tests/CrateRolls.spec.luau`.
- **The purchase path is properly server-authoritative and rate-limited.**
  Crate id is validated, `isOpenable` gates on `CatalogStatus`,
  `PaidRandomPolicyService` gates restricted accounts, balance is checked
  server-side, and the roll uses a server-side `Random`. The client sends a
  crate id and nothing else.
- **Restricted-region handling degrades gracefully.**
  `grantRestrictedValue` (`CrateService.luau:184-213`) converts a Robux crate
  purchase into an equivalent Bonks grant rather than failing the receipt —
  the player is never charged for nothing.
- **Crate cards correctly stay enabled when unaffordable.**
  `ShopCard.luau:75` (`canAfford = card.kind == "Crate" or ...`) means a
  player can always open the details modal to read the odds even when they
  cannot buy — the right call for a disclosure surface.
- **The card CTA is "VIEW ODDS", not a price.** The price lives in the
  supporting text (`hintText`, `ShopViewModel.luau:185-189`). This correctly
  communicates that tapping the card is a *look*, not a *spend* — a small
  detail that meaningfully reduces misclick anxiety.

---

## Suggested sequencing

**Tier 1 — the reveal moment (the actual product gap)**
CR-01 (staged rarity-scaled reveal + sound), CR-07 (pity banner — trivial and
directly feeds CR-01), CR-02 (skip + open-again).

**Tier 2 — trust and clarity**
CR-03 (odds legibility on phone), CR-06 (pity progress), CR-05 (rate-limit
copy — one line), CR-11 / CR-12 / CR-13 (trivial polish, bundle with CR-03).

**Tier 3 — conversion and layout**
CR-08 (route to Bonks), CR-04 (modal aspect constraints), CR-09 (modal
z-order — do this one carefully, it is cross-cutting), CR-10.

---

## Questions

1. **How far do you want the reveal to go?** CR-01 is the core finding, but
   "staged reveal" spans a wide range: a 1.2s spring-and-punch that I can build
   entirely from the existing `Motion`/`ReactSpring` primitives, versus a
   full crate-opening sequence (crate model, shake, burst) that would need
   Studio-authored assets — which per `AGENTS.md` rule 3 I would need you to
   author rather than build in code. Which end of that range are you after?

2. **Is "open again" wanted, and should a multi-open (5×/10×) exist?**
   CR-02's skip/repeat is a refinement I can do now. A true multi-open is a
   different thing — it needs a new remote shape, a batched roll, and a
   different reveal layout, and it changes the spend-rate curve. That feels
   like a product decision rather than a refinement, so I have deliberately
   not designed it here.

3. **Should the unaffordable button route to Bonks packs (CR-08)?** It is a
   clear conversion win, but it is also the flow becoming more insistent at
   the moment of friction. Happy to implement, defer, or implement in a
   softer form (a plain "You need 200 more Bonks" hint with no route).

4. **CR-09's fix reorders modal z-index globally** — notifications would start
   winning over shop/crate modals everywhere, including party and matchmaking
   surfaces. Do you want me to scope that to the economy modals only, or make
   notifications globally top-most?

No blocking questions for the Tier 1/Tier 2 items — those I can proceed on
whenever you want.
