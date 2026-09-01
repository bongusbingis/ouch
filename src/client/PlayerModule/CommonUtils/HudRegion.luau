--!strict

local PlayerModuleEventBus = require(script.Parent:WaitForChild("PlayerModuleEventBus"))

-- GAME MODIFICATION (Combat): lets a touch control publish the screen rectangle
-- it occupies, so the combat gesture classifier can exclude it.
--
-- Sent through the shared event bus rather than by calling into Combat, so the
-- control modules keep no dependency on it. The control owns its geometry and is
-- the only thing that can report it accurately: a dynamic thumbstick appears
-- wherever the player's thumb lands, so guessing at screen fractions cannot work.
--
-- Rectangles are republished whenever the control resizes, because AbsoluteSize
-- is still zero on the frame a control is created and would otherwise never be
-- registered at all.

local HudRegion = {}

local EVENT = "HUD_REGION"
local watched: { [GuiObject]: boolean } = {}

local function rectOf(gui: GuiObject)
	local position, size = gui.AbsolutePosition, gui.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return nil
	end
	return {
		minX = position.X,
		minY = position.Y,
		maxX = position.X + size.X,
		maxY = position.Y + size.Y,
	}
end

function HudRegion.publish(name: string, gui: GuiObject?, visible: boolean)
	if gui == nil or not visible then
		PlayerModuleEventBus:publish(EVENT, name, nil)
		return
	end

	PlayerModuleEventBus:publish(EVENT, name, rectOf(gui))

	if not watched[gui] then
		watched[gui] = true
		local function republish()
			PlayerModuleEventBus:publish(EVENT, name, if gui.Visible then rectOf(gui) else nil)
		end
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(republish)
		gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(republish)
		gui.Destroying:Connect(function()
			watched[gui] = nil
			PlayerModuleEventBus:publish(EVENT, name, nil)
		end)
	end
end

return HudRegion
