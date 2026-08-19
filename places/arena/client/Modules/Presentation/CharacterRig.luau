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

function CharacterRig.dodgeballGripCFrame(character: Model?): CFrame?
	local hand = CharacterRig.rightHand(character)
	if hand == nil then
		return nil
	end
	local attachment = hand:FindFirstChild("DodgeballGrip")
	if attachment and attachment:IsA("Attachment") then
		return hand.CFrame * attachment.CFrame
	end
	return nil
end

-- R15 characters carry a built-in "RightGripAttachment" on RightHand (the
-- same reference frame Roblox's own Tool grip alignment uses); R6 and custom
-- avatars may not have one, so callers must handle nil.
function CharacterRig.rightHandGripCFrame(character: Model?): CFrame?
	local hand = CharacterRig.rightHand(character)
	if hand == nil then
		return nil
	end
	local attachment = hand:FindFirstChild("RightGripAttachment")
	if attachment and attachment:IsA("Attachment") then
		return hand.CFrame * attachment.CFrame
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
