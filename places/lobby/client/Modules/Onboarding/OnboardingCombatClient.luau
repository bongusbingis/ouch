-- Description: Starts the combat client stack inside the lobby so training uses the same input, state, aim and presentation path the arena runs. Mirrors the arena simulation client's combat startup, minus everything match-specific, and routes broadcast sim events to the visual modules.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local OnboardingCombatClient = {}

type System = {
	name: string,
	parent: Instance,
	start: boolean?,
	combat: boolean?,
	intent: boolean?,
	options: any?,
	module: any?,
}

local started = false
local starting = false
local connections: { RBXScriptConnection } = {}
local disposers: { () -> () } = {}
local activeModules: { { path: string, module: any } } = {}

local function requiredChild(parent: Instance, name: string): Instance
	local child = parent:WaitForChild(name, 10)
	assert(
		child,
		`[OnboardingCombatClient] missing {parent:GetFullName()}.{name}; restore the Lobby Rojo mapping or Studio instance`
	)
	return child
end

local function requiredModule(parent: Instance, name: string): any
	local source = requiredChild(parent, name)
	assert(source:IsA("ModuleScript"), `[OnboardingCombatClient] {source:GetFullName()} must be a ModuleScript`)
	local ok, result = pcall(require, source)
	if not ok then
		error(`[OnboardingCombatClient] failed to load {source:GetFullName()}: {result}`, 0)
	end
	assert(typeof(result) == "table", `[OnboardingCombatClient] {source:GetFullName()} must return a module table`)
	return result
end

local function startModule(path: string, module: any, options: any?)
	assert(typeof(module.start) == "function", `[OnboardingCombatClient] required {path}.start is missing`)
	assert(
		typeof(module.destroy or module.stop) == "function",
		`[OnboardingCombatClient] required {path}.destroy or .stop is missing`
	)
	-- Track before calling start so a partially started module is also torn down.
	table.insert(activeModules, { path = path, module = module })
	local ok, err
	if options ~= nil then
		ok, err = pcall(module.start, options)
	else
		ok, err = pcall(module.start)
	end
	if not ok then
		error(`[OnboardingCombatClient] failed to start {path}: {err}`, 0)
	end
end

function OnboardingCombatClient.start()
	if started then
		return
	end
	assert(not starting, "[OnboardingCombatClient] startup is already in progress")
	starting = true

	local ok, err = pcall(function()
		local playerScripts = requiredChild(Players.LocalPlayer, "PlayerScripts")
		local client = requiredChild(playerScripts, "Client")
		local modules = requiredChild(client, "Modules")
		local input = requiredChild(modules, "Input")
		local presentation = requiredChild(modules, "Presentation")
		local ui = requiredChild(modules, "UI")

		local AssistConfig = requiredModule(input, "AssistConfig")
		local CombatState = requiredModule(presentation, "CombatState")
		local InputRouter = requiredModule(input, "InputRouter")
		local CameraAssist = requiredModule(input, "CameraAssist")
		local CombatInputSender = requiredModule(input, "CombatInputSender")

		local systems: { System } = {
			{ name = "BallVisuals", parent = presentation, start = true, combat = true },
			{ name = "HammerVisuals", parent = presentation, start = true, combat = true },
			{ name = "ThrowUXClient", parent = ui, start = true },
			{ name = "ChargeAim", parent = presentation, start = true },
			{ name = "ArmIK", parent = presentation, start = true, options = { replicate = false } },
			{ name = "GameAudio", parent = presentation, combat = true },
			{ name = "WeaponAnimations", parent = presentation, start = true, intent = true },
		}
		for _, system in systems do
			local module = requiredModule(system.parent, system.name)
			if system.start then
				assert(
					typeof(module.start) == "function" and typeof(module.destroy or module.stop) == "function",
					`[OnboardingCombatClient] {system.parent:GetFullName()}.{system.name} needs start and destroy/stop`
				)
			end
			if system.combat then
				assert(
					typeof(module.onEvent) == "function",
					`[OnboardingCombatClient] {system.parent:GetFullName()}.{system.name}.onEvent is missing`
				)
			end
			if system.intent then
				assert(
					typeof(module.onIntent) == "function",
					`[OnboardingCombatClient] {system.parent:GetFullName()}.{system.name}.onIntent is missing`
				)
			end
			system.module = module
		end

		-- Input stays disabled until the onboarding session opens; the camera
		-- is handed over by OnboardingClient at the same moment.
		Combat.setInputEnabled(false)
		startModule(`{input:GetFullName()}.AssistConfig`, AssistConfig)
		startModule(`{presentation:GetFullName()}.CombatState`, CombatState)
		startModule(`{input:GetFullName()}.InputRouter`, InputRouter)
		startModule(`{input:GetFullName()}.CameraAssist`, CameraAssist)
		startModule(`{input:GetFullName()}.CombatInputSender`, CombatInputSender)

		local presenters: { (any) -> () } = {}
		for _, system in systems do
			local module = system.module
			if system.start then
				startModule(`{system.parent:GetFullName()}.{system.name}`, module, system.options)
			end
			if system.intent then
				table.insert(disposers, CombatInputSender.onIntent(module.onIntent))
			end
			if system.combat then
				table.insert(presenters, module.onEvent)
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
	end)
	starting = false
	if not ok then
		OnboardingCombatClient.destroy()
		error(`[OnboardingCombatClient] startup failed: {err}`, 0)
	end
	started = true
end

function OnboardingCombatClient.destroy()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	for _, dispose in disposers do
		local ok, err = pcall(dispose)
		if not ok then
			warn(`[OnboardingCombatClient] WeaponAnimations intent subscription teardown failed: {err}`)
		end
	end
	table.clear(disposers)
	for index = #activeModules, 1, -1 do
		local entry = activeModules[index]
		local module = entry.module
		local teardown = module.destroy or module.stop
		local ok, err = pcall(teardown)
		if not ok then
			warn(`[OnboardingCombatClient] {entry.path} teardown failed: {err}`)
		end
	end
	table.clear(activeModules)
	Combat.setInputEnabled(false)
	started = false
	starting = false
end

return OnboardingCombatClient
