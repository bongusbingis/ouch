-- Description: Client flow controller for first-session training: owns the current step, watches the real combat intents to detect throws, hammer swings and charged releases, escalates assistance on repeated misses or inactivity, and publishes one snapshot the onboarding UI renders. Detection and presentation only -- the server decides and persists.

--!strict

local Listeners = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Util")
		:WaitForChild("Listeners")
)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Config = ReplicatedStorage:WaitForChild("Config")
local InputConfig = require(Config:WaitForChild("Interface"):WaitForChild("Input"))
local OnboardingConfig = require(Config:WaitForChild("Interface"):WaitForChild("Onboarding"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local UIFeedback = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback")
)
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
local AimDirector = require(script.Parent.Parent:WaitForChild("Input"):WaitForChild("AimDirector"))
local GameAudio = require(script.Parent.Parent:WaitForChild("Presentation"):WaitForChild("GameAudio"))
local ThrowUXClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ThrowUXClient"))

local OnboardingClient = {}

export type Snapshot = {
	active: boolean,
	resolved: boolean,
	step: string,
	cue: string,
	trackTargets: boolean,
	deviceClass: string,
	hintLevel: number,
	succeeded: boolean,
	celebrating: boolean,
	waypoint: Vector3?,
}

-- Clearing a field has to go through this sentinel: `{ waypoint = nil }` is an
-- empty table in Luau, so passing nil straight through would silently clear
-- nothing and the arrow would point at a stale destination forever.
local CLEAR = table.freeze({})

local started = false
local listeners: Listeners.Collection<Snapshot> = Listeners.new("OnboardingClient", true, "listener failed")
local connections: { any } = {}
local disposers: { () -> () } = {}
local heartbeat: RBXScriptConnection? = nil

local state: Snapshot = {
	active = false,
	resolved = false,
	step = "Intro",
	cue = "Ready",
	trackTargets = false,
	deviceClass = "Mouse",
	hintLevel = 0,
	succeeded = false,
	celebrating = false,
	waypoint = nil,
}

local lastAttemptAt = os.clock()

local function playCue(name: string)
	local ok, err = pcall(GameAudio.play, name)
	if not ok then
		warn(`[OnboardingClient] audio cue {name} failed: {err}`)
	end
end

-- The same vocabulary the rest of combat uses (Config.AimAssist keys, the
-- DeviceClass attribute, the sim's release device). A second naming scheme here
-- would silently mismatch every hint the moment either side changed.
local function deviceClass(): string
	return AimDirector.deviceClass()
end

local function publish(changes: { [string]: any })
	local next = table.clone(state)
	for key, value in changes do
		next[key] = if value == CLEAR then nil else value
	end
	state = next :: Snapshot
	listeners.emitWith(function(callback)
		callback(state)
	end)
end

function OnboardingClient.getSnapshot(): Snapshot
	return state
end

function OnboardingClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	local unsubscribe = listeners.add(listener)
	return unsubscribe
end

local function reportAttempt(escalated: boolean?)
	lastAttemptAt = os.clock()
	Network.fireServer("OnboardingAction", "Attempt", if escalated then "escalated" else nil)
end

function OnboardingClient.skip()
	Network.fireServer("OnboardingAction", "Skip")
end

-- An intent is an attempt, never a completion. Lessons are finished by the
-- server when the player actually connects with a target, so trying and missing
-- reads as effort here rather than as progress.
local function onIntent(intent: string)
	if not state.active then
		return
	end
	if
		intent == "NormalThrow"
		or intent == "ReleaseCharge"
		or intent == "BeginCharge"
		or intent == "CancelCharge"
		or intent == "HammerAttack"
	then
		reportAttempt()
	end
end

local function tickHints()
	if not state.active or state.succeeded then
		return
	end
	local idle = os.clock() - lastAttemptAt
	local timing = OnboardingConfig.Timing
	local level = 0
	if idle >= timing.EscalatedHintSeconds then
		level = 2
	elseif idle >= timing.InactivityHintSeconds then
		level = 1
	end
	if level ~= state.hintLevel then
		publish({ hintLevel = level })
		if level == 2 then
			playCue("OnboardingHint")
			UIFeedback.haptic("Click")
			Network.fireServer("OnboardingAction", "Attempt", "escalated")
		end
	end
end

local function onServerState(packet: any)
	if typeof(packet) ~= "table" then
		return
	end
	local wasActive = state.active
	if packet.active ~= true then
		publish({
			active = false,
			resolved = true,
			celebrating = false,
			succeeded = false,
			hintLevel = 0,
			waypoint = CLEAR,
			trackTargets = false,
		})
		Combat.setInputEnabled(false)
		Combat.setCameraEnabled(false)
		Combat.setWeaponLocked(false)
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
		if wasActive then
			playCue("OnboardingReveal")
		end
		return
	end

	local changedStep = packet.step ~= state.step
	local entering = not state.active
	lastAttemptAt = os.clock()

	publish({
		active = true,
		resolved = true,
		step = packet.step,
		cue = packet.cue or packet.step,
		trackTargets = packet.trackTargets == true,
		succeeded = packet.succeeded == true,
		hintLevel = 0,
		celebrating = packet.step == "Celebration",
		waypoint = packet.waypoint or CLEAR,
	})

	if packet.reason == "hit" then
		playCue("OnboardingStepSuccess")
		UIFeedback.haptic("Notification")
		if packet.step == "ChargedThrow" then
			playCue("OnboardingCoreComplete")
		end
	elseif entering or changedStep then
		if packet.step == "Celebration" then
			playCue("OnboardingCelebration")
			UIFeedback.haptic("Notification")
		else
			playCue("OnboardingStepStart")
		end
	end

	-- Every lesson before the free-for-all teaches one weapon, so the player is
	-- given it and their own equip controls stay inert until the mini-fight.
	Combat.setWeaponLocked(packet.step ~= "Practice")

	if changedStep and packet.step == "Hammer" then
		Combat.equipHammer()
	elseif
		changedStep and (packet.step == "NormalThrow" or packet.step == "ChargedThrow" or packet.step == "Practice")
	then
		Combat.equipDodgeball()
	end

	-- Training runs the same combat camera the arena uses, so aim, charge and
	-- the trajectory preview behave identically to a real match.
	Combat.setCameraEnabled(true)
	Combat.setInputEnabled(true)
end

function OnboardingClient.start()
	if started then
		return
	end
	started = true
	ThrowUXClient.setHintGate(function()
		return not state.active or (state.step ~= "Intro" and state.step ~= "NormalThrow")
	end)
	local inputContext = Players.LocalPlayer:WaitForChild(InputConfig.ContextName)
	assert(inputContext:IsA("InputContext"), `[OnboardingClient] {InputConfig.ContextName} must be an InputContext`)
	local skipAction = inputContext:WaitForChild("OnboardingSkip")
	assert(skipAction:IsA("InputAction"), "[OnboardingClient] CombatInput.OnboardingSkip must be an InputAction")

	table.insert(connections, Network.on("OnboardingState", onServerState))
	table.insert(disposers, Combat.onIntent(onIntent))
	table.insert(
		connections,
		skipAction.Pressed:Connect(function()
			if state.active and not state.celebrating then
				OnboardingClient.skip()
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.LastInputTypeChanged:Connect(function()
			local device = deviceClass()
			if device ~= state.deviceClass then
				publish({ deviceClass = device })
			end
		end)
	)

	local accumulator = 0
	heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		tickHints()
	end)

	publish({ deviceClass = deviceClass() })

	task.spawn(function()
		local ok, result = pcall(Network.call, "OnboardingReady")
		if not ok or typeof(result) ~= "table" then
			-- Fail open: an unresolved eligibility check must never trap the
			-- player behind a loading state instead of the normal lobby.
			publish({ active = false, resolved = true })
			return
		end
		if result.eligible ~= true then
			publish({ active = false, resolved = true })
		end
	end)
end

function OnboardingClient.destroy()
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
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	Combat.setInputEnabled(false)
	Combat.setCameraEnabled(false)
	Combat.setWeaponLocked(false)
	ThrowUXClient.setHintGate(nil)
	listeners.clear()
	started = false
end

return OnboardingClient
