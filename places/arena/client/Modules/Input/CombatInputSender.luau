--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))
local MobileInput = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MobileInput"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local InputBuffer = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Input"):WaitForChild("InputBuffer")
)
local Gestures = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Input"):WaitForChild("Gestures")
)
local AimDirector = require(script.Parent.AimDirector)
local TouchInput = require(script.Parent.TouchInput)

-- Sends throw and catch intent to the server. Intent only: the server decides
-- whether the action is legal, where it starts from, and what it hits.
--
-- Two producers feed this. Hardware buttons (mouse, keyboard, gamepad) come in
-- through their InputActions; touch comes in as classified gestures from
-- TouchInput. Both land in the same buffer so timing behaves identically.
--
-- Throw style is resolved per producer but from one shared ramp. A button press
-- that will throw a ball resolves on release, so its hold duration is known: a
-- quick click lobs, anything held longer charges. Touch reaches the same two
-- throws through a swipe up and a held release.
--
-- The same button swings the hammer when no ball is held, and a swing has no
-- style to wait for -- deferring it would put the tap window's worth of latency
-- on every melee swing. So the deferral is decided per press by whether a ball
-- is in hand. Catch never defers either.

local CombatInputSender = {}

local started = false
local listeners: { (string) -> () } = {}
local buffer = InputBuffer.new()
-- How a throw was performed, carried alongside the action so a buffered input
-- replays as the same throw the player made.
type Style = { targetId: string?, charge: number?, lob: boolean? }

local pendingStyle: Style? = nil

-- Lets presentation react to the local player's own intent at press time,
-- without a second place detecting the same input edge.
function CombatInputSender.onIntent(listener: (string) -> ())
	table.insert(listeners, listener)
end

local function notify(kind: string)
	for _, listener in listeners do
		local ok, err = pcall(listener, kind)
		if not ok then
			warn(`[CombatInputSender] intent listener error: {err}`)
		end
	end
end

local function holdsBall(): boolean
	local balls = Workspace:FindFirstChild("Balls")
	if balls == nil then
		return false
	end
	local localId = tostring(Players.LocalPlayer.UserId)
	for _, ball in balls:GetChildren() do
		if ball:GetAttribute("hb") == localId then
			local phase = ball:GetAttribute("ph")
			if phase == 0 or phase == 1 then
				return true
			end
		end
	end
	return false
end

-- A ball is inbound when projecting its current velocity forward passes close
-- to the player. Only used to decide which intent a tap means; the server still
-- validates the catch independently.
local function ballIncoming(): boolean
	local settings = MobileInput.ContextualCatch
	if not settings.Enabled then
		return false
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local balls = Workspace:FindFirstChild("Balls")
	if root == nil or not root:IsA("BasePart") or balls == nil then
		return false
	end

	for _, ball in balls:GetChildren() do
		if not ball:IsA("BasePart") then
			continue
		end
		local velocity = ball:GetAttribute("vel")
		if typeof(velocity) ~= "Vector3" or velocity.Magnitude <= 1e-3 then
			continue
		end
		local toPlayer = root.Position - ball.Position
		-- Moving away rather than toward us.
		if toPlayer:Dot(velocity) <= 0 then
			continue
		end
		local projected = ball.Position + velocity * settings.LookaheadSeconds
		local closest = (projected - root.Position).Magnitude
		if math.min(closest, toPlayer.Magnitude) <= settings.ApproachRadiusStuds then
			return true
		end
	end
	return false
end

-- With no ball held a tap is ambiguous between swinging and catching. The
-- hammer stays the default; catch only wins when something is genuinely inbound.
local function intentForTap(): string
	if holdsBall() then
		return "Throw"
	end
	return if ballIncoming() then "Catch" else "Throw"
end

local function send(kind: string, style: Style)
	local aimDir = AimDirector.currentAim()
	if typeof(aimDir) ~= "Vector3" or aimDir.Magnitude <= 1e-6 then
		return
	end
	Network.fireServer("SubmitCombatInput", kind, aimDir, style.targetId, style.charge, style.lob)
	notify(kind)
end

-- The only non-actionable states the client can know for itself. Anything else
-- (cooldowns, windups) is the server's business and is not guessed at here.
local function actionable(): boolean
	local character = Players.LocalPlayer.Character
	if character == nil or character:GetAttribute("CombatAlive") == false then
		return false
	end
	local matchState = ReplicatedStorage:FindFirstChild("MatchState")
	return matchState == nil or matchState:GetAttribute("phase") == "Active"
end

-- Actionable input is sent immediately, so no device pays a frame of latency
-- for the buffer existing. Only input that provably cannot fire yet waits, and
-- only for a short window; mobile taps that land a hair early otherwise feel
-- dropped.
-- A button press resolves to the same two throws touch gets, off the same ramp:
-- a click too short to be a hold lobs, anything longer charges by how long it
-- was held.
local function buttonStyle(heldSeconds: number): Style
	local gestures = MobileInput.Gestures
	if heldSeconds <= gestures.TapMaxSeconds then
		return { lob = true }
	end
	return { charge = Gestures.chargeFor(heldSeconds, gestures) }
end

local function submit(kind: string, style: Style)
	if actionable() or not MobileInput.Buffer.Enabled then
		send(kind, style)
		return
	end
	InputBuffer.push(buffer, kind, os.clock())
	-- The style travels with the buffered action: a throw that waits out a
	-- cooldown must still be the charged or lobbed throw the player performed.
	pendingStyle = style
end

local function flush()
	if not MobileInput.Buffer.Enabled or not actionable() then
		return
	end
	local action = InputBuffer.take(buffer, os.clock(), MobileInput.Buffer.WindowSeconds)
	if action == nil then
		return
	end
	local style = pendingStyle or {}
	pendingStyle = nil
	send(action, style)
end

function CombatInputSender.start()
	if started then
		return
	end
	started = true

	local context = Players.LocalPlayer:WaitForChild(InputConfig.ContextName)
	local actions: { { kind: string, action: InputAction, pressed: boolean } } = {
		{ kind = "Throw", action = context:WaitForChild("Throw") :: InputAction, pressed = false },
		{ kind = "Catch", action = context:WaitForChild("Catch") :: InputAction, pressed = false },
	}
	-- Set on a press that is holding a ball, cleared when that press resolves.
	local throwPressedAt: number? = nil

	-- Touch gestures. Tap picks its own intent and may carry a tapped target; a
	-- held release charges the throw, and an upward swipe lobs it.
	TouchInput.onGesture(function(gesture)
		if TouchInput.getSnapshot().inputDevice ~= "Touch" then
			return
		end
		if gesture.kind == "Tap" or gesture.kind == "DoubleTap" then
			submit(intentForTap(), { targetId = gesture.targetId })
			return
		end
		if gesture.kind == "ChargedRelease" then
			submit("Throw", { charge = gesture.charge })
			return
		end
		-- Only an upward swipe lobs. The other directions stay unclaimed rather
		-- than throwing, so a mis-swiped camera flick does not spend the ball.
		if gesture.kind == "Swipe" and gesture.direction == "Up" then
			submit("Throw", { lob = true })
		end
	end)

	-- One connection polling both hardware actions rather than one each: the aim
	-- state is read at most once per frame instead of once per action.
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, entry in actions do
			local pressed = entry.action:GetState() == true
			if pressed and not entry.pressed then
				if entry.kind == "Throw" and holdsBall() then
					throwPressedAt = now
				else
					submit(entry.kind, {})
				end
			elseif not pressed and entry.pressed and entry.kind == "Throw" then
				local pressedAt = throwPressedAt
				throwPressedAt = nil
				if pressedAt ~= nil then
					submit("Throw", buttonStyle(now - pressedAt))
				end
			end
			entry.pressed = pressed
		end
		flush()
	end)
end

return CombatInputSender
