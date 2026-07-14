--!strict

-- Equip validation shared by the server (enforcement) and the future locker
-- UI (pre-validation): same function, same answers.

local CosmeticsLogic = {}

type ItemDef = { Category: string, [string]: any }

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
	if owned[itemId] ~= true then
		return false, "not_owned"
	end
	return true, nil
end

return CosmeticsLogic
