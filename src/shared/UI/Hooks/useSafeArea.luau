--!strict

local GuiService = game:GetService("GuiService")

local ResponsiveLayout = require(script.Parent.Parent.Models.ResponsiveLayout)
local useViewportSize = require(script.Parent.useViewportSize)

return function(parentScreenInsets: Enum.ScreenInsets?): ResponsiveLayout.SafeRect
	local viewport = useViewportSize()
	local ok, area, parent = pcall(function()
		return GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets),
			GuiService:GetInsetArea(parentScreenInsets or Enum.ScreenInsets.CoreUISafeInsets)
	end)
	if ok and typeof(area) == "Rect" and typeof(parent) == "Rect" then
		return ResponsiveLayout.insetRect(viewport, area.Min, area.Max, parent.Min, parent.Max)
	end
	return ResponsiveLayout.safeRect(viewport, Vector2.zero, viewport, true)
end
