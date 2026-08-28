-- Name: OnboardingClient.luau
-- Author: Jack C.
-- Description: The lobby client's onboarding adapter: derives one snapshot from the server's projections and events, owns the combat camera and input handover for training, plays the local impact, haptic, and camera feedback, and tells the UI what to say.
-- Created: 2026-08-27

--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local OnboardingConfig = require(Config:WaitForChild("Onboarding"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Network = require(Shared:WaitForChild("Network"))
local SharedGame = Shared:WaitForChild("Game")
local Onboarding = SharedGame:WaitForChild("Onboarding")
local OnboardingSteps = require(Onboarding:WaitForChild("OnboardingSteps"))
local UIFeedback = require(Shared:WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIFeedback"))
local CameraShaker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("camera-shaker"))
local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local Client = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Client")
local Presentation = Client:WaitForChild("Modules"):WaitForChild("Presentation")
local GameAudio = require(Presentation:WaitForChild("GameAudio"))

local OnboardingClient = {}

local ROUTE_ATTRIBUTE = "OnboardingRoute"
local STEP_ATTRIBUTE = "OnboardingStep"
local HINT_ATTRIBUTE = "OnboardingHint"

export type Snapshot = {
	-- "Pending" until the server answers; the router fails open to the lobby if
	-- it stays pending past the configured timeout.
	route: "Pending" | "Training" | "Lobby",
	stepId: string,
	stepIndex: number,
	prompt: string,
	-- Non-empty while the success beat is on screen.
	success: string,
	hint: string,
	deviceClass: string,
	-- Set when the player's party is ready to enter a match while they train.
	partyReady: boolean,
	celebrating: boolean,
	revealed: boolean,
	swipeHint: boolean,
	revision: number,
}

-- The mutable working copy. Every publish replaces `snapshot` with a fresh
-- table rather than editing it in place, because the React store hook compares
-- snapshots by identity and would otherwise never see a change.
local state: Snapshot = {
	route = "Pending",
	stepId = "",
	stepIndex = 0,
	prompt = "",
	success = "",
	hint = "",
	deviceClass = "Mouse",
	partyReady = false,
	celebrating = false,
	revealed = false,
	swipeHint = false,
	revision = 0,
}
local snapshot: Snapshot = table.clone(state)

local listeners: { (Snapshot) -> () } = {}
local connections: { any } = {}
local successRevision = 0
local swipeHintRevision = 0
local swipeHintShown = false
local started = false
local cameraShake: any = nil

local function publish()
	state.revision += 1
	snapshot = table.clone(state)
	local published = snapshot
	for _, listener in listeners do
		local ok, err = pcall(listener, published)
		if not ok then
			warn(`[OnboardingClient] listener error: {err}`)
		end
	end
end

function OnboardingClient.getSnapshot(): Snapshot
	return snapshot
end

function OnboardingClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	table.insert(listeners, listener)
	listener(snapshot)
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

local function deviceClass(): string
	local lastInput = UserInputService:GetLastInputType()
	if lastInput == Enum.UserInputType.Touch then
		return "Touch"
	end
	if string.find(lastInput.Name, "Gamepad", 1, true) == 1 then
		return "Gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "Mouse"
end

-- Training owns the combat camera and cursor exactly the way the arena does, so
-- what the player learns here is what they get in a match.
local function applyTrainingMode(active: boolean)
	Combat.setCameraEnabled(active)
	if active then
		Combat.releaseCursor("Lobby")
	else
		Combat.requestCursor("Lobby")
	end
end

-- Every onboarding effect passes through this one scale, so reduced motion and
-- the config intensity can turn the whole layer down together.
local function effectScale(): number
	if GuiService.ReducedMotionEnabled then
		return 0
	end
	return math.max(OnboardingConfig.Effects.Intensity, 0)
end

local function haptic(strength: number)
	if strength * effectScale() <= 0 then
		return
	end
	-- The shared feedback service owns the effect instances; onboarding chooses
	-- which of its intensities a beat deserves rather than making its own.
	UIFeedback.haptic(if strength >= 0.5 then "Notification" else "Click")
end

local function impulseCamera(scale: number)
	local magnitude = OnboardingConfig.Effects.CameraImpulseStuds * scale * effectScale()
	if cameraShake == nil or magnitude <= 1e-3 then
		return
	end
	cameraShake:ShakeOnce(magnitude, 8, 0.02, 0.35)
end

local function showSuccess(text: string)
	successRevision += 1
	local revision = successRevision
	state.success = text
	publish()
	task.delay(OnboardingConfig.UI.PromptSuccessHoldSeconds, function()
		if successRevision == revision then
			state.success = ""
			publish()
		end
	end)
end

-- The swipe gesture is an alternative to the tap, never a requirement. It is
-- offered once, after the throw lesson is already understood, and disappears on
-- its own or the moment the player uses it.
local function offerSwipeHint()
	if swipeHintShown or deviceClass() ~= "Touch" then
		return
	end
	if Players.LocalPlayer:GetAttribute("SwipeThrowLearned") == true then
		return
	end
	swipeHintShown = true
	swipeHintRevision += 1
	local revision = swipeHintRevision
	task.delay(OnboardingConfig.UI.SwipeHintDelaySeconds, function()
		if swipeHintRevision ~= revision or state.route ~= "Training" then
			return
		end
		state.swipeHint = true
		publish()
		task.delay(OnboardingConfig.UI.SwipeHintDurationSeconds, function()
			if swipeHintRevision == revision then
				state.swipeHint = false
				publish()
			end
		end)
	end)
end

local function dismissSwipeHint()
	swipeHintRevision += 1
	if state.swipeHint then
		state.swipeHint = false
		publish()
	end
end

local function applyStep(stepId: string)
	local step = OnboardingSteps.get(stepId)
	state.stepId = stepId
	state.stepIndex = if step then step.Index else 0
	state.prompt = if step then step.Prompt else ""
	publish()
end

local EVENTS: { [string]: ({ [string]: any }) -> () } = {
	StepStarted = function(payload)
		applyStep(payload.stepId)
	end,
	StepCompleted = function(payload)
		local step = OnboardingSteps.get(payload.stepId)
		showSuccess(payload.success or (step and step.Success) or "NICE!")
		haptic(OnboardingConfig.Effects.HapticStrength.Hit)
		if payload.stepId == "NormalThrow" then
			offerSwipeHint()
		end
	end,
	TargetKnockedOut = function(payload)
		local strength = if payload.stepId == "Hammer"
			then OnboardingConfig.Effects.HapticStrength.Bonk
			else OnboardingConfig.Effects.HapticStrength.Hit
		haptic(strength)
		impulseCamera(if payload.stepId == "Hammer" then 1 else 0.6)
	end,
	ChargeTooWeak = function()
		haptic(OnboardingConfig.Effects.HapticStrength.ChargeTick)
	end,
	HintNudge = function()
		state.hint = "Nudge"
		publish()
	end,
	HintEscalated = function()
		state.hint = "Escalated"
		publish()
	end,
	PracticeProgress = function()
		haptic(OnboardingConfig.Effects.HapticStrength.Hit)
	end,
	Celebration = function()
		state.celebrating = true
		haptic(OnboardingConfig.Effects.HapticStrength.Complete)
		impulseCamera(1.2)
		pcall(GameAudio.play, "JumpPadBounce", Workspace.CurrentCamera)
		publish()
	end,
	PartyReady = function()
		state.partyReady = true
		publish()
	end,
	Recovered = function() end,
	Reveal = function()
		state.celebrating = false
		state.partyReady = false
		state.revealed = true
		publish()
	end,
}

local function onRouteChanged()
	local route = Players.LocalPlayer:GetAttribute(ROUTE_ATTRIBUTE)
	if route ~= "Training" and route ~= "Lobby" then
		return
	end
	state.route = route
	if route == "Lobby" then
		state.stepId = ""
		state.prompt = ""
		state.hint = ""
		state.swipeHint = false
		dismissSwipeHint()
	end
	applyTrainingMode(route == "Training")
	publish()
end

function OnboardingClient.submit(action: string, payload: any?): any
	local ok, result = pcall(Network.call, "OnboardingAction", action, payload)
	if not ok then
		warn(`[OnboardingClient] {action} failed: {result}`)
		return nil
	end
	return result
end

function OnboardingClient.skip()
	OnboardingClient.submit("Skip")
end

function OnboardingClient.joinPartyMatch()
	state.partyReady = false
	publish()
	OnboardingClient.submit("JoinPartyMatch")
end

function OnboardingClient.keepTraining()
	state.partyReady = false
	publish()
	OnboardingClient.submit("KeepTraining")
end

function OnboardingClient.replay()
	return OnboardingClient.submit("Replay")
end

-- Fail-open routing: the whole lobby must never be held behind an eligibility
-- answer that never arrives.
function OnboardingClient.resolveRoute(): string
	local player = Players.LocalPlayer
	local deadline = os.clock() + OnboardingConfig.Eligibility.ResolveTimeoutSeconds
	while os.clock() < deadline do
		local route = player:GetAttribute(ROUTE_ATTRIBUTE)
		if route == "Training" or route == "Lobby" then
			return route
		end
		task.wait(0.05)
	end
	warn("[OnboardingClient] onboarding eligibility did not resolve; opening the lobby")
	return "Lobby"
end

function OnboardingClient.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer

	state.deviceClass = deviceClass()
	applyStep((player:GetAttribute(STEP_ATTRIBUTE) :: string?) or "")
	state.hint = (player:GetAttribute(HINT_ATTRIBUTE) :: string?) or ""
	applyTrainingMode(false)
	onRouteChanged()

	table.insert(connections, player:GetAttributeChangedSignal(ROUTE_ATTRIBUTE):Connect(onRouteChanged))
	table.insert(
		connections,
		player:GetAttributeChangedSignal(STEP_ATTRIBUTE):Connect(function()
			applyStep((player:GetAttribute(STEP_ATTRIBUTE) :: string?) or "")
		end)
	)
	table.insert(
		connections,
		player:GetAttributeChangedSignal(HINT_ATTRIBUTE):Connect(function()
			state.hint = (player:GetAttribute(HINT_ATTRIBUTE) :: string?) or ""
			publish()
		end)
	)
	-- Prompts follow the device the player is actually using, and a switch never
	-- disturbs the step they are on.
	table.insert(
		connections,
		UserInputService.LastInputTypeChanged:Connect(function()
			local resolved = deviceClass()
			if resolved ~= state.deviceClass then
				state.deviceClass = resolved
				publish()
			end
		end)
	)
	table.insert(
		connections,
		Combat.onGesture(function(event)
			if event.kind == "SwipeRecognized" then
				dismissSwipeHint()
			end
		end)
	)
	table.insert(
		connections,
		Network.on("OnboardingEvent", function(kind, payload)
			local handler = EVENTS[kind]
			if handler then
				local ok, err = pcall(handler, payload or {})
				if not ok then
					warn(`[OnboardingClient] event {kind} failed: {err}`)
				end
			end
		end)
	)
	-- The same shaker the arena's damage feedback uses, so an onboarding impact
	-- reads exactly like a match one.
	cameraShake = CameraShaker.new(Enum.RenderPriority.Camera.Value + 1, function(shakeCFrame: CFrame)
		local camera = Workspace.CurrentCamera
		if camera then
			camera.CFrame = camera.CFrame * shakeCFrame
		end
	end)
	cameraShake:Start()
end

function OnboardingClient.destroy()
	for _, connection in connections do
		if typeof(connection) == "RBXScriptConnection" then
			connection:Disconnect()
		else
			connection()
		end
	end
	table.clear(connections)
	table.clear(listeners)
	if cameraShake then
		cameraShake:Stop()
		cameraShake = nil
	end
	applyTrainingMode(false)
	started = false
end

return OnboardingClient
