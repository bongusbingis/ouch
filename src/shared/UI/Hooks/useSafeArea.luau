--!strict

local GuiService = game:GetService("GuiService")

local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useViewportSize = require(script.Parent.useViewportSize)

return function(parentScreenInsets: Enum.ScreenInsets?): ResponsiveLayout.SafeRect
	local viewport = useViewportSize()
	local ok, area = pcall(GuiService.GetInsetArea, GuiService, Enum.ScreenInsets.DeviceSafeInsets)
	local minimum = Vector2.zero
	local maximum = viewport
	if ok and typeof(area) == "Rect" then
		minimum = (area :: Rect).Min
		maximum = (area :: Rect).Max
	end
	return ResponsiveLayout.safeRect(viewport, minimum, maximum, parentScreenInsets == Enum.ScreenInsets.None)
end
