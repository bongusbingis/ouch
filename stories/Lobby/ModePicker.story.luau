--[[
    Picking what to play. QueuePicker is the mode-card row (ARENA PVP / SPLASHDOWN) shown at its
    desktop size, its Compact phone size, Stacked (portrait, cards one above the other) and with
    picking disabled (a party member waiting on the leader). Selection is live in every frame.

    QueuePickerModal is the modal the Play page's mode button opens; it lays out from the camera
    viewport, so it is a Screen frame. FocusEnabled is off so it never grabs gamepad selection
    in Studio.

    Data: Fixtures.QueueOptions. Migrated from QueuePicker.story (Compact / Stacked attributes ->
    states) and QueuePickerModal.story.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local Components = StoryRoot.Components
local QueuePicker = require(Components:WaitForChild("QueuePicker"))
local QueuePickerModal = require(Components:WaitForChild("QueuePickerModal"))

local c = React.createElement

local function options(): { any }
	local list = {}
	for _, option in Fixtures.QueueOptions do
		table.insert(list, table.clone(option))
	end
	return list
end

local function Picker(props: { Compact: boolean?, Stacked: boolean?, Enabled: boolean?, CardHeight: number })
	local selected, setSelected = React.useState("Arena")
	return c(QueuePicker, {
		Options = options(),
		SelectedId = selected,
		Enabled = props.Enabled ~= false,
		Compact = props.Compact,
		Stacked = props.Stacked,
		CardHeight = props.CardHeight,
		Native = { Size = UDim2.fromScale(1, 1) },
		OnSelect = setSelected,
	})
end

local function Modal()
	local selected, setSelected = React.useState("Arena")
	return c(QueuePickerModal, {
		Open = true,
		FocusEnabled = false,
		Options = options(),
		SelectedId = selected,
		Enabled = true,
		OnClose = Fixtures.log("ModePicker", "OnClose"),
		OnSelect = setSelected,
	})
end

return StoryRoot.story({
	Title = "Mode picker",
	Summary = "QueuePicker at desktop / compact / stacked / disabled, then QueuePickerModal at the live viewport.",
	States = {
		{ Name = "Desktop", Size = Vector2.new(760, 260), Element = c(Picker, { CardHeight = 220 }) },
		{
			Name = "Compact",
			Note = "Phone row.",
			Size = Vector2.new(420, 200),
			Element = c(Picker, { Compact = true, CardHeight = 160 }),
		},
		{
			Name = "Stacked",
			Note = "Portrait column.",
			Size = Vector2.new(360, 440),
			Element = c(Picker, { Stacked = true, CardHeight = 180 }),
		},
		{
			Name = "Disabled",
			Note = "Member waiting on the leader.",
			Size = Vector2.new(760, 260),
			Element = c(Picker, { Enabled = false, CardHeight = 220 }),
		},
		{ Name = "Modal", Screen = true, Element = c(Modal) },
	},
})
