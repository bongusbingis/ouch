--[[
    The shop's modal stack wired the way the lobby wires it (EconomyMenuModals over a stub
    EconomyMenuController): it opens on the EffectsCrate details card; buying it with Bonks swaps
    to the crate reveal with one real outcome, and closing either modal clears it. Once both are
    closed a REOPEN chip brings the details card back. This is the one story that exercises the
    details -> reveal hand-off rather than each modal alone (see ShopDetails / CrateReveal).

    The stub controller only carries the fields EconomyMenuModals reads; previewItem stays nil, so
    the effect-preview scene (which portals into the local PlayerGui) never mounts. The module is
    required inside the story's component so a load failure shows in the frame, not as a broken
    story. Migrated from EconomyMenuModals.story (PreviewState attribute -> the Ready catalog).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React

local c = React.createElement

local function Story()
	local EconomyMenuModals = require(StoryRoot.Components:WaitForChild("EconomyMenuModals"))
	local built = React.useMemo(function()
		local model, _, data = Fixtures.economy("Ready")
		return { model = model, data = data }
	end, {})
	local model, data = built.model, built.data
	local card = model.byId["Crate:EffectsCrate"]
	local selected, setSelected = React.useState(card)
	local reveal, setReveal = React.useState(nil :: any)
	if selected == nil and reveal == nil then
		return c("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = StoryRoot.Tokens.Colors.Pink,
			Font = StoryRoot.Tokens.Type.Display,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(220, 56),
			Text = "REOPEN",
			TextColor3 = StoryRoot.Tokens.Colors.Surface,
			TextSize = 24,
			[React.Event.Activated] = function()
				setSelected(card)
			end,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	return c(EconomyMenuModals, {
		FocusEnabled = false,
		Controller = {
			selectedShopCard = selected,
			crateReveal = reveal,
			economyData = data,
			busySlots = {},
			closeSelectedShopCard = function()
				setSelected(nil)
			end,
			closeReveal = function()
				setReveal(nil)
			end,
			purchaseSelectedBonks = function()
				setSelected(nil)
				setReveal({ results = { card.odds[1] }, totalRefund = 0 })
			end,
			purchaseSelectedRobux = Fixtures.log("EconomyMenuModals", "purchaseSelectedRobux"),
			closePreview = Fixtures.noop,
			previewEffect = Fixtures.log("EconomyMenuModals", "previewEffect"),
			equipPreview = Fixtures.log("EconomyMenuModals", "equipPreview"),
			inspectReward = Fixtures.log("EconomyMenuModals", "inspectReward"),
			viewInventory = Fixtures.log("EconomyMenuModals", "viewInventory"),
		},
	})
end

return StoryRoot.story({
	Title = "Shop modal stack",
	Summary = "EconomyMenuModals: crate details -> buy with Bonks -> reveal -> close, on a stub controller.",
	States = {
		{ Name = "Details to reveal", Note = "Buy with Bonks to see the hand-off.", Screen = true, Element = c(Story) },
	},
})
