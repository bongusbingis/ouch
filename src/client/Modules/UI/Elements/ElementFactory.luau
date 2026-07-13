--!strict

local ElementHandle = require(script.Parent.ElementHandle)
local ElementTypes = require(script.Parent.ElementTypes)

type ElementHandle = ElementTypes.ElementHandle

local ElementFactory = {}

function ElementFactory.cloneMount(template: GuiObject, parent: Instance): (GuiObject, ElementHandle)
	assert(template:IsA("GuiObject"), "[ElementFactory] template must be a GuiObject")

	local clone = template:Clone()
	assert(clone:IsA("GuiObject"), "[ElementFactory] cloned template must be a GuiObject")
	clone.Parent = parent

	return clone, ElementHandle.new(clone)
end

return ElementFactory
