--[[
    The collectible card language (DESIGN-CARDS, .review/agent-workflow/tasks/RELEASE-001/
    DESIGN-CARDS/design.md): one cream card used by Backpack ItemTiles, crate results, crate odds
    tiles and stacked Shop cards. CollectibleFace draws the face -- a recessed art window tinted by
    rarity, the puffy rarity tag centred on the window's lower seam, the CAPS plum name and an
    optional footer -- and ItemTile wraps it in the puffy card body with its outline states.
    Every entry is a real catalog item (Fixtures.allEntries / rarityRow over Config.Cosmetics).

    States:
      Every rarity    -- Common, Rare, Legendary, Exclusive ItemTiles at the desktop card size.
      Tile states     -- default (ink outline), selected (yellow, pulsing), equipped (pink + ✓),
                         equipped emote in wheel slot 2, locked with a Bonks price, NEW! sticker.
                         HOVER is internal to ItemTile (yellow outline + art plays): hover any card.
                         Locked + hover shows the "GET IT IN THE SHOP" tooltip.
      Art kinds       -- 3D viewport (ball, hammer), animated avatar (emote, outfit), effect seal
                         (impact and elimination effects; hover plays the pop), colour swatch
                         (no tier tag, window tinted by the colour), and image art on a bare
                         CollectibleFace (the Bonks coin).
      Card sizes      -- the same Rare card at Backpack desktop (CardMax 232 / effects 180 /
                         emotes 170), compact landscape (InventoryCard 164, Compact badge) and
                         portrait (124, the narrow-panel minimum). Height = size + ExtraHeight.
      Face footers    -- CollectibleFace as crate results and odds use it: NEW ITEM, DUPE · +150
                         BONKS, odds tag "24%" in the tier colour with a BASE/DUPE footer, and the
                         yellow OWNED corner chip.

    3D previews need ReplicatedStorage.Assets (the place file's rigs and meshes); in a place without
    them those windows stay empty.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)
local Sheet = require(script.Parent.Sheet)

local React = StoryRoot.React
local Components = StoryRoot.Components
local T = StoryRoot.Tokens
local C = T.Colors
local c = React.createElement

local ItemTile = require(Components:WaitForChild("ItemTile"))
local CollectibleFace = require(Components:WaitForChild("CollectibleFace"))
local InventoryPreview = require(Components:WaitForChild("InventoryPreview"))
local CandySurface = require(Components:WaitForChild("CandySurface"))

local DESKTOP = T.Layout.CardMax
local COMPACT = T.LobbyLandscape.InventoryCard
local PORTRAIT = 124
local EXTRA = T.Collectible.ExtraHeight
local log = Fixtures.log("Collectibles", "card")

--> A cream card body (the ItemTile recipe, no button) with a face drawn on top. CandySurface takes
--> no children, so the face is its sibling.
local function body(faceElement: any): any
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Surface = c(CandySurface, {
			Color = C.SurfaceWarm,
			LipColor = C.WellLine,
			Radius = T.Shape.RadiusCard,
			Shadow = false,
			ZIndex = 1,
		}),
		Face = faceElement,
	})
end

--> The first non-default catalog entry of a category (nil if the catalog has none).
local function firstOf(category: string, rarity: string?): any?
	for _, entry in Fixtures.allEntries(category) do
		if not entry.isDefault and (rarity == nil or entry.rarity == rarity) then
			return entry
		end
	end
	return nil
end

local function tile(order: number, caption: string, entry: any?, size: number, props: { [string]: any }?): any
	if entry == nil then
		return Sheet.slot(order, `{caption} (NONE IN CATALOG)`, Vector2.new(size, size + EXTRA), nil)
	end
	return Sheet.slot(
		order,
		caption,
		Vector2.new(size, size + EXTRA),
		c(
			ItemTile,
			Sheet.merge({
				Entry = entry,
				CardSize = size,
				CardHeight = size + EXTRA,
				LayoutOrder = 1,
				ColorId = Fixtures.Appearance.ColorId,
				CostumeId = Fixtures.Appearance.CostumeId,
				OnActivated = function()
					log(entry.displayName)
				end,
				OnShop = function()
					log(`shop {entry.displayName}`)
				end,
			}, props)
		)
	)
end

local function EveryRarity()
	local cells = {}
	for index, entry in Fixtures.rarityRow("BallAssets") do
		table.insert(cells, tile(index, string.upper(entry.rarity), entry, DESKTOP))
	end
	return Sheet.sheet(cells)
end

local function TileStates()
	local entry = Fixtures.entriesByRarity("BallAssets").Legendary
	local emote = firstOf("EmoteAssets")
	return Sheet.sheet({
		tile(1, "DEFAULT", entry, COMPACT),
		tile(2, "SELECTED", entry, COMPACT, { Selected = true }),
		tile(3, "EQUIPPED", entry, COMPACT, { Equipped = true }),
		tile(4, "EQUIPPED · SLOT 2", emote, COMPACT, { Equipped = true, SlotIndex = 2 }),
		tile(5, "LOCKED · PRICE", entry, COMPACT, { Locked = true, Price = 750 }),
		tile(6, "NEW!", entry, COMPACT, { New = true }),
	})
end

local function ArtKinds()
	local swatch = nil
	for _, entry in Fixtures.allEntries("CharacterColor") do
		if not entry.isDefault then
			swatch = entry
			break
		end
	end
	local bonks = Sheet.slot(
		8,
		"IMAGE ART · FACE",
		Vector2.new(COMPACT, COMPACT + EXTRA),
		body(c(CollectibleFace, {
			Width = COMPACT,
			Height = COMPACT + EXTRA - T.Shape.LipHeight,
			Rarity = "Rare",
			Name = "500 Bonks",
			ZIndex = 6,
			Art = c("ImageLabel", {
				BackgroundTransparency = 1,
				Image = "rbxassetid://128078334031314",
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 7,
			}),
		}))
	)
	return Sheet.sheet({
		tile(1, "3D · BALL", firstOf("BallAssets"), COMPACT),
		tile(2, "3D · HAMMER", firstOf("HammerAssets"), COMPACT),
		tile(3, "AVATAR · EMOTE", firstOf("EmoteAssets"), COMPACT),
		tile(4, "AVATAR · OUTFIT", firstOf("CostumeAssets"), COMPACT),
		tile(5, "SEAL · IMPACT", firstOf("ImpactEffectAssets"), COMPACT),
		tile(6, "SEAL · ELIMINATION", firstOf("ElimEffectAssets"), COMPACT),
		tile(7, "SWATCH · COLOUR", swatch, COMPACT),
		bonks,
	})
end

local function Sizes()
	local entry = Fixtures.entriesByRarity("BallAssets").Rare
	local effect = firstOf("ImpactEffectAssets")
	local emote = firstOf("EmoteAssets")
	return Sheet.sheet({
		tile(1, `DESKTOP · {DESKTOP}`, entry, DESKTOP),
		tile(2, `DESKTOP EFFECT · {T.Layout.EffectCardMax}`, effect, T.Layout.EffectCardMax),
		tile(3, `DESKTOP EMOTE · {T.Layout.EmoteCardMax}`, emote, T.Layout.EmoteCardMax),
		tile(4, `COMPACT · {COMPACT}`, entry, COMPACT, { Compact = true, Equipped = true }),
		tile(5, `PORTRAIT · {PORTRAIT}`, entry, PORTRAIT, { Compact = true, Equipped = true }),
	})
end

local function face(order: number, caption: string, entry: any, props: { [string]: any }): any
	local width, height = 200, 268
	return Sheet.slot(
		order,
		caption,
		Vector2.new(width, height),
		body(c(
			CollectibleFace,
			Sheet.merge({
				Width = width,
				Height = height - T.Shape.LipHeight,
				Rarity = entry.rarity,
				Name = entry.displayName,
				ZIndex = 6,
				Art = c(InventoryPreview, {
					ItemId = entry.itemId,
					Category = entry.category,
					Definition = entry.definition,
					ColorId = Fixtures.Appearance.ColorId,
					CostumeId = Fixtures.Appearance.CostumeId,
					Playing = false,
					Candy = true,
					ZIndex = 7,
				}),
			}, props)
		))
	)
end

local function Footers()
	local legendary = Fixtures.entriesByRarity("BallAssets").Legendary
	local rare = Fixtures.entriesByRarity("BallAssets").Rare
	local common = Fixtures.entriesByRarity("BallAssets").Common
	return Sheet.sheet({
		face(1, "CRATE RESULT · NEW", legendary, { Footer = "NEW ITEM" }),
		face(2, "CRATE RESULT · DUPE", rare, { Footer = "DUPE · +150 BONKS" }),
		face(3, "ODDS TILE", legendary, {
			TagText = "24%",
			TagColor = T.Rarity.Legendary.Color,
			Footer = "BASE 24% · DUPE +400",
		}),
		face(4, "OWNED CORNER", common, { CornerText = "OWNED" }),
	})
end

return StoryRoot.story({
	Title = "Collectibles",
	Summary = "The collectible card: ItemTile in every rarity and state, each art kind, desktop/compact/portrait sizes, and CollectibleFace footers. Hover any card for the hover state.",
	States = {
		{
			Name = "Every rarity",
			Note = "Desktop card size, Common → Exclusive",
			Size = Vector2.new(1100, 320),
			Element = c(EveryRarity),
		},
		{
			Name = "Tile states",
			Note = "Default, selected, equipped, slot, locked, NEW — hover any card",
			Size = Vector2.new(1180, 250),
			Element = c(TileStates),
		},
		{
			Name = "Art kinds",
			Note = "3D viewport, avatar, effect seal, swatch, image",
			Size = Vector2.new(1180, 500),
			Element = c(ArtKinds),
		},
		{
			Name = "Card sizes",
			Note = "Desktop / compact landscape / portrait",
			Size = Vector2.new(1180, 320),
			Element = c(Sizes),
		},
		{
			Name = "Face footers",
			Note = "Crate results, odds tile, OWNED corner",
			Size = Vector2.new(1000, 340),
			Element = c(Footers),
		},
	},
})
