-- A world-space podium with screen-space nameplates; the scene owns its temporary camera lease.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Scene = require(script.Parent.Parent.Parent.Services.PostMatchScene)
local Colors =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation")).Colors
local Label = require(script.Parent.Label)
local Surface = require(script.Parent.Surface)
local c = React.createElement

return function(props)
	local region = React.useRef(nil)
	local entries = props.Entries or {}
	local identity = {}
	for _, entry in entries do
		table.insert(
			identity,
			table.concat({
				entry.playerId,
				tostring(entry.placement),
				entry.colorId or "",
				entry.costumeId or "",
				entry.emoteId or "",
			}, ":")
		)
	end
	React.useEffect(function()
		return Scene.create(entries, region.current)
	end, { props.ResultId, table.concat(identity, "|") })
	local labels = {}
	for index = 1, math.min(#entries, 3) do
		local entry = entries[index]
		local x = if index == 1 then 0.5 else if index == 2 then 0.22 else 0.78
		labels[entry.playerId] = c(Surface, {
			Color = if entry.placement == 1
				then Colors.Yellow
				else if entry.placement == 2 then Colors.Cyan else Colors.Pink,
			Shadow = false,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(x, 1),
				Size = UDim2.new(0.265, 0, 0, if props.Compact then 44 else 52),
				Visible = props.ShowLabels ~= false,
			},
		}, {
			Name = c(Label, {
				Text = entry.displayName,
				Title = true,
				Size = if props.Compact then 15 else 21,
				Native = {
					Position = UDim2.fromOffset(6, 3),
					Size = if props.Compact then UDim2.new(1, -12, 0, 20) else UDim2.new(1, -12, 0.55, 0),
				},
			}),
			Score = c(Label, {
				Text = `{entry.score} {props.ScoreLabel}`,
				Color = Colors.White,
				Size = if props.Compact then 12 else 15,
				Native = {
					Position = if props.Compact then UDim2.fromOffset(0, 24) else UDim2.fromScale(0, 0.58),
					Size = if props.Compact then UDim2.new(1, 0, 0, 16) else UDim2.fromScale(1, 0.34),
				},
			}),
		})
	end
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Region = c(
			"Frame",
			{ ref = region, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, if props.Compact then -48 else -56) }
		),
		Names = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, labels),
	})
end
