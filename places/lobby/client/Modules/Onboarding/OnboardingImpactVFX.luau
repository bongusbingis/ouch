-- Name: OnboardingImpactVFX.luau
-- Author: Jack C.
-- Description: The payoff burst when a training dummy goes down: an expanding shockwave ring and a spray of confetti at the spot it was standing. Client-only prototype geometry, driven off the target set rather than any gameplay state.
-- Created: 2026-08-26

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local OnboardingConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Onboarding"))
local OnboardingClient = require(script.Parent:WaitForChild("OnboardingClient"))
local OnboardingTargets = require(script.Parent:WaitForChild("OnboardingTargets"))

local OnboardingImpactVFX = {}

type Effect = {
	part: BasePart,
	elapsed: number,
	lifetime: number,
	spin: Vector3,
	ring: boolean,
	startSize: Vector3,
	endSize: Vector3,
}

local started = false
local effects: { Effect } = {}
local connection: RBXScriptConnection? = nil
local unsubscribe: (() -> ())? = nil
local unsubscribeCue: (() -> ())? = nil
local celebrated = false

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

local function spawnRing(at: Vector3, style: { [string]: any })
	local part = newPart(
		style.RingColor,
		Vector3.new(style.RingThickness, 1, 1),
		CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	)
	part.Shape = Enum.PartType.Cylinder
	table.insert(effects, {
		part = part,
		elapsed = 0,
		lifetime = style.RingSeconds,
		spin = Vector3.zero,
		ring = true,
		startSize = Vector3.new(style.RingThickness, style.RingStartStuds, style.RingStartStuds),
		endSize = Vector3.new(style.RingThickness, style.RingEndStuds, style.RingEndStuds),
	})
end

local function spawnConfetti(at: Vector3, style: { [string]: any })
	local count = math.max(math.floor(style.ConfettiCount * OnboardingConfig.Effects.ParticleIntensity), 0)
	for index = 1, count do
		local angle = (index / count) * math.pi * 2 + math.random() * 0.6
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local color = style.ConfettiColors[math.random(1, #style.ConfettiColors)]
		local size = style.ConfettiSize * (0.7 + math.random() * 0.6)
		local part = newPart(color, size, CFrame.new(at + Vector3.new(0, 1, 0)))
		table.insert(effects, {
			part = part,
			elapsed = 0,
			lifetime = style.ConfettiSeconds * (0.75 + math.random() * 0.5),
			spin = outward * style.ConfettiSpeed + Vector3.new(0, style.ConfettiRise * (0.6 + math.random()), 0),
			ring = false,
			startSize = size,
			endSize = size * 0.2,
		})
	end
end

local function burst(_target: Model, at: Vector3)
	local style = OnboardingConfig.Impact
	spawnRing(at, style)
	spawnConfetti(at, style)
end

-- Finishing is the biggest moment in the flow, so it gets the same burst the
-- dummies do, thrown from the player themselves.
local function onSnapshot(snapshot: any)
	if not snapshot.active or snapshot.cue ~= "Done" then
		celebrated = false
		return
	end
	if celebrated then
		return
	end
	celebrated = true
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return
	end
	local style = OnboardingConfig.Impact
	spawnRing(root.Position, style)
	for _ = 1, 3 do
		spawnConfetti(root.Position + Vector3.new(0, 2, 0), style)
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
			-- Cartoon arc: fast outward throw that falls off and tumbles.
			local drift = effect.spin * (1 - alpha) * delta * 6
			effect.part.CFrame = (effect.part.CFrame + drift) * CFrame.Angles(delta * 6, delta * 8, 0)
		end
	end
end

function OnboardingImpactVFX.start()
	if started then
		return
	end
	started = true
	unsubscribe = OnboardingTargets.onLost(burst)
	unsubscribeCue = OnboardingClient.subscribe(onSnapshot)
	connection = RunService.RenderStepped:Connect(step)
end

function OnboardingImpactVFX.destroy()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	if unsubscribe then
		unsubscribe()
		unsubscribe = nil
	end
	if unsubscribeCue then
		unsubscribeCue()
		unsubscribeCue = nil
	end
	celebrated = false
	for _, effect in effects do
		effect.part:Destroy()
	end
	table.clear(effects)
	started = false
end

return OnboardingImpactVFX
