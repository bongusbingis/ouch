# OUCH! UI design tokens

The single source of stylistic truth for every screen, HUD and modal. Values live in `src/config/Interface/UI.luau` (`ProgressionStyle`, `Radius`, `Well`, `Button`, `LobbyArtwork`, `Layout.PageSurface`, `Layout.WellSurface`) and `src/config/Interface/ArenaPresentation.luau`; this page explains what each value is for so a new element picks the existing token instead of inventing a number. Measured against the shipped artwork on 2026-09-10 (`.review/production/2026-09-10-redesign/assets/`).

## Palette

| Token | Hex | Role |
| --- | --- | --- |
| White | `#FFFFFF` | outlines, display lettering, body text |
| Ink | `#1E2024` | text strokes, name bands, dim scrims, icon tiles |
| Surface | `#252930` | locked / neutral fills |
| Raised | `#373D46` | neutral raised fill |
| Panel | `#14BDDA` | page panel and card face (cyan) |
| PanelRaised | `#35CCE7` | raised band on a Panel face |
| Claimed | `#1185CC` | inner container (well) fill, the darker blue |
| Disabled | `#54A9BE` | disabled control face |
| Track | `#6BDEEE` | progress track, secondary rows |
| Muted | `#DCE6EE` | disabled text |
| Cyan | `#14C0DE` | primary action |
| Pink | `#EF126F` | selected / emphasis action, the local player's row |
| Yellow | `#FFDC3E` | reward, currency, score |
| Green | `#9AE95B` | success |
| Shadow | `#000000` | every hard drop shadow |

A component never introduces a colour outside this table. Rarity colours (`Inventory.RarityColors`) appear only on item cards.

## Radius scale (`UIConfig.Radius`)

| Token | Px | Applies to |
| --- | --- | --- |
| Panel | 16 | page panels, modals, home cards, mode cards, HUD band, full scoreboard |
| Control | 12 | every button, inner container (well), tab, chip taller than 32 px, description band |
| Tile | 8 | anything nested inside a well or card: item cards, rows, day cells, icon tiles, name bands |
| Pill | height / 2 | only elements no taller than `PillMaxPx` (32): vote-count chips, progress bars, dots |

Nesting rule: an element inside a rounded container uses the next smaller step. Never a larger radius inside a smaller one.

## Construction

| Family | Outline | Shadow | Fill | Radius | Source |
| --- | --- | --- | --- | --- | --- |
| Page panel | white 4 px | black 4 px offset (+4, +4), hard edge | Panel | 16 | `assets/source/figma/page-panel-9slice.svg`, Figma node 63-6, 9-slice at `SliceScale 0.5`, `SliceCenter 40 40 984 600` |
| Well (`Components/Well.luau`) | white 2 px | black 4 px offset | Claimed | 12 | `assets/source/figma/well-9slice.svg`, Figma node 63-12, 9-slice at 0.5, `SliceCenter 32 32 480 288`; approved image `138307870774315` |
| Native button (`ButtonSurface`) | white 2 px (`Button.StrokePx`) | black 4 px (`Button.ShadowPx`) | Cyan / Pink / Disabled | 12 | nav buttons are the reference |
| Image button (action slice) | white ≈ 2 px | black ≈ 2.5 px | Cyan / Pink | 12 | `LobbyArtwork.Action.*` at `SliceScale 0.09` |
| Arena `Surface` | white 2 px | black 4 px | any | 16 panels, 12 controls (`Surface.ControlRadiusPx`), 8 tiles | shadow off for chips inside a band |
| HUD standings strip | white 2 px | black 4 px | Claimed | 12 | shared Figma Well; rows Ink 55 % / Pink 20 % for you, Tile radius |

Rows and cards inside a well stay flat (no second shadow).

The approved page image is `125378628790140`. Both panel images belong to group `291738800`; `RedesignArtwork.luau` is generated from approved, byte-matched gate records. Opaque cyan Arena surfaces at Panel radius use this page image. Controls, translucent overlays, progress fills and smaller nested rows retain native geometry where the simple shape is equivalent. Existing Shop offer cards are preserved as required by the brief. Circular emote-wheel geometry and small indicator dots are intentional shape exceptions, not button precedents.

## Slice scales

| Image | Token | Scale |
| --- | --- | --- |
| Page panel 9-slice | `Layout.PageSurface.SliceScale` | 0.5 |
| Well 9-slice | `Layout.WellSurface.SliceScale` | 0.5 |
| Action slice (image buttons, backpack tabs, loading actions, combat menu, onboarding) | `LobbyArtwork.Action.SliceScale` | 0.09 |

Never use the action slice as a panel; panels use the page panel construction.

## Type

| Role | Font | Size | Stroke |
| --- | --- | --- | --- |
| Display: page titles, section headers, buttons, scores | LuckiestGuy | title 42–48, section 24, button 28 (price 25), HUD 16–29 | Ink 0.045 scaled |
| Body | BuilderSansBold | 16–20 | Ink 0.02–0.03 scaled on arena surfaces |
| Caption floor | — | 16 px (`Text.CaptionMinPx`); HUD rows on short viewports 14 px | — |

## Spacing

Panel inset 16 px (12 on short viewports); well inset 12 px (`Well.InsetPx`); sibling gap 8 px; header band 72 px (48 short); touch target ≥ 44 px (`Interaction.MinTargetPx`); HUD edge 12 px, standings gap 8 px.

`WellScroll` keeps the image stationary around a scrolling child, inset 6 px to clear the outline and shadow. Content inside that child supplies its own row/grid padding.

## Icons

Use licensed Iconify glyphs: Phosphor Fill first, then Material Symbols Rounded. The 22 semantic icons render white on an Ink tile at Tile radius, with rarity expressed by the existing card and tile outline. Never use emoji or procedural dots/pills as effect icons. `Icon.luau` resolves a semantic name to an atlas image and rectangle; `tools/workflow.json` → `canonical_icons` records every source and rectangle.

The Phosphor atlas has 19 glyphs (MIT; image `125312270475689`), and the Material Symbols atlas has three (Apache-2.0; image `105358867565806`). Each cell is 192 px with a 160 px glyph and 16 px gutters. `tools/prepare_redesign_assets.py` reproduces the PNGs and provenance; it uses the canonical Iconify GitHub mirror when the public API is rate limited. Source hashes, notices and generated credits are retained. Candy Crash uses the cookie silhouette to communicate a confection; bubbles use `ph:circles-three-fill` because the rejected Material glyph read as a display device. `tools/sync_redesign_assets.py` accepts only approved matching bytes and verified underlying Image IDs, not the upload's Decal ID.

## Match HUD

Band top-centre (620 px max, Panel radius). Standings strip top-right: top three plus the local row (two rows on short viewports), beside the band when the safe area leaves `Standings.GapPx` of room, under it otherwise. Full board is hold-to-view (Tab / Select) or tap-the-strip on touch, never a cursor unlock. Touch emote button parks left of the combat toolbar, vertically centred with it.

Team scores fill proportionally toward the existing score target. The strip crowns the leader and highlights the local player. The full board retains all players: desktop uses side-by-side columns; narrow portrait stacks them in a scrolling well. Touch gets a 44 px close control. Releasing the hold, losing window focus or focusing a text box closes the keyboard board.
