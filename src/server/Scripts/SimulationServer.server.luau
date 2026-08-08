local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local InputSetup = require(Modules:WaitForChild("InputSetup"))
local BallService = require(Modules:WaitForChild("BallService"))
local MatchService = require(Modules:WaitForChild("MatchService"))
local MapFeatureService = require(Modules:WaitForChild("MapFeatureService"))
local AnalyticsService = require(Modules:WaitForChild("AnalyticsService"))
local ProgressionService = require(Modules:WaitForChild("ProgressionService"))
local QuestService = require(Modules:WaitForChild("QuestService"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))
local CrateService = require(Modules:WaitForChild("CrateService"))
local MonetizationService = require(Modules:WaitForChild("MonetizationService"))
local GamePassService = require(Modules:WaitForChild("GamePassService"))
local PaidRandomPolicyService = require(Modules:WaitForChild("PaidRandomPolicyService"))
local CmdrService = require(Modules:WaitForChild("CmdrService"))

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local ServerAuthAdapter = require(Adapters:WaitForChild("ServerAuthAdapter"))
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))

local playedAnimations = EventDedup.new(4096)
local retainedTracks = {}

local function findAnimation(name)
	local animation = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations"):WaitForChild(name)
	assert(animation:IsA("Animation"), `[Combat] Assets.Animations.{name} must be an Animation`)
	return animation
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

local function forwardDamageFeedback(event)
	local recipients = {}
	if event.kind == "Elim" and event.targetId ~= nil then
		local target = PlayerIds.fromId(event.targetId)
		local source = PlayerIds.fromId(event.sourceId)
		if target then
			table.insert(recipients, target)
		end
		if source and source ~= target then
			table.insert(recipients, source)
		end
	elseif event.kind == "BallCaught" then
		local catcher = PlayerIds.fromId(event.playerId or event.sourceId)
		if catcher then
			table.insert(recipients, catcher)
		end
	else
		return
	end

	for _, recipient in recipients do
		Network.fire("DamageFeedback", recipient, {
			kind = event.kind,
			tick = event.tick,
			projectileId = event.projectileId,
			playerId = event.playerId,
			sourceId = event.sourceId,
			targetId = event.targetId,
		})
	end
end

InputSetup.start()
BallService.start()
MapFeatureService.start()
MatchService.start()
AnalyticsService.start(MatchService)
ProgressionService.start(MatchService)
QuestService.start(MatchService)
CosmeticsService.start()
PaidRandomPolicyService.start()
CrateService.start()
MonetizationService.start()
GamePassService.start()
CmdrService.start()

-- Server-side events are authoritative.
ServerAuthAdapter.onEvent(function(event)
	playEventAnimation(event)
	local acceptedElim = MatchService.handleCombatEvent(event)
	if acceptedElim or event.kind ~= "Elim" then
		QuestService.handleCombatEvent(event)
	end
	if acceptedElim or event.kind == "BallCaught" then
		forwardDamageFeedback(event)
	end

	if event.kind == "Elim" then
		print(`[Combat] {event.sourceId} eliminated {event.targetId} ({event.projectileId})`)
	end
end)

ServerAuthAdapter.start()
