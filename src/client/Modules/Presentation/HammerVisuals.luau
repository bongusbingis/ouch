--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local CharacterRig = require(script.Parent.CharacterRig)
local WorldAudio = require(script.Parent.WorldAudio)

local HammerVisuals = {}

local assetsFolder = ReplicatedStorage:WaitForChild("Assets")
	:WaitForChild("Cosmetics")
	:WaitForChild(Cosmetics.CategoryFolders.HammerAssets)
local default = Cosmetics.Defaults.HammerAssets
local defaultTemplate = assetsFolder:WaitForChild(default.AssetName)
assert(defaultTemplate:IsA("BasePart"), "[HammerVisuals] default HammerAssets asset must be a BasePart")

local visuals: { [Player]: BasePart } = {}
local appliedAssets: { [Player]: string } = {}
local assetTemplates: { [string]: BasePart } = {}
local ballsFolder = Workspace:WaitForChild("Balls")
local seenEvents = EventDedup.new(4096)

local function handCFrame(template: BasePart): CFrame
	local offset = Combat.Hammer.VisualHandOffset
	local rotation = Combat.Hammer.VisualRotationDeg
	local gripY = -template.Size.Y * (0.5 - Combat.Hammer.VisualGripInsetScale)
	local grip = CFrame.new(0, gripY, 0)
	return CFrame.new(offset.x, offset.y, offset.z)
		* CFrame.Angles(0, math.rad(Combat.Hammer.VisualHandYawDeg), 0)
		* CFrame.Angles(math.rad(rotation.x), math.rad(rotation.y), math.rad(rotation.z))
		* CFrame.Angles(0, math.rad(Combat.Hammer.VisualGripTwistDeg), 0)
		* grip:Inverse()
end

local function hasBall(player: Player): boolean
	local playerId = PlayerIds.toId(player)
	for _, ball in ballsFolder:GetChildren() do
		if ball:IsA("BasePart") and ball:GetAttribute("hb") == playerId then
			local phase = ball:GetAttribute("ph")
			if phase == 0 or phase == 1 then
				return true
			end
		end
	end
	return false
end

local function remove(player: Player)
	local visual = visuals[player]
	if visual then
		visual:Destroy()
	end
	visuals[player] = nil
	appliedAssets[player] = nil
end

local function effectiveAsset(player: Player): (string, BasePart)
	local itemId = (player:GetAttribute("Equip_HammerAssets") :: string?) or ""
	local template = assetTemplates[itemId]
	if template then
		return itemId, template
	end
	return "", defaultTemplate
end

local function visualFor(player: Player): BasePart
	local assetId, template = effectiveAsset(player)
	local visual = visuals[player]
	if visual and appliedAssets[player] == assetId then
		return visual
	end
	if visual then
		visual:Destroy()
	end

	visual = template:Clone()
	visual.Name = `{player.Name}_HammerVisual`
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanQuery = false
	visual.CanTouch = false
	visual.Parent = Workspace.CurrentCamera
	visuals[player] = visual
	appliedAssets[player] = assetId
	return visual
end

local function audioParentFor(playerId: string): Instance?
	for player, visual in visuals do
		if PlayerIds.toId(player) == playerId then
			return visual
		end
	end

	local player = PlayerIds.fromId(playerId)
	local character = player and player.Character
	if character == nil then
		return nil
	end
	return CharacterRig.rightHand(character) or CharacterRig.rootPart(character)
end

function HammerVisuals.start()
	for itemId, item in Cosmetics.Items do
		if item.Category == "HammerAssets" then
			local asset = assetsFolder:WaitForChild(item.AssetName)
			assert(asset:IsA("BasePart"), `[HammerVisuals] asset template {item.AssetName} must be a BasePart`)
			assetTemplates[itemId] = asset
		end
	end

	Players.PlayerRemoving:Connect(remove)

	RunService.RenderStepped:Connect(function()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character == nil then
				remove(player)
				continue
			end

			local hand = CharacterRig.rightHand(character)
			if hand == nil or hasBall(player) then
				remove(player)
				continue
			end

			local visual = visualFor(player)
			visual.CFrame = hand.CFrame * handCFrame(visual)
		end
	end)
end

function HammerVisuals.onEvent(event: any)
	local soundNames = {
		HammerSwing = "Swing",
		HammerHit = "Hit",
		HammerMiss = "Miss",
	}
	local soundName = soundNames[event.kind]
	if soundName == nil then
		return
	end

	if not seenEvents.markSeen(event) then
		return
	end

	local playerId = event.playerId or event.sourceId
	if playerId == nil then
		return
	end
	local parent = audioParentFor(playerId)
	if parent then
		WorldAudio.play("Hammer", soundName, parent)
	end
end

return HammerVisuals
