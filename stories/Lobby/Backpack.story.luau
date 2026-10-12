--[[
    The Backpack (InventoryPage) on each of its tabs -- OUTFITS, SKINS, EFFECTS, EMOTES -- over a
    save that owns the Showtime pass emotes plus one real item of every rarity
    (Fixtures.inventoryData). The page is full-viewport with live 3D previews, so tabs are picked
    with the chips; the page's own tab pills switch too. Equipping is live local state (tap a card
    to equip, tap again to unequip) through InventoryModel.nextEquip, so the pink equipped ring and
    check sticker can be exercised. Hover a card for the yellow ring and the preview animation.

    The EMOTES tab includes the Backpack emote wheel; its sizes and states are laid out in
    EmoteLoadout.story. Migrated from InventoryPage.story (which opened on EMOTES only).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = StoryRoot.React
local InventoryPage = require(StoryRoot.Components:WaitForChild("InventoryPage"))
local InventoryModel = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("InventoryModel")
)

local c = React.createElement

local function Page(props: { Tab: string })
	local tab, setTab = React.useState(props.Tab)
	local data, setData = React.useState(Fixtures.inventoryData)
	return c(InventoryPage, {
		Data = data,
		SelectedTab = tab,
		OnTabChanged = setTab,
		OnInspect = Fixtures.log("Backpack", "OnInspect"),
		OnLockedSlot = Fixtures.log("Backpack", "OnLockedSlot"),
		OnEquip = function(entry)
			local equipped = table.clone(data.Cosmetics.Equipped)
			equipped[entry.category] = InventoryModel.nextEquip(entry, equipped)
			setData({ Bonks = data.Bonks, Cosmetics = { Owned = data.Cosmetics.Owned, Equipped = equipped } })
		end,
	})
end

return StoryRoot.story({
	Title = "Backpack",
	Summary = "InventoryPage on every tab over a save owning each rarity; equip is live.",
	Mode = "Switch",
	States = {
		{
			Name = "Outfits",
			Note = "Colours (swatches) and costumes.",
			Screen = true,
			Element = c(Page, { Tab = "OUTFITS" }),
		},
		{ Name = "Skins", Note = "Dodgeball and hammer skins.", Screen = true, Element = c(Page, { Tab = "SKINS" }) },
		{
			Name = "Effects",
			Note = "Impacts and elimination sounds (effect seals).",
			Screen = true,
			Element = c(Page, { Tab = "EFFECTS" }),
		},
		{
			Name = "Emotes",
			Note = "Showtime emotes + the emote wheel.",
			Screen = true,
			Element = c(Page, { Tab = "EMOTES" }),
		},
	},
})
