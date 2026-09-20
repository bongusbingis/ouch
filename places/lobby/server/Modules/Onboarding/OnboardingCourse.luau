--!strict
-- Adds authored Splashdown encounters to the existing TutorialArena.
local RS = game:GetService("ReplicatedStorage")
local Arena = require(script.Parent.OnboardingArena)
local Config = require(RS.Config.Interface.Onboarding).Course
local Response = require(RS.Config.Gameplay.Splashdown).HazardResponse
local ScriptableRoots = require(RS.Shared.Game.MapFeatures.ScriptableRoots)
local Course = {}

export type Course = Arena.Arena & {
	origin: Vector3,
	group: Folder,
	hazards: { BasePart },
}

function Course.position(arena: Course, distance: number, lateral: number?): Vector3
	return Arena.point(arena, distance, lateral or 0)
end

function Course.direction(arena: Course, from: number, to: number): Vector3
	return arena.frame.forward * (if to > from then 1 else -1)
end

function Course.spawnAt(arena: Course, distance: number, target: number): CFrame
	local position = Course.position(arena, distance) + Vector3.new(0, 4, 0)
	return CFrame.lookAt(position, position + Course.direction(arena, distance, target))
end

-- x = distance along the original approach, z = distance to its side.
function Course.localPosition(arena: Course, position: Vector3): Vector3
	local delta = position - arena.origin
	return Vector3.new(delta:Dot(arena.frame.forward), delta.Y, delta:Dot(arena.frame.right))
end

function Course.build(index: number): Course
	local arena = Arena.build(index) :: Course
	arena.origin = arena.frame.origin
	arena.hazards = {}
	local templates = RS:WaitForChild("SplashdownTraining")
	local scriptables = Instance.new("Folder")
	scriptables.Name = "TrainingScriptables"
	local motion = Instance.new("Folder")
	motion.Name = "Motion"
	motion.Parent = scriptables
	local group = Instance.new("Folder")
	group.Name = "Training"
	group.Parent = motion
	arena.group = group
	local origin = Instance.new("Part")
	origin.Name = "Origin"
	origin.Anchored = true
	origin.CanCollide = false
	origin.CanTouch = false
	origin.CanQuery = false
	origin.Transparency = 1
	origin.CFrame = CFrame.new(arena.origin)
	origin:SetAttribute("RotationSpeed", 0)
	origin.Parent = group
	local assembly = Instance.new("Model")
	assembly.Name = "Assembly"
	assembly.Parent = group

	-- Same scale, bottom-centred placement, pivot cleanup and sd_ naming as
	-- author-splashdown-courses.luau. Clone the entire authored mesh hierarchy.
	local function piece(name: string, distance: number, lateral: number, clearance: number): BasePart
		local template = templates:FindFirstChild(name)
		assert(template and template:IsA("BasePart"), "Missing authored training asset " .. name)
		local holder = Instance.new("Model")
		local clone = template:Clone()
		clone.Parent = holder
		holder:ScaleTo(Config.AssetScale)
		for _, part in holder:GetDescendants() do
			if part:IsA("BasePart") then
				part.Name = "sd_" .. part.Name
				part.Anchored = true
				part.CanCollide = true
				part.CanTouch = false
				part.CanQuery = true
				part.Massless = false
				part.PivotOffset = CFrame.identity
			end
		end
		local cf, size = holder:GetBoundingBox()
		holder.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0))
		local position = Course.position(arena, distance, lateral) + Vector3.new(0, clearance, 0)
		holder:PivotTo(CFrame.lookAt(position, position - arena.frame.forward))
		clone.Parent = assembly
		holder:Destroy()
		return clone
	end

	for i, position in Config.BumperPositions do
		local bumper = piece(if i == 1 then "obstacle_18_001" else "obstacle_19_001", position[1], position[2], 0)
		bumper:SetAttribute("Bumper", true)
		bumper:SetAttribute("ShoveSpeed", Response.Bumper.Speed)
		bumper:SetAttribute("ShoveUpwardSpeed", Response.Bumper.UpwardSpeed)
		bumper:SetAttribute("ShoveSeconds", Response.Bumper.HoldSeconds)
		table.insert(arena.hazards, bumper)
	end
	local bar = piece("obstacle_6_001", Config.SweeperDistance, 0, 0)
	bar:SetAttribute("Rotor", "spin")
	bar:SetAttribute("RotorAxis", "Y")
	bar:SetAttribute("RotorSpeed", Config.SweeperSpeed)
	bar:SetAttribute("RotorPeriod", 1)
	bar:SetAttribute("Shove", true)
	bar:SetAttribute("ShoveSpeed", Response.Rotor.Speed)
	bar:SetAttribute("ShoveUpwardSpeed", Response.Rotor.UpwardSpeed)
	bar:SetAttribute("ShoveSeconds", Response.Rotor.HoldSeconds)
	table.insert(arena.hazards, bar)

	local mount = piece("obstacle_3_001", Config.HammerDistance, 0, 2)
	local blade = mount:FindFirstChild("sd_obstacle_3_002") :: BasePart
	assert(blade and blade:IsA("BasePart"), "Authored swinging hammer is missing its blade")
	blade.PivotOffset = blade.CFrame:ToObjectSpace(CFrame.new(mount.Position) * mount.CFrame.Rotation)
	blade:SetAttribute("Rotor", "rock")
	-- Shared movers use world axes. TutorialArena's bridge runs along world X,
	-- so the source hammer's Z-axis swing rotates to X with its placed mesh.
	blade:SetAttribute("RotorAxis", if math.abs(arena.frame.forward.X) > 0.5 then "X" else "Z")
	blade:SetAttribute("RotorAmplitude", 55)
	blade:SetAttribute("RotorPeriod", Config.HammerPeriod)
	blade:SetAttribute("Shove", true)
	blade:SetAttribute("ShoveSpeed", Response.HammerSpeed)
	blade:SetAttribute("ShoveUpwardSpeed", Response.Rotor.UpwardSpeed)
	blade:SetAttribute("ShoveSeconds", Response.Rotor.HoldSeconds)
	table.insert(arena.hazards, blade)

	scriptables.Parent = arena.model
	ScriptableRoots.tag(scriptables)
	return arena
end

function Course.destroy(arena: Course?)
	Arena.destroy(arena)
end

return Course
