--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Data"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local PlayerData = require(script.Parent.PlayerData)

type MatchEvent = { [string]: any }

type MatchProgress = {
	Elims: number,
	Deaths: number,
	Catches: number,
	Wins: number,
	Losses: number,
	MatchesPlayed: number,
	XP: number,
	Cash: number,
}

local ProgressionService = {}

local progressByPlayerId: { [string]: MatchProgress } = {}
local seenEvents = EventDedup.new()
local started = false

local function blank(): MatchProgress
	return {
		Elims = 0,
		Deaths = 0,
		Catches = 0,
		Wins = 0,
		Losses = 0,
		MatchesPlayed = 0,
		XP = 0,
		Cash = 0,
	}
end

local function progressFor(id: string): MatchProgress
	local progress = progressByPlayerId[id]
	if progress == nil then
		progress = blank()
		progressByPlayerId[id] = progress
	end
	return progress
end

local function resetMatch()
	table.clear(progressByPlayerId)
	seenEvents.clear()
	for _, player in Players:GetPlayers() do
		progressFor(PlayerIds.toId(player))
	end
end

local function addRewards(progress: MatchProgress, rewardKey: string)
	progress.XP += DataConfig.ProgressionXP[rewardKey] or 0
	progress.Cash += DataConfig.ProgressionCash[rewardKey] or 0
end

local function trackElim(event: MatchEvent)
	if not seenEvents.markSeen(event) then
		return
	end

	local sourceId = event.sourceId :: string?
	local targetId = event.targetId :: string?
	if sourceId == nil or targetId == nil or sourceId == targetId then
		return
	end

	local source = progressFor(sourceId)
	source.Elims += 1
	addRewards(source, "Elim")

	local target = progressFor(targetId)
	target.Deaths += 1
end

local function trackCatch(event: MatchEvent)
	if not seenEvents.markSeen(event) then
		return
	end

	local catcherId = (event.playerId or event.sourceId) :: string?
	if catcherId == nil then
		return
	end

	local progress = progressFor(catcherId)
	progress.Catches += 1
	addRewards(progress, "Catch")
end

local function commitMatch(event: MatchEvent)
	local winnerId = event.winnerId :: string?
	for id, progress in progressByPlayerId do
		local player = PlayerIds.fromId(id)
		local playerWon = player ~= nil and (id == winnerId or player:GetAttribute("TeamId") == winnerId)

		progress.MatchesPlayed += 1
		addRewards(progress, "MatchComplete")

		if winnerId ~= nil and winnerId ~= "" then
			if playerWon then
				progress.Wins += 1
				addRewards(progress, "Win")
			else
				progress.Losses += 1
			end
		end

		if player then
			PlayerData.applyProgression(player, progress)
			PlayerData.completeTutorial(player)
			Network.fire("MatchSummary", player, {
				won = playerWon,
				elims = progress.Elims,
				deaths = progress.Deaths,
				catches = progress.Catches,
				xp = progress.XP,
				cash = progress.Cash,
			})
		end
	end
end

local function handleEvent(event: MatchEvent)
	if event.kind == "MatchStarted" then
		resetMatch()
	elseif event.kind == "Elim" then
		trackElim(event)
	elseif event.kind == "BallCaught" then
		trackCatch(event)
	elseif event.kind == "MatchEnded" then
		commitMatch(event)
	end
end

function ProgressionService.start(matchService: any)
	if started then
		return
	end
	started = true
	resetMatch()
	matchService.onEvent(handleEvent)
	Players.PlayerAdded:Connect(function(player)
		local phase = matchService.phase()
		if phase == "Starting" or phase == "Active" then
			progressFor(PlayerIds.toId(player))
		end
	end)
end

return ProgressionService
