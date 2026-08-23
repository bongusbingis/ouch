--!strict

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Audio = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Audio"))
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local ClientAudio = require(script.Parent.ClientAudio)
local CharacterRig = require(script.Parent.CharacterRig)

-- One entry point for gameplay one-shots. Callers name the event; where the
-- sound comes from and how it reaches the player are decided by
-- Config.Audio.Gameplay, so adding variance or switching an effect to a local
-- cue is a config change rather than a code change.

local GameAudio = {}

local EMITTER_NAME = "GameAudioEmitter"
local ANCHOR_LIFETIME = 6

local random = Random.new()
local seenEvents = EventDedup.new()

local function definition(effectName: string)
	local effect = (Audio.Gameplay :: any)[effectName]
	assert(effect ~= nil, `[GameAudio] no Config.Audio.Gameplay entry named "{effectName}"`)
	assert(#effect.AssetIds > 0, `[GameAudio] "{effectName}" has no AssetIds`)
	return effect
end

local function pickAssetId(effect): string
	return effect.AssetIds[random:NextInteger(1, #effect.AssetIds)]
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

-- A world sound needs something to emit from. Events that only give a point in
-- space get a throwaway anchor rather than every caller inventing one.
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

-- `at` is where the sound belongs: an instance to emit from, or a bare point.
-- Ignored entirely by local effects, which have no position.
function GameAudio.play(effectName: string, at: (Instance | Vector3)?)
	local effect = definition(effectName)
	local assetId = pickAssetId(effect)

	if effect.Scope == "Local" then
		playLocal(effect, assetId, effectName)
		return
	end

	local host: Instance? = nil
	if typeof(at) == "Instance" then
		host = at
	elseif typeof(at) == "Vector3" then
		host = anchorAt(at)
	end
	if host == nil then
		warn(`[GameAudio] world effect "{effectName}" needs an instance or position`)
		return
	end
	playWorld(effect, assetId, host)
end

local function characterPartFor(playerId: string?): BasePart?
	local player = PlayerIds.fromId(playerId)
	return CharacterRig.rootPart(player and player.Character)
end

-- The elimination effect belongs to whoever got the kill, not to the victim:
-- it is bought to be shown off on a win, and reading it from the victim would
-- play a player's own purchase mostly when they lose.
--
-- Reads the equip attribute rather than a profile, because a client only has
-- its own profile and this sound plays for everyone nearby. An unequipped or
-- unknown equip falls through to Cosmetics.Defaults, which names the same audio
-- entries this always used -- so nothing changes for a player who owns nothing.
local function elimEffectFor(playerId: string?): Cosmetics.ElimEffectDef
	local default = Cosmetics.Defaults.ElimEffectAssets.ElimEffect
	assert(default ~= nil, "[GameAudio] default ElimEffectAssets cosmetic must define ElimEffect")
	local player = PlayerIds.fromId(playerId)
	if player == nil then
		return default
	end
	local itemId = (player:GetAttribute("Equip_ElimEffectAssets") :: string?) or ""
	local item = Cosmetics.Items[itemId]
	if item == nil or item.Category ~= "ElimEffectAssets" or item.ElimEffect == nil then
		return default
	end
	return item.ElimEffect
end

-- Which elimination sound an Elim carries is not a field on the event: a
-- projectile means the dodgeball, a source without one means the hammer, and
-- neither means the player fell into an elimination zone. A zone fall has no
-- eliminator, so it is the one variant no cosmetic can change.
local function eliminationEffect(event: { [string]: any }): string
	if event.sourceId == nil and event.projectileId == nil then
		return "ElimZoneFall"
	end
	local effect = elimEffectFor(event.sourceId)
	return if event.projectileId ~= nil then effect.DodgeballSound else effect.HammerSound
end

function GameAudio.onEvent(event: { [string]: any })
	local kind = event.kind
	if kind ~= "Elim" and kind ~= "HammerSwing" and kind ~= "BallThrown" and kind ~= "BallBounced" then
		return
	end
	-- Broadcast events can arrive more than once; a repeated sound is far more
	-- noticeable than a repeated particle.
	if not seenEvents.markSeen(event) then
		return
	end

	if kind == "Elim" then
		local host = characterPartFor(event.targetId)
		if host then
			GameAudio.play(eliminationEffect(event), host)
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

	-- Ball sounds emit from the ball itself, which the visuals already track.
	local balls = Workspace:FindFirstChild("Balls")
	local ball = balls and event.projectileId and balls:FindFirstChild(event.projectileId)
	if ball then
		GameAudio.play(if kind == "BallThrown" then "DodgeballThrow" else "DodgeballBounce", ball)
	end
end

return GameAudio
