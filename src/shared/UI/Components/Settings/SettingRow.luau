-- Description: One reusable row for the settings menu: label, optional description, and the control the definition's Type dispatches to. Adding a new setting never means hand-building a row -- only a new Type branch here, once, ever adds a new visual shape.

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
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))

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
	local verticalInset = if props.Height < 88 then 6 else 10
	local innerHeight = props.Height - verticalInset * 2

	local textWidth = if props.Compact then 1 else 0.56
	local controlHeight = UIConfig.Interaction.MinTargetPx
		+ (if definition.Type == "Slider" then UIConfig.Layout.SettingsControls.SliderLabelHeightPx else 0)
	local textHeight = if props.Compact
		then math.max(innerHeight - controlHeight - UIConfig.Layout.SettingsControls.LabelControlGapPx, 0)
		else innerHeight

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
			AnchorPoint = if props.Compact then Vector2.new(0, 1) else Vector2.new(1, 0.5),
			Position = if props.Compact then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 0.5),
			Size = UDim2.new(if props.Compact then 0.62 else 0.34, 0, 0, controlHeight),
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
			AnchorPoint = if props.Compact then Vector2.new(0, 1) else Vector2.new(1, 0.5),
			Position = if props.Compact then UDim2.fromScale(0, 1) else UDim2.fromScale(1, 0.5),
			Size = UDim2.new(if props.Compact then 1 else 0.4, 0, 0, controlHeight),
		})
	end

	return c("Frame", {
		BackgroundColor3 = UIConfig.ProgressionStyle.Claimed,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, props.Height),
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Outline = c("UIStroke", {
			Color = UIConfig.ProgressionStyle.White,
			Thickness = 1,
			Transparency = 0.65,
		}),
		Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, verticalInset),
			PaddingBottom = UDim.new(0, verticalInset),
		}),
		Text = c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(textWidth, if props.Compact then 0 else -12, 0, textHeight),
		}, {
			Label = c(ResponsiveText, {
				MeasurementFont = UIConfig.Text.BodyFont,
				MaxTextSize = 22,
				MinTextSize = 16,
				Native = {
					BackgroundTransparency = 1,
					Font = UIConfig.Text.BodyFont,
					Position = UDim2.fromScale(0, 0),
					Size = if hasDescription then UDim2.new(1, 0, 0, 28) else UDim2.fromScale(1, 1),
					Text = definition.Label,
					TextColor3 = if enabled then UIConfig.ProgressionStyle.White else UIConfig.ProgressionStyle.Muted,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 5,
				},
			}),
			Description = if hasDescription
				then c(ResponsiveText, {
					MeasurementFont = UIConfig.Text.BodyFont,
					MaxTextSize = 16,
					MinTextSize = 14,
					Wrapped = true,
					Native = {
						BackgroundTransparency = 1,
						Font = UIConfig.Text.BodyFont,
						Position = UDim2.fromOffset(0, 28),
						Size = UDim2.new(1, 0, 1, -28),
						Text = if not enabled and props.DisabledReason
							then props.DisabledReason
							else definition.Description,
						TextColor3 = UIConfig.ProgressionStyle.White,
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
