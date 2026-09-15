-- Name: EmotePlayback.luau
-- Author: Jack C.
-- Description: Plays replicated emotes on arena characters, and cancels the local player's own emote the moment they move, jump, take a hit or fall so a taunt never lingers over gameplay.
-- Created: 2026-09-09
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local EmotePlayer = require(Shared:WaitForChild("Game"):WaitForChild("Cosmetics"):WaitForChild("EmotePlayer"))

local EmotePlayback = {}

local MOVE_GRACE_SECONDS = 0.2

local connections: { RBXScriptConnection } = {}
local remoteTracks: { [Player]: AnimationTrack } = {}
local localTrack: AnimationTrack? = nil
local localWatch: RBXScriptConnection? = nil
local started = false

local function animatorFor(character: Model?): Animator?
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator == nil then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function stopLocal()
	if localWatch then
		localWatch:Disconnect()
		localWatch = nil
	end
	if localTrack then
		EmotePlayer.stop(localTrack)
		localTrack = nil
	end
end

local function watchLocal(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end
	local startedAt = os.clock()
	localWatch = RunService.Heartbeat:Connect(function()
		local track = localTrack
		if track == nil or not track.IsPlaying then
			stopLocal()
			return
		end
		if os.clock() - startedAt < MOVE_GRACE_SECONDS then
			return
		end
		local state = humanoid:GetState()
		if
			humanoid.MoveDirection.Magnitude > 0.05
			or state == Enum.HumanoidStateType.Jumping
			or state == Enum.HumanoidStateType.Freefall
			or humanoid.Health <= 0
			or character:GetAttribute("CombatAlive") == false
		then
			stopLocal()
		end
	end)
end

local function play(userId: any, emoteId: any)
	if type(userId) ~= "number" or type(emoteId) ~= "string" then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	local character = if player then player.Character else nil
	local animator = animatorFor(character)
	if player == nil or character == nil or animator == nil then
		return
	end
	if player == Players.LocalPlayer then
		stopLocal()
		localTrack = EmotePlayer.play(animator, emoteId)
		if localTrack then
			watchLocal(character)
		end
		return
	end
	EmotePlayer.stop(remoteTracks[player])
	local track = EmotePlayer.play(animator, emoteId)
	if track then
		remoteTracks[player] = track
	else
		remoteTracks[player] = nil
	end
end

function EmotePlayback.start()
	if started then
		return
	end
	started = true
	table.insert(connections, Network.on("EmotePlayed", play))
	table.insert(
		connections,
		Network.on("DamageFeedback", function()
			stopLocal()
		end)
	)
	table.insert(
		connections,
		Players.LocalPlayer.CharacterRemoving:Connect(function()
			stopLocal()
		end)
	)
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function(player)
			remoteTracks[player] = nil
		end)
	)
end

function EmotePlayback.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	stopLocal()
	table.clear(remoteTracks)
	started = false
end

return EmotePlayback
