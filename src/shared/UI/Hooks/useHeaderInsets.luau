-- Tracks viewport/device bounds and CoreGui's free top row without changing the root inset.
--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local useViewportSize = require(script.Parent.useViewportSize)

return function()
	local viewport = useViewportSize()
	local _, update = React.useState(0)
	React.useEffect(function()
		local connection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
			update(function(revision)
				return revision + 1
			end)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	local ok, full, core, device, topbar = pcall(function()
		return GuiService:GetInsetArea(Enum.ScreenInsets.None),
			GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets),
			GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets),
			GuiService.TopbarInset
	end)
	if ok and typeof(full) == "Rect" and typeof(core) == "Rect" then
		return {
			viewport = full.Max - full.Min,
			coreOffset = core.Min - full.Min,
			coreSize = core.Max - core.Min,
			deviceOffset = device.Min - full.Min,
			deviceSize = device.Max - device.Min,
			topbar = topbar,
		}
	end
	return {
		viewport = viewport,
		coreOffset = Vector2.zero,
		coreSize = viewport,
		deviceOffset = Vector2.zero,
		deviceSize = viewport,
		topbar = Rect.new(0, 0, viewport.X, 0),
	}
end
