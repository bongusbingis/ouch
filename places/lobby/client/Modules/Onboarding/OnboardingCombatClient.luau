-- Description: Starts the combat client stack inside the lobby so training uses the same input, state, aim and presentation path the arena runs. Mirrors the arena simulation client's combat startup, minus everything match-specific, and routes broadcast sim events to the visual modules.

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

	local presenters = {}
	local systems = {
		{ name = "BallVisuals", parent = presentation, start = true, combat = true },
		{ name = "HammerVisuals", parent = presentation, start = true, combat = true },
		{ name = "ThrowUXClient", parent = ui, start = true },
		{ name = "ChargeAim", parent = presentation, start = true },
		{ name = "ArmIK", parent = presentation, start = true, options = { replicate = false } },
		{ name = "GameAudio", parent = presentation, combat = true },
		{ name = "WeaponAnimations", parent = presentation, start = true, intent = true },
	}
	for _, system in systems do
		local ok, result = pcall(function()
			local module = require(system.parent:WaitForChild(system.name)) :: any
			if system.start then
				if system.options then
					module.start(system.options)
				else
					module.start()
				end
			end
			if system.intent then
				table.insert(disposers, CombatInputSender.onIntent(module.onIntent))
			end
			return module
		end)
		if ok then
			optional[system.name] = result or true
			if result and system.combat then
				table.insert(presenters, result.onEvent)
			end
		else
			warn(`[OnboardingCombatClient] optional {system.name} unavailable: {result}`)
		end
	end

	table.insert(
		connections,
		Network.on("CombatSimEvent", function(events)
			for _, event in events do
				for _, present in presenters do
					present(event)
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
