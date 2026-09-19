-- Description: Arena server entry point: starts every gameplay, economy, and analytics service in order and wires sim events through to animations, feedback, and progression consumers.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local ArenaSessionService = require(Modules:WaitForChild("ArenaSessionService"))
ArenaSessionService.start()

local InputSetup = require(Modules:WaitForChild("InputSetup"))
local PlayerConfigService = require(Modules:WaitForChild("PlayerConfigService"))
local PlayerAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PlayerAssist"))
local ArenaReturnService = require(Modules:WaitForChild("ArenaReturnService"))
local LiveConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("LiveConfig"))
local ConfigLiveService = require(Modules:WaitForChild("ConfigLiveService"))
local BallService = require(Modules:WaitForChild("BallService"))
local ArenaService = require(Modules:WaitForChild("ArenaService"))
local VenueService = require(Modules:WaitForChild("VenueService"))
local MatchService = require(Modules:WaitForChild("MatchService"))
local ModeVoteService = require(Modules:WaitForChild("ModeVoteService"))
local SplashdownService = require(Modules:WaitForChild("Splashdown"):WaitForChild("SplashdownService"))
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
local CombatSimServer = require(Adapters:WaitForChild("CombatSimServer"))
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
	modules = LiveConfig.loadModules("arena"),
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
-- Replenishment and void recovery, both keyed off the arena's own spawn geometry.
-- Without these a match only ever loses balls: every one thrown off the map is
-- gone for the round, and nothing puts a new one into play.
local arena = ArenaService.start()
BallService.startGroundSpawns(arena.ballSpawns)
BallService.configureRecovery(arena.ballSpawns, arena.origin.Position.Y + Combat.Dodgeball.RecoveryBelowOffset)
-- A Splashdown server parks the arena interior here, after the ball supply it
-- stands down was configured and before the kits look for their folders.
VenueService.start()
RotatingPlatforms.startMover()
MapFeatureService.start() -- inspect the anchored features after this frame's mover
MatchService.start()
ModeVoteService.start()
SplashdownService.start()
AnalyticsService.start(MatchService)
CombatPoseService.start()
AnalyticsService.registerGauge("droppedSimMs", CombatSimServer.takeDroppedMilliseconds)
AnalyticsService.registerGauge("rejectedInputs", CombatSimServer.takeRejectedInputs)
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

CombatSimServer.onEvent(function(event)
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

CombatSimServer.start()
