--!strict
local GuiService = game:GetService("GuiService")
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local DeviceClass = require(RS.Shared.Game.Input.DeviceClass)
local Layout = require(script.Parent.Parent.Models.ArenaHUDLayout)
local useViewportSize = require(script.Parent.useViewportSize)

return function(parentInsets: Enum.ScreenInsets?)
	local viewport = useViewportSize()
	local _, refresh = React.useState(0)
	React.useEffect(function()
		local function update()
			refresh(function(value)
				return value + 1
			end)
		end
		local connection = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(update)
		local disconnect = DeviceClass.observe(update)
		return function()
			connection:Disconnect()
			disconnect()
		end
	end, {})
	local device, topbar, origin = Rect.new(Vector2.zero, viewport), Rect.new(0, 0, viewport.X, 58), Vector2.zero
	pcall(function()
		device = GuiService:GetInsetArea(Enum.ScreenInsets.DeviceSafeInsets)
		topbar = GuiService.TopbarInset
		origin = GuiService:GetInsetArea(parentInsets or Enum.ScreenInsets.None).Min
	end)
	local layout = Layout.resolve(viewport, device, topbar, DeviceClass.current() == "Touch")
	return layout, origin
end
