-- Name: OnboardingCombatClient.luau
-- Author: Jack C.
-- Description: Starts the combat client stack inside the lobby so training uses the same input, state, aim and presentation path the arena runs. Mirrors the arena simulation client's combat startup, minus everything match-specific, and routes broadcast sim events to the visual modules.
-- Created: 2026-08-26

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local OnboardingCombatClient = {}

local started = false
local connections: { RBXScriptConnection } = {}
local disposers: { () -> () } = {}
local optional: { [string]: any } = {}

local function startOptional(name: string, callback: () -> any?): any?
	local ok, result = pcall(callback)
	if not ok then
		warn(`[OnboardingCombatClient] optional {name} unavailable: {result}`)
		return nil
	end
	optional[name] = result or true
	return result
end

function OnboardingCombatClient.start()
	if started then
		return
	end
	started = true

	local client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
	local modules = client:WaitForChild("Modules")
	local input = modules:WaitForChild("Input")
	local presentation = modules:WaitForChild("Presentation")
	local ui = modules:WaitForChild("UI")

	local AssistConfig = require(input:WaitForChild("AssistConfig")) :: any
	local CombatState = require(presentation:WaitForChild("CombatState")) :: any
	local InputRouter = require(input:WaitForChild("InputRouter")) :: any
	local CameraAssist = require(input:WaitForChild("CameraAssist")) :: any
	local CombatInputSender = require(input:WaitForChild("CombatInputSender")) :: any

	-- Input stays disabled until the onboarding session actually opens; the
	-- camera is handed over by OnboardingClient at the same moment.
	Combat.setInputEnabled(false)

	AssistConfig.start()
	CombatState.start()
	InputRouter.start()
	CameraAssist.start()
	CombatInputSender.start()

	local BallVisuals = startOptional("BallVisuals", function()
		local module = require(presentation:WaitForChild("BallVisuals")) :: any
		module.start()
		return module
	end)
	local HammerVisuals = startOptional("HammerVisuals", function()
		local module = require(presentation:WaitForChild("HammerVisuals")) :: any
		module.start()
		return module
	end)
	-- Feeds the reticle, charge and swipe feedback the arena HUD renders. Without
	-- it the HUD mounts but every value it reads stays at its idle default.
	startOptional("ThrowUXClient", function()
		local module = require(ui:WaitForChild("ThrowUXClient")) :: any
		module.start()
		return module
	end)
	startOptional("ChargeAim", function()
		local module = require(presentation:WaitForChild("ChargeAim")) :: any
		module.start()
		return module
	end)
	-- The throwing arm tracking the aim, and the one-shots a throw makes, are
	-- most of what separates training from the real thing.
	startOptional("ArmIK", function()
		local module = require(presentation:WaitForChild("ArmIK")) :: any
		module.start({ replicate = false })
		return module
	end)
	local GameAudio = startOptional("GameAudio", function()
		return require(presentation:WaitForChild("GameAudio")) :: any
	end)
	startOptional("WeaponAnimations", function()
		local module = require(presentation:WaitForChild("WeaponAnimations")) :: any
		module.start()
		table.insert(disposers, CombatInputSender.onIntent(module.onIntent))
		return module
	end)

	table.insert(
		connections,
		Network.on("CombatSimEvent", function(events)
			for _, event in events do
				if BallVisuals then
					BallVisuals.onEvent(event)
				end
				if HammerVisuals then
					HammerVisuals.onEvent(event)
				end
				if GameAudio then
					GameAudio.onEvent(event)
				end
			end
		end)
	)
end

function OnboardingCombatClient.destroy()
	for _, connection in connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		end
	end
	table.clear(connections)
	for _, dispose in disposers do
		pcall(dispose)
	end
	table.clear(disposers)
	for _, module in optional do
		if typeof(module) == "table" then
			local teardown = (module :: any).destroy or (module :: any).stop
			if teardown then
				pcall(teardown)
			end
		end
	end
	table.clear(optional)
	Combat.setInputEnabled(false)
	started = false
end

return OnboardingCombatClient
