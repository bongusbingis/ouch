# Shop screen depth pass — decisions

Branch `feature/shop-depth`. Scope is the storefront only: `ShopPage`, `ShopSection`, `ShopCard`, the Shop tokens and two opt-in extensions to shared primitives. Layout packing, spans, card sizes, catalog data, prices, ownership, countdowns, the Get Bonks anchor and every callback are untouched. Inspection, crate, season and reward modals are out of scope.

## What is actually wrong

Looking at the live Studio shop next to the Backpack and the Play page, the flatness is not a missing shadow. It is that every card is built from the same three full-width capsules stacked on top of each other:

1. a full-width product/rarity bar with a 3 px ink outline (`SEASON PASS`, `FEATURED`, `PERMANENT`, `BONKS`, `CRATE`, `RARE`),
2. a full-width plum name band,
3. a full-width outlined price/action pill,

all inside a fourth outlined capsule (the card), all at the same visual level, with the artwork squeezed into the leftover third. At two lanes and six sections that is roughly fifty outlined capsules on one screen. Nothing overlaps anything, nothing is recessed, nothing is on top. That is why it reads as both flat and cluttered at once.

Three smaller things compound it:

- The card body is tinted 75 % toward white, so the puffy lip and highlight that give the Backpack its depth are invisible.
- The product-type bar is the first and widest thing on every card, but it mostly repeats the section title directly above it (`BONKS` under **BONKS**, `CRATE` under **CRATES**, `FEATURED` under **FEATURED**).
- The headline cards (season, featured) are built exactly like a 500-Bonks pack, so there is no hierarchy between "this is the offer" and "here is the catalog".

## Direction: give every card one hero and one layer order

Keep the panel, the pale well, the section headers, the packer and the card sizes. Change the anatomy inside each card so it uses the same layering the Backpack tile and the Play page already use:

```
cream puffy card (ink outline, lip)
  └ tinted artwork tile, recessed (accent fill, accent line, faint swirl)
      ├ rarity ribbon inside the tile (Backpack style)          — stacked cards
      └ plum name band hanging off the tile's bottom edge       — stacked cards
  ├ plum Fredoka name + Builder Sans supporting line             — split cards
  ├ the one outlined pill: the price / action button
  ├ product sticker, tilted, overlapping the top-left corner    (FEATURED, SEASON PASS, PERMANENT, WEEKLY BUNDLE, STARTER OFFER)
  └ OWNED stamp, tilted, overlapping the top-right corner
```

- **The artwork tile is the hero.** It is the only coloured area on a catalog card, it is the largest element, and in split cards it now takes 42 % of the width for the full card height instead of a 34 % strip under a badge row. The tile is drawn as an inset well (accent fill, accent-coloured 3 px line, the Backpack swirl at 95 % transparency), not as another outlined card, so the card gains an interior without gaining another ink rectangle.
- **One ink rectangle per card that is not the card.** The name band survives only where the Backpack uses it: hanging off the bottom of a stacked tile. In split cards the name is upright plum Fredoka on the cream body, the way the Play page's season panel and the season-rewards preview column already write names. The action button is the only outlined pill left, which is right because it is the only thing you press.
- **Product labels become stickers, rarity stays a ribbon.** `FEATURED`, `SEASON PASS`, `PERMANENT`, `WEEKLY BUNDLE` and `STARTER OFFER` are promotional or status labels, so they now render as small tilted `Badge` stickers overlapping the card's top-left corner, the same device the Backpack uses for `NEW!` and the equipped check. Rarity is still the named `RarityRibbon` from the Backpack: inside the tile on stacked cards, as a content-width kicker above the name on split cards. `OWNED` is a yellow tilted stamp at the top-right, separate from both, so ownership, rarity and promotion never share a slot.
- **Drop the labels that only restate the header.** Cards whose view model supplies no badge (plain crates in **CRATES**, packs in **BONKS**) no longer synthesise one from their kind. Every explicit badge the view model produces is still shown.
- **Hierarchy by tint.** Only the two headline blocks (the season card and the featured/bundle/starter promo) keep a pale accent on the card body. Every catalog card is cream, like Settings rows and season-reward cards in the same well. Cosmetic tiles take their rarity colour, which the plan explicitly allows as "an optional matching accent behind a large preview", so the For You rail reads mint / yellow / coral / grape at a glance while the ribbon still names the tier.
- **Title decoration.** The SHOP sticker gets the Backpack title's yellow star and cyan sparkle so the two lobby pages open the same way.

## Considered and rejected

- **Hard shadows on cards.** The style guide disables shadows inside scroll wells and the Backpack proves the lip/overlap recipe is enough. Shadows inside a scroller also smear during scroll.
- **Tinting every card body more strongly.** Fixes the invisible lip but makes six colours fight at once and removes the only hierarchy lever between headline and catalog. The tint moved into the tile instead.
- **Replacing the section headers with title stickers.** Six pink stickers per page would out-shout the page title. The shared `CandySectionHeader` stays; once the cards stop shouting, the headers read fine. The countdown chip stays plum so each block keeps one dark accent tying it to the outlines.
- **Removing the product badge entirely.** The plan requires a product-type badge for currency packs and mixed bundles so that no rarity is ever invented for them. Explicit badges stay, as stickers; only the kind-derived fallbacks that duplicated the header were dropped.
- **Moving the name band under the tile on split cards too.** Long names (`SEASON 1: FIRST SPLAT`, `STARLIGHT EFFECT`) need two lines beside a tall tile; a band there would just recreate the stacked-capsule problem sideways.
- **Entrance stagger per card.** Nice, but the storefront re-renders on refresh and resize and the style guide forbids restarting entrances on ticks; not a depth problem, left alone.

## Ambiguities I picked a side on

- **Sticker tilt.** Badges tilt −10°. A wide sticker at −10° pokes 4 px into the section underline above it (the 12 px header gap is pinned by tests), so product stickers use −6° via `Tokens.Shop.StickerTilt`; the OWNED stamp keeps the standard −10°. Tradeoff: two tilts in one card family; visually the difference is not readable.
- **Rarity kicker vs ribbon-in-tile on split cards.** The tile beside a copy column is ~110 px wide at the split threshold and `LEGENDARY` at the 18 px minimum does not fit, so split cards show the ribbon as a kicker above the name instead of shrinking the label. Stacked cards keep the Backpack placement.
- **Name font in the stacked band.** Backpack bands use Builder Sans; the old shop band used Fredoka. The stacked band now matches the Backpack, and the split name uses Fredoka as display copy. Same rule as the rest of the lobby: bands are labels, copy is display.

## What a reviewer should check in Studio

Desktop 1920×1080 and the 1176×864 Studio viewport (two lanes), phone portrait, and a 1024×500 landscape. Confirm: hover still turns the card outline yellow, clicking artwork/name/footer all open the same inspection once, Get Bonks still scrolls to the Bonks block, stickers never cover a name or a price, and OWNED cosmetics in For You still show both the rarity ribbon and the stamp.
