-- Name: ConfettiImpact.luau
-- Author: Jack C.
-- Description: Script-defined impact effect: expanding neon rings and gravity-driven confetti spawned at a world point, animated on a single self-managing RenderStepped loop that idles when nothing is in flight.
-- Created: 2026-08-29

--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ConfettiImpact = {}

export type Context = {
	position: Vector3,
	direction: Vector3?,
	scale: number?,
}

type Effect = {
	part: BasePart,
	elapsed: number,
	lifetime: number,
	velocity: Vector3,
	angular: Vector3,
	ring: boolean,
	startSize: Vector3,
	endSize: Vector3,
}

local RING_COLOR = Color3.fromRGB(255, 238, 0)
local ECHO_RING_COLOR = Color3.fromRGB(97, 255, 237)
local ECHO_RING_SCALE = 0.68
local RING_THICKNESS = 0.6
local RING_START_STUDS = 3
local RING_END_STUDS = 26
local RING_SECONDS = 0.45

local CONFETTI_COUNT = 14
local CONFETTI_INTENSITY = 1
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 0, 64),
	Color3.fromRGB(255, 238, 0),
	Color3.fromRGB(97, 255, 237),
	Color3.fromRGB(142, 31, 232),
}
local CONFETTI_SIZE = Vector3.new(0.9, 0.9, 0.9)
local CONFETTI_SECONDS = 0.9
local CONFETTI_SPEED = 9
local CONFETTI_RISE = 7
local CONFETTI_GRAVITY = 18

local effects: { Effect } = {}
local connection: RBXScriptConnection? = nil
local random = Random.new()

local function newPart(color: Color3, size: Vector3, cframe: CFrame): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = Workspace
	return part
end

local function spawnRing(at: Vector3, scale: number, color: Color3)
	local part = newPart(color, Vector3.new(RING_THICKNESS, 1, 1), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)))
	part.Shape = Enum.PartType.Cylinder
	table.insert(effects, {
		part = part,
		elapsed = 0,
		lifetime = RING_SECONDS * scale,
		velocity = Vector3.zero,
		angular = Vector3.zero,
		ring = true,
		startSize = Vector3.new(RING_THICKNESS, RING_START_STUDS * scale, RING_START_STUDS * scale),
		endSize = Vector3.new(RING_THICKNESS, RING_END_STUDS * scale, RING_END_STUDS * scale),
	})
end

local function spawnConfetti(at: Vector3)
	local count = math.max(math.floor(CONFETTI_COUNT * CONFETTI_INTENSITY), 0)
	for index = 1, count do
		local angle = (index / count) * math.pi * 2 + random:NextNumber() * 0.6
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local color = CONFETTI_COLORS[random:NextInteger(1, #CONFETTI_COLORS)]
		local size = CONFETTI_SIZE * (0.7 + random:NextNumber() * 0.6)
		local part = newPart(color, size, CFrame.new(at + Vector3.new(0, 1, 0)))
		table.insert(effects, {
			part = part,
			elapsed = 0,
			lifetime = CONFETTI_SECONDS * (0.75 + random:NextNumber() * 0.5),
			velocity = outward * CONFETTI_SPEED + Vector3.new(0, CONFETTI_RISE * (0.6 + random:NextNumber()), 0),
			angular = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-10, 10), random:NextNumber(-8, 8)),
			ring = false,
			startSize = size,
			endSize = size * 0.2,
		})
	end
end

local function step(delta: number)
	for index = #effects, 1, -1 do
		local effect = effects[index]
		effect.elapsed += delta
		local alpha = math.clamp(effect.elapsed / effect.lifetime, 0, 1)
		if alpha >= 1 then
			effect.part:Destroy()
			table.remove(effects, index)
			continue
		end
		local eased = 1 - (1 - alpha) ^ 3
		effect.part.Size = effect.startSize:Lerp(effect.endSize, eased)
		effect.part.Transparency = alpha
		if not effect.ring then
			effect.velocity -= Vector3.new(0, CONFETTI_GRAVITY * delta, 0)
			effect.part.CFrame = (effect.part.CFrame + effect.velocity * delta)
				* CFrame.Angles(effect.angular.X * delta, effect.angular.Y * delta, effect.angular.Z * delta)
		end
	end
	if #effects == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

function ConfettiImpact.play(context: Context)
	local at = context.position
	local scale = context.scale or 1
	spawnRing(at, scale, RING_COLOR)
	spawnRing(at, ECHO_RING_SCALE * scale, ECHO_RING_COLOR)
	spawnConfetti(at)
	if connection == nil then
		connection = RunService.RenderStepped:Connect(step)
	end
end

return ConfettiImpact
