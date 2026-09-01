-- Name: CharacterRig.luau
-- Author: Jack C.
-- Description: Central lookup for character rig part names and grip transforms, including the R15/R6 fallback for the throwing hand, so no presentation module hardcodes rig conventions.
-- Created: 2026-07-16

--!strict

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
