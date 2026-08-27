-- Name: SettingRow.luau
-- Author: Jack C.
-- Description: One reusable row for the settings menu: label, optional description, and the control the definition's Type dispatches to. Adding a new setting never means hand-building a row -- only a new Type branch here, once, ever adds a new visual shape.
-- Created: 2026-08-25

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SettingsRegistry = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Settings")
		:WaitForChild("SettingsRegistry")
)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local ToggleControl = require(script.Parent.ToggleControl)
local SliderControl = require(script.Parent.SliderControl)

local c = React.createElement

export type Props = {
	Definition: SettingsRegistry.Definition,
	Value: any,
	Enabled: boolean?,
	DisabledReason: string?,
	Compact: boolean,
	Height: number,
	LayoutOrder: number?,
	OnChange: (string, any, boolean) -> (),
}

-- OnChange takes the setting id rather than being pre-bound per row so the
-- same callback reference is shared by every row; React.memo below can then
-- skip re-rendering rows whose own props did not change while a slider in a
-- different row is being dragged.
return React.memo(function(props: Props)
	local definition = props.Definition
	local enabled = props.Enabled ~= false
	local hasDescription = definition.Description ~= nil and definition.Description ~= ""

	local textWidth = if props.Compact then 1 else 0.56
	local textHeight = if props.Compact then (if hasDescription then 0.5 else 0.62) else 1

	local control
	if definition.Type == "Toggle" then
		control = c(ToggleControl, {
			Value = props.Value,
			Values = definition.Values,
			Labels = definition.Labels,
			Enabled = enabled,
			OnChange = function(value: any)
				props.OnChange(definition.Id, value, true)
			end,
			AnchorPoint = if props.Compact then nil else Vector2.new(1, 0.5),
			Position = if props.Compact
				then UDim2.fromScale(0, if hasDescription then 0.56 else 0.68)
				else UDim2.fromScale(1, 0.5),
			Size = if props.Compact then UDim2.fromScale(0.62, 0.32) else UDim2.fromScale(0.34, 0.56),
		})
	else
		control = c(SliderControl, {
			Value = props.Value,
			Definition = definition :: any,
			Enabled = enabled,
			Format = definition.Format,
			OnChange = function(value: number, committed: boolean)
				props.OnChange(definition.Id, value, committed)
			end,
			AnchorPoint = if props.Compact then nil else Vector2.new(1, 0.5),
			Position = if props.Compact
				then UDim2.fromScale(0, if hasDescription then 0.56 else 0.68)
				else UDim2.fromScale(1, 0.5),
			Size = if props.Compact then UDim2.fromScale(1, 0.32) else UDim2.fromScale(0.4, 0.56),
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, props.Height),
	}, {
		Text = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(textWidth, textHeight),
		}, {
			Label = c(ResponsiveText, {
				MeasurementFont = Enum.Font.Highway,
				MaxTextSize = 24,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/HighwayGothic.json",
						Enum.FontWeight.Bold,
						Enum.FontStyle.Normal
					),
					Position = UDim2.fromScale(0, 0),
					Size = UDim2.fromScale(1, if hasDescription then 0.52 else 1),
					Text = string.upper(definition.Label),
					TextColor3 = if enabled then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 5,
				},
			}),
			Description = if hasDescription
				then c(ResponsiveText, {
					MeasurementFont = Enum.Font.SourceSans,
					MaxTextSize = 17,
					Wrapped = true,
					Native = {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
						Position = UDim2.fromScale(0, 0.5),
						Size = UDim2.fromScale(1, 0.46),
						Text = if not enabled and props.DisabledReason
							then props.DisabledReason
							else definition.Description,
						TextColor3 = Color3.fromRGB(190, 190, 190),
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						ZIndex = 5,
					},
				})
				else nil,
		}),
		Control = control,
	})
end)
