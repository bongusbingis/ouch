-- Name: AnalyticsService.luau
-- Author: Jack C.
-- Description: Central analytics reporting: funnel steps, onboarding progression, economy and custom events, match and combat tallies, and periodic performance gauges, all deduplicated and dimensioned before being sent.
-- Created: 2026-07-22

--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobloxAnalytics = game:GetService("AnalyticsService")

local AnalyticsConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Analytics"))
local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("Debug"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local AnalyticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("AnalyticsLogic")
)
local PlayerAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PlayerAssist"))
local AssistProjection = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Config")
		:WaitForChild("AssistProjection")
)
local AssistResolver = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Config"):WaitForChild("AssistResolver")
)

local AnalyticsService = {}
local AnalyticsFields = require(ReplicatedStorage.Shared.Game.Economy.AnalyticsFields)
local ShopConfig = require(ReplicatedStorage.Config.Economy.Shop)

type OnboardingProgress = {
	spawned: boolean,
	matchStarted: boolean,
	matchEnded: boolean,
}

local onboardingProgress: { [number]: OnboardingProgress } = {}
local sessionStart: { [number]: number } = {}
local funnelSessionIds: { [number]: { [string]: string } } = {}
local combatDedup = EventDedup.new()
local matchStartedAt = 0
local started = false

type CombatTally = { throws: number, hits: number, catches: number, deaths: number }

local combatTallies: { [number]: CombatTally } = {}
local gauges: { [string]: () -> number } = {}

local function tallyFor(userId: number): CombatTally
	local tally = combatTallies[userId]
	if tally == nil then
		tally = { throws = 0, hits = 0, catches = 0, deaths = 0 }
		combatTallies[userId] = tally
	end
	return tally
end

local function withDimensions(
	player: Player,
	customFields: { [string]: any }?,
	eventName: string?
): { [string]: string }
	local fields: { [string]: any } = table.clone(customFields or {})
	local dimensions = AnalyticsConfig.Dimensions
	fields[dimensions.DeviceClass] = (player:GetAttribute("DeviceClass") :: string?) or "Mouse"

	local projected = player:FindFirstChild(PlayerAssist.FolderName)
	local folder = if projected and projected:IsA("Folder") then projected else nil
	fields[dimensions.AssistBucket] = AssistResolver.bucket(PlayerAssist.Entries, AssistProjection.resolved(folder))
	fields.variantId = if ShopConfig.VariantId == "" then "Default" else ShopConfig.VariantId
	local schemas = AnalyticsConfig.FieldSchemas
	local schema = if eventName == "Economy"
		then schemas.Economy
		else if eventName and string.sub(eventName, 1, 4) == "Shop" then schemas.Shop else schemas.Default
	return AnalyticsFields.resolve(schema, fields)
end

local function isStudio(): boolean
	return RunService:IsStudio()
end

local function verbose(): boolean
	return Debug.AnalyticsVerbose == true
end

local function progressFor(userId: number): OnboardingProgress
	local progress = onboardingProgress[userId]
	if progress == nil then
		progress = { spawned = false, matchStarted = false, matchEnded = false }
		onboardingProgress[userId] = progress
	end
	return progress
end

local function funnelSessionId(userId: number, funnelName: string, step: number): string
	local byFunnel = funnelSessionIds[userId]
	if byFunnel == nil then
		byFunnel = {}
		funnelSessionIds[userId] = byFunnel
	end
	local id = byFunnel[funnelName]
	if id == nil or step <= 1 then
		id = HttpService:GenerateGUID(false)
		byFunnel[funnelName] = id
	end
	return id
end

local function logOnboardingStep(player: Player, step: number, stepName: string, customFields: { [string]: any }?)
	if isStudio() then
		if verbose() then
			print(`[Analytics/studio] OnboardingStep {player.Name} step={step} name={stepName}`)
		end
		return
	end
	local ok, err = pcall(function()
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, stepName, withDimensions(player, customFields))
	end)
	if not ok then
		warn(`[AnalyticsService] LogOnboardingFunnelStepEvent failed: {err}`)
	elseif verbose() then
		print(`[Analytics] OnboardingStep {player.Name} step={step} name={stepName}`)
	end
end

function AnalyticsService.logFunnelStep(
	player: Player,
	funnelName: string,
	step: number,
	stepName: string,
	customFields: { [string]: any }?
)
	local sessionId = funnelSessionId(player.UserId, funnelName, step)
	if isStudio() then
		if verbose() then
			print(`[Analytics/studio] FunnelStep {player.Name} funnel={funnelName} step={step} name={stepName}`)
		end
		return
	end
	local ok, err = pcall(function()
		RobloxAnalytics:LogFunnelStepEvent(
			player,
			funnelName,
			sessionId,
			step,
			stepName,
			withDimensions(player, customFields, funnelName)
		)
	end)
	if not ok then
		warn(`[AnalyticsService] LogFunnelStepEvent failed: {err}`)
	elseif verbose() then
		print(`[Analytics] FunnelStep {player.Name} funnel={funnelName} step={step} name={stepName}`)
	end
end

function AnalyticsService.logEconomyEvent(
	player: Player,
	flowType: AnalyticsConfig.EconomyFlowType,
	currencyType: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	itemSku: string,
	customFields: { [string]: any }?
)
	if isStudio() then
		if verbose() then
			print(
				`[Analytics/studio] Economy {player.Name} flow={flowType} currency={currencyType} amount={amount} type={transactionType} sku={itemSku}`
			)
		end
		return
	end
	local ok, err = pcall(function()
		RobloxAnalytics:LogEconomyEvent(
			player,
			(Enum.AnalyticsEconomyFlowType :: any)[flowType],
			currencyType,
			amount,
			endingBalance,
			transactionType,
			itemSku,
			withDimensions(player, customFields, "Economy")
		)
	end)
	if not ok then
		warn(`[AnalyticsService] LogEconomyEvent failed: {err}`)
	elseif verbose() then
		print(
			`[Analytics] Economy {player.Name} flow={flowType} currency={currencyType} amount={amount} type={transactionType} sku={itemSku}`
		)
	end
end

function AnalyticsService.logCustomEvent(
	player: Player,
	eventName: string,
	value: number?,
	customFields: { [string]: any }?
)
	if isStudio() then
		if verbose() then
			print(`[Analytics/studio] Custom {player.Name} event={eventName} value={value or 1}`)
		end
		return
	end
	local ok, err = pcall(function()
		RobloxAnalytics:LogCustomEvent(player, eventName, value, withDimensions(player, customFields, eventName))
	end)
	if not ok then
		warn(`[AnalyticsService] LogCustomEvent failed: {err}`)
	elseif verbose() then
		print(`[Analytics] Custom {player.Name} event={eventName} value={value or 1}`)
	end
end

local function advanceOnboarding(player: Player, kind: AnalyticsLogic.OnboardingKind)
	local progress = progressFor(player.UserId)
	local step, stepName = AnalyticsLogic.onboardingStepFor(kind, progress)
	if step == nil or stepName == nil then
		return
	end
	if kind == "FirstSpawn" then
		progress.spawned = true
	elseif kind == "MatchStarted" then
		progress.matchStarted = true
	elseif kind == "MatchEnded" then
		progress.matchEnded = true
	end
	logOnboardingStep(player, step, stepName)
end

local function onCharacterAdded(player: Player)
	advanceOnboarding(player, "FirstSpawn")
end

local function onPlayerAdded(player: Player)
	sessionStart[player.UserId] = os.clock()
	advanceOnboarding(player, "Joined")
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	if player.Character then
		onCharacterAdded(player)
	end
end

local function onPlayerRemoving(player: Player)
	local startedAt = sessionStart[player.UserId]
	local playtime = if startedAt then os.clock() - startedAt else 0
	AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.SessionEnded, playtime)
	onboardingProgress[player.UserId] = nil
	sessionStart[player.UserId] = nil
	funnelSessionIds[player.UserId] = nil
	combatTallies[player.UserId] = nil
end

local function matchStateAttribute(name: string): any
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	return if matchState then matchState:GetAttribute(name) else nil
end

local function handleElimOrCatch(event: { [string]: any })
	if not combatDedup.markSeen(event) then
		return
	end

	local modeId = matchStateAttribute("modeId")

	if event.kind == "Elim" then
		local source = PlayerIds.fromId(event.sourceId)
		if source then
			tallyFor(source.UserId).hits += 1
		end
		local target = PlayerIds.fromId(event.targetId)
		if target then
			tallyFor(target.UserId).deaths += 1
			AnalyticsService.logCustomEvent(target, AnalyticsConfig.CustomEvents.Elimination, 1, {
				weaponType = AnalyticsLogic.weaponTypeForElim(event),
				modeId = modeId,
				killer = event.sourceId,
			})
		end
	elseif event.kind == "BallCaught" then
		local catcher = PlayerIds.fromId(event.playerId or event.sourceId)
		if catcher then
			tallyFor(catcher.UserId).catches += 1
			AnalyticsService.logCustomEvent(catcher, AnalyticsConfig.CustomEvents.BallCaught, 1, {
				modeId = modeId,
			})
		end
	end
end

local function handleMatchEvent(event: { [string]: any })
	if event.kind == "MatchStarted" then
		combatDedup.clear()
		table.clear(combatTallies)
		matchStartedAt = os.clock()
		for _, player in Players:GetPlayers() do
			advanceOnboarding(player, "MatchStarted")
		end
	elseif event.kind == "BallWindup" then
		if combatDedup.markSeen(event) then
			local thrower = PlayerIds.fromId(event.playerId)
			if thrower then
				tallyFor(thrower.UserId).throws += 1
			end
		end
	elseif event.kind == "Elim" or event.kind == "BallCaught" then
		handleElimOrCatch(event)
	elseif event.kind == "MatchEnded" then
		local durationSeconds = if matchStartedAt > 0 then os.clock() - matchStartedAt else 0
		local gaugeValues: { [string]: any } = {}
		for name, read in gauges do
			local ok, value = pcall(read)
			gaugeValues[name] = if ok then value else nil
		end
		matchStartedAt = 0
		local modeId = matchStateAttribute("modeId")
		local playerCount = #Players:GetPlayers()
		for _, player in Players:GetPlayers() do
			advanceOnboarding(player, "MatchEnded")
			AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.MatchCompleted, durationSeconds, {
				reason = event.reason,
				winnerId = event.winnerId,
				modeId = modeId,
				playerCount = playerCount,
				score = player:GetAttribute("MatchScore"),
				won = event.winnerId ~= nil
					and (event.winnerId == PlayerIds.toId(player) or event.winnerId == player:GetAttribute("TeamId")),
			})

			local tally = tallyFor(player.UserId)
			local fields: { [string]: any } = {
				modeId = modeId,
				throws = tally.throws,
				hits = tally.hits,
				catches = tally.catches,
				deaths = tally.deaths,
			}
			for name, value in gaugeValues do
				fields[name] = value
			end
			AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.CombatSummary, tally.throws, fields)
			for _, metric in { "hits", "catches", "deaths" } do
				AnalyticsService.logCustomEvent(player, "Combat_" .. metric, tally[metric], { modeId = modeId })
			end
		end
		local reporter = Players:GetPlayers()[1]
		if reporter then
			for name, value in gaugeValues do
				AnalyticsService.logCustomEvent(reporter, "Server_" .. name, value, { modeId = modeId })
			end
		end
		table.clear(combatTallies)
	end
end

local function handleReport(player: Player, payload: { [string]: any })
	local route = AnalyticsLogic.routeUIEvent(payload :: AnalyticsLogic.UIEventPayload)
	if route == nil then
		return
	end
	if route.funnel and route.step and route.stepName then
		AnalyticsService.logFunnelStep(player, route.funnel, route.step, route.stepName)
	elseif route.customEventName then
		AnalyticsService.logCustomEvent(player, route.customEventName, 1, {
			menuId = payload.menuId,
			offerKey = payload.offerKey,
			offerKind = payload.offerKind,
		})
	end
end

function AnalyticsService.registerGauge(name: string, read: () -> number)
	gauges[name] = read
end

local function sampleLatency()
	for _, player in Players:GetPlayers() do
		local ok, ping = pcall(function()
			return player:GetNetworkPing()
		end)
		if ok and typeof(ping) == "number" then
			AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.InputLatency, ping * 2000)
		end
	end
end

function AnalyticsService.start(matchService: any?)
	if started then
		return
	end
	started = true

	Network.handleProtected("ReportAnalyticsEvent", {
		rateLimit = 10,
		validate = function(_player, payload)
			if typeof(payload) ~= "table" or typeof(payload.kind) ~= "string" then
				return false, "invalid_payload"
			end
			return AnalyticsLogic.routeUIEvent(payload :: AnalyticsLogic.UIEventPayload) ~= nil, "unknown_kind"
		end,
	}, handleReport)

	if matchService then
		matchService.onEvent(handleMatchEvent)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(AnalyticsConfig.LatencySampleSeconds)
			sampleLatency()
		end
	end)
end

return AnalyticsService
