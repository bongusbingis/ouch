-- Name: CosmeticVisualFactory.luau
-- Author: Jack C.
-- Description: Builds the visual instance for a cosmetic by cloning its authored MeshPart, the shared path used by both world rendering and inventory previews.
-- Created: 2026-08-16

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))

local CosmeticVisualFactory = {}

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

-- Neither MeshId nor a SurfaceAppearance's PBR maps can be written from a
-- runtime script, so every visual is an authored MeshPart cloned as-is: a
-- category default comes from Assets.Cosmetics.Templates.<Template>, and each
-- item from its own part under that category's VisualFolders folder. Config
-- keeps only what is still writable (Size, Color, Material); MeshId and
-- SurfaceMaps stay in config as the record of what the authored asset must
-- carry, and the in-place asset spec is what holds the two in agreement.
local function sourceFor(category: string, itemId: string?, templateName: string): MeshPart
	local cosmetics = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Cosmetics")
	local source
	if itemId == nil or itemId == "" then
		source = cosmetics:WaitForChild("Templates"):WaitForChild(templateName)
	else
		local folder = Cosmetics.VisualFolders[category]
		assert(folder ~= nil, `[CosmeticVisualFactory] {category} has no VisualFolders entry`)
		source = cosmetics:WaitForChild(folder):WaitForChild(itemId)
	end
	assert(source:IsA("MeshPart"), `[CosmeticVisualFactory] {source:GetFullName()} must be a MeshPart`)
	return source
end

function CosmeticVisualFactory.create(category: string, itemId: string?): MeshPart
	local definition = definitionFor(category, itemId)
	assert(definition ~= nil, `[CosmeticVisualFactory] unknown {category} cosmetic {tostring(itemId)}`)
	local visual = definition.Visual
	assert(visual ~= nil, `[CosmeticVisualFactory] {category} cosmetic {tostring(itemId)} has no Visual`)
	local templateDef = Cosmetics.VisualTemplates[visual.Template]
	assert(templateDef ~= nil, `[CosmeticVisualFactory] unknown visual template {visual.Template}`)

	local mesh = sourceFor(category, itemId, visual.Template):Clone()
	mesh.Name = if itemId and itemId ~= "" then itemId else `Default{category}`
	mesh.Size = visual.Size or templateDef.Size
	mesh.Color = visual.Color or templateDef.Color
	mesh.Material = visual.Material or templateDef.Material
	mesh.Anchored = false
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false

	return mesh
end

return CosmeticVisualFactory
