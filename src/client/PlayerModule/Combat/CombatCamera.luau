--!strict

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraModule = require(script.Parent.Parent:WaitForChild("CameraModule"))
local CameraUtils = require(script.Parent.Parent:WaitForChild("CameraModule"):WaitForChild("CameraUtils"))
local CameraInput = require(script.Parent.Parent:WaitForChild("CameraModule"):WaitForChild("CameraInput"))
local CombatConfig = require(script.Parent:WaitForChild("CombatConfig"))

-- The over-the-shoulder combat camera, and the single owner of mouse lock and
-- cursor visibility.
--
-- This replaces Roblox's shift lock as a *game* mode rather than a player
-- toggle. The player never presses Shift for it; the game decides when combat is
-- happening and the camera follows. Shift itself is left unbound and free for
-- gameplay to use later.
--
-- Two concepts that Roblox deliberately couples are separated here:
--
--   mouse lock + shoulder offset   -- how the camera is framed and controlled
--   character follows camera yaw   -- whether the body turns to match
--
-- Upstream ties both to inMouseLockedMode inside BaseCamera:UpdateMouseBehavior,
-- so you cannot have one without the other. Driving the two overrides directly
-- decouples them, which is what makes CharacterFollowsCameraYaw = false a valid
-- configuration: identical camera, identical controls, the body simply stops
-- turning on its own.
--
-- Body yaw uses Roblox's own RotationType.CameraRelative rather than a custom
-- yaw spring. That path already turns the character smoothly and is the same one
-- shift lock uses, so there is exactly one owner of root rotation and nothing to
-- fight over. A hand-rolled spring here would have to disable Humanoid.AutoRotate
-- and take that ownership away from the engine for no visible gain.
--
-- Cursor release is reference counted. Several things can independently need a
-- pointer -- a shop, a settings panel, a results screen -- and the cursor should
-- only come back when the last of them is finished. A plain boolean loses that
-- and leaves the player cursorless in a menu.

local CombatCamera = {}

local RENDER_NAME = "CombatCameraState"

local enabled = false
local started = false
local cursorRequests: { [string]: boolean } = {}
local appliedLock: boolean? = nil
local appliedRotationType: boolean? = nil
local appliedCursor: boolean? = nil
local listeners: { (boolean) -> () } = {}
-- Set by the facade. Kept as a predicate rather than a require so this module
-- stays independent of the classifier.
local chargingPredicate: () -> boolean = function()
	return false
end

local function cursorIsRequested(): boolean
	return next(cursorRequests) ~= nil
end

-- Three things must agree before the camera engages:
--   enabled                  -- runtime, set by the place. Starts false, which
--                               is what leaves the lobby with a normal cursor.
--   config.Enabled           -- kill switch for testing. Ships true.
--   no outstanding cursor request
--
-- A menu open over combat therefore behaves exactly like combat is off, without
-- the game having to turn combat off and on around every panel.
local function isActive(): boolean
	return enabled and CombatConfig.CombatCamera.Enabled and not cursorIsRequested()
end

local function notify()
	local active = isActive()
	for _, listener in listeners do
		local ok, err = pcall(listener, active)
		if not ok then
			warn("[CombatCamera] listener errored: " .. tostring(err))
		end
	end
end

-- Applied every frame rather than only on change, because the active camera
-- controller is swapped out whenever the camera mode changes and a freshly
-- created controller knows nothing about our state. Re-asserting is a few
-- boolean writes and removes a whole class of "camera silently reverted" bugs.
--
-- The individual engine writes underneath are still change-gated, so this costs
-- nothing when the state is steady.
local function apply()
	local config = CombatConfig.CombatCamera
	local active = isActive()

	local controller = (CameraModule :: any).activeCameraController
	if controller then
		controller:SetIsMouseLocked(active)
		if active then
			controller:SetMouseLockOffset(config.ShoulderOffset)
		end
	end

	if appliedLock ~= active then
		appliedLock = active
		if active and config.LockMouseToCenter then
			CameraUtils.setMouseBehaviorOverride(Enum.MouseBehavior.LockCenter)
		else
			CameraUtils.restoreMouseBehavior()
		end
	end

	-- The flag that decides whether the body turns, kept independent of the lock
	-- above so either can change without disturbing the other.
	-- Explicitly force MovementRelative when we do not want camera yaw to own the
	-- model, because restoring the previous value is wrong if the default PlayerModule
	-- has been forked to CameraRelative (which is the current behavior that still
	-- makes the character yaw to the camera).
	local followYaw = active and config.CharacterFollowsCameraYaw
	if active and not followYaw then
		local player = Players.LocalPlayer
		local character = player and player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.AutoRotate = false
		end
	end
	if appliedRotationType ~= followYaw then
		appliedRotationType = followYaw
		if followYaw then
			CameraUtils.setRotationTypeOverride(Enum.RotationType.CameraRelative)
		elseif active then
			CameraUtils.setRotationTypeOverride(Enum.RotationType.MovementRelative)
		else
			CameraUtils.restoreRotationType()
		end
	end

	-- Fine aim while a charge is building, and the overall mouse feel knob. One
	-- multiplier covering every device, so no single device ends up with a
	-- different effective sensitivity than the others.
	local scale = 1
	if active then
		scale = config.MouseSensitivityMultiplier
		if chargingPredicate() then
			scale *= CombatConfig.Camera.ChargeSensitivityMultiplier
		end
	end
	CameraInput.setSensitivityScale(scale)

	local hideCursor = active and config.HideMouseCursor
	if appliedCursor ~= hideCursor and UserInputService.MouseEnabled then
		appliedCursor = hideCursor
		UserInputService.MouseIconEnabled = not hideCursor
	end
end

-- Turns combat framing on or off. The game calls this when a match starts and
-- ends; it is not a player-facing toggle.
function CombatCamera.setChargingPredicate(predicate: () -> boolean)
	chargingPredicate = predicate
end

function CombatCamera.setEnabled(value: boolean)
	if enabled == value then
		return
	end
	enabled = value
	apply()
	notify()
end

function CombatCamera.isEnabled(): boolean
	return enabled
end

function CombatCamera.isActive(): boolean
	return isActive()
end

-- Asks for the pointer back, keyed by who wants it. The cursor returns only once
-- every requester has released, so overlapping menus cannot strand each other.
function CombatCamera.requestCursor(reason: string)
	if cursorRequests[reason] then
		return
	end
	cursorRequests[reason] = true
	apply()
	notify()
end

function CombatCamera.releaseCursor(reason: string)
	if cursorRequests[reason] == nil then
		return
	end
	cursorRequests[reason] = nil
	apply()
	notify()
end

-- Fires with the effective active state, so combat input can gate itself on the
-- same signal the camera uses rather than tracking its own idea of "in combat".
function CombatCamera.onChanged(listener: (boolean) -> ()): () -> ()
	table.insert(listeners, listener)
	listener(isActive())
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function CombatCamera.start()
	if started then
		return
	end
	started = true

	-- Just ahead of the camera's own update, so the controller reads this
	-- frame's state rather than last frame's.
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value - 1, apply)

	-- Losing focus with the mouse locked strands the player pointerless over
	-- whatever took focus.
	UserInputService.WindowFocusReleased:Connect(function()
		CombatCamera.requestCursor("WindowFocus")
	end)
	UserInputService.WindowFocused:Connect(function()
		CombatCamera.releaseCursor("WindowFocus")
	end)
end

return CombatCamera
