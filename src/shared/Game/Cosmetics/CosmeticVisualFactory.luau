-- Name: CosmeticVisualFactory.luau
-- Author: Jack C.
-- Description: Builds the visual instance for a cosmetic from its catalog definition, the shared path used by both world rendering and inventory previews.
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

function CosmeticVisualFactory.create(category: string, itemId: string?): MeshPart
	local definition = definitionFor(category, itemId)
	assert(definition ~= nil, `[CosmeticVisualFactory] unknown {category} cosmetic {tostring(itemId)}`)
	local visual = definition.Visual
	assert(visual ~= nil, `[CosmeticVisualFactory] {category} cosmetic {tostring(itemId)} has no Visual`)
	local templateDef = Cosmetics.VisualTemplates[visual.Template]
	assert(templateDef ~= nil, `[CosmeticVisualFactory] unknown visual template {visual.Template}`)

	local mesh = Instance.new("MeshPart")
	mesh.Name = if itemId and itemId ~= "" then itemId else `Default{category}`
	mesh.MeshId = `rbxassetid://{visual.MeshId or templateDef.MeshId}`
	mesh.Size = visual.Size or templateDef.Size
	mesh.Color = visual.Color or templateDef.Color
	mesh.Material = visual.Material or templateDef.Material
	mesh.Anchored = false
	mesh.CanCollide = false
	mesh.CanQuery = false
	mesh.CanTouch = false

	if visual.TextureId then
		mesh.TextureID = `rbxassetid://{visual.TextureId}`
	end

	local maps = visual.SurfaceMaps or templateDef.SurfaceMaps
	if maps then
		local sa = Instance.new("SurfaceAppearance")
		if maps.ColorMapId then
			sa.ColorMap = `rbxassetid://{maps.ColorMapId}`
		end
		if maps.MetalnessMapId then
			sa.MetalnessMap = `rbxassetid://{maps.MetalnessMapId}`
		end
		if maps.NormalMapId then
			sa.NormalMap = `rbxassetid://{maps.NormalMapId}`
		end
		if maps.RoughnessMapId then
			sa.RoughnessMap = `rbxassetid://{maps.RoughnessMapId}`
		end
		if maps.EmissiveStrength then
			sa.EmissiveStrength = maps.EmissiveStrength
		end
		sa.Parent = mesh
	end

	if templateDef.EffectsCarrier then
		local carrier = ReplicatedStorage:WaitForChild("Assets")
			:WaitForChild("Cosmetics")
			:WaitForChild("Templates")
			:WaitForChild(templateDef.EffectsCarrier)
		for _, child in carrier:GetChildren() do
			if not child:IsA("SurfaceAppearance") then
				child:Clone().Parent = mesh
			end
		end
	end

	return mesh
end

return CosmeticVisualFactory
