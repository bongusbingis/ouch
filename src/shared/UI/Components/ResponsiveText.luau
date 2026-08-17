--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local useViewportSize = require(script.Parent.Parent.Hooks.useViewportSize)
local TextMetrics = require(script.Parent.Parent.TextMetrics)

local c = React.createElement

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
	children: { [any]: any }?,
}

return function(props: Props)
	local labelRef = React.useRef(nil)
	local revision = React.useRef(0)
	local viewportSize = useViewportSize()
	local maximum = props.MaxTextSize or 100
	local minimum = math.min(props.MinTextSize or 1, maximum)
	local textSize, setTextSize = React.useState(maximum)
	local text = tostring(props.Native.Text or "")

	React.useEffect(function()
		revision.current += 1
		local currentRevision = revision.current
		local sizeConnection: RBXScriptConnection? = nil
		local function measure(): boolean
			local label: TextLabel? = labelRef.current
			if currentRevision ~= revision.current or label == nil then
				return false
			end
			local absoluteSize = label.AbsoluteSize / layoutScale(label)
			if absoluteSize.X <= 0 or absoluteSize.Y <= 0 then
				return false
			end
			local bounds = Vector2.new(math.max(absoluteSize.X - 2, 1), math.max(absoluteSize.Y - 2, 1))
			setTextSize(
				TextMetrics.fittingSize(text, props.MeasurementFont, bounds, minimum, maximum, props.Wrapped == true)
			)
			return true
		end
		task.defer(function()
			if not measure() then
				local label: TextLabel? = labelRef.current
				if label then
					sizeConnection = label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
						if measure() and sizeConnection then
							sizeConnection:Disconnect()
							sizeConnection = nil
						end
					end)
				end
			end
		end)
		return function()
			revision.current += 1
			if sizeConnection then
				sizeConnection:Disconnect()
			end
		end
	end, { text, props.MeasurementFont, minimum, maximum, props.Wrapped, viewportSize })

	local native = table.clone(props.Native)
	native.ref = labelRef
	native.TextScaled = false
	native.TextSize = textSize
	return c(React.Fragment, nil, {
		[props.HostName or "TextLabel"] = c("TextLabel", native, props.children),
	})
end
