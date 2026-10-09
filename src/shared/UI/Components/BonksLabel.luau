-- Keeps the coin and amount together as one fitted, aligned currency display.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local T = require(script.Parent.Parent.Tokens)
local TextMetrics = require(script.Parent.Parent.TextMetrics)
local usePreferredTextSize = require(script.Parent.Parent.Hooks.usePreferredTextSize)
local formatAmount = require(script.Parent.Parent.Models.NumberText)
local c = React.createElement

local BONKS_COIN = "rbxassetid://106703644238993"

export type Props = {
	Amount: number,
	Native: { [any]: any }?,
	TextColor: Color3?,
	IconSize: UDim2?,
	MaxTextSize: number?,
	TextStroke: number?,
	Alignment: Enum.HorizontalAlignment?,
	Framed: boolean?,
	children: { [any]: any }?,
}

return function(props: Props)
	local reference = React.useRef(nil)
	local preferred = usePreferredTextSize()
	local maximum =
		math.round((props.MaxTextSize or UI.Text.DefaultMaxSize) * (UI.Text.PreferredScale[preferred.Name] or 1))
	local textSize, setTextSize = React.useState(maximum)
	local text = formatAmount(props.Amount)
	-- One Bonks glyph at every amount; the coin stack is pack art only.
	local icon = BONKS_COIN
	React.useEffect(function()
		local object = reference.current
		if object == nil then
			return
		end
		local lastSize = Vector2.zero
		local function fit()
			local size = TextMetrics.layoutSize(object)
			size = Vector2.new(math.round(size.X), math.round(size.Y))
			if size == lastSize or size.X <= 0 or size.Y <= 0 then
				return
			end
			lastSize = size
			local cap = math.min(maximum, math.floor(size.Y * 0.82))
			-- Currency stays legible: fit to the box, but never below the menu floor.
			setTextSize(
				math.max(
					T.Type.Minimum,
					TextMetrics.fittingIconTextSize(
						text,
						T.Type.Display,
						Vector2.new(math.max(1, size.X - 4), size.Y - 2),
						math.max(1, cap),
						UI.Button.GapPx
					)
				)
			)
		end
		local connection = object:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		task.defer(fit)
		return function()
			connection:Disconnect()
		end
	end, { text, maximum })
	local native = table.clone(props.Native or {})
	native.ref = reference
	native.BackgroundTransparency = native.BackgroundTransparency or 1
	native.Size = native.Size or UDim2.fromScale(1, 1)
	local children = table.clone(props.children or {})
	children.Layout = c("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = props.Alignment or Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, UI.Button.GapPx),
	})
	children.Icon = c(
		"ImageLabel",
		{
			BackgroundTransparency = if props.Framed then 0.86 else 1,
			BackgroundColor3 = T.Colors.Surface,
			BorderSizePixel = 0,
			Image = icon,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 1,
			Size = UDim2.fromOffset(textSize, textSize),
			ZIndex = native.ZIndex or 1,
		},
		if props.Framed
			then {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Rim = c("UIStroke", { Color = T.Colors.Ink, Thickness = 1, Transparency = 0.65 }),
			}
			else nil
	)
	children.Amount = c("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Font = T.Type.Display,
		TextSize = textSize,
		Text = text,
		TextColor3 = props.TextColor or T.Colors.Yellow,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = native.ZIndex or 1,
	}, {
		Stroke = if props.TextStroke
			then c("UIStroke", {
				Color = T.Colors.Ink,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = props.TextStroke,
			})
			else nil,
	})
	return c("Frame", native, children)
end
