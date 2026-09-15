-- Keeps the coin and amount together as one fitted, aligned currency display.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local TextMetrics = require(script.Parent.Parent.TextMetrics)
local usePreferredTextSize = require(script.Parent.Parent.Hooks.usePreferredTextSize)
local formatAmount = require(script.Parent.Parent.Models.NumberText)
local c = React.createElement

export type Props = {
	Amount: number,
	Native: { [any]: any }?,
	TextColor: Color3?,
	IconSize: UDim2?,
	MaxTextSize: number?,
	TextStroke: number?,
	StackThreshold: number?,
	StackIconAsset: string?,
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
	local icon = if props.Amount >= (props.StackThreshold or 1000)
		then props.StackIconAsset or "rbxassetid://128078334031314"
		else "rbxassetid://106703644238993"
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
			setTextSize(
				TextMetrics.fittingIconTextSize(
					text,
					Enum.Font.LuckiestGuy,
					Vector2.new(math.max(1, size.X - 4), size.Y - 2),
					math.max(1, cap),
					UI.Button.GapPx
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
			BackgroundColor3 = UI.ProgressionStyle.White,
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
				Rim = c("UIStroke", { Color = UI.ProgressionStyle.Ink, Thickness = 1, Transparency = 0.65 }),
			}
			else nil
	)
	children.Amount = c("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Font = Enum.Font.LuckiestGuy,
		TextSize = textSize,
		Text = text,
		TextColor3 = props.TextColor or UI.ProgressionStyle.Yellow,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = native.ZIndex or 1,
	}, {
		Stroke = if props.TextStroke
			then c("UIStroke", {
				Color = UI.ProgressionStyle.Ink,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = props.TextStroke,
			})
			else nil,
	})
	return c("Frame", native, children)
end
