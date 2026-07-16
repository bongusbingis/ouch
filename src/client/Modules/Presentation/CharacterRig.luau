--!strict

-- Rig-name lookups shared by presentation modules, including the R15/R6
-- naming fallback for the throwing hand. Keep every rig-name convention here.

local CharacterRig = {}

function CharacterRig.rightHand(character: Model?): BasePart?
	if character == nil then
		return nil
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		return hand
	end
	return nil
end

function CharacterRig.rootPart(character: Model?): BasePart?
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

return CharacterRig
