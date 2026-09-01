-- Name: CosmeticsLogic.luau
-- Author: Jack C.
-- Description: Pure equip validation shared by the server's enforcement and the client's storefront, so both agree on which items may go in which slots.
-- Created: 2026-07-13

--!strict

local CosmeticsLogic = {}

type ItemDef = { Category: string, AlwaysAvailable: boolean?, [string]: any }

function CosmeticsLogic.canEquip(
	items: { [string]: ItemDef },
	slots: { [string]: boolean },
	owned: { [string]: any },
	slot: string,
	itemId: string?
): (boolean, string?)
	if not slots[slot] then
		return false, "invalid_slot"
	end
	if itemId == nil then
		return true, nil
	end
	local item = items[itemId]
	if item == nil then
		return false, "unknown_item"
	end
	if item.Category ~= slot then
		return false, "wrong_slot"
	end
	if item.AlwaysAvailable ~= true and owned[itemId] ~= true then
		return false, "not_owned"
	end
	return true, nil
end

return CosmeticsLogic
