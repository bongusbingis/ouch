--!strict
local GuiService = game:GetService("GuiService")
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local DeviceClass = require(RS.Shared.Game.Input.DeviceClass)
local Layout = require(script.Parent.Parent.Models.ArenaHUDLayout)
local InputHint = require(script.Parent.Parent.Components.InputHint)
local Hints = require(RS:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Input")).Hints
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
	local class = DeviceClass.current()
	local hints = {
		menu = InputHint.reserve(class, Hints.Menu),
		scores = InputHint.reserve(class, Hints.Scores),
	}
	local layout = Layout.resolve(viewport, device, topbar, class == "Touch", hints)
	return layout, origin
end
