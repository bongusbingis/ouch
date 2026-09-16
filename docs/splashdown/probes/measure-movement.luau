-- Studio Server execute_luau probe. Physics calibration, deliberately separate
-- from deterministic unit tests. Teleports only between trials, never in a run.
-- Optional prefix: local PROBE = {outputName="...", skipSpeed=true,
-- gaps={22.25,22.5,22.75}, heights={11,11.5,12,12.5,13,14}, triggers={-11,-11,-11}}
local options = PROBE or {}
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
assert(not workspace:FindFirstChild("SplashdownMovementProbe"), "A movement probe already exists")
local output = Instance.new("StringValue")
output.Name = options.outputName or "SplashdownMovementResults"
output.Parent = SS
local rigSource = assert(game.Players:GetPlayers()[1].Character, "A spawned player is required")
local oldArchivable = rigSource.Archivable
rigSource.Archivable = true
local rig = rigSource:Clone()
rigSource.Archivable = oldArchivable
rig.Name = "MeasuredRunner"
for _, item in rig:GetDescendants() do
	if item:IsA("LuaSourceContainer") then
		item:Destroy()
	end
end
local folder = Instance.new("Folder")
folder.Name = "SplashdownMovementProbe"
folder.Parent = workspace
rig.Parent = folder
local root = assert(rig:FindFirstChild("HumanoidRootPart"))
local humanoid = assert(rig:FindFirstChildOfClass("Humanoid"))
local jumpCount = 0
humanoid.StateChanged:Connect(function(_, state)
	if state == Enum.HumanoidStateType.Jumping then
		jumpCount += 1
	end
end)
root.Anchored = false
root:SetNetworkOwner(nil)
local y = 2000
local rows = {}
local settings = {
	walkSpeed = humanoid.WalkSpeed,
	jumpHeight = humanoid.JumpHeight,
	jumpPower = humanoid.JumpPower,
	useJumpPower = humanoid.UseJumpPower,
	gravity = workspace.Gravity,
	hipHeight = humanoid.HipHeight,
	rootSize = { root.Size.X, root.Size.Y, root.Size.Z },
	maxSlope = humanoid.MaxSlopeAngle,
	rig = tostring(humanoid.RigType),
	owner = "server",
	footOffset = 0,
	jumpRequestSeconds = 0.1,
}
local function publish(status)
	output.Value = HttpService:JSONEncode({ status = status, settings = settings, trials = rows })
end
local platforms = Instance.new("Folder")
platforms.Name = "TrialSurfaces"
platforms.Parent = folder
local function part(name, size, cf, velocity)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = platforms
	p.AssemblyLinearVelocity = velocity or Vector3.zero
	return p
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
	task.wait(0.4)
end
local function clear()
	humanoid:Move(Vector3.zero)
	platforms:ClearAllChildren()
end
local function runSpeed(angle, belt)
	clear()
	local a = math.rad(angle)
	local p = part("SpeedSurface", Vector3.new(180, 2, 80), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, a), belt)
	local start = p.CFrame:PointToWorldSpace(Vector3.new(-50, 1, 0))
	reset(start + Vector3.yAxis * (humanoid.HipHeight + root.Size.Y / 2 + 0.2))
	local t, first, measured = 0, nil, 0
	local initial, last = root.Position, root.Position
	local distance = 0
	local maxDt = 0
	while t < 2 do
		humanoid:Move(Vector3.xAxis, false)
		local dt = RunService.Heartbeat:Wait()
		t += dt
		maxDt = math.max(maxDt, dt)
		if t >= 0.45 then
			if not first then
				first = root.Position
			else
				measured += dt
				distance += (root.Position - last).Magnitude
			end
		end
		last = root.Position
	end
	local delta = root.Position - first
	table.insert(rows, {
		kind = "speed",
		angle = angle,
		belt = { belt.X, belt.Y, belt.Z },
		seconds = measured,
		speed3D = distance / measured,
		speedX = delta.X / measured,
		speedZ = delta.Z / measured,
		speedY = delta.Y / measured,
		maxFrameSeconds = maxDt,
		grounded = humanoid.FloorMaterial ~= Enum.Material.Air,
		distance = (root.Position - initial).Magnitude,
	})
	publish("running")
end
local function jump(gap, height, trigger, repeatIndex)
	clear()
	part("Takeoff", Vector3.new(70, 2, 30), CFrame.new(-35, y - 1, 0))
	part("Landing", Vector3.new(90, 2, 30), CFrame.new(gap + 45, y + height - 1, 0))
	reset(Vector3.new(-30, y + humanoid.HipHeight + root.Size.Y / 2 + 0.2, 0))
	local initialY = root.Position.Y
	jumpCount = 0
	settings.footOffset = initialY - y
	local t, jumped, left, landed, peak = 0, false, nil, nil, initialY
	local requestedAt = 0
	local takeoffX, contactX, contactY = nil, nil, nil
	local passed = false
	local maxDt = 0
	while t < 3.5 do
		humanoid:Move(Vector3.xAxis, false)
		if not jumped and root.Position.X >= trigger then
			humanoid.Jump = true
			jumped = true
			requestedAt = t
		end
		local dt = RunService.Heartbeat:Wait()
		-- One Heartbeat can be shorter than a Humanoid update. Hold long enough
		-- to consume the request, but end before even the shortest landing.
		if jumped and t - requestedAt >= 0.1 then
			humanoid.Jump = false
		end
		t += dt
		maxDt = math.max(maxDt, dt)
		peak = math.max(peak, root.Position.Y)
		if jumped and not left and humanoid.FloorMaterial == Enum.Material.Air then
			left = t
			takeoffX = root.Position.X
		end
		if left and not landed and t - left > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air then
			landed = t
			contactX = root.Position.X
			contactY = root.Position.Y
		end
		if landed and root.Position.X >= gap + 8 and root.Position.Y >= y + height + settings.footOffset - 0.8 then
			passed = true
			break
		end
		if root.Position.Y < y - 20 then
			break
		end
	end
	table.insert(rows, {
		kind = if height == 0 then "gap" else "step",
		gap = gap,
		height = height,
		trigger = trigger,
		repeatIndex = repeatIndex,
		passed = passed,
		seconds = t,
		jumpCount = jumpCount,
		takeoffX = takeoffX,
		landingX = contactX,
		landingY = contactY and contactY - y,
		airtime = if left and landed then landed - left else nil,
		apex = peak - initialY,
		endX = root.Position.X,
		endY = root.Position.Y - y,
		maxFrameSeconds = maxDt,
	})
	publish("running")
end
publish("starting")
task.spawn(function()
	local ok, err = xpcall(function()
		if not options.skipSpeed then
			for _, angle in { 0, 15, 30, 45, -15, -30, -45 } do
				runSpeed(angle, Vector3.zero)
			end
			for _, speed in { -13, -15.6, -18.2, 15.6 } do
				runSpeed(0, Vector3.xAxis * speed)
			end
			runSpeed(0, Vector3.zAxis * 15.6)
		end
		for _, gap in options.gaps or { 16, 18, 20, 21, 22, 23, 24 } do
			for repeatIndex = 1, 3 do
				jump(gap, 0, -0.65, repeatIndex)
			end
		end
		for _, height in options.heights or { 8, 9, 9.5, 10, 10.5, 11 } do
			for repeatIndex, trigger in options.triggers or { -5, -9, -13 } do
				jump(0, height, trigger, repeatIndex)
			end
		end
	end, debug.traceback)
	humanoid:Move(Vector3.zero)
	publish(if ok then "complete" else "error: " .. tostring(err))
	folder:Destroy()
end)
return "Movement probe started; read ServerStorage." .. output.Name
