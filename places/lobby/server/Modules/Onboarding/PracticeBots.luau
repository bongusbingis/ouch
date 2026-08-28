-- Name: PracticeBots.luau
-- Author: Jack C.
-- Description: The tiny wandering opponents of the freeform practice beat: they approach, circle, and come back after a knockout, giving the player something that behaves like a person to use what they just learned on.
-- Created: 2026-08-27

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OnboardingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Onboarding"))
local OnboardingLayout = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Onboarding")
		:WaitForChild("OnboardingLayout")
)
local TrainingDummies = require(script.Parent:WaitForChild("TrainingDummies"))

local PracticeBots = {}

-- Bots are deliberately harmless: they never throw and the player is
-- invulnerable for the whole session, so the practice fight can only ever end
-- in the player winning. It exists to make them feel competent, not to test
-- them.
type Bot = {
	id: string,
	home: Vector3,
	-- Time the bot last picked a new place to stand, so movement reads as
	-- deliberate rather than jittery.
	steeredAt: number,
	angle: number,
}

-- The layout module is pure and speaks the native vector type; the engine side
-- converts once, here.
local function toVector3(value: vector): Vector3
	return Vector3.new(value.x, value.y, value.z)
end

local bots: { [number]: { Bot } } = {}
local random = Random.new()

function PracticeBots.spawn(slot: number, count: number, playerPosition: Vector3)
	PracticeBots.clear(slot)
	local list: { Bot } = {}
	for index = 1, count do
		local position = toVector3(OnboardingLayout.practicePosition(slot, index, count))
		local dummy = TrainingDummies.spawn("Practice", position, playerPosition)
		table.insert(list, {
			id = dummy.id,
			home = position,
			steeredAt = 0,
			angle = random:NextNumber(0, math.pi * 2),
		})
	end
	bots[slot] = list
end

local function nearestPlayerPosition(from: Vector3): Vector3?
	local best: Vector3? = nil
	local bestDistance = math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		local distance = (root.Position - from).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			best = root.Position
		end
	end
	return best
end

function PracticeBots.step(slot: number, now: number)
	local list = bots[slot]
	if list == nil then
		return
	end
	local training = OnboardingConfig.Training
	for _, bot in list do
		if TrainingDummies.isKnockedOut(bot.id) then
			local dummy = TrainingDummies.get(bot.id)
			if
				dummy
				and dummy.knockedOutAt
				and now - dummy.knockedOutAt >= OnboardingConfig.Timing.DummyRespawnSeconds
			then
				TrainingDummies.restore(bot.id)
			end
			continue
		end
		if now - bot.steeredAt < 0.6 then
			continue
		end
		bot.steeredAt = now
		local position = TrainingDummies.position(bot.id)
		if position == nil then
			continue
		end
		local target = nearestPlayerPosition(position)
		if target == nil then
			continue
		end
		-- Approach to a comfortable distance and then circle, so the player has
		-- to turn and pick rather than swing at a stationary line.
		bot.angle += 0.5
		local toPlayer = target - position
		local flat = Vector3.new(toPlayer.X, 0, toPlayer.Z)
		local distance = flat.Magnitude
		local desired: Vector3
		if distance > 16 then
			desired = target - (if distance > 1e-3 then flat.Unit else Vector3.zAxis) * 12
		else
			desired = target + Vector3.new(math.sin(bot.angle), 0, math.cos(bot.angle)) * 12
		end
		TrainingDummies.walkTo(bot.id, desired, training.PracticeBotWalkSpeed)
	end
end

function PracticeBots.clear(slot: number)
	local list = bots[slot]
	bots[slot] = nil
	if list == nil then
		return
	end
	for _, bot in list do
		TrainingDummies.despawn(bot.id)
	end
end

function PracticeBots.count(slot: number): number
	local list = bots[slot]
	return if list then #list else 0
end

return PracticeBots
