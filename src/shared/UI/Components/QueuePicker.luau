-- Name: QueuePicker.luau
-- Author: Jack C.
-- Description: The lobby's matchmaking queue choice as a row of candy pills, one per enabled queue, with the selected queue in pink and the rest cream, so a party leader picks the arena brawl or the Splashdown race before pressing play.
-- Created: 2026-09-14

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local PuffyButton = require(script.Parent.PuffyButton)
local T = require(script.Parent.Parent.Tokens)

local c = React.createElement

export type Option = {
	id: string,
	title: string,
}

export type Props = {
	Options: { Option },
	SelectedId: string,
	Enabled: boolean,
	OnSelect: (queueId: string) -> (),
	Compact: boolean?,
	Native: { [string]: any }?,
}

return function(props: Props)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	local pills = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, if props.Compact then 6 else 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	local count = math.max(#props.Options, 1)
	local gap = if props.Compact then 6 else 8
	for index, option in props.Options do
		local active = option.id == props.SelectedId
		pills[option.id] = c(PuffyButton, {
			Text = option.title,
			TextSize = if props.Compact then T.Type.Minimum else T.Type.Body,
			Color = if active then T.Colors.Pink else T.Colors.Surface,
			LipColor = if active then T.Colors.PinkLip else T.Colors.WellLine,
			TextColor = if active then T.Colors.Surface else T.Colors.Ink,
			Enabled = props.Enabled,
			Shadow = false,
			Native = {
				LayoutOrder = index,
				Size = UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0),
			},
			OnActivated = function()
				if props.Enabled and not active then
					props.OnSelect(option.id)
				end
			end,
		})
	end
	return c("Frame", native, pills)
end
