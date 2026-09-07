--!strict

-- Sole writer for scripted presentation cameras. Each owner supplies its motion;
-- leases prevent old teardown and camera replacement from restoring stale state.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LeaseState = require(script.Parent.Parent.Parent.Game.Cosmetics.CameraLeaseState)

local PresentationCamera = {}
PresentationCamera.Priority = table.freeze({ Lobby = 10, Preview = 20, Death = 30, Results = 35, Vote = 40 })

export type Token = LeaseState.Token
type Owner = { render: (Camera, number) -> (), onPreempted: (() -> ())? }
type OriginalCamera = { fieldOfView: number, cframe: CFrame, focus: CFrame }

local state = LeaseState.new()
local owners: { [Token]: Owner } = {}
local current: Token? = nil
local bound = false
local original: { [Camera]: OriginalCamera } = {}
local listeners: { [() -> ()]: boolean } = {}
local BINDING = "PresentationCamera"

local function restore()
	for camera, values in original do
		camera.FieldOfView = values.fieldOfView
		camera.CFrame = values.cframe
		camera.Focus = values.focus
		if camera == Workspace.CurrentCamera then
			local character = Players.LocalPlayer.Character
			local humanoid = if character then character:FindFirstChildWhichIsA("Humanoid") else nil
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		camera.CameraType = Enum.CameraType.Custom
	end
	table.clear(original)
end

local function render(delta: number)
	local owner = if current then owners[current] else nil
	local camera = Workspace.CurrentCamera
	if owner == nil or camera == nil then
		return
	end
	if original[camera] == nil then
		original[camera] = { fieldOfView = camera.FieldOfView, cframe = camera.CFrame, focus = camera.Focus }
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = original[camera].fieldOfView
	local ok, err = pcall(owner.render, camera, delta)
	if not ok then
		warn(`[PresentationCamera] camera update failed: {err}`)
	end
end

local function sync()
	local nextOwner = LeaseState.current(state)
	local previous = current
	current = nextOwner
	if previous ~= nextOwner then
		local prior = if previous then owners[previous] else nil
		if nextOwner and prior and prior.onPreempted then
			local ok, err = pcall(prior.onPreempted)
			if not ok then
				warn(`[PresentationCamera] preemption failed: {err}`)
			end
		end
		for listener in table.clone(listeners) do
			local ok, err = pcall(listener)
			if not ok then
				warn(`[PresentationCamera] listener failed: {err}`)
			end
		end
	end
	if current then
		if not bound then
			bound = true
			RunService:BindToRenderStep(BINDING, Enum.RenderPriority.Camera.Value + 1, render)
		end
		render(0)
	elseif bound then
		bound = false
		RunService:UnbindFromRenderStep(BINDING)
		restore()
	end
end

function PresentationCamera.acquire(
	reason: string,
	priority: number,
	callback: (Camera, number) -> (),
	onPreempted: (() -> ())?
): Token
	local token = LeaseState.acquire(state, reason, priority)
	owners[token] = { render = callback, onPreempted = onPreempted }
	sync()
	return token
end

function PresentationCamera.release(token: Token)
	LeaseState.release(state, token)
	owners[token] = nil
	sync()
end

function PresentationCamera.isCurrent(token: Token): boolean
	return current == token
end

function PresentationCamera.getOwner(): string?
	return if current then current.reason else nil
end

function PresentationCamera.subscribe(listener: () -> ()): () -> ()
	listeners[listener] = true
	return function()
		listeners[listener] = nil
	end
end

return PresentationCamera
