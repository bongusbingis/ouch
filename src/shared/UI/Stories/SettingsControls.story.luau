--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Registry = require(script.Parent.Parent.Parent.Game.Settings.SettingsRegistry)
local Row = require(script.Parent.Parent.Components.Settings.SettingRow)
local mount = require(script.Parent.StoryRoot)

local function Story(props)
	local values, setValues = React.useState({})
	local children = { Layout = React.createElement("UIListLayout", { Padding = UDim.new(0, 12) }) }
	for index, definition in Registry.forPlace("Lobby") do
		children[definition.Id] = React.createElement(Row, {
			Definition = definition,
			Value = if values[definition.Id] ~= nil then values[definition.Id] else definition.Default,
			Enabled = not props.Disabled,
			DisabledReason = "PREVIEW DISABLED STATE",
			Compact = props.Compact,
			Height = Config.Layout.SettingsControls.RowHeight[if props.Compact then "Compact" else "Wide"].Description,
			LayoutOrder = index,
			OnChange = function(id, value)
				setValues(function(previous)
					local updated = table.clone(previous)
					updated[id] = value
					return updated
				end)
			end,
		})
	end
	return React.createElement("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Config.ProgressionStyle.Surface,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, children)
end

return function(target: Instance)
	return mount(
		target,
		React.createElement(Story, {
			Compact = target:GetAttribute("Compact") ~= false,
			Disabled = target:GetAttribute("Disabled") == true,
		})
	)
end
