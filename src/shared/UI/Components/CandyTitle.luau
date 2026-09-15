--!strict
-- A reusable title sticker; its measured host stays aligned with modal content.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local TextService = game:GetService("TextService")
local T = require(script.Parent.Parent.Tokens)
local c, C = React.createElement, T.Colors
return function(props)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	native.Size = native.Size or UDim2.fromOffset(240, T.Layout.TitleHeight)
	local z = native.ZIndex or 7
	local size = props.TextSize or T.Type.Title
	local wanted = TextService:GetTextSize(props.Text or "", size, T.Type.Display, Vector2.new(100000, 1000)).X + 36
	local available, setAvailable = React.useState(math.huge)
	local width = math.min(wanted, available)
	native[React.Change.AbsoluteSize] = function(instance)
		setAvailable(instance.AbsoluteSize.X)
	end
	local text = {
		BackgroundTransparency = 1,
		Font = T.Type.Display,
		Text = props.Text or "",
		TextSize = size,
		TextWrapped = true,
		TextColor3 = C.Surface,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		ZIndex = z + 2,
	}
	local shadow = table.clone(text)
	shadow.Position = UDim2.fromOffset(12 + T.Type.ShadowOffset.X, T.Type.ShadowOffset.Y)
	shadow.TextColor3 = C.Ink
	shadow.ZIndex = z + 1
	return c("Frame", native, {
		Sticker = c("Frame", {
			BackgroundColor3 = props.Color or C.Pink,
			BorderSizePixel = 0,
			Size = UDim2.new(0, width, 1, 0),
			Rotation = if props.Tilt ~= nil
				then props.Tilt
				else if width > 500 then T.Shape.TiltPanel else T.Shape.TiltTitle,
			ZIndex = z,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusPanel) }),
			Outline = c("UIStroke", { Color = C.Ink, Thickness = T.Shape.StrokeCard }),
			Shadow = c("TextLabel", shadow),
			Title = c("TextLabel", text, { Outline = c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }) }),
		}),
	})
end
