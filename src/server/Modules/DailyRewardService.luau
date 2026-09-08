-- Description: Server owner of daily reward state: validates and grants one claim per UTC day, advancing through a 7-day cycle without streak reset, and pushes state changes to the client.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyRewardsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("DailyRewards"))
local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local DailyRewardLogic = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("DailyReward")
		:WaitForChild("DailyRewardLogic")
)
local PlayerData = require(script.Parent.PlayerData)
local RewardService = require(script.Parent.RewardService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local DailyRewardService = {}

type StartOptions = {
	players: any?,
	config: any?,
	playerData: any?,
	rewardService: any?,
	network: any?,
	analyticsService: any?,
	time: (() -> number)?,
	runAsync: ((callback: () -> ()) -> ())?,
}

local started = false
local activePlayers: any = Players
local activeConfig: any = DailyRewardsConfig
local activePlayerData: any = PlayerData
local activeRewardService: any = RewardService
local activeNetwork: any = Network
local activeAnalyticsService: any = AnalyticsService
local activeTime: () -> number = os.time
local activeRunAsync: (callback: () -> ()) -> () = task.spawn
local connections: { any } = {}

function DailyRewardService.ensureData(player: Player): any
	local data = activePlayerData.get(player)
	if data == nil then
		return nil
	end
	if data.DailyReward == nil then
		data.DailyReward = DailyRewardLogic.blankState()
	end
	return data
end

function DailyRewardService.stateFor(player: Player): DailyRewardLogic.PublicState?
	local data = DailyRewardService.ensureData(player)
	if data == nil then
		return nil
	end
	local state = DailyRewardLogic.readState(data.DailyReward)
	return DailyRewardLogic.publicState(state, activeConfig, activeTime())
end

function DailyRewardService.fireState(player: Player)
	local state = DailyRewardService.stateFor(player)
	if state ~= nil then
		activeNetwork.fire("DailyRewardStateChanged", player, state)
	end
end

function DailyRewardService.claim(player: Player): (DailyRewardLogic.PublicState?, string?)
	local data = DailyRewardService.ensureData(player)
	if data == nil then
		return nil, "profile_not_ready"
	end

	local state = DailyRewardLogic.readState(data.DailyReward)
	local now = activeTime()

	local newState, result = DailyRewardLogic.claim(state, activeConfig, now)
	if newState == nil or result == nil then
		return nil, "not_available"
	end

	local granted, grantReason = activeRewardService.grant(player, result.reward)
	if not granted then
		return nil, grantReason or "grant_failed"
	end

	data.DailyReward.Day = newState.Day
	data.DailyReward.LastClaimAt = newState.LastClaimAt
	data.DailyReward.TotalClaimed = newState.TotalClaimed

	activeAnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.DailyRewardClaimed, 1, {
		day = result.day,
		totalClaimed = newState.TotalClaimed,
	})
	if result.reward.kind == "Bonks" then
		activeAnalyticsService.logEconomyEvent(
			player,
			"Source",
			"Bonks",
			result.reward.amount or 0,
			data.Bonks,
			AnalyticsConfig.EconomyTransactionTypes.TimedReward,
			`daily_reward_day_{result.day}`
		)
	end

	local publicState = DailyRewardLogic.publicState(newState, activeConfig, now)
	activeNetwork.fire("DailyRewardStateChanged", player, publicState)
	return publicState, nil
end

local function waitForProfile(player: Player)
	local deadline = os.clock() + 15
	while player.Parent ~= nil and activePlayerData.get(player) == nil and os.clock() < deadline do
		task.wait()
	end
	if player.Parent ~= nil then
		DailyRewardService.fireState(player)
	end
end

function DailyRewardService.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	activePlayers = if options and options.players then options.players else Players
	activeConfig = if options and options.config then options.config else DailyRewardsConfig
	activePlayerData = if options and options.playerData then options.playerData else PlayerData
	activeRewardService = if options and options.rewardService then options.rewardService else RewardService
	activeNetwork = if options and options.network then options.network else Network
	activeAnalyticsService = if options and options.analyticsService then options.analyticsService else AnalyticsService
	activeTime = if options and options.time then options.time else os.time
	activeRunAsync = if options and options.runAsync then options.runAsync else task.spawn

	activeNetwork.handleProtected("GetDailyRewardState", { rateLimit = 4 }, function(player)
		return DailyRewardService.stateFor(player)
	end)
	activeNetwork.handleProtected("ClaimDailyReward", { rateLimit = 3 }, function(player)
		return DailyRewardService.claim(player)
	end)

	table.insert(
		connections,
		activePlayers.PlayerAdded:Connect(function(player)
			activeRunAsync(function()
				waitForProfile(player)
			end)
		end)
	)
	for _, player in activePlayers:GetPlayers() do
		activeRunAsync(function()
			waitForProfile(player)
		end)
	end
end

function DailyRewardService._resetForTest()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	started = false
	activePlayers = Players
	activeConfig = DailyRewardsConfig
	activePlayerData = PlayerData
	activeRewardService = RewardService
	activeNetwork = Network
	activeAnalyticsService = AnalyticsService
	activeTime = os.time
	activeRunAsync = task.spawn
end

return DailyRewardService
