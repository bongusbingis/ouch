-- Studio-only empirical kit runner. Real R15 humanoid, physics, original meshes.
-- Isolated from round flow; teleports occur only between trials.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local RS, SS = game.ReplicatedStorage, game.ServerStorage
local Run = game:GetService("RunService")
local Http = game:GetService("HttpService")
local Modules = game.ServerScriptService.Server.Modules.MapFeatures
local R = require(RS.Shared.Game.MapFeatures.RotatingPlatforms)
local kits = {
	Conveyor = require(Modules.Conveyors),
	BigBall = require(Modules.BigBalls),
	Tile = require(Modules.FallingTiles),
	Seesaw = require(Modules.Seesaws),
	BeachBall = require(Modules.BeachBalls),
	Fan = require(Modules.FanUpdraft),
	Carry = require(Modules.ServerRiders),
}
local result = Instance.new("StringValue")
result.Name = "SplashdownKitPhysicsResults"
result.Value = "waiting for character"
result.Parent = SS
local player = game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
local source = player.Character or player.CharacterAdded:Wait()
source:WaitForChild("HumanoidRootPart")
task.wait(2)
local archivable = source.Archivable
source.Archivable = true
local rig = source:Clone()
source.Archivable = archivable
for _, d in rig:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		d:Destroy()
	end
end
local owned = Instance.new("Folder")
owned.Name = "SplashdownKitPhysicsProbe"
owned.Parent = workspace
rig.Name = "MeasuredKitRunner"
rig.Parent = owned
local root = rig.HumanoidRootPart
local humanoid = rig:FindFirstChildOfClass("Humanoid")
local token = {}
local arenaOrigin = workspace.Assets.Arena.MapOrigin.Position
local center = arenaOrigin + Vector3.new(0, 100, 0)
local rows = {}
local currentPlatform = nil
local scriptables, group, assembly, origin, context
local function publish(status)
	result.Value = Http:JSONEncode({
		status = status,
		gravity = workspace.Gravity,
		walkSpeed = humanoid.WalkSpeed,
		hipHeight = humanoid.HipHeight,
		rootSize = { root.Size.X, root.Size.Y, root.Size.Z },
		trials = rows,
	})
end
local function clear()
	for _, kit in kits do
		if kit.forget then
			kit.forget(nil)
		end
	end
	if currentPlatform then
		local i = table.find(R.all(), currentPlatform)
		if i then
			table.remove(R.all(), i)
		end
		currentPlatform = nil
	end
	if scriptables then
		scriptables:Destroy()
	end
	scriptables = Instance.new("Folder")
	scriptables.Name = "Scriptables"
	scriptables.Parent = owned
	local rotating = Instance.new("Folder")
	rotating.Name = "Rotating"
	rotating.Parent = scriptables
	group = Instance.new("Folder")
	group.Name = "MeasuredGroup"
	group.Parent = rotating
	origin = Instance.new("Part")
	origin.Name = "Origin"
	origin.CFrame = CFrame.new(center)
	origin.Anchored = true
	origin.CanCollide = false
	origin.Transparency = 1
	origin:SetAttribute("RotationSpeed", 0)
	origin:SetAttribute("ServerCarries", true)
	origin.Parent = group
	assembly = Instance.new("Model")
	assembly.Name = "Assembly"
	assembly.Parent = group
	context = { instances = { group }, now = os.clock(), deltaTime = 1 / 60 }
end
local function fixture(name)
	local model = RS.SplashdownKitFixtures[name]:Clone()
	model:PivotTo(CFrame.new(center))
	model.Parent = assembly
	return model
end
local function asset(model, name)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("SourceAsset") == name then
			return part
		end
	end
	error("missing fixture member " .. name)
end
local function reset(position)
	humanoid:Move(Vector3.zero)
	humanoid.Jump = false
	root.Anchored = true
	rig:PivotTo(CFrame.new(position) * root.CFrame:Inverse() * rig:GetPivot())
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	root.Anchored = false
	root:SetNetworkOwner(nil)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
end
local function stand(part, offset)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { assembly }
	params.RespectCanCollide = true
	local point = part.Position + (offset or Vector3.zero)
	local hit =
		assert(workspace:Raycast(point + Vector3.yAxis * 60, -Vector3.yAxis * 120, params), "no real mesh support")
	reset(hit.Position + Vector3.yAxis * (humanoid.HipHeight + root.Size.Y / 2 + 0.15))
end
local function run(seconds, active, observe)
	local elapsed = 0
	while elapsed < seconds do
		local dt = Run.Heartbeat:Wait()
		elapsed += dt
		context.now = os.clock()
		context.deltaTime = dt
		if currentPlatform then
			R.applyAt(currentPlatform, workspace:GetServerTimeNow())
		end
		for _, name in active do
			local kit = kits[name]
			if kit.tickWorld then
				kit.tickWorld(context)
			end
			if kit.tickPlayer then
				kit.tickPlayer(context, token, root)
			end
		end
		if observe then
			observe(elapsed, dt)
		end
	end
	return elapsed
end
local function compile()
	currentPlatform = R.build(origin, assembly)
	table.insert(R.all(), currentPlatform)
end
local ok, err = xpcall(function()
	clear()
	local model = fixture("Conveyor")
	local belt = model.PrimaryPart
	belt:SetAttribute("Conveyor", true)
	belt:SetAttribute("ConveyorAxis", "Z")
	belt:SetAttribute("ConveyorSpeed", 15.6)
	stand(belt, Vector3.new(0, 0, -12))
	run(0.4, { "Conveyor" })
	local start = root.Position
	local seconds = run(1, { "Conveyor" })
	table.insert(rows, {
		name = "conveyor_humanoid",
		seconds = seconds,
		travel = (root.Position - start).Z,
		speed = (root.Position - start).Z / seconds,
	})
	publish("running")
	local ball = fixture("BeachBall").PrimaryPart
	ball.CFrame = CFrame.new(belt.Position + Vector3.new(0, belt.Size.Y / 2 + ball.Size.Y / 2 + 0.1, -12))
	ball:SetAttribute("BeachBall", true)
	root.Anchored = true
	root.CFrame = CFrame.new(center + Vector3.new(80, 80, 0))
	run(0.5, { "BeachBall", "Conveyor" })
	start = ball.Position
	seconds = run(1.5, { "BeachBall", "Conveyor" })
	table.insert(rows, {
		name = "conveyor_beach_ball",
		seconds = seconds,
		travel = (ball.Position - start).Z,
		speed = (ball.Position - start).Z / seconds,
		serverOwned = ball:GetNetworkOwner() == nil,
	})
	publish("running")
	clear()
	model = fixture("Fan")
	local fan = model.PrimaryPart
	model:PivotTo(CFrame.new(center) * CFrame.Angles(math.pi / 2, 0, 0))
	fan:SetAttribute("Fan", true)
	fan:SetAttribute("FanAxis", "Y")
	fan:SetAttribute("FanBallSpeed", 32)
	fan:SetAttribute("FanColumnHeight", 45)
	ball = fixture("BeachBall").PrimaryPart
	ball:SetAttribute("BeachBall", true)
	local direction = fan.CFrame.UpVector
	ball.CFrame = CFrame.new(fan.Position + direction * (fan.Size.Y / 2 + 3))
	ball.CanCollide = false
	local maxSpeed = 0
	seconds = run(0.5, { "BeachBall", "Fan" }, function()
		maxSpeed = math.max(maxSpeed, ball.AssemblyLinearVelocity:Dot(direction))
	end)
	table.insert(rows, { name = "fan_beach_ball", seconds = seconds, axialPeakSpeed = maxSpeed })
	publish("running")
	clear()
	model = fixture("BigBall")
	local sphere = asset(model, "obstacle_23_002")
	sphere:SetAttribute("BigBall", true)
	sphere:SetAttribute("BounceSpeed", 58)
	reset(sphere.Position + Vector3.yAxis * (sphere.Size.Y / 2 + humanoid.HipHeight + root.Size.Y / 2 + 7))
	local peak = 0
	local firstBounce = nil
	seconds = run(1.2, { "BigBall" }, function(t)
		if root.AssemblyLinearVelocity.Y > peak then
			peak = root.AssemblyLinearVelocity.Y
		end
		if root.AssemblyLinearVelocity.Y > 40 and not firstBounce then
			firstBounce = t
		end
	end)
	table.insert(
		rows,
		{ name = "big_ball_cap", bounceAt = firstBounce, peakUpward = peak, connected = firstBounce ~= nil }
	)
	publish("running")
	kits.BigBall.forget(token)
	reset(sphere.Position + Vector3.new(sphere.Size.X / 2 + 0.2, 0, 0))
	start = root.Position
	seconds = run(0.6, { "BigBall" })
	table.insert(rows, { name = "big_ball_side", outwardTravel = (root.Position - start).X, seconds = seconds })
	publish("running")
	clear()
	model = fixture("Tile")
	local tile = model.PrimaryPart
	tile:SetAttribute("FallingTile", true)
	tile:SetAttribute("DropDelaySeconds", 0.65)
	tile:SetAttribute("RespawnSeconds", 1)
	stand(tile)
	local drop, restore = nil, nil
	seconds = run(2.2, { "Tile" }, function(t)
		if not tile.CanCollide and not drop then
			drop = t
		end
		if drop and tile.CanCollide and not restore then
			restore = t
		end
	end)
	table.insert(
		rows,
		{ name = "falling_tile", dropAt = drop, restoreAt = restore, fell = root.Position.Y < tile.Position.Y }
	)
	publish("running")
	for _, mode in { "slide", "spin" } do
		clear()
		model = fixture("Tile")
		tile = model.PrimaryPart
		tile:SetAttribute("Rotor", mode)
		tile:SetAttribute("RotorAxis", if mode == "slide" then "Y" else "Y")
		tile:SetAttribute("RotorAmplitude", 2)
		tile:SetAttribute("RotorPeriod", 4)
		tile:SetAttribute("RotorSpeed", 35)
		tile:SetAttribute("RotorCarries", true)
		compile()
		R.applyAt(currentPlatform, workspace:GetServerTimeNow())
		stand(tile, Vector3.new(2, 0, 0))
		run(0.5, { "Carry" })
		local relative = tile.CFrame:PointToObjectSpace(root.Position)
		local drift = 0
		local supportFrames, totalFrames = 0, 0
		seconds = run(2, { "Carry" }, function()
			drift = math.max(drift, (tile.CFrame:PointToObjectSpace(root.Position) - relative).Magnitude)
			totalFrames += 1
			if humanoid.FloorMaterial ~= Enum.Material.Air then
				supportFrames += 1
			end
		end)
		table.insert(rows, {
			name = "carry_" .. mode,
			seconds = seconds,
			maxLocalDrift = drift,
			supportedFrames = supportFrames,
			totalFrames = totalFrames,
		})
		publish("running")
	end
	clear()
	model = fixture("Seesaw")
	local board = asset(model, "obstacle_25_002")
	board:SetAttribute("Seesaw", true)
	board:SetAttribute("SeesawAxis", "X")
	board:SetAttribute("MaxTiltDegrees", 24)
	compile()
	stand(board, Vector3.new(0, 0, 8))
	local maxTilt = 0
	seconds = run(2, { "Seesaw", "Carry" }, function()
		maxTilt = math.max(maxTilt, math.deg(math.acos(math.clamp(board.CFrame.UpVector.Y, -1, 1))))
	end)
	local supported = humanoid.FloorMaterial ~= Enum.Material.Air
	reset(center + Vector3.new(80, 60, 0))
	root.Anchored = true
	run(2, { "Seesaw", "Carry" })
	table.insert(rows, {
		name = "seesaw",
		maxTiltDegrees = maxTilt,
		supportedAtEnd = supported,
		emptyTiltDegrees = math.deg(math.acos(math.clamp(board.CFrame.UpVector.Y, -1, 1))),
	})
	publish("running")
end, debug.traceback)
for _, kit in kits do
	if kit.forget then
		kit.forget(nil)
	end
end
if currentPlatform then
	local i = table.find(R.all(), currentPlatform)
	if i then
		table.remove(R.all(), i)
	end
end
owned:Destroy()
if not ok then
	table.insert(rows, { error = err })
end
publish(if ok then "complete" else "failed")
