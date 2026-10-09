--[[
    The Backpack's emote loadout editor (BackpackEmoteWheel): the radial wheel used when the
    Backpack content is at least WheelMinWidth wide, and the wrapped slot grid used on compact
    widths, side by side. Four slots are filled (Fixtures.EmoteSlots), capacity is 6, so slots 7+
    show the lock. Selecting a slot is live.

    States: RADIAL (760 wide, slot 2 selected, an emote waiting to be placed -- "PICK A SLOT"),
    RADIAL IDLE (nothing selected), COMPACT GRID (420 wide) and ERROR (the pink hint line after a
    failed assignment). The component also subscribes to the live EmoteWheelController; the story
    passes WheelSnapshot so the controller's data is never used.

    Migrated from BackpackEmoteWheel.story (ContentWidth / Compact attributes -> states).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local BackpackEmoteWheel = require(StoryRoot.Components:WaitForChild("BackpackEmoteWheel"))

local c = React.createElement

local function Loadout(props: {
	ContentWidth: number,
	Compact: boolean?,
	Selected: number?,
	Pending: boolean?,
	ErrorText: string?,
})
	local selected, setSelected = React.useState(props.Selected)
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Padding = c(
			"UIPadding",
			{ PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20), PaddingTop = UDim.new(0, 12) }
		),
		Layout = c("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Wheel = c(BackpackEmoteWheel, {
			LayoutOrder = 1,
			HeaderHeight = 42,
			ContentWidth = props.ContentWidth,
			Compact = props.Compact,
			ColorId = Fixtures.Appearance.ColorId,
			CostumeId = Fixtures.Appearance.CostumeId,
			SelectedSlot = selected,
			PendingEmote = if props.Pending then { displayName = "Confetti Twirl" } else nil,
			ErrorText = props.ErrorText,
			WheelSnapshot = { slots = table.clone(Fixtures.EmoteSlots), capacity = Fixtures.EmoteCapacity },
			OnSelectSlot = setSelected,
			OnAssign = Fixtures.log("EmoteLoadout", "OnAssign"),
			OnLockedSlot = Fixtures.log("EmoteLoadout", "OnLockedSlot"),
		}),
	})
end

return StoryRoot.story({
	Title = "Emote loadout",
	Summary = "BackpackEmoteWheel radial vs compact grid, with pending, idle and error hints.",
	States = {
		{
			Name = "Radial",
			Note = "Slot 2 selected, emote waiting.",
			Size = Vector2.new(800, 340),
			Element = c(Loadout, { ContentWidth = 760, Selected = 2, Pending = true }),
		},
		{ Name = "Radial idle", Size = Vector2.new(800, 340), Element = c(Loadout, { ContentWidth = 760 }) },
		{
			Name = "Compact grid",
			Note = "Phone width.",
			Size = Vector2.new(460, 420),
			Element = c(Loadout, { ContentWidth = 420, Compact = true, Selected = 1 }),
		},
		{
			Name = "Error",
			Size = Vector2.new(800, 340),
			Element = c(
				Loadout,
				{ ContentWidth = 760, Selected = 3, ErrorText = "COULDN'T SAVE YOUR WHEEL. TRY AGAIN." }
			),
		},
	},
})
