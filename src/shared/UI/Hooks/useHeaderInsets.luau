-- Keeps decorative viewport coverage current without changing the lobby's core-safe root.
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
	local ok, full, core = pcall(function()
		return GuiService:GetInsetArea(Enum.ScreenInsets.None),
			GuiService:GetInsetArea(Enum.ScreenInsets.CoreUISafeInsets)
	end)
	if ok and typeof(full) == "Rect" and typeof(core) == "Rect" then
		return { viewport = full.Max - full.Min, coreOffset = core.Min - full.Min, coreSize = core.Max - core.Min }
	end
	return { viewport = viewport, coreOffset = Vector2.zero, coreSize = viewport }
end
