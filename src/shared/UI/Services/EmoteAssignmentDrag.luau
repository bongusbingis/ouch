--!strict
-- Desktop-only drag assignment; touch keeps scrolling and tap/tap semantics.
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local targets = {}
local active = nil
local suppressedUntil = 0
local Drag = {}
function Drag.register(button, onDrop)
	targets[button] = onDrop
	return function()
		targets[button] = nil
	end
end
function Drag.begin(itemId: string, input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		active = { itemId = itemId, origin = UserInputService:GetMouseLocation() }
	end
end
function Drag.suppressClick(): boolean
	return os.clock() < suppressedUntil
end
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or not active then
		return
	end
	local dragged = active
	active = nil
	local pointer = UserInputService:GetMouseLocation()
	if (pointer - dragged.origin).Magnitude < 12 then
		return
	end
	suppressedUntil = os.clock() + 0.2
	local inset = GuiService:GetGuiInset()
	pointer -= inset
	for button, onDrop in targets do
		if button.Parent and button.Visible then
			local low, size = button.AbsolutePosition, button.AbsoluteSize
			if
				pointer.X >= low.X
				and pointer.Y >= low.Y
				and pointer.X <= low.X + size.X
				and pointer.Y <= low.Y + size.Y
			then
				onDrop(dragged.itemId)
				break
			end
		end
	end
end)
UserInputService.WindowFocusReleased:Connect(function()
	active = nil
end)
return Drag
