-- Name: CharacterColorLogic.luau
-- Author: Jack C.
-- Description: Pure resolution of a player's character color from their equipped cosmetic, falling back to the default for anything missing or invalid.
-- Created: 2026-08-17

--!strict

local CharacterColorLogic = {}

export type ColorDefinition = {
	PreviewColor: Color3?,
}

export type ItemDefinition = ColorDefinition & {
	Category: string,
}

export type Catalog = {
	Defaults: { [string]: ColorDefinition },
	Items: { [string]: ItemDefinition },
}

function CharacterColorLogic.resolve(catalog: Catalog, itemId: any): Color3
	if typeof(itemId) == "string" then
		local item = catalog.Items[itemId]
		if item ~= nil and item.Category == "CharacterColor" and item.PreviewColor ~= nil then
			return item.PreviewColor
		end
	end

	local default = catalog.Defaults.CharacterColor
	assert(
		default ~= nil and default.PreviewColor ~= nil,
		"[CharacterColorLogic] CharacterColor default requires PreviewColor"
	)
	return default.PreviewColor
end

return CharacterColorLogic
