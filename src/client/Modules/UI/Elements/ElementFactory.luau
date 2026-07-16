--!strict

local ElementHandle = require(script.Parent.ElementHandle)
local ElementTypes = require(script.Parent.ElementTypes)

type ElementHandle = ElementTypes.ElementHandle

local ElementFactory = {}

function ElementFactory.resolveTemplate(name: string, className: string): Instance
	local replicatedStorage = game:GetService("ReplicatedStorage")
	local template =
		replicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("Templates"):WaitForChild(name)
	assert(template:IsA(className), `[ElementFactory] Assets.UI.Templates.{name} must be a {className}`)
	return template
end

function ElementFactory.cloneMount(template: GuiObject, parent: Instance): (GuiObject, ElementHandle)
	assert(template:IsA("GuiObject"), "[ElementFactory] template must be a GuiObject")

	local clone = template:Clone()
	assert(clone:IsA("GuiObject"), "[ElementFactory] cloned template must be a GuiObject")
	clone.Parent = parent

	return clone, ElementHandle.new(clone)
end

return ElementFactory
