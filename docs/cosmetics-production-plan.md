# Cosmetics and shop production integration

Execution plan, 2026-09-06. Baseline: `b8adf7e` on `main` and `origin/main`; 690 headless tests pass, all format checks pass, and lint has zero findings using the cached Roblox API definitions. The existing work, including `gameassets-renamed.rbxmx`, was committed without alteration.

## Approved direction

- Complete outfits fitted to the existing custom R15 character. Preserve its face, proportions, combat rig, movement and collision. Selected body color affects exposed body parts; outfit colors remain authored.
- Author and identify outfit pieces separately, then compose complete outfits from those pieces. The first release sells/equips complete looks. Future individual-piece sales must reuse the same assets and ownership records.
- One shared appearance assembly path serves live characters, wardrobe/shop previews, lobby party characters, victory emotes and results. CosmeticsService remains the only writer of cosmetic ownership/equips.
- Use a real 3D scene for effect previews. Share effect definitions and playback with gameplay, with isolated lifetime and camera ownership.
- Complete Season 1 with configurable cosmetic rewards. Preserve already-promised Bonks; add cosmetics and reconcile eligible prior claims once. Changes to cosmetic reward choices must be localized to season config and an explicit revision.
- Both lobby and arena must support the full shop, purchase, inventory and equip flow. Arena access uses its existing menu action/button. Menus do not pause combat or confer protection.
- Trails are obsolete prototype content. Preserve their dormant extension points and existing ordinary dodgeball flight trail; remove obsolete store/wardrobe promises. No new trail cosmetics are part of this release.
- Preserve the established React design system, existing weapon/effect assets, Marketplace-sourced Robux prices, server purchase authority, and profile persistence boundaries.

## Research and design rationale

Fall Guys' official [food-themed pass](https://www.fallguys.com/news/fall-guys-tool-up-update?lang=en-US) and [upper/lower costume merchandising](https://www.fallguys.com/news/bugsnax-costumes-announce?lang=en-US) establish useful references: readable themed silhouettes and separable costume components. Adapt those principles into original Splat Brawl designs: inflated forms, rounded transitions, clear face openings, a small coordinated palette and purposeful material contrast. Do not copy branded character assets or hide weak modeling behind noisy textures/effects.

Roblox's [ViewportFrame documentation](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame/LightDirection) documents missing shadows/post-processing, reduced Glass/Neon rendering, unsupported nested GUI rendering and different PBR illumination. [Beams require Workspace ancestry](https://create.roblox.com/docs/reference/engine/classes/Beam/Attachment0). A WorldModel does not make the existing heterogeneous effects a faithful embedded preview: ParticleKit, Primitives and CosmeticEffectFactory currently spawn into Workspace, including particles, beam ribbons and BillboardGui glyphs. Verify representative primitives in a disposable Studio comparison before implementing the scene; do not substitute a second UI particle implementation.

## 1. Content and outfit contract

Create six original, complete outfits, each composed of separately identified headwear, torso wear and footwear. Footwear may contain separate left/right parts; torso wear must follow the appropriate torso segments. All authored render parts carry an explicit body-part mount. Keep hands and the face clear through throw, catch and hammer animations.

| Outfit ID | Visual direction | Acquisition |
|---|---|---|
| `FoamLeague` | Padded sports helmet, contrasting athletic vest, rounded trainers; cobalt/coral/cream | Common Bonks offer; starter bundle |
| `RainHopper` | Frog-eyed hood with open face, yellow rainwear, soft boots; lime/yellow/cream | Rare Bonks offer |
| `SnackStack` | Rounded snack-themed headwear, simple diner apron/vest and shoes; warm bun/coral/cream | Rare Bonks offer |
| `OrbitRookie` | Open space helmet rim, padded flight vest and boots; ivory/navy/orange | Legendary Bonks offer |
| `SundaeSprinter` | Soft swirl headwear, wafer/icing details and candy shoes; cream/strawberry/cocoa | Season 1 free finale |
| `PartyRoyal` | Soft crown, short shoulder mantle and sash, rounded ceremonial shoes; plum/gold/cream | Season 1 premium finale |

These are implementation art directions, subject to visual refinement during authoring. Keep IDs stable. Existing rarity prices supply Bonks prices; do not invent per-item hard-currency fallback prices.

Catalog structure:

- Add a dedicated costume catalog module. Each component is a catalog item with an immutable ID, authored model lookup and component role. Components are hidden from the release's shop/wardrobe and cannot be equipped individually yet.
- A complete outfit is a `CostumeAssets` catalog entry with a flat, validated `Contents` list referencing component items. That list is the single composition definition used for ownership, grants, complete-look rendering and product contents.
- Persist only atomic component ownership in `Cosmetics.Owned`. An outfit is owned when all its components are owned. Do not persist a second outfit-owned flag.
- Continue storing the selected complete-look ID in `Cosmetics.Equipped.CostumeAssets` and projecting `Equip_CostumeAssets`. Default/nil means the existing uncostumed character.
- Centralize atomic grant expansion and ownership checks in CosmeticsLogic. Use them in CosmeticsService, InventoryModel, ShopRotation/ShopService, DirectPurchase, ShopViewModel and any reward/duplicate calculation affected by composed items. Reject cycles, missing components, nested sets and invalid component roles at catalog validation.
- Future piece sales expose existing component items and appropriate equip slots; they do not require reconstructing meshes or migrating purchased components. Do not ship unused mix-and-match UI now.
- Keep monetary bundles in existing `Economy.Bundles`; reference the complete-look catalog item there rather than repeating its component list. Starter bundle: Foam League outfit, the existing blue dodgeball and Star Pop. Disclose all contents and existing duplicate compensation; no unsupported saving claims.

## 2. Authored assets and appearance

Use `ReplicatedStorage.Assets.Cosmetics.Costumes.<ComponentId>` Models in both places. Each visible part has a `BodyPart` string naming its R15 target, `BodySize` recording that target's authored dimensions, and an authored `BodyMount` Attachment defining alignment relative to that body part. The runtime clones finished assets; geometry construction/import happens only in Studio. Meshes must be baked/published assets suitable for ordinary runtime cloning, not mutable EditableMesh dependencies in gameplay.

The close fit review confirmed all 15 live and preview body meshes match, while the experience's loaded character is uniformly 1.017769 times the preview size. Mounts and garment dimensions therefore derive from the actual target's size without changing the character. The user explicitly approved fitted replacement clothing meshes: exact copies of covered torso and leg surfaces carry `CoversBody = true`; the appearance lifecycle temporarily hides the original surface and restores its prior transparency on removal or replacement. Face, arms, hands, rig joints, collision and body-color ownership remain as specified above. This replaces the rejected enlarged torso and waist-gusset treatment, whose seams appeared in side/back views.

Implement a shared `CostumeVisualFactory` and character appearance module under `src/shared/Game/Cosmetics`. Resolve the existing complete-look definition, validate required authored assets with WaitForChild/assert, clone once per equip change, apply mounts and expose update/destroy operations. Live assembly follows body parts without introducing collision, mass, query/touch targets or extra rig joints. Preview assembly can explicitly update mounts after VictoryRig's manual pose pass. Keep that pose graph at its existing 15 R15 links.

Evolve CharacterColorService into the shared character appearance owner, updating its project mappings/startup references as necessary. It observes the two existing equip attributes and character lifecycle. Recolor only the declared original rig body parts; never all descendant MeshParts. Handle profile readiness, appearance-loaded ordering, replacement, rapid equip changes, player leave and descendants arriving late without leaking bindings.

Extend existing lobby party projections and result appearance snapshots with an optional costume ID. Preserve backward-compatible reads for old snapshots. Propagate through PartyClient/PartyModel/PartyService, PartyCharacterRenderer, MatchService/PostMatchResult and CelebrationAvatar/ResultsPodium/ResultProgress. Use the same assembler in InventoryPreview and color/emote previews, including the currently equipped outfit.

Asset acceptance: clean topology/normals, deliberate rounded silhouettes, no visible gaps or interpenetration in representative poses, stable face opening, no hand/grip obstruction, all six free body colors, visible team markers, no physics/gameplay changes, bounded part/triangle/texture cost. Inspect front/back/side, close-up and gameplay-distance views in Studio. Fix weak pieces before multiplying variants.

## 3. Real effect preview scene

Author a reusable compact preview stage under `ReplicatedStorage.Assets.Cosmetics.PreviewScene` in both places, with named origin, impact marker, camera framing and a restrained backdrop/ground. Clone it locally into Workspace only while previewing. No replicated gameplay objects, character teleports or match state changes are needed.

Introduce an explicit effect render scope containing its Workspace parent, camera basis, owned instances, animation registrations and cancellation. Preserve the existing default gameplay scope. Thread the optional scope through CosmeticEffectFactory, ParticleKit, Primitives and script-effect calls; register particle-only anchors as well as animated geometry. A preview owns one scope and cancels only that scope. Do not use a global current-target override or `Runtime.clear()` to close a preview.

Add a small shared camera lease owner for lobby page transitions, effect preview, arena vote and death. Existing modules keep their motion logic. Tokens prevent stale cleanup from resetting a newer owner; handle CurrentCamera replacement. Lobby preview suspends the lobby transition and PartyBackgroundController, then returns through the current page owner. Death, vote, results, onboarding, loading and teleport preempt preview.

Add preview state to EconomyMenuController and its existing back/close hierarchy. Back returns to the same item details and focus; menu close/eligibility loss destroys the scene. Use the existing named cursor/input suppression path, plus a scoped movement/jump input binding for the preview. Do not change WalkSpeed or server combat state. Replay is deliberate, bounded, and respects reduced motion/audio settings. Provide elimination-sound audition with one active sample at a time.

Keep ordinary model ViewportFrames for weapons/outfits. Use item-specific representative artwork on effect cards and the real scene for exact audition; remove generic HIT!/SFX! as the only description of a paid item.

## 4. Shared shop and inventory experience

Both server entry points already start EconomyService and CosmeticsService. LobbyApp and arena CombatMenu use the shared ShopClient, EconomyMenuController, ShopPage and EconomyMenuModals. Extend those shared paths; place wrappers supply only availability/camera context.

- Every visible offer opens details even if owned or unaffordable. Gate the purchase action, not inspection.
- Show the actual complete outfit prominently, readable name/rarity, complete contents, per-item owned badges, price and eligibility. Provide a clear default/outfit choice in inventory with a small equipped badge that does not obscure the model.
- Add explicit pending/error feedback for equip requests. Derive selection from authoritative replication, never optimistic ownership/equips.
- After confirmed acquisition, offer Equip and View inventory. Do not autoequip a purchase. Crate reveals offer the same handoff for newly owned usable items while preserving repeat-open behavior.
- Use one complete contents model for bundles; cap only card artwork, never the detail disclosure.
- Preserve the plum/ink, cyan, pink and yellow palette, current typography, safe areas, 44-pixel targets, controller focus and Reduced Motion behavior. Test short landscape phones, desktop and tablet. Retain existing portrait branches.
- Remove obsolete trail sections, placeholder launch offers and implementation-facing copy. Give every existing weapon skin a deliberate display name after inspecting its actual authored appearance; immutable IDs remain unchanged.

## 5. Season 1 completion

Keep season dates, XP thresholds, premium product identity and existing Bonks rewards. Add configurable cosmetic supplements to selected free/premium tiers, including real existing weapon/effect items and the two exclusive finale outfits. Distribute visible cosmetic milestones across the track, not only the final tier. Do not grant paid-pass-exclusive items through the free track.

Represent supplemental cosmetic rewards in season config with stable grant keys/revision metadata. BattlePassService remains the owner of claims and historical settlement. Record only completed supplemental grants alongside the existing season/history claim journal; compute eligibility from the existing claimed/unlocked track and premium entitlement. Backfill previously claimed eligible tiers once. On reward replacement, a new item/grant key can be earned without revoking old ownership or reissuing Bonks. Preserve partial-retry and rollover behavior.

Add a complete free/premium season browser with locked/unlocked/claimed states, previews, claims and a clearly disclosed premium purchase. Reuse the same reward presentation for season details and next-reward summaries. Make it reachable from both shops and the existing season status affordance. Keep reward choice changes in config.

## 6. Purchase correctness and platform readiness

- Bound Bonks purchase/crate requests using the existing ClientRequest conventions. Timeouts clear UI pending state without claiming the server failed to grant; late authoritative results reconcile once.
- Include product identity on restricted-crate compensation so the paid request completes correctly. Keep PolicyService gating, exact next-open odds, pity and durable receipt acknowledgement.
- Separate sale visibility from historical fulfillment lookup. Retired/hidden product identities must still fulfill charged receipts and reconcile owned passes. Preserve boosts' entitlement-readiness behavior.
- Unify rotation eligibility predicates, including explicit item opt-ins; do not reroll unrelated stored offers after a purchase. Revalidate stale offer eligibility without changing accepted paid receipt grants.
- Preserve existing real Marketplace product/pass IDs and client regional-price metadata. Inspect current sale state in the same experience used by the two connected places. Prepare missing outfit-bundle and effect-collection platform definitions with concrete contents. Activate only after authored content and fulfillment validate.
- The user will handle final Creator Hub prices and sale activation. Keep that platform handoff in [shop-platform-release.md](shop-platform-release.md). Effects Crate should use the same baked 500-Bonk balance as the other crates; remove its unintended live 750-Bonk override in Creator Hub rather than introducing a code exception to live configuration.
- Real billing tests require an explicit account/amount at execution; do not spend the user's Robux implicitly. Report platform configuration or real-billing gates separately from code/Studio test success.

## 7. Verification and deployment

Run focused regressions per change, then the documented full Lune, lint and format checks once integrated. Extend pure specs for composed ownership/grants, eligibility, inventory/store projections, supplemental season settlement and preview cancellation. Add shared engine tests for both places covering authored costume/preview assets, appearance lifecycle, DirectPurchaseService, actual configured receipt grants and request completion.

Run Studio visual and interaction checks for lobby shop and arena menu shop: inspect → buy → authoritative ownership → equip → live gameplay → results → return/rejoin. Cover fresh/owned/partial-bundle/unaffordable/pending/off-sale/restricted states, duplicate notifications, interrupted requests and receipt retries. Test costume poses (throw, catch, hammer, dash, jump, ragdoll, respawn, victory); remote observers and party/result snapshots after player leave. Test preview cleanup during death/results/vote/teleport and simultaneous gameplay effects.

Asset/deployment gate: current checkout lacks a `.rbxl` under each `places/<place>` and lacks LFS setup. Never edit place contents with repository tooling or guess which root binary belongs to a place. Save/publish reviewed Studio assets through Studio, import correctly identified published bases only via `pull-places.sh`, and establish LFS tracking. Build both explicit projects and test the actual merged saved versions. The current deploy script publishes automatically after green cloud tests; `--test-only` does not test a newly built local artifact. Treat publishing as a final reviewed step, not a substitute for asset persistence.

Completion requires concrete evidence for both places, a clean source diff, asset identities/hierarchy documentation, test counts and captured visual QA. Any unavailable multiplayer, real-device, real-billing or deployment verification remains explicitly open; do not label those gates passed from fixtures.

## Work sequence

1. Composed costume catalog/ownership and one complete shared appearance path.
2. One polished outfit through all render surfaces; then author/refine the remaining capsule and stage.
3. Scoped effect playback and camera/input lifecycle; integrate real previews in both menus.
4. Universal details, purchase-to-equip handoffs and wardrobe refinement.
5. Configurable season supplements, backfill and complete season browser.
6. Receipt/rotation/platform lifecycle fixes, full content naming/disclosure and documentation reconciliation.
7. Both-place asset/visual/gameplay tests, complete repository checks and reviewed persistence/deployment handoff.

Independent work can proceed in parallel after this plan: core appearance/ownership, scoped previews, season fulfillment/UI, and Studio art. Shared catalog and menu integration changes must be coordinated to avoid competing owners or edits.
