-- Name: SimulationServer.server.luau
-- Author: Jack C.
-- Description: Arena server entry point: starts every gameplay, economy, and analytics service in order and wires sim events through to animations, feedback, and progression consumers.
-- Created: 2026-07-12

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local ArenaSessionService = require(Modules:WaitForChild("ArenaSessionService"))
ArenaSessionService.start()

local InputSetup = require(Modules:WaitForChild("InputSetup"))
local PlayerConfigService = require(Modules:WaitForChild("PlayerConfigService"))
local PlayerAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PlayerAssist"))
local ArenaReturnService = require(Modules:WaitForChild("ArenaReturnService"))
local ConfigLiveService = require(Modules:WaitForChild("ConfigLiveService"))
local BallService = require(Modules:WaitForChild("BallService"))
local MatchService = require(Modules:WaitForChild("MatchService"))
local ModeVoteService = require(Modules:WaitForChild("ModeVoteService"))
local MapFeatureService = require(Modules:WaitForChild("MapFeatureService"))
local AnalyticsService = require(Modules:WaitForChild("AnalyticsService"))
local CombatPoseService = require(Modules:WaitForChild("CombatPoseService"))
local ProgressionService = require(Modules:WaitForChild("ProgressionService"))
local QuestService = require(Modules:WaitForChild("QuestService"))
local PostMatchService = require(Modules:WaitForChild("PostMatchService"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))
local CharacterColorService = require(Modules:WaitForChild("CharacterColorService"))
local EconomyService = require(Modules:WaitForChild("EconomyService"))
local SettingsService = require(Modules:WaitForChild("SettingsService"))
local CmdrService = require(Modules:WaitForChild("CmdrService"))
local ThrowUXService = require(Modules:WaitForChild("ThrowUXService"))

local RotatingPlatforms = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("RotatingPlatforms")
)
local Adapters = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters")
local ServerAuthAdapter = require(Adapters:WaitForChild("ServerAuthAdapter"))
local PlayerIds = require(Adapters:WaitForChild("PlayerIds"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local ConfigRoot = ReplicatedStorage:WaitForChild("Config")
local Combat = require(ConfigRoot:WaitForChild("Gameplay"):WaitForChild("Combat"))

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

ConfigLiveService.start({
	modules = {
		Combat = Combat,
		AimAssist = require(ConfigRoot:WaitForChild("Gameplay"):WaitForChild("AimAssist")),
		GameModes = require(ConfigRoot:WaitForChild("Gameplay"):WaitForChild("GameModes")),
		MapFeatures = require(ConfigRoot:WaitForChild("Gameplay"):WaitForChild("MapFeatures")),
		Modes = require(ConfigRoot:WaitForChild("Gameplay"):WaitForChild("Modes")),
		Shop = require(ConfigRoot:WaitForChild("Economy"):WaitForChild("Shop")),
		Crates = require(ConfigRoot:WaitForChild("Economy"):WaitForChild("Crates")),
	},
	holdSimOverrides = function()
		local phase = MatchService.phase()
		return phase == "Starting" or phase == "Active"
	end,
})
MatchService.onEvent(function(event)
	if event.kind == "MatchPreparing" then
		ConfigLiveService.releaseLatched()
	end
end)

ArenaReturnService.start()
PlayerConfigService.start({ schemas = { PlayerAssist } })
InputSetup.start()
BallService.start()
MapFeatureService.start()
RotatingPlatforms.startMover()
MatchService.start()
ModeVoteService.start()
AnalyticsService.start(MatchService)
CombatPoseService.start()
AnalyticsService.registerGauge("droppedSimMs", ServerAuthAdapter.takeDroppedMilliseconds)
AnalyticsService.registerGauge("rejectedInputs", ServerAuthAdapter.takeRejectedInputs)
AnalyticsService.registerGauge("movementCorrections", require(Adapters.MovementGuard).takeCorrections)
CosmeticsService.start()
CharacterColorService.start()
EconomyService.start()
SettingsService.start()
ProgressionService.start(MatchService)
QuestService.start(MatchService)
PostMatchService.start()
CmdrService.start()
ThrowUXService.start()

ServerAuthAdapter.onEvent(function(event)
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
