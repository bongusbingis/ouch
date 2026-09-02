-- Name: ResponsiveText.luau
-- Author: Jack C.
-- Description: Text component that scales its size and stroke with the viewport and measured bounds so labels stay legible on every device.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local TextMetrics = require(script.Parent.Parent.TextMetrics)
local usePreferredTextSize = require(script.Parent.Parent.Hooks.usePreferredTextSize)

local c = React.createElement

-- Stand-in for "no limit" on an axis the label sizes to its own content
-- (AutomaticSize); feeding the auto-fitted extent back in as the fit bound would
-- ratchet the text down every re-measure.
local UNBOUNDED = 1e6

local function layoutScale(label: TextLabel): number
	local scale = 1
	local ancestor = label.Parent
	while ancestor and not ancestor:IsA("ScreenGui") do
		for _, child in ancestor:GetChildren() do
			if child:IsA("UIScale") then
				scale *= child.Scale
			end
		end
		ancestor = ancestor.Parent
	end
	return math.max(scale, 0.001)
end

export type Props = {
	Native: { [any]: any },
	MeasurementFont: Enum.Font,
	HostName: string?,
	MinTextSize: number?,
	MaxTextSize: number?,
	Wrapped: boolean?,
	Truncate: boolean?,
	children: { [any]: any }?,
}

return function(props: Props)
	local labelRef = React.useRef(nil)
	local revision = React.useRef(0)
	local preferredTextSize = usePreferredTextSize()
	local preferredScale = UIConfig.Text.PreferredScale[preferredTextSize.Name] or 1
	local maximum = math.max(math.round((props.MaxTextSize or UIConfig.Text.DefaultMaxSize) * preferredScale), 1)
	local minimum =
		math.min(math.max(math.round((props.MinTextSize or UIConfig.Text.DefaultMinSize) * preferredScale), 1), maximum)
	local textSize, setTextSize = React.useState(maximum)
	local text = tostring(props.Native.Text or "")

	-- The label is fitted to the live pixel size of its own box, so the box's
	-- AbsoluteSize is the single source of truth and the re-fit is driven by that
	-- changing -- never by the viewport signal, which fires before the engine has
	-- re-laid-out the box and would measure a stale size (small text after a
	-- window resize). A persistent listener catches every real box change,
	-- including the resize the viewport-dependency approach missed.
	React.useEffect(function()
		revision.current += 1
		local currentRevision = revision.current
		-- The last box we actually fitted to, in the label's own coordinates
		-- (AbsoluteSize divided back out by animated UIScale ancestors). A running
		-- UIScale animation changes AbsoluteSize every frame while this stays put,
		-- so keying re-measures on it keeps the text search off the hot path.
		local lastBox: Vector2? = nil
		local function measure()
			local label: TextLabel? = labelRef.current
			if currentRevision ~= revision.current or label == nil then
				return
			end
			local absoluteSize = label.AbsoluteSize / layoutScale(label)
			if absoluteSize.X <= 0 or absoluteSize.Y <= 0 then
				return
			end
			local automatic = label.AutomaticSize
			local autoX = automatic == Enum.AutomaticSize.X or automatic == Enum.AutomaticSize.XY
			local autoY = automatic == Enum.AutomaticSize.Y or automatic == Enum.AutomaticSize.XY
			local boundsX = if autoX then UNBOUNDED else math.max(absoluteSize.X - 2, 1)
			local boundsY = if autoY then UNBOUNDED else math.max(absoluteSize.Y - 2, 1)
			local key = Vector2.new(
				if autoX then UNBOUNDED else math.round(boundsX),
				if autoY then UNBOUNDED else math.round(boundsY)
			)
			if lastBox == key then
				return
			end
			lastBox = key
			setTextSize(
				TextMetrics.fittingSize(
					text,
					props.MeasurementFont,
					Vector2.new(boundsX, boundsY),
					minimum,
					maximum,
					props.Wrapped == true
				)
			)
		end

		local label: TextLabel? = labelRef.current
		local sizeConnection: RBXScriptConnection? = if label
			then label:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
			else nil
		-- Cover the case where the box is already at its final size and so never
		-- emits an AbsoluteSize change for the listener to catch.
		task.defer(measure)

		return function()
			revision.current += 1
			if sizeConnection then
				sizeConnection:Disconnect()
			end
		end
	end, { text, props.MeasurementFont, minimum, maximum, props.Wrapped })

	local native = table.clone(props.Native)
	native.ref = labelRef
	native.TextScaled = false
	native.TextSize = textSize
	if props.Truncate ~= false and props.Wrapped ~= true then
		native.TextTruncate = Enum.TextTruncate.AtEnd
	end
	return c(React.Fragment, nil, {
		[props.HostName or "TextLabel"] = c("TextLabel", native, props.children),
	})
end
