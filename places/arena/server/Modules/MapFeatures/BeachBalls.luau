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
BeachBalls.folderNames = { "BeachBalls", "Rotating" }
BeachBalls.instanceClass = "Folder"

type BallInfo = {
	homeRelative: CFrame,
	assembly: Model | BasePart,
	parent: Instance,
	anchored: boolean,
	properties: PhysicalProperties?,
	collide: boolean,
}

local balls: { [BasePart]: BallInfo } = {}
local initializedAssemblies: { [Instance]: boolean } = {}
local nextCheckAt = 0
local mapOrigin: Vector3? = nil
local warnedNoMapOrigin = false

-- Balls live beside their own Scriptables root -- the arena's or a course's --
-- so a course's balls leave with the course instead of piling up under the
-- arena folder.
local function getRuntimeFolder(assembly: Model | BasePart): Folder
	local scriptables = assembly:FindFirstAncestor("Scriptables") or ArenaService.get().scriptables
	local existing = scriptables:FindFirstChild("BeachBalls")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "BeachBalls"
	folder.Parent = scriptables
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
	local folder = getRuntimeFolder(assembly)
	local pivot = assembly:GetPivot()
	local descendants = assembly:GetDescendants()
	if assembly:IsA("BasePart") then
		table.insert(descendants, assembly)
	end
	for _, ball in descendants do
		if
			ball:IsA("BasePart")
			and (
				ball:GetAttribute(MapFeatures.Attributes.BeachBall) == true
			or (
				assembly:FindFirstAncestor("SplashdownCourse") == nil
				and ball.Parent == assembly
				and ball.Name:find(settings.NamePrefix, 1, true) == 1
			)
			)
		then
			balls[ball] = {
				homeRelative = pivot:ToObjectSpace(ball.CFrame),
				assembly = assembly,
				parent = ball.Parent :: Instance,
				anchored = ball.Anchored,
				properties = ball.CustomPhysicalProperties,
				collide = ball.CanCollide,
			}
			-- Model:PivotTo in the ring mover would otherwise teleport an unanchored
			-- ball every heartbeat and fight physics, so it moves under a runtime
			-- Folder the mover never touches.
			ball.Parent = folder
			ball.Anchored = false
			ball.CanCollide = true
			if ball:GetAttribute(MapFeatures.Attributes.BeachBall) == true then
				ball:SetNetworkOwner(nil)
			end
			ball.CustomPhysicalProperties =
				PhysicalProperties.new(settings.Density, settings.Friction, settings.Elasticity, 1, 1)
		end
	end
end

function BeachBalls.tickWorld(context: MapFeatureKit.Context)
	for assembly in initializedAssemblies do
		if not assembly:IsDescendantOf(Workspace) then
			initializedAssemblies[assembly] = nil
		end
	end
	for _, group in context.instances do
		local assembly = group:FindFirstChild("Assembly")
		if assembly and assembly:IsA("Model") then
			if not initializedAssemblies[assembly] then
				initGroup(assembly)
			end
		elseif not assembly then
			for _, child in group:GetChildren() do
				if (child:IsA("Model") or child:IsA("BasePart")) and not initializedAssemblies[child] then
					initGroup(child)
				end
			end
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
		if ball.Parent == nil or info.assembly.Parent == nil then
			if ball.Parent and info.assembly.Parent == nil then
				ball:Destroy()
			end
			balls[ball] = nil
			initializedAssemblies[info.assembly] = nil
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
		if ball.Parent and info.assembly.Parent then
			ball.Anchored = if ball:GetAttribute(MapFeatures.Attributes.BeachBall) == true then info.anchored else true
			ball.CFrame = info.assembly:GetPivot() * info.homeRelative
			ball.Parent = info.parent
			ball.CustomPhysicalProperties = info.properties
			if ball:GetAttribute(MapFeatures.Attributes.BeachBall) == true then
				ball.CanCollide = info.collide
			end
		end
	end
	table.clear(balls)
	table.clear(initializedAssemblies)
	nextCheckAt = 0
end

-- Only live course balls opt into directional fan forcing. Arena physics stay unchanged.
function BeachBalls.active(): { BasePart }
	local result = {}
	for ball, info in balls do
		if ball.Parent and info.assembly.Parent and ball:GetAttribute(MapFeatures.Attributes.BeachBall) == true then
			table.insert(result, ball)
		end
	end
	return result
end

return BeachBalls
