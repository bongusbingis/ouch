--!strict

-- Applies body color and composed costumes through one appearance path; authored clothing retains its colors.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cosmetics = require(ReplicatedStorage.Config.Cosmetics.Cosmetics)
local CharacterColorLogic = require(script.Parent.Parent.Economy.CharacterColorLogic)
local CostumeVisualFactory = require(script.Parent.CostumeVisualFactory)
local CharacterAppearance = {}

export type Appearance = { characterColorId: string?, costumeId: string? }

function CharacterAppearance.prepare(appearance: Appearance)
	CostumeVisualFactory.prepare(appearance.costumeId)
end

function CharacterAppearance.create(character: Model, appearance: Appearance, options: { live: boolean? }?): any
	local costume, costumeId = nil, nil
	local destroyed = false
	local function updateMounts()
		if costume then
			costume.update()
		end
	end
	local function update(nextAppearance: Appearance)
		if destroyed then
			return
		end
		local color = CharacterColorLogic.resolve(Cosmetics, nextAppearance.characterColorId)
		for name in CostumeVisualFactory.BodyParts do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Color = color
			end
		end
		local nextId = if nextAppearance.costumeId ~= "" then nextAppearance.costumeId else nil
		if nextId ~= costumeId then
			if costume then
				costume.destroy()
				costume = nil
			end
			costumeId = nil
			if nextId then
				costume = CostumeVisualFactory.create(character, nextId, options and options.live)
			end
			costumeId = nextId
		end
		updateMounts()
	end
	update(appearance)
	return {
		update = update,
		updateMounts = updateMounts,
		destroy = function()
			if destroyed then
				return
			end
			destroyed = true
			if costume then
				costume.destroy()
				costume = nil
			end
		end,
	}
end

return CharacterAppearance
