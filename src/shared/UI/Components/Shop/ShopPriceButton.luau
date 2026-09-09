-- Store actions keep the label and live price centered within one consistent button face.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local AnimatedButton = require(script.Parent.Parent.AnimatedButton)
local ButtonSurface = require(script.Parent.Parent.ButtonSurface)
local BonksLabel = require(script.Parent.Parent.BonksLabel)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)
local c = React.createElement

local function label(text, position, size, maximum, color, zIndex, stroke)
	return c(ResponsiveText, {
		MeasurementFont = Enum.Font.LuckiestGuy,
		MinTextSize = 12,
		MaxTextSize = maximum,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Text = text,
			Font = Enum.Font.LuckiestGuy,
			TextColor3 = color,
			ZIndex = zIndex,
		},
	}, {
		Outline = if stroke > 0
			then c("UIStroke", { Thickness = stroke, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize })
			else nil,
	})
end

return function(props)
	local stacked = props.SubText ~= nil or props.SubBonks ~= nil
	local enabled = props.Enabled ~= false
	local z = props.ZIndex or 8
	local color = if enabled then props.TextColor or UI.ProgressionStyle.White else UI.ProgressionStyle.White
	local stroke = if enabled then props.TextStroke or 0.055 else 0.055
	local top = if stacked then UDim2.fromOffset(10, 3) else UDim2.fromOffset(10, 2)
	local extent = if stacked then UDim2.new(1, -20, 0.5, -3) else UDim2.new(1, -20, 1, -4)
	return c(AnimatedButton, {
		SelectionRadius = if props.Compact then UDim.new(0, 8) else UDim.new(1, 0),
		ButtonRef = props.ButtonRef,
		EntranceDelay = props.EntranceDelay,
		Enabled = enabled,
		Style = "Standard",
		OnActivated = props.OnActivated,
		Visual = c(ButtonSurface, {
			Enabled = enabled,
			Radius = if props.Compact then UDim.new(0, 8) else nil,
			Color = props.Color or (if props.Red then UI.ProgressionStyle.Pink else UI.ProgressionStyle.Cyan),
		}),
		Native = {
			AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Image = "",
			LayoutOrder = props.LayoutOrder,
			Position = props.Position or UDim2.fromScale(0.5, 0.95),
			Size = props.Size or UDim2.fromScale(0.78, 0.19),
			ZIndex = z,
		},
	}, {
		Minimum = c(
			"UISizeConstraint",
			{ MinSize = Vector2.new(UI.Interaction.MinTargetPx, UI.Interaction.MinTargetPx) }
		),
		Label = if props.BonksAmount
			then c(BonksLabel, {
				Amount = props.BonksAmount,
				MaxTextSize = props.TextSize or UI.Button.TextPx,
				TextColor = props.BonksColor or color,
				TextStroke = stroke,
				Native = { Position = top, Size = extent, ZIndex = z + 1 },
			})
			else label(props.Text, top, extent, props.TextSize or UI.Button.TextPx, color, z + 1, stroke),
		Price = if props.SubBonks
			then c(BonksLabel, {
				Amount = props.SubBonks,
				MaxTextSize = props.SubTextSize or UI.Button.PricePx,
				TextColor = props.SubTextColor or color,
				TextStroke = stroke,
				Native = { Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.new(1, -20, 0.5, -3), ZIndex = z + 1 },
			})
			elseif props.SubText then label(
				props.SubText,
				UDim2.new(0, 10, 0.5, 0),
				UDim2.new(1, -20, 0.5, -3),
				props.SubTextSize or UI.Button.PricePx,
				props.SubTextColor or color,
				z + 1,
				stroke
			)
			else nil,
	})
end
