local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ServerScriptService:WaitForChild("Server"):WaitForChild("Modules")
local InputSetup = require(Modules:WaitForChild("InputSetup"))
local ArenaSessionService = require(Modules:WaitForChild("ArenaSessionService"))
local PlayerAssistService = require(Modules:WaitForChild("PlayerAssistService"))
local ArenaReturnService = require(Modules:WaitForChild("ArenaReturnService"))
local ConfigLiveService = require(Modules:WaitForChild("ConfigLiveService"))
local BallService = require(Modules:WaitForChild("BallService"))
local MatchService = require(Modules:WaitForChild("MatchService"))
local ModeVoteService = require(Modules:WaitForChild("ModeVoteService"))
local MapFeatureService = require(Modules:WaitForChild("MapFeatureService"))
local AnalyticsService = require(Modules:WaitForChild("AnalyticsService"))
local ProgressionService = require(Modules:WaitForChild("ProgressionService"))
local QuestService = require(Modules:WaitForChild("QuestService"))
local CosmeticsService = require(Modules:WaitForChild("CosmeticsService"))
local CharacterColorService = require(Modules:WaitForChild("CharacterColorService"))
local CrateService = require(Modules:WaitForChild("CrateService"))
local EntitlementService = require(Modules:WaitForChild("EntitlementService"))
local BattlePassService = require(Modules:WaitForChild("BattlePassService"))
local DirectPurchaseService = require(Modules:WaitForChild("DirectPurchaseService"))
local MonetizationService = require(Modules:WaitForChild("MonetizationService"))
local GamePassService = require(Modules:WaitForChild("GamePassService"))
local PaidRandomPolicyService = require(Modules:WaitForChild("PaidRandomPolicyService"))
local CmdrService = require(Modules:WaitForChild("CmdrService"))

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
local Combat = require(ConfigRoot:WaitForChild("Combat"))

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
		AimAssist = require(ConfigRoot:WaitForChild("AimAssist")),
		GameModes = require(ConfigRoot:WaitForChild("GameModes")),
		MapFeatures = require(ConfigRoot:WaitForChild("MapFeatures")),
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

PlayerAssistService.start()
InputSetup.start()
ArenaSessionService.start()
BallService.start()
MapFeatureService.start()
RotatingPlatforms.startMover()
MatchService.start()
ModeVoteService.start()
ArenaReturnService.start()
AnalyticsService.start(MatchService)
-- Reported per match rather than read by AnalyticsService directly, so shared
-- simulation code keeps no dependency on a server-only reporting service.
AnalyticsService.registerGauge("droppedSimMs", ServerAuthAdapter.takeDroppedMilliseconds)
EntitlementService.start()
BattlePassService.start({ monetizationService = MonetizationService })
ProgressionService.start(MatchService)
QuestService.start(MatchService)
CosmeticsService.start()
CharacterColorService.start()
PaidRandomPolicyService.start()
CrateService.start()
DirectPurchaseService.start()
MonetizationService.start()
GamePassService.start()
CmdrService.start()

-- Server-side events are authoritative.
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
