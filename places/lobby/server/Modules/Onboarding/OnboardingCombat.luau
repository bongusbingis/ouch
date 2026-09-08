-- Description: Brings the real server-side combat stack up inside the lobby so training teaches with the same simulation the arena runs. Provides the minimal replicated MatchState the adapter reads, starts input/assist/ball provisioning and the authoritative adapter, and guarantees an onboarding player actually has a character to fight with.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerAuthAdapter = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Adapters")
		:WaitForChild("ServerAuthAdapter")
)
local ModeRegistry = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Modes"):WaitForChild("ModeRegistry")
)
local BallService = require(script.Parent.Parent:WaitForChild("BallService"))
local InputSetup = require(script.Parent.Parent:WaitForChild("InputSetup"))
local PlayerConfigService = require(script.Parent.Parent:WaitForChild("PlayerConfigService"))
local PlayerAssist = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("PlayerAssist"))

local OnboardingCombat = {}

local STATE_FOLDER_NAME = "MatchState"
local ADMISSION_ATTRIBUTE = "ArenaAdmission"
local READY_ATTRIBUTE = "ArenaReady"

local started = false

-- ServerAuthAdapter reads exactly two attributes off this folder: modeId, to
-- resolve which rules the sim runs under, and phase, which it requires to be
-- "Active" before it steps at all. The lobby has no match, so it publishes a
-- permanently active FFA-shaped state purely to satisfy the simulation.
local function ensureMatchState(): Folder
	local existing = ReplicatedStorage:FindFirstChild(STATE_FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = STATE_FOLDER_NAME
	folder:SetAttribute("phase", "Active")
	folder:SetAttribute("modeId", ModeRegistry.default().id)
	folder:SetAttribute("timeRemaining", 0)
	folder:SetAttribute("winnerId", "")
	folder.Parent = ReplicatedStorage
	return folder
end

-- ServerAuthAdapter admits a player to the simulation on two attributes that
-- ArenaSessionService owns in the arena, and the shared aim and charge modules
-- read the same pair on the client. The lobby runs no such service, so training
-- grants them for the length of the session: without them the player is not a
-- simulation character at all and every input is dropped before it is queued.
function OnboardingCombat.admit(player: Player)
	player:SetAttribute(ADMISSION_ATTRIBUTE, "Direct")
	player:SetAttribute(READY_ATTRIBUTE, true)
end

function OnboardingCombat.release(player: Player)
	player:SetAttribute(READY_ATTRIBUTE, nil)
	player:SetAttribute(ADMISSION_ATTRIBUTE, nil)
end

-- The lobby is a menu experience and may not spawn characters on its own, so
-- training cannot assume one exists. Loading is idempotent and only ever
-- happens for a player who is actually onboarding.
function OnboardingCombat.ensureCharacter(player: Player): Model?
	if player.Character and player.Character.Parent ~= nil then
		return player.Character
	end
	local ok, err = pcall(function()
		player:LoadCharacter()
	end)
	if not ok then
		warn(`[OnboardingCombat] could not load a character for {player.Name}: {err}`)
		return nil
	end
	return player.Character
end

function OnboardingCombat.grantBall(player: Player): boolean
	if player.Character == nil then
		return false
	end
	if BallService.hasHeldBall(player) then
		return true
	end
	return BallService.grantHeldBall(player)
end

function OnboardingCombat.clearBall(player: Player)
	BallService.clearOwned(player)
end

function OnboardingCombat.hasBall(player: Player): boolean
	return BallService.hasHeldBall(player)
end

function OnboardingCombat.start()
	if started then
		return
	end
	started = true

	ensureMatchState()
	InputSetup.start()
	PlayerConfigService.start({ schemas = { PlayerAssist } })
	BallService.start()
	ServerAuthAdapter.start()
end

return OnboardingCombat
