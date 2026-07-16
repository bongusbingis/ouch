local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local InputSetup = require(Modules:WaitForChild("InputSetup"))
local BallService = require(Modules:WaitForChild("BallService"))
local MatchService = require(Modules:WaitForChild("MatchService"))
local MapFeatureService = require(Modules:WaitForChild("MapFeatureService"))
local MovementSpeedService = require(Modules:WaitForChild("MovementSpeedService"))
local ProgressionService = require(Modules:WaitForChild("ProgressionService"))
local QuestService = require(Modules:WaitForChild("QuestService"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))
local CrateService = require(Modules:WaitForChild("CrateService"))
local MonetizationService = require(Modules:WaitForChild("MonetizationService"))

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local ServerAuthAdapter = require(Adapters:WaitForChild("ServerAuthAdapter"))
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))

local playedAnimations = EventDedup.new(4096)
local appliedStuns = EventDedup.new(4096)
local retainedTracks = {}

local function findAnimation(name)
	local animation = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations"):WaitForChild(name)
	assert(animation:IsA("Animation"), `[Combat] Assets.Animations.{name} must be an Animation`)
	return animation
end

local function rootForPlayer(player)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function eventDirection(event): Vector3?
	local direction = event.direction
	if typeof(direction) == "Vector3" then
		local flat = Vector3.new(direction.X, 0, direction.Z)
		return if flat.Magnitude > 1e-6 then flat.Unit else nil
	elseif typeof(direction) == "vector" then
		local flat = Vector3.new(direction.x, 0, direction.z)
		return if flat.Magnitude > 1e-6 then flat.Unit else nil
	end
	return nil
end

-- Which sim events play a character animation, and how. New animated events
-- add a row here rather than a new handler.
local eventAnimations = {
	BallWindup = { animationName = Combat.Dodgeball.ThrowAnimationName, fadeTime = 0.04, retainSeconds = 3 },
	HammerSwing = { animationName = Combat.Hammer.AnimationName, fadeTime = 0.03, retainSeconds = 2 },
}

local function playEventAnimation(event)
	local spec = eventAnimations[event.kind]
	if spec == nil or not playedAnimations.markSeen(event) then
		return
	end

	local player = PlayerIds.fromEvent(event)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil or character:GetAttribute("CombatAlive") == false then
		return
	end

	local animator = humanoid:WaitForChild("Animator")
	assert(animator:IsA("Animator"), "[Combat] Humanoid.Animator must be an Animator")

	local track = animator:LoadAnimation(findAnimation(spec.animationName))
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false
	track:Play(spec.fadeTime)

	table.insert(retainedTracks, track)
	task.delay(spec.retainSeconds, function()
		local index = table.find(retainedTracks, track)
		if index then
			table.remove(retainedTracks, index)
		end
	end)
end

local function applyHammerMotion(event)
	local direction = eventDirection(event)
	if direction == nil then
		return
	end

	if event.kind == "HammerSwing" then
		local root = rootForPlayer(PlayerIds.fromEvent(event))
		if root == nil then
			return
		end
		local current = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity =
			Vector3.new(direction.X * Combat.Hammer.DashSpeed, current.Y, direction.Z * Combat.Hammer.DashSpeed)
	elseif event.kind == "HammerHit" and event.targetId ~= nil then
		local root = rootForPlayer(PlayerIds.fromId(event.targetId))
		if root == nil then
			return
		end
		root.AssemblyLinearVelocity = Vector3.new(
			direction.X * Combat.Hammer.KnockbackSpeed,
			Combat.Hammer.KnockbackUpSpeed,
			direction.Z * Combat.Hammer.KnockbackSpeed
		)
	end
end

local function applyHammerMissStun(event)
	if event.kind ~= "HammerMiss" then
		return
	end

	if not appliedStuns.markSeen(event) then
		return
	end

	local player = PlayerIds.fromEvent(event)
	local character = player and player.Character
	if player == nil or character == nil or character:GetAttribute("CombatAlive") == false then
		return
	end

	MovementSpeedService.applyTimedModifier(
		player,
		"hammerStun",
		Combat.Hammer.MissStunWalkSpeedScale,
		Combat.Hammer.MissStunDuration
	)
end

local function forwardDamageFeedback(event)
	if event.kind ~= "Elim" or event.targetId == nil then
		return
	end

	local target = PlayerIds.fromId(event.targetId)
	if target == nil then
		return
	end

	Network.fire("DamageFeedback", target, {
		kind = "Elim",
		tick = event.tick,
		projectileId = event.projectileId,
		sourceId = tostring(event.sourceId or ""),
		targetId = tostring(event.targetId),
	})
end

InputSetup.start()
BallService.start()
MovementSpeedService.start()
MapFeatureService.start()
MatchService.start()
ProgressionService.start(MatchService)
QuestService.start(MatchService)
CosmeticsService.start()
CrateService.start()
MonetizationService.start()

-- Server-side events are authoritative.
ServerAuthAdapter.onEvent(function(event)
	playEventAnimation(event)
	applyHammerMotion(event)
	applyHammerMissStun(event)
	local acceptedElim = MatchService.handleCombatEvent(event)
	if acceptedElim then
		QuestService.handleCombatEvent(event)
		forwardDamageFeedback(event)
	elseif event.kind ~= "Elim" then
		QuestService.handleCombatEvent(event)
	end

	if event.kind == "Elim" then
		print(`[Combat] {event.sourceId} eliminated {event.targetId} ({event.projectileId})`)
	end
end)

ServerAuthAdapter.start()
