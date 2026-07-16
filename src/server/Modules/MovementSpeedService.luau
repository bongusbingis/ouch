--!strict

local Players = game:GetService("Players")

-- Sole writer of Humanoid.WalkSpeed. Named modifiers compose multiplicatively
-- over a base speed captured when the first modifier is applied and restored
-- when the last one clears; state resets on character spawn so the authored
-- WalkSpeed stays the base. Timed modifiers use per-name generation counters
-- so a newer application or manual clear cancels a stale restore timer.

local MovementSpeedService = {}

type PlayerState = {
	baseSpeed: number,
	modifiers: { [string]: number },
}

local states: { [Player]: PlayerState } = {}
local generations: { [Player]: { [string]: number } } = {}
local started = false

local function humanoidFor(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function bumpGeneration(player: Player, name: string): number
	local perPlayer = generations[player]
	if perPlayer == nil then
		perPlayer = {}
		generations[player] = perPlayer
	end
	perPlayer[name] = (perPlayer[name] or 0) + 1
	return perPlayer[name]
end

local function apply(player: Player, state: PlayerState)
	local humanoid = humanoidFor(player)
	if humanoid == nil then
		return
	end
	local scale = 1
	for _, value in state.modifiers do
		scale *= value
	end
	humanoid.WalkSpeed = state.baseSpeed * scale
end

function MovementSpeedService.setModifier(player: Player, name: string, scale: number)
	local state = states[player]
	if state == nil then
		local humanoid = humanoidFor(player)
		if humanoid == nil then
			return
		end
		state = { baseSpeed = humanoid.WalkSpeed, modifiers = {} }
		states[player] = state
	end
	state.modifiers[name] = scale
	apply(player, state)
end

function MovementSpeedService.clearModifier(player: Player, name: string)
	bumpGeneration(player, name)
	local state = states[player]
	if state == nil or state.modifiers[name] == nil then
		return
	end
	state.modifiers[name] = nil
	if next(state.modifiers) == nil then
		local humanoid = humanoidFor(player)
		if humanoid then
			humanoid.WalkSpeed = state.baseSpeed
		end
		states[player] = nil
	else
		apply(player, state)
	end
end

function MovementSpeedService.applyTimedModifier(player: Player, name: string, scale: number, duration: number)
	MovementSpeedService.setModifier(player, name, scale)
	if states[player] == nil then
		return
	end
	local generation = bumpGeneration(player, name)
	task.delay(duration, function()
		local perPlayer = generations[player]
		if perPlayer == nil or perPlayer[name] ~= generation then
			return
		end
		MovementSpeedService.clearModifier(player, name)
	end)
end

function MovementSpeedService.start()
	if started then
		return
	end
	started = true

	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			states[player] = nil
			generations[player] = nil
		end)
	end

	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		generations[player] = nil
	end)
end

return MovementSpeedService
