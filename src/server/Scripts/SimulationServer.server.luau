local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local InputSetup = require(Modules:WaitForChild("InputSetup"))
local BallService = require(Modules:WaitForChild("BallService"))
local MatchService = require(Modules:WaitForChild("MatchService"))

local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local ServerAuthAdapter = require(Adapters:WaitForChild("ServerAuthAdapter"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))

local playedAnimationEvents = {}
local retainedTracks = {}
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes == nil then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local damageFeedbackRemote = remotes:FindFirstChild("DamageFeedback")
if damageFeedbackRemote == nil then
	damageFeedbackRemote = Instance.new("RemoteEvent")
	damageFeedbackRemote.Name = "DamageFeedback"
	damageFeedbackRemote.Parent = remotes
end
assert(damageFeedbackRemote:IsA("RemoteEvent"), "[Combat] Remotes.DamageFeedback must be a RemoteEvent")

local function findAnimation(name)
	local animation = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Animations"):WaitForChild(name)
	assert(animation:IsA("Animation"), `[Combat] Assets.Animations.{name} must be an Animation`)
	return animation
end

local function playerFromEvent(event)
	local playerId = event.playerId or event.sourceId
	local userId = if playerId then tonumber(playerId) else nil
	if userId == nil then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function playerFromId(playerId)
	local userId = if playerId then tonumber(playerId) else nil
	if userId == nil then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

local function rootForPlayer(player)
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function playThrowAnimation(event)
	if event.kind ~= "BallWindup" then
		return
	end

	local key = `{event.kind}:{event.tick}:{event.projectileId or ""}`
	if playedAnimationEvents[key] then
		return
	end
	playedAnimationEvents[key] = true
	task.delay(5, function()
		playedAnimationEvents[key] = nil
	end)

	local animation = findAnimation(Combat.Dodgeball.ThrowAnimationName)

	local player = playerFromEvent(event)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil or character:GetAttribute("CombatAlive") == false then
		return
	end

	local animator = humanoid:WaitForChild("Animator")
	assert(animator:IsA("Animator"), "[Combat] Humanoid.Animator must be an Animator")

	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false
	track:Play(0.04)

	table.insert(retainedTracks, track)
	task.delay(3, function()
		local index = table.find(retainedTracks, track)
		if index then
			table.remove(retainedTracks, index)
		end
	end)
end

local function playHammerAnimation(event)
	if event.kind ~= "HammerSwing" then
		return
	end

	local key = `{event.kind}:{event.tick}:{event.playerId or ""}`
	if playedAnimationEvents[key] then
		return
	end
	playedAnimationEvents[key] = true
	task.delay(5, function()
		playedAnimationEvents[key] = nil
	end)

	local player = playerFromEvent(event)
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character == nil or humanoid == nil or character:GetAttribute("CombatAlive") == false then
		return
	end

	local animator = humanoid:WaitForChild("Animator")
	assert(animator:IsA("Animator"), "[Combat] Humanoid.Animator must be an Animator")

	local track = animator:LoadAnimation(findAnimation(Combat.Hammer.AnimationName))
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = false
	track:Play(0.03)

	table.insert(retainedTracks, track)
	task.delay(2, function()
		local index = table.find(retainedTracks, track)
		if index then
			table.remove(retainedTracks, index)
		end
	end)
end

local function applyHammerMotion(event)
	if event.direction == nil then
		return
	end

	if event.kind == "HammerHit" and event.targetId ~= nil then
		local root = rootForPlayer(playerFromId(event.targetId))
		if root == nil then
			return
		end
		local direction = event.direction
		root.AssemblyLinearVelocity = Vector3.new(
			direction.x * Combat.Hammer.KnockbackSpeed,
			Combat.Hammer.KnockbackUpSpeed,
			direction.z * Combat.Hammer.KnockbackSpeed
		)
	end
end

local function forwardDamageFeedback(event)
	if event.kind ~= "Elim" or event.targetId == nil then
		return
	end

	local target = playerFromId(event.targetId)
	if target == nil then
		return
	end

	damageFeedbackRemote:FireClient(target, {
		kind = "Elim",
		tick = event.tick,
		projectileId = event.projectileId,
		sourceId = tostring(event.sourceId or ""),
		targetId = tostring(event.targetId),
	})
end

InputSetup.start()
BallService.start()
MatchService.start()

-- Server-side events are authoritative.
ServerAuthAdapter.onEvent(function(event)
	playThrowAnimation(event)
	playHammerAnimation(event)
	applyHammerMotion(event)
	local acceptedElim = MatchService.handleCombatEvent(event)
	if acceptedElim then
		forwardDamageFeedback(event)
	end

	if event.kind == "Elim" then
		print(`[Combat] {event.sourceId} eliminated {event.targetId} ({event.projectileId})`)
	end
end)

ServerAuthAdapter.start()
