--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobloxAnalytics = game:GetService("AnalyticsService")

local AnalyticsConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Analytics"))
local Debug = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Debug"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local EventDedup = require(Adapters:WaitForChild("EventDedup"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local AnalyticsLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("AnalyticsLogic")
)

-- Sole caller of Roblox's AnalyticsService. Every other service reports
-- through the public log* functions here rather than touching the engine
-- API directly, so naming/session-id/Studio-gating stays in one place.
--
-- In Studio, calls are never sent (the dashboard drops Studio sessions
-- anyway) — instead they're printed when Config.Debug.AnalyticsVerbose is
-- on. On a real server they're sent for real, and optionally also printed.

local AnalyticsService = {}

type OnboardingProgress = {
	spawned: boolean,
	matchStarted: boolean,
	matchEnded: boolean,
}

local onboardingProgress: { [number]: OnboardingProgress } = {}
local sessionStart: { [number]: number } = {}
local funnelSessionIds: { [number]: { [string]: string } } = {}
local combatDedup = EventDedup.new()
local started = false

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

local function funnelSessionId(userId: number, funnelName: string): string
	local byFunnel = funnelSessionIds[userId]
	if byFunnel == nil then
		byFunnel = {}
		funnelSessionIds[userId] = byFunnel
	end
	local id = byFunnel[funnelName]
	if id == nil then
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
		RobloxAnalytics:LogOnboardingFunnelStepEvent(player, step, stepName, customFields)
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
	local sessionId = funnelSessionId(player.UserId, funnelName)
	if isStudio() then
		if verbose() then
			print(`[Analytics/studio] FunnelStep {player.Name} funnel={funnelName} step={step} name={stepName}`)
		end
		return
	end
	local ok, err = pcall(function()
		RobloxAnalytics:LogFunnelStepEvent(player, funnelName, sessionId, step, stepName, customFields)
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
			customFields
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
		RobloxAnalytics:LogCustomEvent(player, eventName, value, customFields)
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
end

local function matchStateAttribute(name: string): any
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	return if matchState then matchState:GetAttribute(name) else nil
end

local function handleElimOrCatch(event: { [string]: any })
	if not combatDedup.markSeen(event) then
		return
	end

	local mapId = matchStateAttribute("mapId")
	local modeId = matchStateAttribute("modeId")

	if event.kind == "Elim" then
		local target = PlayerIds.fromId(event.targetId)
		if target then
			AnalyticsService.logCustomEvent(target, AnalyticsConfig.CustomEvents.Elimination, 1, {
				weaponType = AnalyticsLogic.weaponTypeForElim(event),
				mapId = mapId,
				modeId = modeId,
				killer = event.sourceId,
			})
		end
	elseif event.kind == "BallCaught" then
		local catcher = PlayerIds.fromId(event.playerId or event.sourceId)
		if catcher then
			AnalyticsService.logCustomEvent(catcher, AnalyticsConfig.CustomEvents.BallCaught, 1, {
				mapId = mapId,
				modeId = modeId,
			})
		end
	end
end

local function handleMatchEvent(event: { [string]: any })
	if event.kind == "MatchStarted" then
		combatDedup.clear()
		for _, player in Players:GetPlayers() do
			advanceOnboarding(player, "MatchStarted")
		end
	elseif event.kind == "Elim" or event.kind == "BallCaught" then
		handleElimOrCatch(event)
	elseif event.kind == "MatchEnded" then
		for _, player in Players:GetPlayers() do
			advanceOnboarding(player, "MatchEnded")
			AnalyticsService.logCustomEvent(player, AnalyticsConfig.CustomEvents.MatchCompleted, 1, {
				winnerId = event.winnerId,
			})
		end
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
		AnalyticsService.logCustomEvent(player, route.customEventName, 1, { menuId = payload.menuId })
	end
end

function AnalyticsService.start(matchService: any)
	if started then
		return
	end
	started = true

	Network.handleProtected("ReportAnalyticsEvent", {
		rateLimit = 10,
		validate = function(_player, payload)
			return typeof(payload) == "table" and typeof(payload.kind) == "string", "invalid_payload"
		end,
	}, handleReport)

	matchService.onEvent(handleMatchEvent)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return AnalyticsService
