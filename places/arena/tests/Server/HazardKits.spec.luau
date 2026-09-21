-- Deterministic engine smoke tests, deliberately separate from physics playtests.
--!nonstrict
local Modules = game.ServerScriptService.Server.Modules
local Kits = Modules.MapFeatures
local Parts = require(Kits.FeatureParts)
local Conveyor = require(Kits.Conveyors)
local Balls = require(Kits.BigBalls)
local Tiles = require(Kits.FallingTiles)
local BreakDoors = require(Kits.Doors)
local Seesaws = require(Kits.Seesaws)
local ServerRiders = require(Kits.ServerRiders)
local Rotating = require(game.ReplicatedStorage.Shared.Game.MapFeatures.RotatingPlatforms)
local Beaches = require(Kits.BeachBalls)
local Fans = require(Kits.FanUpdraft)
local Doors = require(Modules.Splashdown.DoorRows)
local DoorPlan = require(game.ReplicatedStorage.Shared.Game.Splashdown.DoorPlan)
local Attributes = require(game.ReplicatedStorage.Config.Gameplay.MapFeatures).Attributes
local Rules = require(game.ReplicatedStorage.Shared.Game.MapFeatures.AttributeRules)
local JumpPads = require(Kits.JumpPads)
local Audit = require(game.ReplicatedStorage.Shared.Game.MapFeatures.AttributeAudit)
return function()
	describe("Attribute hazard kits", function()
		local folder, group, group, context, character, root, humanoid, player
		local function part(name, size, position, parent, attributes)
			local p = Instance.new("Part")
			p.Name = name
			p.Size = size
			p.Position = position
			p.Anchored = true
			p.Parent = parent
			for key, value in attributes or {} do
				p:SetAttribute(key, value)
			end
			return p
		end
		beforeEach(function()
			folder = Instance.new("Folder")
			folder.Name = "Scriptables"
			folder.Parent = workspace
			local rotating = Instance.new("Folder")
			rotating.Name = "Rotating"
			rotating.Parent = folder
			group = Instance.new("Folder")
			group.Name = "TestGroup"
			group.Parent = rotating
			context = { instances = { group }, now = os.clock(), deltaTime = 1 / 60 }
			character = Instance.new("Model")
			character.Parent = folder
			humanoid = Instance.new("Humanoid")
			humanoid.RequiresNeck = false
			humanoid.HipHeight = 2
			humanoid.Parent = character
			root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 1503.5, 0), character)
			root.Anchored = false
			character.PrimaryPart = root
			player = {} -- opaque per-runner identity; tests must not manufacture Players
		end)
		afterEach(function()
			for _, kit in { Conveyor, Balls, Tiles, Seesaws, ServerRiders, Fans, Beaches, JumpPads } do
				kit.forget(nil)
			end
			BreakDoors.reset()
			folder:Destroy()
		end)
		it("sets signed conveyor velocity and restores it on unload", function()
			local belt = part(
				"RenamedBelt",
				Vector3.new(20, 1, 20),
				Vector3.new(0, 1500, 0),
				group,
				{ Conveyor = true, ConveyorAxis = "X", ConveyorSpeed = -15.6 }
			)
			Conveyor.tickWorld(context)
			expect((belt.AssemblyLinearVelocity - Vector3.new(-15.6, 0, 0)).Magnitude < 1e-4).to.equal(true)
			Conveyor.forget(nil)
			expect(belt.AssemblyLinearVelocity.Magnitude).to.equal(0)
		end)
		it("rejects a malformed conveyor override mutated after activation", function()
			local belt = part(
				"LiveBelt",
				Vector3.new(20, 1, 20),
				Vector3.new(0, 1500, 0),
				group,
				{ Conveyor = true, ConveyorAxis = "X", ConveyorSpeed = 15 }
			)
			Conveyor.tickWorld(context)
			belt:SetAttribute("ConveyorSpeed", "fast")
			local ok, message = pcall(Conveyor.tickWorld, context)
			expect(ok).to.equal(false)
			expect(string.find(message, belt:GetFullName() .. ".ConveyorSpeed", 1, true) ~= nil).to.equal(true)
		end)
		it("keeps optional defaults and accepts exact feature limits", function()
			local feature = part("Bounds", Vector3.one, Vector3.zero, group)
			expect(Parts.number(feature, "LaunchSpeed", 51)).to.equal(51)
			expect(Parts.axis(feature, "FanAxis", "Y")).to.equal(Vector3.yAxis)
			feature:SetAttribute("LaunchSpeed", 1)
			expect(Parts.number(feature, "LaunchSpeed", 51)).to.equal(1)
			feature:SetAttribute("LaunchSpeed", 160)
			expect(Parts.number(feature, "LaunchSpeed", 51)).to.equal(160)
			feature:SetAttribute("FanAxis", "Z")
			expect(Parts.axis(feature, "FanAxis", "Y")).to.equal(Vector3.zAxis)
		end)
		it("rejects malformed live feature overrides with exact paths and ranges", function()
			local feature = part("BrokenOverride", Vector3.one, Vector3.zero, group)
			feature:SetAttribute("LaunchSpeed", "51")
			local ok, message = pcall(Parts.number, feature, "LaunchSpeed", 51)
			expect(ok).to.equal(false)
			expect(string.find(message, feature:GetFullName() .. ".LaunchSpeed", 1, true) ~= nil).to.equal(true)
			expect(string.find(message, "1..160", 1, true) ~= nil).to.equal(true)
			feature:SetAttribute("LaunchSpeed", 161)
			expect(pcall(Parts.number, feature, "LaunchSpeed", 51)).to.equal(false)
			feature:SetAttribute("SeesawAxis", "Y")
			ok, message = pcall(Parts.axis, feature, "SeesawAxis", "Z")
			expect(ok).to.equal(false)
			expect(string.find(message, feature:GetFullName() .. ".SeesawAxis", 1, true) ~= nil).to.equal(true)
			expect(string.find(message, "X or Z", 1, true) ~= nil).to.equal(true)
		end)
		it("bounces a top-cap landing once and cleans its float", function()
			local ball = part(
				"RenamedSphere",
				Vector3.one * 10,
				Vector3.new(0, 1495, 0),
				group,
				{ BigBall = true, BounceSpeed = 57 }
			)
			root.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
			Balls.tickWorld(context)
			Balls.tickPlayer(context, player, root)
			expect(root.AssemblyLinearVelocity.Y).to.equal(57)
			root.AssemblyLinearVelocity = Vector3.zero
			Balls.tickPlayer(context, player, root)
			expect(root.AssemblyLinearVelocity.Y).to.equal(0)
			Balls.forget(player)
			expect(root:FindFirstChild("BigBallFloatAttachment")).to.equal(nil)
		end)
		it("rolls a side contact outward and never hits sphere-box corners", function()
			part("Sphere", Vector3.one * 10, Vector3.new(0, 1500, 0), group, { BigBall = true, RollOffSpeed = 39 })
			root.Position = Vector3.new(5.5, 1500, 0)
			Balls.tickWorld(context)
			Balls.tickPlayer(context, player, root)
			expect(root.AssemblyLinearVelocity.X).to.equal(39)
			Balls.forget(player)
			root.Position = Vector3.new(5.5, 1500, 5.5)
			root.AssemblyLinearVelocity = Vector3.zero
			Balls.tickPlayer(context, player, root)
			expect(root.AssemblyLinearVelocity.Magnitude).to.equal(0)
		end)
		it("measures the cap at the feet contact, not the elevated root center", function()
			part("Sphere", Vector3.one * 10, Vector3.new(0, 1500, 0), group, { BigBall = true, CapDegrees = 40 })
			root.Position = Vector3.new(5 * math.sin(math.rad(50)), 1500 + 5 * math.cos(math.rad(50)) + 3, 0)
			root.AssemblyLinearVelocity = -Vector3.yAxis * 10
			Balls.tickWorld(context)
			Balls.tickPlayer(context, player, root)
			expect(root.AssemblyLinearVelocity.X > 30).to.equal(true)
			expect(root.AssemblyLinearVelocity.Y < 58).to.equal(true)
		end)
		it("shares a tile countdown and restores authored collision", function()
			local tile = part(
				"Tile",
				Vector3.new(10, 1, 10),
				Vector3.new(0, 1500, 0),
				group,
				{ FallingTile = true, DropDelaySeconds = 0.5, RespawnSeconds = 2 }
			)
			Tiles.tickWorld(context)
			Tiles.tickPlayer(context, player, root)
			expect(tile:GetAttribute("HazardTileState")).to.equal("armed")
			expect(tile:GetAttribute("HazardTileDropAt") > workspace:GetServerTimeNow()).to.equal(true)
			context.now += 0.49
			Tiles.tickWorld(context)
			expect(tile.CanCollide).to.equal(true)
			context.now += 0.02
			Tiles.tickWorld(context)
			expect(tile.CanCollide).to.equal(false)
			expect(tile:GetAttribute("HazardTileState")).to.equal("hidden")
			context.now += 2
			Tiles.tickWorld(context)
			expect(tile.CanCollide).to.equal(true)
			expect(tile.Transparency).to.equal(0)
			expect(tile:GetAttribute("HazardTileState")).to.equal("solid")
		end)
		it("supports never-respawn tiles but reset always restores them", function()
			local tile = part(
				"Tile",
				Vector3.new(10, 1, 10),
				Vector3.new(0, 1500, 0),
				group,
				{ FallingTile = true, DropDelaySeconds = 0.1, RespawnSeconds = 0 }
			)
			Tiles.tickWorld(context)
			Tiles.tickPlayer(context, player, root)
			context.now += 1
			Tiles.tickWorld(context)
			context.now += 1000
			Tiles.tickWorld(context)
			expect(tile.CanCollide).to.equal(false)
			Tiles.forget(nil)
			expect(tile.CanCollide).to.equal(true)
		end)
		it("forgets a streamed-out armed tile without publishing to a removed part", function()
			local tile = part(
				"TemporaryTile",
				Vector3.new(10, 1, 10),
				Vector3.new(0, 1500, 0),
				group,
				{ FallingTile = true, DropDelaySeconds = 0.5 }
			)
			Tiles.tickWorld(context)
			Tiles.tickPlayer(context, player, root)
			expect(tile:GetAttribute("HazardTileState")).to.equal("armed")
			tile:Destroy()
			expect(pcall(Tiles.tickWorld, context)).to.equal(true)
		end)
		it("replicates only public broken-door state and restores it", function()
			local chosen = part("Chosen", Vector3.new(6, 8, 1), Vector3.new(0, 1500, 0), group)
			local decoy = part("Decoy", Vector3.new(6, 8, 1), Vector3.new(10, 1500, 0), group)
			context.instances = { chosen, decoy }
			root.Position = chosen.Position
			BreakDoors.setPlan({ [chosen] = true, [decoy] = false })
			expect(chosen:GetAttribute("HazardDoorState")).to.equal(nil)
			expect(decoy:GetAttribute("HazardDoorState")).to.equal(nil)
			BreakDoors.tickPlayer(context, player, root)
			expect(chosen.CanCollide).to.equal(false)
			expect(chosen:GetAttribute("HazardDoorState")).to.equal("broken")
			expect(decoy:GetAttribute("HazardDoorState")).to.equal(nil)
			BreakDoors.reset()
			expect(chosen.CanCollide).to.equal(true)
			expect(chosen:GetAttribute("HazardDoorState")).to.equal("solid")
		end)
		it("builds one native 85-degree hinge and restores the authored board", function()
			local pedestal = part("Pedestal", Vector3.new(3, 5, 3), Vector3.new(0, 1497, 0), group)
			local board = part(
				"Board",
				Vector3.new(20, 1, 8),
				Vector3.new(0, 1500, 0),
				pedestal,
				{ Seesaw = true, SeesawAxis = "X", MaxTiltDegrees = 20 }
			)
			local rest = board.CFrame
			Seesaws.tickWorld(context)
			local hinge = pedestal:FindFirstChild("SeesawHinge")
			expect(hinge:IsA("HingeConstraint")).to.equal(true)
			expect(hinge.LowerAngle).to.equal(-85)
			expect(hinge.UpperAngle).to.equal(85)
			expect(board:GetAttribute("MaxTiltDegrees")).to.equal(85)
			expect(hinge.LimitsEnabled).to.equal(true)
			expect(hinge.TargetAngle).to.equal(0)
			expect(board.Anchored).to.equal(false)
			expect(pedestal.Anchored).to.equal(true)
			expect(board:GetNetworkOwner()).to.equal(nil)
			expect(pedestal:FindFirstChild("SeesawPedestalNoCollision") ~= nil).to.equal(true)
			local force = board:FindFirstChild("SeesawGravityCompensation")
			expect(force:IsA("VectorForce")).to.equal(true)
			expect(force.ApplyAtCenterOfMass).to.equal(true)
			expect(math.abs(force.Force.Y - board:GetMass() * workspace.Gravity) < 0.01).to.equal(true)
			Seesaws.tickWorld(context)
			expect(pedestal:FindFirstChild("SeesawHinge")).to.equal(hinge)
			Seesaws.forget(nil)
			expect(pedestal:FindFirstChild("SeesawHinge")).to.equal(nil)
			expect(board:FindFirstChild("SeesawGravityCompensation")).to.equal(nil)
			expect(board.Anchored).to.equal(true)
			expect(board.CFrame).to.equal(rest)
			expect(board.CustomPhysicalProperties).to.equal(nil)
			expect(board:GetAttribute("MaxTiltDegrees")).to.equal(20)
		end)
		it("never applies server kinematic carry on a native seesaw", function()
			local pedestal = part("Pedestal", Vector3.new(3, 5, 3), Vector3.new(0, 1497, 0), group)
			local board = part("Board", Vector3.new(20, 1, 8), Vector3.new(0, 1500, 0), pedestal, {
				Seesaw = true,
				SeesawAxis = "X",
			})
			Seesaws.tickWorld(context)
			local platforms = Rotating.all()
			table.insert(platforms, { assembly = pedestal, serverCarries = true, localRotors = {} })
			ServerRiders.tickPlayer(context, player, root)
			board.CFrame += Vector3.xAxis * 5
			local before = root.CFrame
			ServerRiders.tickPlayer(context, player, root)
			table.remove(platforms)
			ServerRiders.forget(player)
			expect(root.CFrame).to.equal(before)
		end)
		it("finds multiple renamed beach balls and restores their parent", function()
			local a = part("BeachA", Vector3.one * 4, Vector3.new(0, 1500, 0), group, { BeachBall = true })
			local b = part("BeachB", Vector3.one * 4, Vector3.new(6, 1500, 0), group, { BeachBall = true })
			Beaches.tickWorld(context)
			expect(#Beaches.active()).to.equal(2)
			expect(a.Anchored).to.equal(false)
			expect(b:GetNetworkOwner()).to.equal(nil)
			Beaches.forget(nil)
			expect(a.Parent).to.equal(group)
			expect(a.Anchored).to.equal(true)
		end)
		it("lifts inside a renamed directional fan without an entry velocity spike", function()
			part(
				"Fan",
				Vector3.new(20, 2, 20),
				Vector3.new(0, 1500, 0),
				group,
				{ Fan = true, FanAxis = "Y", LaunchSpeed = 47, FloatFactor = 0 }
			)
			root.AssemblyLinearVelocity = Vector3.new(3, -4, 0)
			local before = root.AssemblyLinearVelocity
			Fans.tickWorld(context)
			Fans.tickPlayer(context, player, root)
			expect(root.AssemblyLinearVelocity).to.equal(before)
			local force = root:FindFirstChild("FanFloatForce")
			expect(force ~= nil).to.equal(true)
			expect(force.Force.Y / root.AssemblyMass > workspace.Gravity).to.equal(true)
			Fans.tickPlayer(context, player, root)
			expect(root:FindFirstChild("FanFloatForce")).to.equal(force)
			root.Position = Vector3.new(30, 1503.5, 0)
			Fans.tickPlayer(context, player, root)
			expect(root:FindFirstChild("FanFloatForce")).to.equal(nil)
		end)
		it("honours per-pad launch and float overrides on a renamed pad", function()
			local pad = Instance.new("Model")
			pad.Name = "RenamedCoursePad"
			pad:SetAttribute("JumpPad", true)
			pad:SetAttribute("LaunchSpeed", 51)
			pad:SetAttribute("FloatFactor", 0.2)
			pad.Parent = folder
			part("Contact", Vector3.new(12, 1, 12), Vector3.new(0, 1500, 0), pad)
			context.instances = { pad }
			root.AssemblyLinearVelocity = -Vector3.yAxis * 10
			JumpPads.tickPlayer(context, player, root)
			expect(root.AssemblyLinearVelocity.Y).to.equal(51)
			local force = root:FindFirstChild("JumpPadFloatForce")
			expect(force ~= nil).to.equal(true)
			expect(math.abs(force.Force.Y / root.AssemblyMass / workspace.Gravity - 0.2) < 1e-5).to.equal(true)
		end)
		it("rejects a malformed ball override before allocating a visit", function()
			local ball = part(
				"MalformedSphere",
				Vector3.one * 10,
				Vector3.new(0, 1495, 0),
				group,
				{ BigBall = true, BounceSpeed = "fast" }
			)
			root.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
			Balls.tickWorld(context)
			local ok, message = pcall(Balls.tickPlayer, context, player, root)
			expect(ok).to.equal(false)
			expect(string.find(message, ball:GetFullName() .. ".BounceSpeed", 1, true) ~= nil).to.equal(true)
			expect(root:FindFirstChild("BigBallFloatAttachment")).to.equal(nil)
			expect(root.AssemblyLinearVelocity.Y).to.equal(-10)
			ball:SetAttribute("BounceSpeed", 57)
			Balls.tickPlayer(context, player, root)
			expect(root.AssemblyLinearVelocity.Y).to.equal(57)
		end)
		it("keeps world-up airflow for a fan with no axis override", function()
			part(
				"Fan",
				Vector3.new(20, 2, 20),
				Vector3.new(0, 1500, 0),
				group,
				{ Fan = true, LaunchSpeed = 47, FloatFactor = 0 }
			)
			Fans.tickWorld(context)
			Fans.tickPlayer(context, player, root)
			local force = root:FindFirstChild("FanFloatForce")
			expect(force ~= nil).to.equal(true)
			expect(force.Force.X).to.equal(0)
			expect(force.Force.Y / root.AssemblyMass > workspace.Gravity).to.equal(true)
		end)
		it("follows a signed local fan axis and yields to a jump pad", function()
			part(
				"Fan",
				Vector3.new(20, 20, 20),
				Vector3.new(0, 1500, 0),
				group,
				{ Fan = true, FanAxis = "X", FanDirection = -1, LaunchSpeed = 47 }
			)
			root.Position = Vector3.new(-12, 1500, 0)
			Fans.tickWorld(context)
			Fans.tickPlayer(context, player, root)
			local force = root:FindFirstChild("FanFloatForce")
			expect(force ~= nil).to.equal(true)
			expect(force.Force.X < 0).to.equal(true)
			expect(force.Force.Y / root.AssemblyMass > 0).to.equal(true)
			local jumpForce = Instance.new("VectorForce")
			jumpForce.Name = "JumpPadFloatForce"
			jumpForce.Parent = root
			Fans.tickPlayer(context, player, root)
			expect(root:FindFirstChild("FanFloatForce")).to.equal(nil)
			jumpForce:Destroy()
			Fans.tickPlayer(context, player, root)
			expect(root:FindFirstChild("FanFloatForce") ~= nil).to.equal(true)
			humanoid.PlatformStand = true
			Fans.tickPlayer(context, player, root)
			expect(root:FindFirstChild("FanFloatForce")).to.equal(nil)
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			Fans.tickPlayer(context, player, root)
			expect(root:FindFirstChild("FanFloatForce") ~= nil).to.equal(true)
		end)
		it("rejects a seesaw axis changed after activation", function()
			local pedestal = part("Pedestal", Vector3.new(3, 5, 3), Vector3.new(0, 1497, 0), group)
			local board = part(
				"ChangedAxis",
				Vector3.new(20, 1, 8),
				Vector3.new(0, 1500, 0),
				pedestal,
				{ Seesaw = true, SeesawAxis = "X" }
			)
			Seesaws.tickWorld(context)
			board:SetAttribute("SeesawAxis", "Y")
			local ok, message = pcall(Seesaws.tickWorld, context)
			expect(ok).to.equal(false)
			expect(string.find(message, board:GetFullName() .. ".SeesawAxis", 1, true) ~= nil).to.equal(true)
			board:SetAttribute("SeesawAxis", "Z")
		end)
		it("rejects malformed jump pad overrides before changing velocity", function()
			local pad = Instance.new("Model")
			pad.Name = "BrokenCoursePad"
			pad:SetAttribute("JumpPad", true)
			pad:SetAttribute("LaunchSpeed", "51")
			pad.Parent = folder
			part("Contact", Vector3.new(12, 1, 12), Vector3.new(0, 1500, 0), pad)
			context.instances = { pad }
			root.AssemblyLinearVelocity = -Vector3.yAxis * 10
			local ok, message = pcall(JumpPads.tickPlayer, context, player, root)
			expect(ok).to.equal(false)
			expect(string.find(message, pad:GetFullName() .. ".LaunchSpeed", 1, true) ~= nil).to.equal(true)
			expect(root.AssemblyLinearVelocity.Y).to.equal(-10)
			pad:SetAttribute("LaunchSpeed", 51)
			pad:SetAttribute("FloatFactor", 1)
			ok, message = pcall(JumpPads.tickPlayer, context, player, root)
			expect(ok).to.equal(false)
			expect(string.find(message, pad:GetFullName() .. ".FloatFactor", 1, true) ~= nil).to.equal(true)
			expect(root.AssemblyLinearVelocity.Y).to.equal(-10)
		end)
		it("supports 3, 4 and 5 doors with every valid breakable quota", function()
			local f = Instance.new("Folder")
			f.Parent = folder
			for n = 3, 5 do
				f:ClearAllChildren()
				local keys = {}
				for i = 1, n do
					part(tostring(i), Vector3.one, Vector3.zero, f, { DoorRow = 1, DoorIndex = i })
					table.insert(keys, tostring(i))
				end
				expect(#Doors.resolve(f)[1]).to.equal(n)
				for count = 1, n do
					local chosen = DoorPlan.choose({ keys }, count, function()
						return 1
					end)
					local actual = 0
					for _ in chosen do
						actual += 1
					end
					expect(actual).to.equal(count)
				end
			end
		end)
		it("rejects duplicate and missing door indices", function()
			local f = Instance.new("Folder")
			f.Parent = folder
			part("A", Vector3.one, Vector3.zero, f, { DoorRow = 1, DoorIndex = 1 })
			local b = part("B", Vector3.one, Vector3.zero, f, { DoorRow = 1, DoorIndex = 1 })
			expect(pcall(Doors.resolve, f)).to.equal(false)
			b:SetAttribute("DoorIndex", 3)
			expect(pcall(Doors.resolve, f)).to.equal(false)
		end)
		it("flags unknown attributes and conflicting motion owners", function()
			expect(
				#Rules.validate({ Rotor = "rock", RotorAxis = "X", RotorProfile = "hammer", Shove = true }, Attributes)
			).to.equal(0)
			local staleErrors, staleWarnings = Rules.validate({ TypoSpeed = 7 }, Attributes)
			expect(#staleErrors).to.equal(0)
			expect(#staleWarnings).to.equal(1)
			part("Stale", Vector3.one, Vector3.zero, group, { TypoSpeed = 7 })
			local auditErrors, auditWarnings = Audit.check(group)
			expect(#auditErrors).to.equal(0)
			expect(#auditWarnings).to.equal(1)
			for _, a in
				{
					{ Rotor = "spin", RotorAxis = "W" },
					{ Rotor = "slide", Seesaw = true },
					{ Rotor = "spin", RotorProfile = "hammer" },
					{ DoorRow = 0, DoorIndex = 1 },
					{ FanDirection = 0 },
					{ Bumper = true, Shove = true, Rotor = "spin" },
					{ Seesaw = true, Conveyor = true },
					{ FallingTile = true, Fan = true },
				}
			do
				expect(#Rules.validate(a, Attributes) > 0).to.equal(true)
			end
		end)
		it("validates clone hierarchy and authoritative ride ownership", function()
			part("Origin", Vector3.one, Vector3.zero, group, { RotationSpeed = 0 })
			local assembly = Instance.new("Model")
			assembly.Name = "Assembly"
			assembly.Parent = group
			part(
				"Ride",
				Vector3.one,
				Vector3.zero,
				assembly,
				{ Rotor = "spin", RotorAxis = "Y", RotorSpeed = 30, RotorCarries = true }
			)
			expect(#Audit.check(group) > 0).to.equal(true)
			assembly:SetAttribute("ServerCarries", true)
			expect(#Audit.check(group)).to.equal(0)
		end)
	end)
end
