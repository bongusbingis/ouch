-- Name: BallService.spec.luau
-- Author: Jack C.
-- Description: In-place spec exercising the ball service against the real authored ball template: held grants, cloning into the world folder, attribute seeding, naming, and clearing.
-- Created: 2026-07-16

--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BallService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("BallService"))
local Combat = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Combat"))
local Helpers = ServerStorage:WaitForChild("Tests"):WaitForChild("Helpers")
local CharacterFixture = require(Helpers:WaitForChild("CharacterFixture"))
local FakePlayer = require(Helpers:WaitForChild("FakePlayer"))
local TestAssets = require(Helpers:WaitForChild("TestAssets"))

local function ballsIn(folder: Instance): { BasePart }
	local balls = {}
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(balls, child)
		end
	end
	return balls
end

return function()
	local simulationIt = if RunService:IsRunning() then it else itSKIP

	describe("BallService", function()
		local rigs = {}

		local function rigFor(player)
			local rig = CharacterFixture.create(player.Name)
			table.insert(rigs, rig)
			player.Character = rig
			return rig
		end

		afterEach(function()
			BallService.stopGroundSpawns()
			BallService.clearRecovery()
			BallService.clearAll()
			for _, rig in rigs do
				CharacterFixture.destroy(rig)
			end
			table.clear(rigs)
		end)

		it("grants a held ball cloned from the authored default template", function()
			local player = FakePlayer.new(100001)
			rigFor(player)

			expect(BallService.grantHeldBall(player)).to.equal(true)

			local folder = TestAssets.get(Workspace, "Balls")
			local balls = ballsIn(folder)
			expect(#balls).to.equal(1)

			local ball = balls[1]
			expect(string.match(ball.Name, "^ball_%d%d%d%d$")).to.be.ok()
			expect(ball:GetAttribute("ph")).to.equal(0)
			expect(ball:GetAttribute("hb")).to.equal("100001")
			expect(ball:GetAttribute("ow")).to.equal("100001")
			expect(ball:GetAttribute("er")).to.be.near(Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness)
			expect(ball:GetAttribute("ft")).to.equal(0)
			expect(ball:GetAttribute("vel")).to.equal(Vector3.zero)
			expect(ball.Anchored).to.equal(true)

			local template = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", "Templates", "DodgeballBase")
			expect(ball.Size).to.equal(template.Size)
		end)

		it("spawns the held ball at the player's root", function()
			local player = FakePlayer.new(100002)
			local rig = rigFor(player)
			rig:PivotTo(CFrame.new(50, 10, -20))

			expect(BallService.grantHeldBall(player)).to.equal(true)

			local ball = ballsIn(TestAssets.get(Workspace, "Balls"))[1]
			local root = rig:FindFirstChild("HumanoidRootPart")
			expect((ball.CFrame.Position - root.Position).Magnitude).to.be.near(0, 1e-3)
		end)

		it("refuses grants for players without characters", function()
			local player = FakePlayer.new(100003)
			expect(BallService.grantHeldBall(player)).to.equal(false)
			expect(#ballsIn(TestAssets.get(Workspace, "Balls"))).to.equal(0)
		end)

		it("assigns unique sequential ball names", function()
			local firstPlayer = FakePlayer.new(100004)
			local secondPlayer = FakePlayer.new(100014)
			rigFor(firstPlayer)
			rigFor(secondPlayer)

			expect(BallService.grantHeldBall(firstPlayer)).to.equal(true)
			expect(BallService.grantHeldBall(secondPlayer)).to.equal(true)

			local names = {}
			local sequences = {}
			for _, ball in ballsIn(TestAssets.get(Workspace, "Balls")) do
				expect(names[ball.Name]).never.to.be.ok()
				names[ball.Name] = true
				table.insert(sequences, tonumber(string.match(ball.Name, "^ball_(%d%d%d%d)$")))
			end
			expect(#sequences).to.equal(2)
			table.sort(sequences)
			expect(sequences[2]).to.equal(sequences[1] + 1)
		end)

		it("clearAll empties the balls folder", function()
			local player = FakePlayer.new(100005)
			rigFor(player)
			BallService.grantHeldBall(player)

			BallService.clearAll()

			expect(#ballsIn(TestAssets.get(Workspace, "Balls"))).to.equal(0)
		end)

		simulationIt("recycles an out-of-bounds ball without replacing its instance", function()
			local player = FakePlayer.new(100006)
			rigFor(player)
			BallService.grantHeldBall(player)

			local folder = TestAssets.get(Workspace, "Balls")
			local ball = ballsIn(folder)[1]
			local originalName = ball.Name
			ball.CFrame = CFrame.new(0, -100, 0)
			ball:SetAttribute("ph", 5)

			local point = Instance.new("Part")
			point.Name = "RecoveryPoint"
			point.Anchored = true
			point.Position = Vector3.new(25, 6, -9)
			point.Parent = Workspace
			BallService.configureRecovery({ point }, -40)
			BallService.start()

			for _ = 1, 30 do
				if ball.CFrame.Position.Y > -40 then
					break
				end
				task.wait()
			end

			expect(ball.Parent).to.equal(folder)
			expect(ball.Name).to.equal(originalName)
			local expected = point.Position + Vector3.new(0, Combat.Dodgeball.Radius, 0)
			expect((ball.CFrame.Position - expected).Magnitude).to.be.near(0, 1e-3)
			expect(ball:GetAttribute("ph")).to.equal(5)
			expect(ball:GetAttribute("hb")).never.to.be.ok()
			expect(ball:GetAttribute("ow")).never.to.be.ok()
			expect(ball:GetAttribute("er")).to.be.near(Combat.Dodgeball.Radius + Combat.Dodgeball.HitForgiveness)
			point:Destroy()
		end)

		simulationIt("cadence ground spawns produce free balls at active points", function()
			local point = Instance.new("Part")
			point.Name = "TestBallSpawn"
			point.Anchored = true
			point.Position = Vector3.new(1000, 5, 1000)
			point.Parent = Workspace

			BallService.start()
			BallService.startGroundSpawns({ point })

			local folder = TestAssets.get(Workspace, "Balls")
			local spawned = nil
			for _ = 1, 120 do
				task.wait()
				local balls = ballsIn(folder)
				if #balls > 0 then
					spawned = balls[1]
					break
				end
			end

			expect(spawned).to.be.ok()
			expect(spawned:GetAttribute("ph")).to.equal(5)
			local expected = point.Position + Vector3.new(0, Combat.Dodgeball.Radius, 0)
			expect((spawned.CFrame.Position - expected).Magnitude).to.be.near(0, 1e-3)

			local before = #ballsIn(folder)
			for _ = 1, 10 do
				task.wait()
			end
			expect(#ballsIn(folder)).to.equal(before)

			BallService.stopGroundSpawns()
			point:Destroy()
		end)
	end)
end
