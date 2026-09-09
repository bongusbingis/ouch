-- Description: Frees the authored beach balls into live physics once the ring assembly streams in, resetting any that fall out of bounds and restoring their anchored authored pose when the feature stops.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MapFeatures =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Gameplay"):WaitForChild("MapFeatures"))
local MapFeatureKit = require(script.Parent.MapFeatureKit)
local ArenaService = require(script.Parent.Parent.ArenaService)

local BeachBalls = {}
BeachBalls.folderName = "Rotating"
BeachBalls.instanceClass = "Folder"

type BallInfo = {
	homeRelative: CFrame,
	assembly: Model,
}

local balls: { [BasePart]: BallInfo } = {}
local initializedAssemblies: { [Model]: boolean } = {}
local runtimeFolder: Folder? = nil
local nextCheckAt = 0
local mapOrigin: Vector3? = nil
local warnedNoMapOrigin = false

local function getRuntimeFolder(): Folder
	if runtimeFolder and runtimeFolder.Parent then
		return runtimeFolder
	end
	local scriptables = ArenaService.get().scriptables
	local existing = scriptables:FindFirstChild("BeachBalls")
	if existing and existing:IsA("Folder") then
		runtimeFolder = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "BeachBalls"
	folder.Parent = scriptables
	runtimeFolder = folder
	return folder
end

local function mapOriginPosition(): Vector3?
	if mapOrigin then
		return mapOrigin
	end
	local assets = Workspace:FindFirstChild("Assets")
	local arena = assets and assets:FindFirstChild("Arena")
	local origin = arena and arena:FindFirstChild("MapOrigin")
	if origin == nil or not origin:IsA("BasePart") then
		if not warnedNoMapOrigin then
			warnedNoMapOrigin = true
			warn("[BeachBalls] No Workspace.Assets.Arena.MapOrigin Part authored; reset bounds inactive")
		end
		return nil
	end
	mapOrigin = origin.Position
	return mapOrigin
end

local function initGroup(assembly: Model)
	initializedAssemblies[assembly] = true
	local settings = MapFeatures.BeachBall
	local folder = getRuntimeFolder()
	local pivot = assembly:GetPivot()
	for _, ball in assembly:GetChildren() do
		if ball:IsA("BasePart") and ball.Name:find(settings.NamePrefix, 1, true) == 1 then
			balls[ball] = {
				homeRelative = pivot:ToObjectSpace(ball.CFrame),
				assembly = assembly,
			}
			-- Model:PivotTo in the ring mover would otherwise teleport an unanchored
			-- ball every heartbeat and fight physics, so it moves under a runtime
			-- Folder the mover never touches.
			ball.Parent = folder
			ball.Anchored = false
			ball.CanCollide = true
			ball.CustomPhysicalProperties =
				PhysicalProperties.new(settings.Density, settings.Friction, settings.Elasticity, 1, 1)
		end
	end
end

function BeachBalls.tickWorld(context: MapFeatureKit.Context)
	for _, group in context.instances do
		local assembly = group:FindFirstChild("Assembly")
		if assembly and assembly:IsA("Model") and not initializedAssemblies[assembly] then
			initGroup(assembly)
		end
	end

	if context.now < nextCheckAt then
		return
	end
	nextCheckAt = context.now + MapFeatures.BeachBall.CheckIntervalSeconds

	local origin = mapOriginPosition()
	if origin == nil then
		return
	end
	local settings = MapFeatures.BeachBall
	for ball, info in balls do
		if ball.Parent == nil then
			balls[ball] = nil
			continue
		end
		local position = ball.Position
		if
			position.Y < origin.Y + settings.ResetBelowOffset
			or (position - origin).Magnitude > settings.ResetRadius
		then
			ball.AssemblyLinearVelocity = Vector3.zero
			ball.AssemblyAngularVelocity = Vector3.zero
			ball.CFrame = info.assembly:GetPivot() * info.homeRelative
		end
	end
end

function BeachBalls.forget(player: Player?)
	if player then
		return
	end
	for ball, info in balls do
		if ball.Parent then
			ball.Anchored = true
			ball.CFrame = info.assembly:GetPivot() * info.homeRelative
			ball.Parent = info.assembly
			ball.CustomPhysicalProperties = nil
		end
	end
	table.clear(balls)
	table.clear(initializedAssemblies)
	nextCheckAt = 0
end

return BeachBalls
