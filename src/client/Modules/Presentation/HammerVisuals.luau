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
local Util = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Util")
local Spring = require(Util:WaitForChild("Spring"))
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
-- Springs outlive the visual (hidden while holding a ball, rebuilt on respawn)
-- so a mid-wobble hammer resumes naturally; cleared only on PlayerRemoving.
local springs: { [Player]: Spring.Spring } = {}
local baseSize = template.Size
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
end

local function springFor(player: Player): Spring.Spring
	local spring = springs[player]
	if spring == nil then
		spring = Spring.new(0)
		springs[player] = spring
	end
	return spring
end

local function scaleFor(stretch: number): Vector3
	local along = 1 + stretch
	-- Volume-preserving: cross-axes thin as the hammer stretches and fatten
	-- as it squashes.
	local cross = 1 / math.sqrt(along)
	local axis = Combat.HammerFeel.StretchAxis
	if axis == "X" then
		return Vector3.new(along, cross, cross)
	elseif axis == "Z" then
		return Vector3.new(cross, cross, along)
	end
	return Vector3.new(cross, along, cross)
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
	Players.PlayerRemoving:Connect(function(player)
		remove(player)
		springs[player] = nil
	end)

	RunService.RenderStepped:Connect(function(dt)
		local feel = Combat.HammerFeel
		local grip = offsetCFrame()
		local gripLocal = grip:Inverse().Position
		local now = os.clock()
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

			local spring = springFor(player)
			Spring.step(spring, feel.SpringFrequencyHz, feel.SpringDampingRatio, dt)
			-- Per-player phase offset desyncs idle wobble between hammers.
			local phase = (player.UserId % 100) * 0.618
			local wobble = feel.IdleWobbleAmplitude * math.sin((now + phase) * feel.IdleWobbleHz * 2 * math.pi)
			local stretch = math.clamp(spring.position + wobble, feel.MinStretch, feel.MaxStretch)
			local scale = scaleFor(stretch)

			local visual = visualFor(player)
			visual.Size = Vector3.new(baseSize.X * scale.X, baseSize.Y * scale.Y, baseSize.Z * scale.Z)
			-- Size scales the mesh about the part center; the translation maps
			-- the scaled grip point back onto the hand so the handle stays put.
			visual.CFrame = hand.CFrame
				* grip
				* CFrame.new(gripLocal.X * (1 - scale.X), gripLocal.Y * (1 - scale.Y), gripLocal.Z * (1 - scale.Z))
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
	if parent then
		WorldAudio.play("Hammer", soundName, parent)
	end
end

return HammerVisuals
