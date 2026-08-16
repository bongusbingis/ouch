--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))

local CosmeticVisualFactory = {}

local function assetId(value: string): number?
	local digits = string.match(value, "%d+")
	return if digits then tonumber(digits) else nil
end

local function definitionFor(category: string, itemId: string?): any
	if itemId == nil or itemId == "" then
		return Cosmetics.Defaults[category]
	end
	local definition = Cosmetics.Items[itemId]
	if definition == nil or definition.Category ~= category then
		return nil
	end
	return definition
end

function CosmeticVisualFactory.definition(category: string, itemId: string?): any
	return definitionFor(category, itemId)
end

function CosmeticVisualFactory.create(category: string, itemId: string?): MeshPart
	local definition = definitionFor(category, itemId)
	assert(definition ~= nil, `[CosmeticVisualFactory] unknown {category} cosmetic {tostring(itemId)}`)
	local visual = definition.Visual
	assert(visual ~= nil, `[CosmeticVisualFactory] {category} cosmetic {tostring(itemId)} has no Visual`)
	local templateDefinition = Cosmetics.VisualTemplates[visual.Template]
	assert(templateDefinition ~= nil, `[CosmeticVisualFactory] unknown visual template {visual.Template}`)

	local carrier = ReplicatedStorage:WaitForChild("Assets")
		:WaitForChild("Cosmetics")
		:WaitForChild("Templates")
		:WaitForChild(templateDefinition.CarrierName)
	assert(carrier:IsA("MeshPart"), `[CosmeticVisualFactory] {templateDefinition.CarrierName} must be a MeshPart`)
	assert(
		assetId(carrier.MeshId) == templateDefinition.MeshId,
		`[CosmeticVisualFactory] {templateDefinition.CarrierName} MeshId does not match Config.Cosmetics`
	)

	local clone = carrier:Clone()
	clone.Name = if itemId and itemId ~= "" then itemId else `Default{category}`
	if visual.Color then
		clone.Color = visual.Color
	end
	if visual.TextureId then
		clone.TextureID = `rbxassetid://{visual.TextureId}`
	end
	return clone
end

return CosmeticVisualFactory
