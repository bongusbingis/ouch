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
local warnedMissingAssets: { [string]: boolean } = {}

local function definition(effectName: string)
	local effect = (Audio.Gameplay :: any)[effectName]
	assert(effect ~= nil, `[GameAudio] no Config.Audio.Gameplay entry named "{effectName}"`)
	return effect
end

local function pickAssetId(effect): string?
	local available = {}
	for _, assetId in effect.AssetIds do
		if typeof(assetId) == "string" and string.find(assetId, "%S") ~= nil then
			table.insert(available, assetId)
		end
	end
	if #available == 0 then
		return nil
	end
	return available[random:NextInteger(1, #available)]
end

local function emitterFor(host: Instance): AudioEmitter
	local existing = host:FindFirstChild(EMITTER_NAME)
	if existing and existing:IsA("AudioEmitter") then
		return existing
	end
	local emitter = Instance.new("AudioEmitter")
	emitter.Name = EMITTER_NAME
	emitter.Parent = host
	return emitter
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

local function playWorld(effect, assetId: string, host: Instance)
	local emitter = emitterFor(host)
	local player = Instance.new("AudioPlayer")
	player.AssetId = assetId
	player.Volume = ClientAudio.effectiveVolume("Effects", effect.Volume)
	player.Parent = host

	local wire = Instance.new("Wire")
	wire.SourceInstance = player
	wire.TargetInstance = emitter
	wire.Parent = player

	player:Play()
	Debris:AddItem(player, math.max(player.TimeLength, 3) + 0.25)
end

local function playLocal(effect, assetId: string, effectName: string)
	ClientAudio.play({
		name = effectName,
		assetId = assetId,
		category = "Effects",
		volume = effect.Volume,
	})
end

function GameAudio.play(effectName: string, at: (Instance | Vector3)?): boolean
	local effect = definition(effectName)
	local assetId = pickAssetId(effect)
	if assetId == nil then
		if not warnedMissingAssets[effectName] then
			warnedMissingAssets[effectName] = true
			warn(`[GameAudio] "{effectName}" has no published AssetIds; using caller fallback when available`)
		end
		return false
	end

	if effect.Scope == "Local" then
		playLocal(effect, assetId, effectName)
		return true
	end

	local host: Instance? = nil
	if typeof(at) == "Instance" then
		host = at
	elseif typeof(at) == "Vector3" then
		host = anchorAt(at)
	end
	if host == nil then
		warn(`[GameAudio] world effect "{effectName}" needs an instance or position`)
		return false
	end
	playWorld(effect, assetId, host)
	return true
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
	if kind ~= "Elim" and kind ~= "HammerSwing" and kind ~= "BallThrown" and kind ~= "BallBounced" then
		return
	end
	if not seenEvents.markSeen(event) then
		return
	end

	if kind == "Elim" then
		local position = toVector3(event.position)
		if position == nil then
			warn("[GameAudio] elimination event is missing its authoritative world position")
			return
		end
		local effectName, fallbackName = EliminationAudio.soundFor(Cosmetics, elimEffectItemId(event), event)
		if not GameAudio.play(effectName, position) and fallbackName ~= nil and fallbackName ~= effectName then
			GameAudio.play(fallbackName, position)
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
		GameAudio.play(if kind == "BallThrown" then "DodgeballThrow" else "DodgeballBounce", ball)
	end
end

return GameAudio
