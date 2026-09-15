--!strict
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local c = React.createElement
return function(props)
	local ref = React.useRef(nil)
	local visible, setVisible = React.useBinding(true)
	React.useEffect(function()
		local header = ref.current
		local scroller = if header then header:FindFirstAncestorWhichIsA("ScrollingFrame") else nil
		if not scroller then
			return nil
		end
		local function update()
			setVisible(
				header.AbsolutePosition.Y < scroller.AbsolutePosition.Y + scroller.AbsoluteSize.Y
					and header.AbsolutePosition.Y + header.AbsoluteSize.Y > scroller.AbsolutePosition.Y
			)
		end
		update()
		local connection = header:GetPropertyChangedSignal("AbsolutePosition"):Connect(update)
		return function()
			connection:Disconnect()
		end
	end, {})
	local z = props.ZIndex or 4
	local bottomGap = props.BottomGapPx or 0
	local underlineGap = props.UnderlineGapPx
	local titleHeightOffset = T.Shape.LipHeight + bottomGap + (underlineGap or 0)
	local stripes = { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }
	for index = 0, 8 do
		stripes["Stripe" .. index] = c("Frame", {
			BackgroundColor3 = T.Colors.Surface,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(index * T.Layout.StripeWidth * 2, 0),
			Size = UDim2.fromOffset(T.Layout.StripeWidth * 2, T.Shape.LipHeight),
			ZIndex = z,
		}, {
			-- Angle the paint rather than the frame so the stripe stays clipped.
			Slant = c("UIGradient", {
				Rotation = -30,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.24, 1),
					NumberSequenceKeypoint.new(0.25, 0),
					NumberSequenceKeypoint.new(0.74, 0),
					NumberSequenceKeypoint.new(0.75, 1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	return c("Frame", {
		BackgroundTransparency = 1,
		ref = ref,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size or UDim2.new(1, 0, 0, props.HeightPx or 54),
		ZIndex = z,
	}, {
		Underline = c("Frame", {
			Visible = visible,
			BackgroundColor3 = props.Color or T.Colors.Yellow,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Position = UDim2.new(0, 0, 1, -T.Shape.LipHeight - bottomGap),
			Size = UDim2.fromOffset(T.Layout.RibbonWidth, T.Shape.LipHeight),
			ZIndex = z,
		}, stripes),
		Title = c("TextLabel", {
			Visible = visible,
			BackgroundTransparency = 1,
			Font = T.Type.Display,
			Text = props.Text,
			TextSize = props.TextSize or (if (props.HeightPx or 54) < 45 then T.Type.TileLabel else T.Type.Section),
			TextColor3 = T.Colors.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = if underlineGap then Enum.TextYAlignment.Bottom else Enum.TextYAlignment.Center,
			TextWrapped = true,
			Position = UDim2.fromOffset(0, if underlineGap then 0 else -T.Shape.LipHeight / 2),
			Size = UDim2.new(1, -(props.AccessoryWidthPx or 0), 1, -titleHeightOffset),
			Rotation = props.TitleRotation or -T.Shape.TiltTab,
			ZIndex = z + 1,
		}),
		Accessory = if props.Accessory
			then c("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, props.AccessoryWidthPx or 120, 1, if underlineGap then -titleHeightOffset else 0),
				ZIndex = z + 1,
			}, { Content = props.Accessory })
			else nil,
	})
end
