--!strict

--[[
	Headless touch input layer.

	Owns every touch signal on the client and turns it into gameplay-level
	gestures. It renders nothing and creates no GuiObject: the screen exists here
	only as normalized rectangles it owns as data. React consumes it through the
	same getSnapshot/subscribe shape the rest of this codebase uses, so it can be
	read with useExternalStore and knows nothing about UserInputService.

	Public API
	----------
	TouchInput.start()
	    Idempotent. Begins tracking; safe on every device.

	TouchInput.getSnapshot(): Snapshot
	    inputDevice     "Touch" | "Mouse" | "Gamepad" - the ACTIVE device, from
	                    LastInputType, not from platform capability. Everything
	                    device-gated keys off this, so a Windows touchscreen and
	                    a phone with a controller both behave correctly.
	    zones           Normalized rects { x, y, width, height } in 0-1.
	    zonePixels      The same rects in pixels, inset-corrected. Use these to
	                    align on-screen affordances.
	    leftHanded      Whether the zones are mirrored.
	    charge          0-1, live while a hold is in progress, else 0.
	    lockedTargetId  Currently locked target, or nil. Populated in Phase 2.
	    viewport        { width, height } of the usable area.

	TouchInput.subscribe(listener): () -> ()
	    Fires on any snapshot change. Returns an unsubscribe function.

	TouchInput.onGesture(listener): () -> ()
	    Fires per completed gesture:
	      { kind = "Tap" | "DoubleTap" | "ChargedRelease" | "Swipe",
	        direction = "Up" | "Down" | "Left" | "Right" | nil,
	        charge = 0-1,
	        targetId = string?,   -- set when the tap landed on an enemy
	        x = number, y = number }   -- normalized tap position

	TouchInput.registerExclusionRect(id, rect): () -> ()
	    Registers a normalized rect that swallows touches, for when real buttons
	    exist. Returns a function that removes it. Touches inside an exclusion
	    rect are ignored entirely by this layer.

	TouchInput.setLeftHanded(value)
	TouchInput.setLockedTarget(targetId)   -- called by the aim layer

	Notes
	-----
	Camera drag is NOT gated here. The stock PlayerModule reads the same touch
	stream, and UserInputService signals observe without consuming, so a drag
	moves the camera from its first frame regardless of how this layer later
	classifies it. Nothing needs to be buffered and replayed for that to feel
	right; Gestures still tracks the pre-promotion delta for assists that want
	to scale drag rather than merely observe it.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MobileInput = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MobileInput"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local InputFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Input")
local Gestures = require(InputFolder:WaitForChild("Gestures"))
local TapTarget = require(InputFolder:WaitForChild("TapTarget"))
local Zones = require(InputFolder:WaitForChild("Zones"))
local PlayerIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Adapters"):WaitForChild("PlayerIds")
)

local TouchInput = {}

export type Gesture = {
	kind: string,
	direction: string?,
	charge: number,
	targetId: string?,
	x: number,
	y: number,
}

export type Snapshot = {
	inputDevice: string,
	zones: Zones.Layout,
	zonePixels: Zones.Layout,
	leftHanded: boolean,
	charge: number,
	lockedTargetId: string?,
	-- 0-1 confidence in that lock, from how centred and close the target is.
	-- Assists scale by it and a reticle can render it directly.
	lockConfidence: number,
	-- True while a touch in the action zone is dragging the camera. Aim friction
	-- only applies during one, and a reticle can use it to show active aiming.
	aiming: boolean,
	viewport: { width: number, height: number },
}

local started = false
local activeTouches: { [InputObject]: Gestures.Touch } = {}
local exclusionRects: { [string]: Zones.Rect } = {}
local snapshotListeners: { (Snapshot) -> () } = {}
local gestureListeners: { (Gesture) -> () } = {}

local inputDevice = "Mouse"
local leftHanded = MobileInput.Zones.LeftHanded
local charge = 0
local lockedTargetId: string? = nil
local lockConfidence = 0
local aiming = false
local lastTapAt: number? = nil
local snapshot: Snapshot

local function gestureSettings()
	local gestures = MobileInput.Gestures
	local viewportHeight = snapshot.viewport.height
	local reference = MobileInput.ReferenceViewportHeight
	return {
		-- Distance thresholds scale with the screen so the same physical thumb
		-- travel means the same thing on a phone and a tablet.
		DragThresholdPixels = Zones.scalePixels(gestures.DragThresholdPixels, viewportHeight, reference),
		SwipeMinPixels = Zones.scalePixels(gestures.SwipeMinPixels, viewportHeight, reference),
		TapMaxSeconds = gestures.TapMaxSeconds,
		HoldMinSeconds = gestures.HoldMinSeconds,
		ChargeFullSeconds = gestures.ChargeFullSeconds,
		SwipeMaxSeconds = gestures.SwipeMaxSeconds,
		SwipeAngleToleranceDeg = gestures.SwipeAngleToleranceDeg,
		DoubleTapMaxSeconds = gestures.DoubleTapMaxSeconds,
	}
end

local function currentDevice(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Touch"
	end
	if string.find(last.Name, "Gamepad", 1, true) == 1 then
		return "Gamepad"
	end
	-- Only fall back to capability when the last input says nothing useful.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	end
	return "Mouse"
end

local function publish()
	for _, listener in snapshotListeners do
		local ok, err = pcall(listener, snapshot)
		if not ok then
			warn(`[TouchInput] snapshot listener error: {err}`)
		end
	end
end

local function rebuildSnapshot()
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1920, 1080)
	local inset = GuiService:GetGuiInset()
	local zones = Zones.layout(MobileInput.Zones.MovementWidthFraction, leftHanded)

	snapshot = {
		inputDevice = inputDevice,
		zones = zones,
		zonePixels = {
			Movement = Zones.toPixels(zones.Movement, viewport.X, viewport.Y, inset.X, inset.Y),
			Action = Zones.toPixels(zones.Action, viewport.X, viewport.Y, inset.X, inset.Y),
		},
		leftHanded = leftHanded,
		charge = charge,
		lockedTargetId = lockedTargetId,
		lockConfidence = lockConfidence,
		aiming = aiming,
		viewport = { width = viewport.X, height = viewport.Y },
	}
end

local function refresh()
	rebuildSnapshot()
	publish()
end

-- Screen position of a touch in normalized usable-area coordinates, or nil when
-- it is not ours: under the topbar, outside the action zone, or inside a rect
-- some UI has claimed.
local function actionZonePoint(position: Vector3): (number?, number?)
	local camera = Workspace.CurrentCamera
	if camera == nil then
		return nil, nil
	end
	local inset = GuiService:GetGuiInset()
	local x, y = Zones.normalize(position.X, position.Y, camera.ViewportSize.X, camera.ViewportSize.Y, inset.X, inset.Y)
	if x == nil or y == nil then
		return nil, nil
	end
	if not Zones.contains(snapshot.zones.Action, x, y) then
		return nil, nil
	end
	if Zones.excluded(exclusionRects, x, y) then
		return nil, nil
	end
	return x, y
end

-- Enemies the player can actually see, projected to the screen. Everything
-- behind the camera, off-screen, or occluded is discarded before scoring.
local function tapCandidates(camera: Camera, localCharacter: Model): { TapTarget.Candidate }
	local candidates = {}
	local localRoot = localCharacter:FindFirstChild("HumanoidRootPart")
	if localRoot == nil or not localRoot:IsA("BasePart") then
		return candidates
	end
	local localTeamId = localCharacter:GetAttribute("TeamId")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local balls = Workspace:FindFirstChild("Balls")
	params.FilterDescendantsInstances = if balls then { localCharacter, balls } else { localCharacter }

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if player == Players.LocalPlayer or character == nil then
			continue
		end
		if character:GetAttribute("CombatAlive") == false then
			continue
		end
		if localTeamId ~= nil and character:GetAttribute("TeamId") == localTeamId then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			continue
		end

		local screen, onScreen = camera:WorldToViewportPoint(root.Position)
		if not onScreen or screen.Z <= 0 then
			continue
		end

		local offset = root.Position - camera.CFrame.Position
		local hit = Workspace:Raycast(camera.CFrame.Position, offset, params)
		if hit ~= nil and not hit.Instance:IsDescendantOf(character) then
			continue
		end

		-- Apparent height from projecting a point one character-height above the
		-- root: the on-screen size the player is actually tapping at.
		local top = camera:WorldToViewportPoint(root.Position + Vector3.new(0, Combat.CharacterCapsule.Height, 0))
		table.insert(candidates, {
			id = PlayerIds.toId(player),
			screenX = screen.X,
			screenY = screen.Y,
			apparentHeightPixels = math.abs(screen.Y - top.Y),
			worldDistance = (root.Position - localRoot.Position).Magnitude,
		})
	end
	return candidates
end

local function pickTapTarget(normalizedX: number, normalizedY: number): string?
	local settings = MobileInput.TapToTarget
	if not settings.Enabled or settings.Strength <= 0 then
		return nil
	end
	local camera = Workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	if camera == nil or character == nil then
		return nil
	end

	local inset = GuiService:GetGuiInset()
	local tapX = inset.X + normalizedX * (camera.ViewportSize.X - inset.X)
	local tapY = inset.Y + normalizedY * (camera.ViewportSize.Y - inset.Y)

	-- Strength shrinks the selection radius rather than gating the feature, so a
	-- partial rollout is a smaller target rather than an on/off cliff.
	local scaled = {
		RadiusScale = settings.RadiusScale * settings.Strength,
		MinRadiusPixels = Zones.scalePixels(
			settings.MinRadiusPixels * settings.Strength,
			snapshot.viewport.height,
			MobileInput.ReferenceViewportHeight
		),
		MaxRadiusPixels = Zones.scalePixels(
			settings.MaxRadiusPixels,
			snapshot.viewport.height,
			MobileInput.ReferenceViewportHeight
		),
		WorldDistanceWeight = settings.WorldDistanceWeight,
	}
	return TapTarget.pick(tapCandidates(camera, character), tapX, tapY, Combat.Dodgeball.TargetSelectRange, scaled)
end

local function emit(gesture: Gesture)
	for _, listener in gestureListeners do
		local ok, err = pcall(listener, gesture)
		if not ok then
			warn(`[TouchInput] gesture listener error: {err}`)
		end
	end
end

local function onTouchEnded(input: InputObject)
	local touch = activeTouches[input]
	if touch == nil then
		return
	end
	activeTouches[input] = nil

	local settings = gestureSettings()
	local now = os.clock()
	local release = Gestures.release(touch, settings, now)
	if release.kind == "None" then
		return
	end

	local normalizedX, normalizedY = actionZonePoint(input.Position)
	local x = normalizedX or 0
	local y = normalizedY or 0

	local kind = release.kind
	if kind == "Tap" then
		if Gestures.isDoubleTap(lastTapAt, now, settings) then
			kind = "DoubleTap"
			lastTapAt = nil
		else
			lastTapAt = now
		end
	end

	-- Only a tap identifies a target; a swipe or a charged release keeps
	-- whatever the aim layer had, since the finger was not pointing at anything
	-- in particular when it lifted.
	local targetId: string? = nil
	if kind == "Tap" or kind == "DoubleTap" then
		targetId = pickTapTarget(x, y)
	end

	emit({ kind = kind, direction = release.direction, charge = release.charge, targetId = targetId, x = x, y = y })
end

local function step()
	local settings = gestureSettings()
	local now = os.clock()
	local highest = 0
	local dragging = false
	-- Only action-zone touches are ever tracked, so any drag here is the player
	-- turning the camera.
	for _, touch in activeTouches do
		Gestures.step(touch, settings, now)
		highest = math.max(highest, Gestures.charge(touch, settings, now))
		if touch.phase == "Drag" then
			dragging = true
		end
	end
	if highest ~= charge or dragging ~= aiming then
		charge = highest
		aiming = dragging
		refresh()
	end
end

function TouchInput.getSnapshot(): Snapshot
	return snapshot
end

function TouchInput.subscribe(listener: (Snapshot) -> ()): () -> ()
	table.insert(snapshotListeners, listener)
	return function()
		local index = table.find(snapshotListeners, listener)
		if index then
			table.remove(snapshotListeners, index)
		end
	end
end

function TouchInput.onGesture(listener: (Gesture) -> ()): () -> ()
	table.insert(gestureListeners, listener)
	return function()
		local index = table.find(gestureListeners, listener)
		if index then
			table.remove(gestureListeners, index)
		end
	end
end

function TouchInput.registerExclusionRect(id: string, rect: Zones.Rect): () -> ()
	exclusionRects[id] = rect
	return function()
		exclusionRects[id] = nil
	end
end

function TouchInput.setLeftHanded(value: boolean)
	if leftHanded == value then
		return
	end
	leftHanded = value
	refresh()
end

-- Telegraphs the aim assist's current pick and how sure it is, so a reticle can
-- render exactly what the assists are acting on. Purely a projection: this never
-- decides the target, it only reports the one AimDirector chose.
function TouchInput.setLockedTarget(targetId: string?, confidence: number?)
	local resolved = if targetId == nil then 0 else math.clamp(confidence or 0, 0, 1)
	if lockedTargetId == targetId and lockConfidence == resolved then
		return
	end
	lockedTargetId = targetId
	lockConfidence = resolved
	refresh()
end

function TouchInput.start()
	if started then
		return
	end
	started = true

	inputDevice = currentDevice()
	rebuildSnapshot()

	UserInputService.LastInputTypeChanged:Connect(function()
		local device = currentDevice()
		if device ~= inputDevice then
			inputDevice = device
			refresh()
		end
	end)

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local current = Workspace.CurrentCamera
		if current then
			current:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
		end
		refresh()
	end)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(refresh)

	UserInputService.TouchStarted:Connect(function(input, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end
		local x, y = actionZonePoint(input.Position)
		if x == nil or y == nil then
			return
		end
		activeTouches[input] = Gestures.begin(input.Position.X, input.Position.Y, os.clock())
	end)

	UserInputService.TouchMoved:Connect(function(input, gameProcessedEvent)
		local touch = activeTouches[input]
		if touch == nil or gameProcessedEvent then
			return
		end
		Gestures.move(touch, input.Position.X, input.Position.Y, input.Delta.X, input.Delta.Y, gestureSettings())
	end)

	UserInputService.TouchEnded:Connect(function(input)
		onTouchEnded(input)
	end)

	RunService.RenderStepped:Connect(step)
end

return TouchInput
