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
local DeviceClass = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Input"):WaitForChild("DeviceClass")
)
local GameAudio = require(script.Parent.Parent:WaitForChild("Presentation"):WaitForChild("GameAudio"))
local ThrowUXClient = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("ThrowUXClient"))

local OnboardingClient = {}

export type Snapshot = {
	active: boolean,
	resolved: boolean,
	step: string,
	cue: string,
	trackTargets: boolean,
	retrying: boolean,
	checkpoint: number,
	checkpointCount: number,
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

-- Server rate-limits OnboardingReady to 3 calls per second; stay well under it.
local RESOLVE_RETRY_SECONDS = 1

local started = false
local listeners: Listeners.Collection<Snapshot> = Listeners.new("OnboardingClient", true, "listener failed")
local connections: { any } = {}
local disposers: { () -> () } = {}
local heartbeat: RBXScriptConnection? = nil

local state: Snapshot = {
	active = false,
	resolved = false,
	step = "Intro",
	cue = "Intro",
	trackTargets = false,
	retrying = false,
	checkpoint = 0,
	checkpointCount = 1,
	deviceClass = "Mouse",
	hintLevel = 0,
	succeeded = false,
	celebrating = false,
	waypoint = nil,
}

local lastAttemptAt = os.clock()
local CURSOR_REASON = "OnboardingPointer"

local function releasePointer()
	Combat.releaseCursor(CURSOR_REASON)
end

local function playCue(name: string)
	local ok, err = pcall(GameAudio.play, name)
	if not ok then
		warn(`[OnboardingClient] audio cue {name} failed: {err}`)
	end
end

-- The same vocabulary the rest of combat uses (Config.AimAssist keys, the
-- DeviceClass attribute, the sim's release device). A second naming scheme here
-- would silently mismatch every hint the moment either side changed.
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

function OnboardingClient.skip()
	if not state.active or state.celebrating then
		return
	end
	Network.fireServer("OnboardingAction", "Skip")
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
		releasePointer()
		publish({
			active = false,
			resolved = true,
			celebrating = false,
			succeeded = false,
			hintLevel = 0,
			waypoint = CLEAR,
			trackTargets = false,
			retrying = false,
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
	if packet.step == "Celebration" then
		releasePointer()
	end
	lastAttemptAt = os.clock()

	publish({
		active = true,
		resolved = true,
		step = packet.step,
		cue = packet.cue or packet.step,
		trackTargets = false,
		retrying = packet.retrying == true,
		checkpoint = packet.checkpoint or 0,
		checkpointCount = packet.checkpointCount or 1,
		succeeded = packet.succeeded == true,
		hintLevel = 0,
		celebrating = packet.step == "Celebration",
		waypoint = packet.waypoint or CLEAR,
	})

	if packet.reason == "success" or packet.reason == "checkpoint" then
		playCue("OnboardingStepSuccess")
		UIFeedback.haptic("Notification")
		if packet.step == "TimeHammer" then
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

	-- Keep Splashdown's movement camera, while combat gestures and weapon
	-- presentation remain disabled. Native movement/jump controls stay active.
	Combat.setWeaponLocked(true)
	Combat.setCameraEnabled(true)
	Combat.setInputEnabled(false)
	if entering or packet.reason == "recovered" then
		local camera = Workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if camera and humanoid and root and root:IsA("BasePart") then
			camera.CameraSubject = humanoid
			camera.CameraType = Enum.CameraType.Custom
			local facing = if typeof(packet.facing) == "Vector3" then packet.facing else root.CFrame.LookVector
			camera.CFrame = CFrame.lookAt(
				root.Position - facing * 16 + Vector3.new(0, 8, 0),
				root.Position + facing * 12 + Vector3.new(0, 2, 0)
			)
		end
	end
end

function OnboardingClient.start()
	if started then
		return
	end
	started = true
	ThrowUXClient.setHintGate(function()
		return not state.active
	end)
	local inputContext = Players.LocalPlayer:WaitForChild(InputConfig.ContextName)
	assert(inputContext:IsA("InputContext"), `[OnboardingClient] {InputConfig.ContextName} must be an InputContext`)
	local skipAction = inputContext:WaitForChild("OnboardingSkip")
	assert(skipAction:IsA("InputAction"), "[OnboardingClient] CombatInput.OnboardingSkip must be an InputAction")

	table.insert(connections, Network.on("OnboardingState", onServerState))
	table.insert(
		connections,
		skipAction.Pressed:Connect(function()
			if state.active and not state.celebrating then
				OnboardingClient.skip()
			end
		end)
	)
	table.insert(
		disposers,
		DeviceClass.observe(function(device)
			if device ~= "Mouse" then
				releasePointer()
			end
			if device ~= state.deviceClass then
				publish({ deviceClass = device })
			end
		end)
	)
	-- Aiming owns the locked cursor during lessons. Holding Alt temporarily
	-- hands it to the visible controls without changing the combat camera mode.
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			if input.KeyCode == Enum.KeyCode.LeftAlt and not processed and state.active and not state.celebrating then
				Combat.requestCursor(CURSOR_REASON)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.LeftAlt then
				releasePointer()
			end
		end)
	)
	table.insert(connections, UserInputService.WindowFocusReleased:Connect(releasePointer))

	local accumulator = 0
	heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if state.active and humanoid and humanoid.MoveDirection.Magnitude > 0.05 then
			lastAttemptAt = os.clock()
		end
		tickHints()
	end)

	task.spawn(function()
		-- The server answers "unresolved" until the player's profile has loaded.
		-- Ask again (bounded by ResolveTimeoutSeconds) instead of treating that as
		-- "not eligible", so a slow DataStore does not skip training for a new
		-- player. Past the deadline, fail open to the normal lobby.
		local deadline = os.clock() + OnboardingConfig.Eligibility.ResolveTimeoutSeconds
		while started do
			local ok, result = pcall(Network.call, "OnboardingReady")
			if not started or state.resolved then
				-- Torn down, or the server already pushed training state for us.
				return
			end
			if not ok or typeof(result) ~= "table" then
				-- Fail open: an unresolved eligibility check must never trap the
				-- player behind a loading state instead of the normal lobby.
				publish({ active = false, resolved = true })
				return
			end
			if result.eligible == true then
				return
			end
			if result.status ~= "unresolved" or os.clock() >= deadline then
				publish({ active = false, resolved = true })
				return
			end
			task.wait(RESOLVE_RETRY_SECONDS)
		end
	end)
end

function OnboardingClient.destroy()
	releasePointer()
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
