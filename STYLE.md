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
| Motion | Open .35 s, tab .25 s, press .08 s, release .16 s, stamp .3 s, item stagger .04 s; hover 1.05, press .94; 12-piece equip burst |

## Puffy recipe

`PuffyButton` keeps a stable input hitbox around an animated visual. Draw the hard offset shadow, darker lip, inset fill, and a white fading top highlight; finish with a rounded ink or white outline. Shadows are disabled inside the scroll well. `PanelFrame` tilts only its decorative face so the unrotated scrolling content can clip correctly.

Reusable components: `PuffyButton`, `TabPill`, `ItemTile`, `PanelFrame`, `SectionHeader`, `Badge`, and `BackpackEmoteWheel`. The existing `EmoteSlotRail` module remains as its compatibility entry point. The separate gameplay wheel is unchanged.

Button hover, press, and release share one cancellable Cubic Out tween for scale, rotation, and lip compression. Inside a `ScrollingFrame` with `ClipsDescendants` enabled, hold button faces and other animated UI at their authored rotation while preserving scale, position, transparency, and lip motion; Roblox does not reliably clip descendants whose rotation changes. Retarget from the current visual and finish exactly at rest; do not use elastic or repeated bounce easing on text-bearing controls. `Motion.Control` and `Motion.Navigation` use near-critical damping with overshoot clamped, including toolbar buttons and sliding selections. Reduced motion still applies immediately.

## Lobby navigation

`LobbyNavigation` is the lobby-only connected white capsule with lilac dividers, a violet rim, and the supplied home, cart, backpack, and gear sprites. `Tokens.LobbyNavigation` owns its geometry, palette roles, asset IDs, and transparent-padding crops. The home tab reads **PLAY** and retains the existing `SplashScreen` route.

The selected tab rises into a pink pillow with narrower shoulders, a wider rounded base, curved white highlights, violet depth, enlarged icon, white outlined label, and two yellow emphasis marks. `LobbySelectionPillow` uses the editable mask atlas in `assets/source/ui/lobby-navigation-selection.svg`. Selection blends with `Motion.Navigation`; `AnimatedButton` supplies the established hover, press, focus, sound, and cancellation behavior. Selection and interaction never move the input hitboxes. Reduced motion applies the selection immediately. Decorative stars/marks are not notification badges.

Desktop expands the rail only inside the existing logo/party clearance and header reservation. Compact layouts retain the existing reflow and use condensed 18-pixel labels, fixed touch targets of at least 44 pixels, and smaller icons. The other pages, logo, background band, party/emote actions, and Arena navigation retain their existing presentation and behavior.

On mobile, `LobbyHeaderLayout.resolveMobile` docks navigation in the free portion of `GuiService.TopbarInset`, vertically centered with Roblox's controls. Wide phones retain labeled tabs; narrow portrait phones use four 44-pixel icon-only targets, as explicitly approved. If even four targets cannot fit beside CoreGui, use one labeled row below it rather than shrinking the targets or covering Roblox controls. Omit the extra mobile logo row and size the patterned band to the selected pillow's actual clearance. The existing overflow-enabled lobby root preserves modal input ownership; do not introduce a navigation portal above modal layers. Desktop and Arena navigation are unchanged. Shop uses the same mobile header reservation to grow upward into the recovered space while retaining its existing width and character-preview window.

## Splash and game modes

Lobby page entrances use the shared `Motion.LobbyPages` presets and cancellable `PageTransition` phases. Shop rises with a small scale swell, then seats into place; Settings slides from the right and settles horizontally; Play brings its progression panel in first with the action card trailing slightly. Each uses a finite Cubic arrival and short settle with no oscillating tail. Backpack retains its approved page spring and panel pop. Interruptions retarget from the current visual and cancel obsolete settle phases; reduced motion applies the final layout immediately. Content remains upright, and settled dimensions and spacing are unchanged.

Season is the default, leftmost progression tab, followed by Quests and Daily. After the initial quest snapshot, a changed UTC daily quest key automatically opens Quests so the newly assigned set is visible; progress and claim updates within the same cycle do not change the player's tab. The tab rail leaves a 12-pixel clear gap before every tab's content, reduced to 8 pixels only in compact layouts so one complete quest remains visible above the action dock. Its outer panel fits the existing season summary without scaling its title, XP bar, tier, or reward buttons. Daily also fits its summary; Quests expands into the available height and retains full progress/reward/claim rows. The mode, Play, Join Party, and Invite card follows directly below the active panel, using the same height binding for a smooth transition. `Tokens.Splash` and `SplashLayout` own the content budgets, spacing, and unchanged party camera window. Compact layouts cap the panel to the available space and scroll its contents; reward buttons open the established detail flows.

With Season or Daily active and a mode selected, desktop expands the mode row into an artwork card using up to 60% of the spare column height, capped at 188 px. Its name, artwork, and Change action morph with the shared control spring; the existing queue description appears when there is enough height. Play and party buttons move with the card while retaining their sizes. Quests, an unselected mode, and compact layouts use the existing small mode control. `Tokens.Splash` owns the expansion budget and artwork proportions.

Game modes appear only after **Select Mode**, **Change** (desktop), or **Mode** (compact). `QueuePickerModal` uses the shared cream panel, modal spring, focus handling, and close/back routing. Each `QueuePicker` card has large cropped artwork, an upright title, the authoritative queue description, and a pink selected check. The whole card is the input target. Selection closes the picker and updates the named Play action through the existing party queue request; it never starts matchmaking.

An idle leader starts each lobby session with no selected mode: **Select Mode** is emphasized and **Play** is disabled. Opening or dismissing the picker does not choose a mode. Either card, including the server's internal default, must receive a successful queue response before Play unlocks. The choice persists across page visits within that party, and resets when the party or leader changes. Failed requests keep the picker available for retry. Party members display their leader's queue and remain read-only; queued/regrouping parties keep their existing Cancel action. Keyboard/controller focus starts on Select Mode, then the first card (focus is not selection).

`Tokens.ModePicker.PlaceholderArt` is `rbxassetid://87184300931227`. Each card renders an `ImageLabel` named `Artwork`; options can later provide their own `artwork` values. Both modes intentionally use this placeholder for now.

Keep splash copy short and functional, without slogans or decorative sayings. Preserve the authored moving swirl texture, drift, roll, and original podium. Only the splash tint changes to warm peach (`Tokens.Splash.BackdropColor`, `#FFD2AC`) through the existing page-color transition. The approved four-tab navbar retains its presentation.

See the [splash gallery](.review/candy-splash/index.html) and [validation report](.review/candy-splash/VALIDATION.md) for actual Studio captures and coverage limits.

The [Season-first layout review](.review/season-primary/VALIDATION.md) supersedes the earlier splash gallery's tab order and panel heights.

## Existing rarity, clearer indication

The existing inventory already defines **Common, Rare, Legendary, and Exclusive**. Each cosmetic tile shows its tier as a named ribbon: mint, yellow, coral, or grape respectively. These colors follow the existing tier cues in a softer palette. The label communicates rarity without relying on color alone. The tile stays pale, preserving contrast with the yellow selection ring and pink equipped ring. Outfit colors remain actual color swatches. No tiers, drop rates, prices, or ownership data were added.

## Tile state matrix

| State | Presentation and behavior |
| --- | --- |
| Default | Pale tile or outfit swatch, top highlight and lip, large preview, plum name pill |
| Hover / keyboard focus | Yellow outline and smooth lift; emote loops and effect accents play on hover |
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


## Splashdown course intros

Each course opens with three fixed camera compositions over nine seconds: an overview, a signature obstacle, and a finish reveal. `src/config/Interface/SplashdownIntro.luau` owns map-specific instructions, course-local camera positions, targets, and lenses. The shot list must follow the current course-authoring layouts. Camera and overlay sample the same server deadline; repeat snapshots and late loading do not restart the sequence. Short plum fades cover cuts, with no orbit, shake, or camera travel.

`SplashdownIntro` uses the shared `CandySurface`, `Tokens.CourseIntro`, and `Motion.popIn`: a cream lower-third, upright plum Fredoka title and Builder Sans instructions, yellow round pill, and three pink progress segments. Only the decorative face tilts. Copy stays visible across all three shots. Narrow and short layouts keep readable type; reduced motion suppresses the card pop. The race HUD, scoreboard, menu button, and touch controls clear for the intro and return for countdown, with the previous camera lens and touch-control setting restored.

The [intro review gallery](.review/splashdown-intro/index.html) and [validation report](.review/splashdown-intro/VALIDATION.md) separate actual Studio renders from untested conditions. New playable courses need their own copy and three shot compositions; the coverage spec checks that every course in `CourseOrder` has them.

## Shop and connected economy UI

The approved Backpack is the baseline for the Shop, item inspection, crate odds/results, season rewards, daily rewards, purchase notifications, and effect/sound audition controls. [SHOP_REDESIGN_PLAN.md](SHOP_REDESIGN_PLAN.md) records the implementation spec written before this extension. Reuse these rules across future UI work; do not choose a fresh palette or panel style for each screen.

## Settings

Settings uses the same cream candy panel and pink title sticker as the Backpack and Shop. Its single pale-blue scroll well holds upright yellow-striped section headings and cream puffy setting cards; row labels use plum Builder Sans, while controls keep the pink primary state and a yellow slider knob. Toggle, saving, focus, persistence, and asset-credit behavior are unchanged. Slider mouse/touch tracking starts inside its 44-pixel hit target, stays claimed outside the control, and ends only on release; vertical touch movement still yields to page scrolling. `Tokens.Settings` owns the page-specific spacing and control geometry, and all interactive targets remain at least 44 logical pixels.

## Arena HUD

Active matches use compact cream candy score bands, plum Fredoka/Builder Sans labels, pale team score wells, and pink/yellow action states. On touch devices, full standings open from a 44-pixel Scores button; the always-on player list is reserved for roomy desktop layouts. The two weapon choices use small puffy cards at the bottom, with the emote launcher beside them. The hammer action sits above the actual jump-button bounds. Touch exclusions follow the real controls, and decorative press motion never changes their hitboxes.

`Tokens.ArenaHUD` and `ArenaHUDLayout` own the full-screen geometry for combat and Splashdown. Use the free part of `GuiService.TopbarInset` for the score band and Menu/Scores controls where it fits, falling back below platform controls on narrow screens. Convert full-screen positions into each root's coordinate space once; do not apply the CoreUI inset again to bottom controls. Interactive controls still clear device cutouts and the home gesture area. The invisible dynamic-thumbstick input modifier is not selectable, preventing a selection outline around the whole movement region.

## Party modal

The Your Party modal uses the Settings family: a cream candy shell, floating pink title sticker, and one pale-blue well containing cream puffy party-code and member cards. Code visibility is a yellow secondary control; member removal is an orange destructive control. Plum Builder Sans labels replace the legacy outlined white text. `Tokens.PartyModal` owns its responsive geometry, including clearance around scrolling member-card strokes so clipped viewports keep every outline intact. Showing or hiding the code, leader-only removal, scrolling, close behavior, and keyboard/gamepad focus remain unchanged, with every action retaining a 44-pixel target.

The Join Party code-entry modal shares that cream shell and pink title sticker, with six cream puffy digit cards in a pale-blue well, plum labels, a pink Join action, and a cream Cancel action. A yellow card marks the next empty digit while typing. `Tokens.JoinCode` owns the visual geometry; `JoinCodeLayout` retains the native-keyboard avoidance and scroll budget. Keep the single transparent native text field over the decorative digits so paste, backspace, focus, and submit behavior stay intact. The title travels with the upright form when it must scroll above the keyboard, and outlines have inset clearance rather than touching the clipping boundary.

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

| `QueuePicker` / `QueuePickerModal` | On-demand artwork cards with queue descriptions and an explicit selected check; only an idle party leader can change queue |

`BackpackTitle` and `PanelFrame` retain the approved Backpack composition. New economy surfaces share their tokens and puffy recipe through the components above. Do not replace the legacy `OuchPanel` globally: other UI families still use it.

### Storefront composition

`ShopComposition` promotes the existing season product into the first featured position, exactly once, including when premium is owned. Remaining featured offers wrap before the general catalog. `CandyShopConfig` and `Tokens.Shop` own sizing and section roles; `ShopLayout` packs measured blocks on twelve tracks.

Wide layouts pair a four-track season card with an eight-track featured offer, then arrange passes, For You, crates, and Bonks in neighboring blocks. Medium widths keep two lanes where each block fits. Portrait uses full-width cards when two readable cards will not fit. Short landscape switches to shorter artwork-and-copy cards. Section height comes from real card count; empty sections collapse and unknown sections remain reachable. Countdown ticks must not reorder the catalog.

Card proportions follow the usable section width, not just the viewport. Pass and catalog cards fill their supported grid columns; at 320 px or wider they use a 220-pixel-tall artwork/copy split, while narrower cards retain the 270-pixel stacked showcase. Short landscape uses 176-pixel cards. A split card below 280 px wide falls back to the full 270-pixel stacked height so its artwork, name, and action cannot collide. Featured/season and currency cards otherwise retain their distinct proportions. Cards remain pale. Rarity/product badges and OWNED stickers are separate. A yellow selection outline means selection, while premium access is labeled explicitly in the season flow. Names and prices never inherit rarity colors as their only meaning.

Storefront category titles stay upright, with 6 px before the clipped striped underline and 12 px before the next card (including room for the thick outline). Countdown labels use Builder Sans and move to a separate line in narrow sections. Product and ownership chips have a 14-pixel layout gap, leaving 8 clear pixels between their outlines; wide cards share a badge row, while stacked cards reserve an artwork lane clear of OWNED. Hover remains active across the card body and footer. Clicking artwork or the name opens the same inspection as the footer, using separate hitboxes and one keyboard/controller focus target; purchases remain explicit inside inspection.

### Modal and reward rules

Keep the preview, content browser, and action footer separate. Measure title bands and reserve footer space before allocating scrolling content. Phone crate inspection starts with the odds browser; selecting an outcome exposes its preview. It does not change or guarantee the next result.

Season rewards use `Tokens.SeasonRewards` and `SeasonLayout` to reserve a title band, an inset tier/progress well, a separate reward browser, and a measured action footer. Free/Premium are upright, width-limited `TabPill` controls with a clear gap before the cards. Desktop pairs the selected preview with the browser; portrait opens that preview on selection; short screens put the track controls beside a horizontal card list. The selected tier starts on a complete grid row. Reward names use plum bands, with rarity ribbons and labeled claim/access states kept separate. Premium access uses a gold label, while a yellow outline identifies the selected reward. `TabPill.Tilt` and `CandyTitle.Tilt` allow upright controls in tight layouts without changing their defaults elsewhere.

The [season layout review](.review/season-rewards-layout/VALIDATION.md) records the updated desktop and phone captures and their coverage.

Crate odds use existing per-item current/base probabilities, guarantees, and duplicate refunds. A group may say “each” only when every member has the same value. A duplicate result retains the item name plus an explicit refund label. Season tiles distinguish claimed, ready, tier-locked, and premium-required states. Preserve existing purchase/equip/claim callbacks and modal return context.

Use pink for primary actions, cream for secondary navigation, plum text on pale surfaces, and at least 44 logical pixels for interactive targets. The compact lobby keeps Season first, scrolls progression content as needed, and reserves reachable Play actions. Daily and Season reward buttons open their existing detail modals. Existing sounds and authored item assets remain the source of previews.

### Evidence and coverage

The [Shop review gallery](.review/candy-shop/index.html) contains real Studio captures and a recording. The [validation report](.review/candy-shop/VALIDATION.md) distinguishes rendered states from source-reviewed states. The final suite has 813 passing tests, including season composition, odds summaries, and the short-layout width regression. Both places build.

Fixture rendering was blocked by the Studio tool's React capability restriction. Single/batch reveals, transaction notifications, and pending/claim failure variants are implemented and source-reviewed but were not visually validated in this session. Physical touch/gamepad and expanded preferred-text-size coverage also remain unverified. Do not treat those states as visually approved merely because this style guide exists.


## Splashdown onboarding

- Retain the authored TutorialArena, approach bridge, waypoint arrow and short lesson flow.
- Use the exact Splashdown/arena mesh assets in `assets/SplashdownTraining.rbxm`; the server clones them at the Splashdown authoring scale and uses the shared rotating-platform and shove kits. Do not replace them with generated primitive obstacles or add a new training map.
- The instruction surface is a compact cream candy prompt with upright Fredoka/BuilderSans text. Skip remains a separate yellow 44 px target. Use `Tokens.Onboarding`, `CandySurface` and `PuffyButton`.
- Validation is recorded in `.review/candy-onboarding/VALIDATION.md`. Visual review must use the actual Lobby Studio window.
