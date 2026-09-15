# Ouch! Candy UI

The Backpack uses cream sticker surfaces, bright candy controls, plum outlines, and the original Ouch! swirl. The original logo, authored character, cosmetic assets, ownership rules, four tabs, category names, and server equip requests remain in place.

## Tokens

`src/shared/UI/Tokens.luau` owns the palette, reusable geometry, type, timing, and stage settings.

| Family | Values |
| --- | --- |
| Backdrop | Sky `#9ED9FF` → lilac `#C9C2FF` → pink `#F9C6EC` |
| Surfaces | Cream `#FFF9F2`, white `#FFFFFF`, well `#EAF1FF`, well outline `#C9D6F5` |
| Ink | `#2E2A4A`; secondary `#4A4470` |
| Candy | Pink `#FF4F9A`, yellow `#FFD54A`, cyan `#3ED3FF`, lime `#B6F04A`, orange `#FF8C42`, grape `#A667FF` |
| Geometry | Panel radius 28; card radius 20; full pills; outlines 6/4/3; lip 6; hard shadow offset 6,8 at 25% opacity |
| Wonk | Frame −1.5°; title −3°; tabs ±2°; badges −10°. Grid positions stay straight. |
| Type | Built-in Fredoka One display, Builder Sans ExtraBold labels, Roboto Condensed for compact navigation. Title 52, section 30, tab 26, label 22, body 20, minimum 18 logical pixels. |
| Motion | Open .35 s, tab .25 s, press .08 s, stamp .3 s, item stagger .04 s; hover 1.05, press .94; 12-piece equip burst |

## Puffy recipe

`PuffyButton` keeps a stable input hitbox around an animated visual. Draw the hard offset shadow, darker lip, inset fill, and a white fading top highlight; finish with a rounded ink or white outline. Shadows are disabled inside the scroll well. `PanelFrame` tilts only its decorative face so the unrotated scrolling content can clip correctly.

Reusable components: `PuffyButton`, `TabPill`, `ItemTile`, `PanelFrame`, `SectionHeader`, `Badge`, and `BackpackEmoteWheel`. The existing `EmoteSlotRail` module remains as its compatibility entry point. The separate gameplay wheel is unchanged.

## Existing rarity, clearer indication

The existing inventory already defines **Common, Rare, Legendary, and Exclusive**. Each cosmetic tile shows its tier as a named ribbon: mint, yellow, coral, or grape respectively. These colors follow the existing tier cues in a softer palette. The label communicates rarity without relying on color alone. The tile stays pale, preserving contrast with the yellow selection ring and pink equipped ring. Outfit colors remain actual color swatches. No tiers, drop rates, prices, or ownership data were added.

## Tile state matrix

| State | Presentation and behavior |
| --- | --- |
| Default | Pale tile or outfit swatch, top highlight and lip, large preview, plum name pill |
| Hover / keyboard focus | Yellow outline and bounce; emote loops and effect accents play on hover |
| Pressed | Visual squashes to .94; input hitbox stays fixed |
| Selected emote | Pulsing yellow outline; wheel asks for a slot |
| Equipped / assigned | Pink ring and stamped yellow check or slot-number sticker |
| Locked, when supplied | Muted fill, lock badge, price label, Shop hint; activation delegates to Shop |
| New, when supplied | NEW sticker clears on first hover |

The owned-inventory feed does not invent locked or new entries. Those optional component states are ready for callers that supply them.

## Interaction and layout

Desktop has eight numbered radial slots. Click an emote then a slot, choose a slot first, or drag an emote onto a slot. Selecting the same assigned emote and slot clears it. Narrow layouts use two columns of large slot buttons and normal vertical scrolling. All eight numbers and the server's slot-capacity checks are retained.

Accepted equips trigger confetti and a small podium hop. Ball skins pop into the character's hand; emote assignments give a brief character reaction. The desktop podium supports drag rotation. Reduced-motion preferences suppress decorative bursts, pop animations, crown bob, and drifting accents. Existing audio feedback is reused; no new sounds or external assets are required.

Portrait prioritizes the scrolling Backpack and its item previews; the floating world nameplate is suppressed to keep the title clear. Desktop and 4:3 retain the large world character and candy podium.

## Review and validation

Open [.review/candy-backpack/index.html](.review/candy-backpack/index.html) for all four before/after captures at 1920×1080, portrait and 4:3 captures, and a 19-second recording of actual menu interactions. Screenshots are from Studio, not mockups. The video records the visible Studio viewport at 1220×686 and 20 fps.

Validation includes the existing 806-test Lune suite, Selene, StyLua, Rojo builds, live text-fit checks, real color/ball equips, click-click assignment, desktop drag assignment, and restoration of the original loadout. Physical touch hardware and a physical gamepad have not been tested; portrait is a Studio device simulation.

Visual reference: [lead artist's launch-era UI comparison](https://www.artstation.com/artwork/P6Xmv8). The implementation uses native Roblox UI/parts, available built-in fonts, and existing Ouch! assets; no Fall Guys artwork, logos, fonts, characters, or sounds were imported.


## Shop and connected economy UI

The approved Backpack is the baseline for the Shop, item inspection, crate odds/results, season rewards, daily rewards, purchase notifications, and effect/sound audition controls. [SHOP_REDESIGN_PLAN.md](SHOP_REDESIGN_PLAN.md) records the implementation spec written before this extension. Reuse these rules across future UI work; do not choose a fresh palette or panel style for each screen.

## Loading and teleport screens

Every loading surface is one component, `LoadingScreen`, drawn on `LoadingBackdrop`: the lobby's sky-to-pink gradient with the faint swirl tile and slow confetti drift, so the trip from lobby to arena and back never leaves the candy world. The cropped OUCH! logo bobs above a cream `CandyPanel` whose decorative face tilts while the copy stays upright: an optional yellow kicker pill names the queue (ARENA PVP / SPLASHDOWN), the status is a plum Fredoka title with a Builder Sans detail line, and the meter is either a `CandyProgressBar` with scrolling stripes (asset preload, then the roster count while the server waits for everyone) or three hopping pink/yellow/cyan dots when nothing can be measured. Failure states put a pink puffy primary and a pale secondary in the panel, with gamepad focus on the primary. A cream tip sticker with a yellow TIP chip sits at the bottom; race servers rotate `Config.Interface.Loading.RaceTips` instead of the brawl tips. `Loading.Layout` owns the geometry, with compact values for narrow or short safe areas and the logo dropping when actions must fit a short screen.

Static teleport screens (the GUI carried through a teleport) render with `Static = true`: no pop, bob, drift or stripe motion, the dots at rest, no tip, so the captured snapshot is complete. Reduced motion holds every animation the same way. The `OnPresented` handshake, gamepad focus restore and fade timings are unchanged from the previous screen.

### Shared primitives

| Component | Use |
| --- | --- |
| `LoadingBackdrop` | Full-screen candy gradient, swirl and confetti for loading and transition screens; `Static` freezes the drift |
| `CandySurface` | Common puffy fill, highlight, lip, and outline recipe used by `PuffyButton` and Shop cards |
| `CandyPanel` | Cream outer shell; decorative face tilts while content, refs, and scrollers stay upright |
| `CandyTitle` | Pink measured title sticker; keep a reserved title band clear of Close/Back |
| `RarityRibbon` | Named existing rarity or explicit product type; never invent a rarity for a currency pack or mixed bundle |
| `CandyProgressBar` | Plum-edged pink striped progress; clamp to actual progress |
| `ShopPriceButton` | Pink primary, cream secondary, muted unavailable; currency and quantity remain legible together |
| `EconomyPalette` | Compatibility roles derived from `Tokens`, not another independent palette |

| `QueuePicker` | Row of candy pills for the lobby's matchmaking queue (ARENA PVP / SPLASHDOWN); the chosen queue is pink, the rest cream, and only an idle party leader can press them |

`BackpackTitle` and `PanelFrame` retain the approved Backpack composition. New economy surfaces share their tokens and puffy recipe through the components above. Do not replace the legacy `OuchPanel` globally: other UI families still use it.

### Storefront composition

`ShopComposition` promotes the existing season product into the first featured position, exactly once, including when premium is owned. Remaining featured offers wrap before the general catalog. `CandyShopConfig` and `Tokens.Shop` own sizing and section roles; `ShopLayout` packs measured blocks on twelve tracks.

Wide layouts pair a four-track season card with an eight-track featured offer, then arrange passes, For You, crates, and Bonks in neighboring blocks. Medium widths keep two lanes where each block fits. Portrait uses full-width cards when two readable cards will not fit. Short landscape switches to shorter artwork-and-copy cards. Section height comes from real card count; empty sections collapse and unknown sections remain reachable. Countdown ticks must not reorder the catalog.

Featured/season and currency cards may split art from copy; cosmetics and crates keep a larger art band. Cards remain pale. Rarity/product badges and OWNED stickers are separate. A yellow selection outline means selection, while premium access is labeled explicitly in the season flow. Names and prices never inherit rarity colors as their only meaning.

### Modal and reward rules

Keep the preview, content browser, and action footer separate. Measure title bands and reserve footer space before allocating scrolling content. Phone crate inspection starts with the odds browser; selecting an outcome exposes its preview. It does not change or guarantee the next result.

Crate odds use existing per-item current/base probabilities, guarantees, and duplicate refunds. A group may say “each” only when every member has the same value. A duplicate result retains the item name plus an explicit refund label. Season tiles distinguish claimed, ready, tier-locked, and premium-required states. Preserve existing purchase/equip/claim callbacks and modal return context.

Use pink for primary actions, cream for secondary navigation, plum text on pale surfaces, and at least 44 logical pixels for interactive targets. The compact Lobby summaries retain their existing footprint; full details belong in the corresponding modal. Existing sounds and authored item assets remain the source of previews.

### Evidence and coverage

The [Shop review gallery](.review/candy-shop/index.html) contains real Studio captures and a recording. The [validation report](.review/candy-shop/VALIDATION.md) distinguishes rendered states from source-reviewed states. The final suite has 813 passing tests, including season composition, odds summaries, and the short-layout width regression. Both places build.

Fixture rendering was blocked by the Studio tool's React capability restriction. Single/batch reveals, transaction notifications, and pending/claim failure variants are implemented and source-reviewed but were not visually validated in this session. Physical touch/gamepad and expanded preferred-text-size coverage also remain unverified. Do not treat those states as visually approved merely because this style guide exists.
