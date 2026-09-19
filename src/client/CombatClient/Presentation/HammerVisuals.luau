-- Description: Renders every player's equipped hammer: clones the cosmetic carrier, solves its grip onto the hand, scales and springs it through swings, and hosts the swing audio.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("Combat"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local CosmeticVisualFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CosmeticVisualFactory")
)
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local Util = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Util")
local Spring = require(Util:WaitForChild("Spring"))
local CharacterRig = require(script.Parent.CharacterRig)
local EquippedWeapon = require(script.Parent.EquippedWeapon)
local WorldAudio = require(script.Parent.WorldAudio)
local HammerGrip = require(script.Parent.HammerGrip)

local HammerVisuals = {}

local visuals: { [Player]: BasePart } = {}
local appliedAssets: { [Player]: string } = {}
local visualBaseSizes: { [Player]: Vector3 } = {}
local visualGripCFrames: { [Player]: CFrame } = {}
local visualLongAxes: { [Player]: HammerGrip.Axis } = {}
local springs: { [Player]: Spring.Spring } = {}
local seenEvents = EventDedup.new(4096)
local started = false
local renderConnection: RBXScriptConnection? = nil
local playerRemovingConnection: RBXScriptConnection? = nil

local function gripFor(visual: BasePart, baseSize: Vector3): (CFrame, HammerGrip.Axis)
	local axis = HammerGrip.longestAxis(baseSize.X, baseSize.Y, baseSize.Z)
	local existing = visual:FindFirstChild("GripAttachment")
	if existing then
		assert(existing:IsA("Attachment"), `[HammerVisuals] {visual.Name}.GripAttachment must be an Attachment`)
		return existing.CFrame, axis
	end

	local config = Combat.Hammer.AutoGrip
	local solution =
		HammerGrip.solve(baseSize.X, baseSize.Y, baseSize.Z, config.MinAxisDominanceRatio, config.GripAlongLongAxis)
	assert(solution ~= nil, `[HammerVisuals] {visual.Name} has ambiguous dimensions; author a GripAttachment`)
	local position = solution.position
	local rotation = solution.rotationDeg
	return CFrame.new(position.x, position.y, position.z) * CFrame.Angles(
		math.rad(rotation.x),
		math.rad(rotation.y),
		math.rad(rotation.z)
	),
		solution.axis
end

local function handGripCFrame(character: Model, hand: BasePart): CFrame
	local rigGrip = CharacterRig.rightHandGripCFrame(character)
	if rigGrip then
		return rigGrip
	end
	local fallback = Combat.Hammer.HandGripFallbackOffset
	return hand.CFrame * CFrame.new(fallback.x, fallback.y, fallback.z)
end

local function springFor(player: Player): Spring.Spring
	local spring = springs[player]
	if spring == nil then
		spring = Spring.new(0)
		springs[player] = spring
	end
	return spring
end

local function scaleFor(stretch: number, axis: HammerGrip.Axis): Vector3
	local along = 1 + stretch
	local cross = 1 / math.sqrt(along)
	if axis == "X" then
		return Vector3.new(along, cross, cross)
	elseif axis == "Z" then
		return Vector3.new(cross, cross, along)
	end
	return Vector3.new(cross, along, cross)
end

local function remove(player: Player)
	local visual = visuals[player]
	if visual then
		visual:Destroy()
	end
	visuals[player] = nil
	appliedAssets[player] = nil
	visualBaseSizes[player] = nil
	visualGripCFrames[player] = nil
	visualLongAxes[player] = nil
end

local function effectiveAsset(player: Player): string
	local itemId = (player:GetAttribute("Equip_HammerAssets") :: string?) or ""
	local item = Cosmetics.Items[itemId]
	if item and item.Category == "HammerAssets" and item.Visual ~= nil then
		return itemId
	end
	return ""
end

local function visualFor(player: Player): BasePart
	local assetId = effectiveAsset(player)
	local visual = visuals[player]
	if visual and appliedAssets[player] == assetId then
		return visual
	end
	if visual then
		visual:Destroy()
	end

	visual = CosmeticVisualFactory.create("HammerAssets", if assetId == "" then nil else assetId)
	visual.Name = `{player.Name}_HammerVisual`
	local baseSize = visual.Size
	local gripCFrame, longAxis = gripFor(visual, baseSize)
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanQuery = false
	visual.CanTouch = false
	visual.Parent = Workspace.CurrentCamera
	visuals[player] = visual
	appliedAssets[player] = assetId
	visualBaseSizes[player] = baseSize
	visualGripCFrames[player] = gripCFrame
	visualLongAxes[player] = longAxis
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
	if started then
		return
	end
	started = true

	playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		remove(player)
		springs[player] = nil
	end)

	renderConnection = RunService.RenderStepped:Connect(function(dt)
		local feel = Combat.HammerFeel
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character == nil then
				remove(player)
				continue
			end

			local hand = CharacterRig.rightHand(character)
			if hand == nil or not EquippedWeapon.isShowing(player, "Hammer") then
				remove(player)
				continue
			end

			local spring = springFor(player)
			Spring.step(spring, feel.SpringFrequencyHz, feel.SpringDampingRatio, dt)
			local phase = (player.UserId % 100) * 0.618
			local wobble = feel.IdleWobbleAmplitude * math.sin((now + phase) * feel.IdleWobbleHz * 2 * math.pi)
			local stretch = math.clamp(spring.position + wobble, feel.MinStretch, feel.MaxStretch)
			local visual = visualFor(player)
			local baseSize = assert(visualBaseSizes[player], `[HammerVisuals] missing base size for {player.Name}`)
			local itemGrip = assert(visualGripCFrames[player], `[HammerVisuals] missing grip CFrame for {player.Name}`)
			local longAxis = assert(visualLongAxes[player], `[HammerVisuals] missing long axis for {player.Name}`)
			local scale = scaleFor(stretch, longAxis)
			local gripLocal = itemGrip.Position
			local handWorld = handGripCFrame(character, hand)

			visual.Size = Vector3.new(baseSize.X * scale.X, baseSize.Y * scale.Y, baseSize.Z * scale.Z)
			visual.CFrame = handWorld
				* itemGrip:Inverse()
				* CFrame.new(gripLocal.X * (1 - scale.X), gripLocal.Y * (1 - scale.Y), gripLocal.Z * (1 - scale.Z))
		end
	end)
end

function HammerVisuals.onEvent(event: any)
	local soundNames = {
		HammerHit = "Hit",
		HammerMiss = "Miss",
	}
	local soundName = soundNames[event.kind]
	if soundName == nil and event.kind ~= "HammerSwing" then
		return
	end

	if not seenEvents.markSeen(event) then
		return
	end

	local playerId = event.playerId or event.sourceId
	if playerId == nil then
		return
	end

	local player = PlayerIds.fromId(playerId)
	if player then
		local feel = Combat.HammerFeel
		local spring = springFor(player)
		if event.kind == "HammerSwing" then
			Spring.impulse(spring, feel.SwingStretchImpulse)
		elseif event.kind == "HammerHit" then
			Spring.impulse(spring, feel.HitSquashImpulse)
		elseif event.kind == "HammerMiss" then
			spring.position -= feel.MissDeflateAmount
		end
	end

	local parent = audioParentFor(playerId)
	if parent and soundName then
		WorldAudio.play("Hammer", soundName, parent)
	end
end

function HammerVisuals.stop()
	if not started then
		return
	end
	started = false
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if playerRemovingConnection then
		playerRemovingConnection:Disconnect()
		playerRemovingConnection = nil
	end
	for player in visuals do
		remove(player)
		springs[player] = nil
	end
end

return HammerVisuals
