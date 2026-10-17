--[[
    Item inspection: ShopDetailsModal opened on each kind of Shop card, built from the real
    ShopViewModel (Fixtures.economy). One card at a time via the chips (each is a full-viewport
    modal with 3D previews).

    States: CRATE (EffectsCrate: the odds grid -- Shop/CrateOddsGrid -- with its collectible odds
    tiles and preview pane), CRATE UNAFFORDABLE (0 Bonks), CRATE PENDING (purchase in flight),
    CRATE RESTRICTED (paid random blocked), BONKS OFFER (DodgeBall19 for Bonks), ROBUX OFFER
    (DodgeBall1), and the first game pass, Bonks product and bundle cards the catalog builds. A
    card the catalog does not produce shows a notice instead.

    FocusEnabled is off (the modal's gamepad focus path reads Players.LocalPlayer, nil in edit
    mode). Purchases only print. CrateOddsGrid is covered here inside the crate state rather than
    standalone: its Layout/Odds props are produced by ShopDetailsLayout for this modal.
    Migrated from ShopDetailsModal.story (PreviewState / CardId attributes -> states).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local ShopDetailsModal = require(StoryRoot.Components:WaitForChild("ShopDetailsModal"))

local c = React.createElement
local log = Fixtures.log

local function firstCard(model: any, prefix: string): any
	local ids = {}
	for id in model.byId do
		if string.sub(id, 1, #prefix) == prefix then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return if ids[1] then model.byId[ids[1]] else nil
end

local function details(state: string, pick: (any) -> any): any
	local model, _, data = Fixtures.economy(state)
	local card = pick(model)
	if card == nil then
		return StoryRoot.Notice("The catalog builds no card of this kind right now.")
	end
	return c(ShopDetailsModal, {
		Visible = true,
		FocusEnabled = false,
		Card = card,
		Owned = data.Cosmetics.Owned,
		Equipped = data.Cosmetics.Equipped,
		BusySlots = {},
		OnClose = log("ShopDetails", "OnClose"),
		OnPurchaseBonks = log("ShopDetails", "OnPurchaseBonks"),
		OnPurchaseRobux = log("ShopDetails", "OnPurchaseRobux"),
		OnPreviewEffect = log("ShopDetails", "OnPreviewEffect"),
		OnEquipItem = log("ShopDetails", "OnEquipItem"),
		OnViewInventory = log("ShopDetails", "OnViewInventory"),
	})
end

local function byId(id: string): (any) -> any
	return function(model)
		return model.byId[id]
	end
end

local function prefixed(prefix: string): (any) -> any
	return function(model)
		return firstCard(model, prefix)
	end
end

return StoryRoot.story({
	Title = "Item inspection",
	Summary = "ShopDetailsModal on crate, offer, pass, product and bundle cards from the real catalog.",
	Mode = "Switch",
	States = {
		{
			Name = "Crate",
			Note = "EffectsCrate odds grid + preview.",
			Screen = true,
			Element = details("Ready", byId("Crate:EffectsCrate")),
		},
		{
			Name = "Crate unaffordable",
			Note = "0 Bonks.",
			Screen = true,
			Element = details("Unaffordable", byId("Crate:EffectsCrate")),
		},
		{
			Name = "Crate pending",
			Note = "Purchase in flight.",
			Screen = true,
			Element = details("Pending", byId("Crate:EffectsCrate")),
		},
		{
			Name = "Crate restricted",
			Note = "Paid random blocked.",
			Screen = true,
			Element = details("Restricted", byId("Crate:EffectsCrate")),
		},
		{
			Name = "Bonks offer",
			Note = "DodgeBall19 for Bonks.",
			Screen = true,
			Element = details("Ready", byId("Cosmetic:DodgeBall19")),
		},
		{
			Name = "Robux offer",
			Note = "DodgeBall1.",
			Screen = true,
			Element = details("Ready", byId("Cosmetic:DodgeBall1")),
		},
		{ Name = "Game pass", Screen = true, Element = details("Ready", prefixed("GamePass:")) },
		{ Name = "Bonks product", Screen = true, Element = details("Ready", prefixed("Product:")) },
		{ Name = "Bundle", Screen = true, Element = details("Ready", prefixed("Bundle:")) },
	},
})
