-- Temporary real-Player contact probe for legacy kits' Player-filtered overlap queries.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
local RS = game.ReplicatedStorage
local K = game.ServerScriptService.Server.Modules.MapFeatures
local Bumper = require(K.Bumpers)
local Shove = require(K.RotorBump)
local Foam = require(K.FoamPits)
local R = require(RS.Shared.Game.MapFeatures.RotatingPlatforms)
local Guard = require(RS.Shared.Game.Adapters.MovementGuard)
local Network = require(RS.Shared.Network)
local MovementSpeed = require(RS.Shared.Game.Adapters.MovementSpeedService)
local player = game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
task.wait(3)
local result = Instance.new("StringValue")
result.Name = "SplashdownContactResults"
result.Parent = game.ServerStorage
local home = root.CFrame
local alive = character:GetAttribute("CombatAlive")
local folder = Instance.new("Folder")
folder.Name = "SplashdownContactProbe"
folder.Parent = workspace
local group = Instance.new("Folder")
group.Parent = folder
local origin = Instance.new("Part")
origin.Name = "Origin"
origin.CFrame = CFrame.new(workspace.Assets.Arena.MapOrigin.Position + Vector3.new(0, 100, 0))
origin.Anchored = true
origin.CanCollide = false
origin.Transparency = 1
origin:SetAttribute("RotationSpeed", 0)
origin.Parent = group
local assembly = Instance.new("Model")
assembly.Name = "Assembly"
assembly.Parent = group
local rows = {}
local platform
local ok, err = xpcall(function()
	character:SetAttribute("CombatAlive", true)
	root.Anchored = false
	root:SetNetworkOwner(nil)
	local context = { instances = { group }, now = os.clock(), deltaTime = 1 / 60 }
	local function place(position)
		root.CFrame = CFrame.new(position)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		Guard.reset(root)
		Guard.allow(root, "Probe", 10, 150, 150)
	end
	local model = RS.SplashdownKitFixtures.Bumper:Clone()
	model:PivotTo(origin.CFrame)
	model.Parent = assembly
	local part = model.PrimaryPart
	part:SetAttribute("Bumper", true)
	part:SetAttribute("ShoveSpeed", 54)
	part:SetAttribute("ShoveSeconds", 0.26)
	part:SetAttribute("ShoveContact", "mesh")
	place(part.Position + part.CFrame.LookVector * (part.Size.Z / 2))
	Bumper.tickWorld(context)
	Bumper.tickPlayer(context, player, root)
	table.insert(rows, {
		name = "renamed_bumper",
		horizontal = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude,
		hold = root:FindFirstChild("BumperShoveAttachment") ~= nil,
	})
	Bumper.forget(player)
	model:Destroy()
	for _, spec in
		{
			{ "Spinner", "obstacle_6_001", "spin", "Y" },
			{ "Disc", "obstacle_14_002", "spin", "Y" },
			{ "SwingPanel", "obstacle_8_002", "rock", "X" },
			{ "Roller", "obstacle_2_002", "spin", "X" },
			{ "Hammer", "obstacle_4_002", "rock", "Z" },
			{ "Piston", "obstacle_22_003", "slide", "Z" },
			{ "Mace", "obstacle_5_001", "rock", "Z" },
		}
	do
		model = RS.SplashdownKitFixtures[spec[1]]:Clone()
		model:PivotTo(origin.CFrame)
		model.Parent = assembly
		part = nil
		for _, p in model:GetDescendants() do
			if p:GetAttribute("SourceAsset") == spec[2] then
				part = p
			end
		end
		assert(part, "missing member " .. spec[2])
		part:SetAttribute("Rotor", spec[3])
		part:SetAttribute("RotorAxis", spec[4])
		part:SetAttribute("RotorSpeed", 180)
		part:SetAttribute("RotorAmplitude", 45)
		part:SetAttribute("RotorPeriod", 3)
		part:SetAttribute("Shove", true)
		part:SetAttribute("ShoveSpeed", 48)
		part:SetAttribute("ShoveSeconds", 0.24)
		part:SetAttribute("ShoveContact", "mesh")
		part:SetAttribute("ImpactVisual", true)
		if spec[1] == "Hammer" then
			part:SetAttribute("RotorProfile", "hammer")
		end
		if spec[1] == "Piston" then
			part:SetAttribute("RotorProfile", "piston")
			part:SetAttribute("PistonExtendStuds", 6)
		end
		platform = R.build(origin, assembly)
		table.insert(R.all(), platform)
		R.applyAt(platform, workspace:GetServerTimeNow())
		-- Sample the actual mesh surface: several assets have hollow collision centers.
		local collider = part
		if spec[1] == "Mace" then
			for _, p in part:GetDescendants() do
				if p:GetAttribute("SourceAsset") == "obstacle_5_011" then
					collider = p
				end
			end
		end
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Include
		ray.FilterDescendantsInstances = { collider }
		local hit
		for _, direction in
			{ Vector3.xAxis, Vector3.yAxis, Vector3.zAxis, -Vector3.xAxis, -Vector3.yAxis, -Vector3.zAxis }
		do
			local distance = collider.Size.Magnitude + 5
			hit = workspace:Raycast(collider.Position + direction * distance, -direction * distance * 2, ray)
			if hit then
				break
			end
		end
		assert(hit, "no collision surface for " .. spec[1])
		place(hit.Position)
		context.now = os.clock()
		Shove.tickWorld(context)
		Shove.tickPlayer(context, player, root)
		table.insert(rows, {
			name = "renamed_" .. spec[1],
			horizontal = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude,
			hold = root:FindFirstChild("RotorShoveAttachment") ~= nil,
		})
		Shove.forget(player)
		table.remove(R.all(), assert(table.find(R.all(), platform)))
		platform = nil
		model:Destroy()
	end
	local pit = Instance.new("Part")
	pit.Name = "RenamedFoamVolume"
	pit.Size = Vector3.new(30, 10, 30)
	pit.Anchored = true
	pit.CanCollide = false
	pit.Position = origin.Position
	pit:SetAttribute("FoamPit", true)
	pit.Parent = folder
	place(pit.Position)
	context.instances = { pit }
	Foam.tickPlayer(context, player, root)
	MovementSpeed.step({ players = {} }, { [tostring(player.UserId)] = character }, {})
	local scale = character:GetAttribute("mvEx")
	Foam.forget(player)
	MovementSpeed.step({ players = {} }, { [tostring(player.UserId)] = character }, {})
	table.insert(rows, { name = "renamed_foam", scale = scale, cleared = character:GetAttribute("mvEx") == nil })
end, debug.traceback)
Bumper.forget(player)
Shove.forget(player)
Foam.forget(player)
if platform then
	local i = table.find(R.all(), platform)
	if i then
		table.remove(R.all(), i)
	end
end
root.CFrame = home
root.AssemblyLinearVelocity = Vector3.zero
root:SetNetworkOwnershipAuto()
character:SetAttribute("CombatAlive", alive)
Guard.reset(root)
folder:Destroy()
if not ok then
	table.insert(rows, { error = err })
end
result.Value = game.HttpService:JSONEncode({ ok = ok, trials = rows })
