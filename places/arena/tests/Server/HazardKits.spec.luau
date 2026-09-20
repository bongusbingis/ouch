-- Deterministic engine smoke tests, deliberately separate from physics playtests.
--!nonstrict
local Modules = game.ServerScriptService.Server.Modules
local Kits = Modules.MapFeatures
local Conveyor = require(Kits.Conveyors)
local Balls = require(Kits.BigBalls)
local Tiles = require(Kits.FallingTiles)
local Seesaws = require(Kits.Seesaws)
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
			for _, kit in { Conveyor, Balls, Tiles, Seesaws, Fans, Beaches, JumpPads } do
				kit.forget(nil)
			end
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
			context.now += 0.49
			Tiles.tickWorld(context)
			expect(tile.CanCollide).to.equal(true)
			context.now += 0.02
			Tiles.tickWorld(context)
			expect(tile.CanCollide).to.equal(false)
			context.now += 2
			Tiles.tickWorld(context)
			expect(tile.CanCollide).to.equal(true)
			expect(tile.Transparency).to.equal(0)
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
		it("tilts under an offset rider, clamps and returns to level", function()
			local board = part(
				"Board",
				Vector3.new(20, 1, 8),
				Vector3.new(0, 1500, 0),
				group,
				{ Seesaw = true, MaxTiltDegrees = 20 }
			)
			root.Position = Vector3.new(6, 1503.5, 0)
			Seesaws.tickWorld(context)
			Seesaws.tickPlayer(context, player, root)
			Seesaws.tickWorld(context)
			expect(board.CFrame.RightVector.Y < 0).to.equal(true)
			expect(math.abs(board.CFrame.RightVector.Y) < math.sin(math.rad(20))).to.equal(true)
			local first = math.abs(board.CFrame.RightVector.Y)
			for _ = 1, 100 do
				Seesaws.tickWorld(context)
			end
			expect(math.abs(board.CFrame.RightVector.Y) < first / 10).to.equal(true)
			Seesaws.forget(nil)
			expect(board.CFrame.RightVector.Y).to.equal(0)
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
		it("launches a renamed directional fan without stacking speed", function()
			part(
				"Fan",
				Vector3.new(20, 2, 20),
				Vector3.new(0, 1500, 0),
				group,
				{ Fan = true, FanAxis = "Y", LaunchSpeed = 47, FloatFactor = 0 }
			)
			Fans.tickWorld(context)
			Fans.tickPlayer(context, player, root)
			expect(root.AssemblyLinearVelocity.Y).to.equal(47)
			Fans.tickPlayer(context, player, root)
			expect(root.AssemblyLinearVelocity.Y).to.equal(47)
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
			local origin = part("Origin", Vector3.one, Vector3.zero, group, { RotationSpeed = 0 })
			part(
				"Ride",
				Vector3.one,
				Vector3.zero,
				group,
				{ Rotor = "spin", RotorAxis = "Y", RotorSpeed = 30, RotorCarries = true }
			)
			expect(#Audit.check(group) > 0).to.equal(true)
			origin:SetAttribute("ServerCarries", true)
			expect(#Audit.check(group)).to.equal(0)
		end)
	end)
end
