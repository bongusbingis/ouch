-- Description: Maps sim events to the one-shot sounds declared in the audio config, spawning world-space emitters for spatial cues and routing flat cues to local playback, including the three elimination variants.

--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Audio = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Audio"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local EliminationAudio = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("EliminationAudio")
)
local ClientAudio = require(script.Parent.ClientAudio)
local CharacterRig = require(script.Parent.CharacterRig)

local GameAudio = {}

local EMITTER_NAME = "GameAudioEmitter"
local ANCHOR_LIFETIME = 6

local random = Random.new()
local seenEvents = EventDedup.new()

local function definition(effectName: string)
	assert(
		typeof(Audio.Gameplay) == "table",
		"Config.Infra.Audio.Gameplay: expected cue dictionary; correct the configuration and republish Arena"
	)
	local effect = (Audio.Gameplay :: any)[effectName]
	assert(
		typeof(effect) == "table",
		`Config.Infra.Audio.Gameplay.{effectName}: required cue is missing or malformed; correct the configuration and republish Arena`
	)
	assert(
		effect.Scope == "Local" or effect.Scope == "World",
		`Config.Infra.Audio.Gameplay.{effectName}.Scope: expected Local or World, received {tostring(effect.Scope)}; correct the configuration and republish Arena`
	)
	assert(
		typeof(effect.Volume) == "number"
			and effect.Volume == effect.Volume
			and effect.Volume > 0
			and math.abs(effect.Volume) < math.huge,
		`Config.Infra.Audio.Gameplay.{effectName}.Volume: expected finite positive number, received {tostring(
			effect.Volume
		)}; correct the configuration and republish Arena`
	)
	return effect
end

local function pickAssetId(effect, effectName: string): string
	local assetIds = effect.AssetIds
	local path = `Config.Infra.Audio.Gameplay.{effectName}.AssetIds`
	assert(
		typeof(assetIds) == "table" and #assetIds > 0,
		`{path}: expected nonempty asset ID array; publish a valid cue ID and republish Arena`
	)
	local count = 0
	for index, assetId in assetIds do
		assert(
			typeof(index) == "number" and index % 1 == 0 and index >= 1 and index <= #assetIds,
			`{path}[{tostring(index)}]: expected dense numeric array; correct the configuration and republish Arena`
		)
		assert(
			typeof(assetId) == "string" and string.match(assetId, "^rbxassetid://%d+$") ~= nil,
			`{path}[{index}]: expected rbxassetid:// followed by digits, received {tostring(assetId)}; publish the correct asset ID and republish Arena`
		)
		count += 1
	end
	assert(count == #assetIds, `{path}: expected dense numeric array; correct the configuration and republish Arena`)
	return assetIds[random:NextInteger(1, #assetIds)]
end

local function emitterFor(host: Instance): (AudioEmitter, boolean)
	local existing = host:FindFirstChild(EMITTER_NAME)
	if existing then
		assert(
			existing:IsA("AudioEmitter"),
			`{existing:GetFullName()}: expected AudioEmitter; remove the conflicting child and republish Arena`
		)
		return existing, false
	end
	local emitter = Instance.new("AudioEmitter")
	emitter.Name = EMITTER_NAME
	emitter.Parent = host
	return emitter, true
end

local function anchorAt(position: Vector3): BasePart
	local anchor = Instance.new("Part")
	anchor.Name = "GameAudioAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = Workspace
	Debris:AddItem(anchor, ANCHOR_LIFETIME)
	return anchor
end

local function playWorld(
	effect,
	assetId: string,
	effectName: string,
	host: Instance,
	transientAnchor: BasePart?
): (boolean, string?)
	local emitter, createdEmitter = emitterFor(host)
	local player = Instance.new("AudioPlayer")
	player.AssetId = assetId
	player.Volume = ClientAudio.effectiveVolume("Effects", effect.Volume)
	player.Parent = host
	local wire = Instance.new("Wire")
	wire.SourceInstance = player
	wire.TargetInstance = emitter
	wire.Parent = player
	local hostPath = host:GetFullName()
	local ok, err = pcall(function()
		player:Play()
	end)
	if not ok then
		player:Destroy()
		if createdEmitter then
			emitter:Destroy()
		end
		if transientAnchor ~= nil then
			transientAnchor:Destroy()
		end
		local reason =
			`Config.Infra.Audio.Gameplay.{effectName} asset {assetId} at {hostPath}: AudioPlayer:Play() failed: {err}`
		warn(
			`[GameAudio] {reason}; cleaned this attempt's player, wire, new emitter and transient anchor; verify asset access and republish Arena`
		)
		return false, reason
	end
	Debris:AddItem(player, math.max(player.TimeLength, 3) + 0.25)
	return true, nil
end

local function playLocal(effect, assetId: string, effectName: string)
	ClientAudio.play({
		name = effectName,
		assetId = assetId,
		category = "Effects",
		volume = effect.Volume,
	})
end

function GameAudio.play(effectName: string, at: (Instance | Vector3)?): (boolean, string?)
	local effect = definition(effectName)
	local assetId = pickAssetId(effect, effectName)

	if effect.Scope == "Local" then
		playLocal(effect, assetId, effectName)
		return true, nil
	end

	local host: Instance? = nil
	local transientAnchor: BasePart? = nil
	if typeof(at) == "Instance" then
		host = at
	elseif typeof(at) == "Vector3" then
		transientAnchor = anchorAt(at)
		host = transientAnchor
	end
	assert(
		host ~= nil,
		`Config.Infra.Audio.Gameplay.{effectName}: World cue requires an Instance or Vector3 host; fix the caller before playback`
	)
	return playWorld(effect, assetId, effectName, host, transientAnchor)
end

local function characterPartFor(playerId: string?): BasePart?
	local player = PlayerIds.fromId(playerId)
	return CharacterRig.rootPart(player and player.Character)
end

local function toVector3(value: any): Vector3?
	if typeof(value) == "Vector3" then
		return value
	end
	if typeof(value) == "vector" then
		return Vector3.new(value.x, value.y, value.z)
	end
	return nil
end

local function elimEffectItemId(event: { [string]: any }): string?
	if typeof(event.elimEffectItemId) == "string" then
		return event.elimEffectItemId
	end
	local player = PlayerIds.fromId(event.sourceId)
	local itemId = if player then player:GetAttribute("Equip_ElimEffectAssets") else nil
	return if typeof(itemId) == "string" then itemId else nil
end

function GameAudio.onEvent(event: { [string]: any })
	local kind = event.kind
	if kind ~= "Elim" and kind ~= "HammerSwing" and kind ~= "BallReleased" and kind ~= "BallBounced" then
		return
	end
	if not seenEvents.markSeen(event) then
		return
	end

	if kind == "Elim" then
		local position = toVector3(event.position)
		assert(
			position ~= nil,
			"[GameAudio] Elim event.position: expected authoritative Vector3; correct event producer before playback"
		)
		local effectName, fallbackName = EliminationAudio.soundFor(Cosmetics, elimEffectItemId(event), event)
		local started, reason = GameAudio.play(effectName, position)
		-- Permanent cosmetic contract: only a classified synchronous start failure
		-- of a selected elimination cue may try its named default once.
		if not started and fallbackName ~= nil and fallbackName ~= effectName then
			warn(`[GameAudio] selected Elim cue {effectName} failed: {reason}; trying default {fallbackName} once`)
			local fallbackStarted, fallbackReason = GameAudio.play(fallbackName, position)
			if fallbackStarted then
				warn(`[GameAudio] default Elim cue {fallbackName} started after {effectName} failed`)
			else
				warn(`[GameAudio] default Elim cue {fallbackName} failed after {effectName}: {fallbackReason}`)
			end
		end
		return
	end
	if kind == "HammerSwing" then
		local host = characterPartFor(event.playerId or event.sourceId)
		if host then
			GameAudio.play("HammerSwing", host)
		end
		return
	end

	local balls = Workspace:FindFirstChild("Balls")
	local ball = balls and event.projectileId and balls:FindFirstChild(event.projectileId)
	if ball then
		GameAudio.play(if kind == "BallReleased" then "DodgeballThrow" else "DodgeballBounce", ball)
	end
end

return GameAudio
