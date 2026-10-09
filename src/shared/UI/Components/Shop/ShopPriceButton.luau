--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Parent.Tokens)
local PuffyButton = require(script.Parent.Parent.PuffyButton)
local BonksLabel = require(script.Parent.Parent.BonksLabel)
local c, C = React.createElement, T.Colors
return function(props)
	local stacked = props.SubText ~= nil or props.SubBonks ~= nil
	local z = props.ZIndex or 8
	local enabled = props.Enabled ~= false
	-- Muted reads as a status in the action slot (the disabled recipe) while
	-- staying focusable, so the card it belongs to can still be inspected.
	local muted = props.Muted == true
	local color = if muted then C.WellLine else props.Color or (if props.Red then C.Pink else C.Surface)
	local textColor = if enabled and not muted
		then props.TextColor or (if color == C.Pink or color == C.Grape then C.Surface else C.Ink)
		else C.InkSoft
	local children =
		{ Minimum = c("UISizeConstraint", { MinSize = Vector2.new(T.Layout.MinTarget, T.Layout.MinTarget) }) }
	local function line(name, text, amount, y, height, textSize)
		local native = {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 10, y, 0),
			Size = UDim2.new(1, -20, height, -T.Shape.LipHeight / 2),
			ZIndex = z + 6,
		}
		if amount ~= nil then
			return c(
				BonksLabel,
				{ Amount = amount, MaxTextSize = textSize, TextColor = textColor, TextStroke = 0, Native = native }
			)
		end
		native.Font = T.Type.Display
		native.Text = text or ""
		native.TextSize = textSize
		native.TextColor3 = textColor
		native.TextWrapped = true
		return c("TextLabel", native)
	end
	children.Label = line(
		"Label",
		props.Text,
		props.BonksAmount,
		0,
		if stacked then 0.5 else 1,
		math.max(T.Type.Minimum, props.TextSize or T.Type.TileLabel)
	)
	if stacked then
		children.Price = line(
			"Price",
			props.SubText,
			props.SubBonks,
			0.5,
			0.5,
			math.max(T.Type.Minimum, props.SubTextSize or T.Type.Minimum)
		)
	end
	return c(PuffyButton, {
		ButtonRef = props.ButtonRef,
		Enabled = enabled,
		Color = color,
		Shadow = false,
		EntranceDelay = props.EntranceDelay,
		OnActivated = props.OnActivated,
		OnHoverChanged = props.OnHoverChanged,
		Native = {
			AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 1),
			LayoutOrder = props.LayoutOrder,
			Position = props.Position or UDim2.fromScale(0.5, 0.95),
			Size = props.Size or UDim2.fromScale(0.78, 0.19),
			ZIndex = z,
		},
	}, children)
end
