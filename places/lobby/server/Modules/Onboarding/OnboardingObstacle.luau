-- Description: Builds the single obstacle the tutorial teaches avoidance with. Clones the authored Splashdown sweeper into a learner's own arena, places it across the bridge at the Splashdown authoring scale, and hands it to the shared rotor and shove kits, so the one hazard a new player meets behaves exactly like the real thing and disappears again the moment that lesson ends.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Config")
local OnboardingConfig = require(Config:WaitForChild("Interface"):WaitForChild("Onboarding"))
local SplashdownConfig = require(Config:WaitForChild("Gameplay"):WaitForChild("Splashdown"))
local ScriptableRoots = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("MapFeatures")
		:WaitForChild("ScriptableRoots")
)
local OnboardingArena = require(script.Parent:WaitForChild("OnboardingArena"))

local OnboardingObstacle = {}

export type Obstacle = {
	root: Folder,
	bar: BasePart,
}

-- The authored model is Rojo-mapped, so it is normally already there. Waiting
-- is bounded anyway: a missing asset leaves the lesson an ordinary crossing
-- rather than stalling the session that was about to start.
local TEMPLATE_TIMEOUT_SECONDS = 5

local cached: BasePart? = nil
local resolved = false

-- Resolved once per server, including the failure: a lesson transition must
-- never pay the wait, or the same warning, twice.
local function template(): BasePart?
	if resolved then
		return cached
	end
	resolved = true
	local obstacle = OnboardingConfig.Obstacle
	local folder = ReplicatedStorage:FindFirstChild("SplashdownTraining")
		or ReplicatedStorage:WaitForChild("SplashdownTraining", TEMPLATE_TIMEOUT_SECONDS)
	local found = if folder then folder:FindFirstChild(obstacle.Asset) else nil
	if found == nil or not found:IsA("BasePart") then
		warn(`[OnboardingObstacle] authored {obstacle.Asset} is missing; the dodge lesson runs without its sweeper`)
		return nil
	end
	cached = found
	return found
end

-- Same scale, bottom-centred placement, pivot cleanup and sd_ naming as
-- author-splashdown-courses.luau, so the mesh sits on the bridge deck the way
-- it sits on a real course.
local function place(source: BasePart, arena: OnboardingArena.Arena, parent: Instance): BasePart
	local obstacle = OnboardingConfig.Obstacle
	local holder = Instance.new("Model")
	local bar = source:Clone()
	bar.Parent = holder
	holder:ScaleTo(obstacle.AssetScale)
	for _, part in holder:GetDescendants() do
		if part:IsA("BasePart") then
			part.Name = `sd_{part.Name}`
			part.Anchored = true
			part.CanCollide = true
			part.CanTouch = false
			part.CanQuery = true
			part.Massless = false
			part.PivotOffset = CFrame.identity
		end
	end
	local boundsCFrame, size = holder:GetBoundingBox()
	holder.WorldPivot = CFrame.new(boundsCFrame.Position - Vector3.new(0, size.Y / 2, 0))
	local position = OnboardingArena.point(arena, obstacle.SweeperDistance, 0)
	holder:PivotTo(CFrame.lookAt(position, position - arena.frame.forward))
	bar.Parent = parent
	holder:Destroy()
	return bar
end

-- A rotor rather than a named spinner: the shared mover and the shared shove
-- both read these attributes, so the bar is driven and responds to a hit with
-- the tuning Splashdown already ships rather than anything training-only.
local function drive(bar: BasePart)
	local obstacle = OnboardingConfig.Obstacle
	local response = SplashdownConfig.HazardResponse.Rotor
	bar:SetAttribute("Rotor", "spin")
	bar:SetAttribute("RotorAxis", "Y")
	bar:SetAttribute("RotorSpeed", obstacle.SweeperSpeed)
	bar:SetAttribute("RotorPeriod", 1)
	bar:SetAttribute("Shove", true)
	bar:SetAttribute("ShoveSpeed", response.Speed)
	bar:SetAttribute("ShoveUpwardSpeed", response.UpwardSpeed)
	bar:SetAttribute("ShoveSeconds", response.HoldSeconds)
end

-- Returns nil rather than erroring on a missing or rejected asset: the lesson
-- degrades to a plain crossing, which still advances, instead of ending a
-- session the player is already standing in.
function OnboardingObstacle.build(arena: OnboardingArena.Arena): Obstacle?
	local source = template()
	if source == nil then
		return nil
	end
	local root = Instance.new("Folder")
	root.Name = "TrainingHazards"
	local motion = Instance.new("Folder")
	motion.Name = "Motion"
	motion.Parent = root
	local assembly = Instance.new("Model")
	assembly.Name = "Assembly"
	assembly.Parent = motion

	local ok, result = pcall(place, source, arena, assembly)
	if not ok then
		warn(`[OnboardingObstacle] could not place the sweeper: {result}`)
		root:Destroy()
		return nil
	end
	local bar = result :: BasePart
	drive(bar)

	root.Parent = arena.model
	local tagged, reason = ScriptableRoots.tag(root)
	if not tagged then
		warn(`[OnboardingObstacle] rejected {root:GetFullName()}:\n{reason}`)
		root:Destroy()
		return nil
	end
	return { root = root, bar = bar }
end

function OnboardingObstacle.destroy(obstacle: Obstacle?)
	if obstacle == nil then
		return
	end
	ScriptableRoots.untag(obstacle.root)
	obstacle.root:Destroy()
end

return OnboardingObstacle
