-- Description: Pure catalog composition, atomic ownership and equip validation shared by the server and storefront.

--!strict

local CosmeticsLogic = {}

type ItemDef = { Category: string, AlwaysAvailable: boolean?, [string]: any }

function CosmeticsLogic.validate(items: { [string]: ItemDef })
	for itemId, item in items do
		if item.CostumePiece ~= nil then
			assert(item.Category == "CostumeAssets", `[Cosmetics] {itemId} component must be a costume`)
			assert(
				table.find({ "Head", "Body", "Feet" }, item.CostumePiece),
				`[Cosmetics] {itemId} has an invalid component role`
			)
			assert(item.Contents == nil, `[Cosmetics] {itemId} component cannot compose other items`)
		end
		if item.Contents ~= nil then
			assert(
				item.Category == "CostumeAssets" and #item.Contents == 3,
				`[Cosmetics] {itemId} requires three costume components`
			)
			local roles, seen = {}, {}
			for _, componentId in item.Contents do
				local component = items[componentId]
				assert(
					component ~= nil and componentId ~= itemId,
					`[Cosmetics] {itemId} references an invalid component`
				)
				assert(component.Contents == nil, `[Cosmetics] {itemId} cannot contain nested sets`)
				assert(
					component.Category == item.Category and component.CostumePiece ~= nil,
					`[Cosmetics] {itemId} requires costume components`
				)
				assert(
					not seen[componentId] and not roles[component.CostumePiece],
					`[Cosmetics] {itemId} repeats a component role`
				)
				seen[componentId], roles[component.CostumePiece] = true, true
			end
			assert(roles.Head and roles.Body and roles.Feet, `[Cosmetics] {itemId} is incomplete`)
		end
	end
end

function CosmeticsLogic.grantIds(items: { [string]: ItemDef }, itemId: string): { string }?
	local item = items[itemId]
	if item == nil then
		return nil
	end
	return if item.Contents then table.clone(item.Contents) else { itemId }
end

function CosmeticsLogic.isOwned(items: { [string]: ItemDef }, owned: { [string]: any }, itemId: string): boolean
	local item = items[itemId]
	if item == nil then
		return false
	end
	if item.AlwaysAvailable then
		return true
	end
	if item.Contents then
		for _, componentId in item.Contents do
			if owned[componentId] ~= true then
				return false
			end
		end
		return #item.Contents > 0
	end
	return owned[itemId] == true
end

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
	if item.Equippable == false then
		return false, "not_equippable"
	end
	if not CosmeticsLogic.isOwned(items, owned, itemId) then
		return false, "not_owned"
	end
	return true, nil
end

return CosmeticsLogic
