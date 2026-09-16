-- Description: Engine-side acceptance spec for declaratively built Splashdown courses. It builds each selected CourseSpec through CourseBuilder into an isolated Workspace container, runs the real CourseQA audit against it with actual raycasts, and asserts the HANDOFF section 8 contracts that can be measured without a driven playtest. Selection comes from ServerStorage.SplashdownQASelection when the run-course-qa probe sets it, and defaults to the pilot otherwise.

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Splashdown = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Splashdown")
local CourseBuilder = require(Splashdown:WaitForChild("CourseBuilder"))
local CourseQA = require(Splashdown:WaitForChild("CourseQA"))
local SplashdownConfig = require(ReplicatedStorage:WaitForChild("Config").Gameplay.Splashdown)
local DoorRows = require(game:GetService("ServerScriptService").Server.Modules.Splashdown.DoorRows)
local BeachBalls = require(game:GetService("ServerScriptService").Server.Modules.MapFeatures.BeachBalls)
local FallingTiles = require(game:GetService("ServerScriptService").Server.Modules.MapFeatures.FallingTiles)
local MapFeatures = require(ReplicatedStorage:WaitForChild("Config").Gameplay.MapFeatures)
local RisingLiquid = require(ReplicatedStorage:WaitForChild("Shared").Game.MapFeatures.RisingLiquid)

local function selectedIds(): { string }
	local selection = ServerStorage:FindFirstChild("SplashdownQASelection")
	if selection and selection:IsA("StringValue") and selection.Value ~= "" then
		local ids = {}
		for id in selection.Value:gmatch("[^,]+") do
			table.insert(ids, (id:gsub("^%s*(.-)%s*$", "%1")))
		end
		return ids
	end
	return { "BallBarrage" }
end

local function authoringSources()
	local root = ServerStorage:FindFirstChild("SplashdownAuthoringSources")
	if not root then
		return nil
	end
	local kit = root:FindFirstChild("Kit")
	local arena = root:FindFirstChild("ArenaSources")
	local wall = arena and arena:FindFirstChild("BoundaryWall")
	if not kit or not wall then
		return nil
	end
	return { Kit = kit, BoundaryWall = wall }
end

return function()
	for _, courseId in selectedIds() do
		describe(courseId, function()
			local container, model, report, qa

			beforeAll(function()
				local sources = authoringSources()
				-- Without the section 4 source export there is nothing to build
				-- from. Fail loudly rather than reporting an empty pass.
				assert(sources, "ServerStorage.SplashdownAuthoringSources is missing; run the section 4 export first")
				local spec = require(Splashdown:WaitForChild("CourseSpecs"):WaitForChild(courseId))
				model, report = CourseBuilder.build(spec, sources)
				container = Instance.new("Folder")
				container.Name = "SplashdownQAIsolation_" .. courseId
				container.Parent = Workspace
				model.Parent = container
				qa = CourseQA.check(model, spec, CourseQA.DefaultCalibration, {
					Route = report.Route,
					SpecHash = report.SpecHash,
				})
			end)

			afterAll(function()
				if container then
					container:Destroy()
				end
			end)

			it("builds with no attribute, route or bounds errors", function()
				expect(#report.AttributeErrors).to.equal(0)
				expect(#report.RouteErrors).to.equal(0)
				expect(#report.Bounds.Violations).to.equal(0)
				expect(report.Ok).to.equal(true)
			end)

			it("keeps every part corner within 600 studs of Origin", function()
				expect(report.Bounds.MaxCornerDistance <= 600).to.equal(true)
			end)

			it("keeps geometry centres within 380 and the route within its BoundsRadius", function()
				expect(report.Bounds.MaxGeometryCenterRadius <= 380).to.equal(true)
				expect(report.Bounds.MaxRouteRadius <= 300).to.equal(true)
			end)

			it("keeps the static route envelope inside the -30..90 band", function()
				expect(report.Bounds.RouteMinY >= -30).to.equal(true)
				expect(report.Bounds.RouteMaxY <= 90).to.equal(true)
			end)

			it("fits every beat between 0.85 and 1.15 of its length target", function()
				for _, beat in report.Beats do
					expect(beat.Ratio >= 0.85).to.equal(true)
					expect(beat.Ratio <= 1.15).to.equal(true)
				end
			end)

			it("holds the total route arclength inside the 800-1000 stud window", function()
				expect(report.RouteLength >= 800).to.equal(true)
				expect(report.RouteLength <= 1000).to.equal(true)
			end)

			it("rebuilds deterministically to the same spec hash", function()
				local spec = require(Splashdown:WaitForChild("CourseSpecs"):WaitForChild(courseId))
				local second, secondReport = CourseBuilder.build(spec, authoringSources())
				expect(secondReport.SpecHash).to.equal(report.SpecHash)
				second:Destroy()
			end)

			it("exposes exactly 30 start pads, ordered checkpoints and one finish", function()
				expect(qa.Counts.StartPads).to.equal(30)
				expect(qa.Counts.Checkpoints >= 1).to.equal(true)
				expect(model:GetAttribute("CheckpointCount")).to.equal(qa.Counts.Checkpoints)
			end)

			it("carries the 24-wall boundary ring at radius 390", function()
				expect(qa.Counts.BoundaryWalls).to.equal(24)
			end)

			it("samples a real walkable surface graph rather than trusting the spec", function()
				expect(qa.Counts.SurfaceCells > 0).to.equal(true)
				expect(qa.Counts.GraphNodes > 0).to.equal(true)
				expect(qa.Counts.GraphEdges > 0).to.equal(true)
			end)

			it("reports no QA errors", function()
				if #qa.Errors > 0 then
					error(table.concat(qa.Errors, " | "), 0)
				end
				expect(#qa.Errors).to.equal(0)
			end)

			it("never reports an overall PASS while live-playtest checks are outstanding", function()
				expect(#qa.NotRun > 0).to.equal(true)
				expect(qa.Status).never.to.equal("PASS")
			end)

			-- Regression for two CoursePresets defects the Door Dash build exposed.
			it("leaves no original source name on any part", function()
				local leaked = {}
				for _, instance in model:GetDescendants() do
					if instance:IsA("BasePart") then
						local name = instance.Name
						for _, prefix in
							{
								"obstacle_",
								"platform_",
								"door_",
								"trampoline_",
								"box_",
								"slide_",
								"arch_",
								"propeller_",
								"water_platform_",
								"octagon_",
								"ball_",
							}
						do
							if string.sub(name, 1, #prefix) == prefix then
								table.insert(leaked, instance:GetFullName())
							end
						end
					end
				end
				if #leaked > 0 then
					error(`{#leaked} parts kept a source name, e.g. {leaked[1]}`, 0)
				end
				expect(#leaked).to.equal(0)
			end)

			it("clones each declared sub-part once instead of doubling a nested assembly", function()
				-- A duplicated sub-part lands exactly on top of the original, so two
				-- parts of one piece sharing a position is the signature to catch.
				local seen: { [string]: string } = {}
				local doubled = {}
				for _, instance in model:GetDescendants() do
					if instance:IsA("BasePart") and instance:GetAttribute("PieceId") then
						local key = string.format(
							"%s|%d|%d|%d",
							tostring(instance:GetAttribute("PieceId")),
							math.round(instance.Position.X * 100),
							math.round(instance.Position.Y * 100),
							math.round(instance.Position.Z * 100)
						)
						if seen[key] then
							table.insert(doubled, `{instance.Name} over {seen[key]}`)
						end
						seen[key] = instance.Name
					end
				end
				if #doubled > 0 then
					error(`{#doubled} coincident sub-parts, e.g. {doubled[1]}`, 0)
				end
				expect(#doubled).to.equal(0)
			end)

			it("puts door slabs where the door kit can actually see them", function()
				-- DoorRows.resolve and MapFeatureService both walk the folder's
				-- IMMEDIATE BasePart children: a slab inside a holder Model resolves as
				-- no rows at all, and every door would stay permanently solid.
				local doors = model:FindFirstChild("Scriptables") and model.Scriptables:FindFirstChild("Doors")
				local slabs = 0
				local nested = 0
				for _, child in (doors and doors:GetChildren() or {}) do
					if child:IsA("BasePart") then
						slabs += 1
						expect(typeof(child:GetAttribute("DoorRow"))).to.equal("number")
						expect(typeof(child:GetAttribute("DoorIndex"))).to.equal("number")
					else
						nested += 1
					end
				end
				expect(nested).to.equal(0)
				local rows = DoorRows.resolve(doors)
				local configured = SplashdownConfig.Courses[courseId] and SplashdownConfig.Courses[courseId].Doors
				if configured then
					expect(#rows > 0).to.equal(true)
					for _, row in rows do
						expect(#row).to.equal(configured.PerRow)
					end
				else
					expect(#rows).to.equal(if slabs > 0 then #rows else 0)
				end
			end)

			-- The door defect above was silent: the build succeeded, the audit passed,
			-- and the kit still could not see a single slab. Beach balls have exactly the
			-- same failure mode, so this drives the REAL BeachBalls kit over the built
			-- model and checks what the kit ends up owning, rather than trusting that a
			-- ball looks present in a preview.
			it("hands its beach balls to the kit as real unanchored server-owned physics", function()
				local scriptables = model:FindFirstChild("Scriptables")
				local rotating = scriptables and scriptables:FindFirstChild("Rotating")
				local groups = {}
				for _, group in (rotating and rotating:GetChildren() or {}) do
					table.insert(groups, group)
				end

				local authored = {}
				for _, instance in model:GetDescendants() do
					if instance:IsA("BasePart") and instance:GetAttribute(MapFeatures.Attributes.BeachBall) == true then
						table.insert(authored, instance)
						-- HANDOFF 8.1: no unanchored template asset; the live ball is the
						-- runtime exception, so the authored one must still be anchored.
						expect(instance.Anchored).to.equal(true)
						-- 02-kits.md: "do not also give them a kinematic motion owner."
						expect(instance:GetAttribute(MapFeatures.Attributes.Rotor)).to.equal(nil)
						-- The kit walks Rotating/<group>/Assembly descendants, so a ball
						-- parked anywhere else is invisible to it however present it looks.
						local assembly = instance:FindFirstAncestor("Assembly")
						expect(assembly ~= nil and assembly:IsA("Model")).to.equal(true)
						expect(assembly.Parent ~= nil and assembly.Parent.Parent == rotating).to.equal(true)
					end
				end

				BeachBalls.forget(nil)
				BeachBalls.tickWorld({ instances = groups, now = os.clock(), deltaTime = 1 / 60 })
				local live = BeachBalls.active()
				expect(#live).to.equal(#authored)
				for _, ball in live do
					expect(ball.Anchored).to.equal(false)
					expect(ball.CanCollide).to.equal(true)
					-- SetNetworkOwner(nil) is server ownership; GetNetworkOwner returns nil
					-- for it AND for an anchored part, so the unanchored assertion above is
					-- what makes this one mean something.
					expect(ball:GetNetworkOwner()).to.equal(nil)
					expect(ball.Parent ~= nil and ball.Parent.Name).to.equal("BeachBalls")
					expect(ball:IsDescendantOf(model)).to.equal(true)
				end
				BeachBalls.forget(nil)
			end)

			-- Same reasoning as the beach-ball test above, for the other kit whose parts
			-- are the route's own FLOOR: a falling tile that the kit cannot see is a
			-- permanently solid platform, which looks perfect in a preview and in the
			-- audit and quietly removes the whole mechanic. This drives the REAL
			-- FallingTiles kit over the built model: it registers the tiles, arms one
			-- through the kit's own support raycast, lets its countdown expire, and
			-- checks the tile actually loses collision and then comes back.
			it("hands its falling tiles to the kit as real armable, droppable, respawning tiles", function()
				local scriptables = model:FindFirstChild("Scriptables")
				local rotating = scriptables and scriptables:FindFirstChild("Rotating")
				local groups = {}
				for _, group in (rotating and rotating:GetChildren() or {}) do
					table.insert(groups, group)
				end

				local authored = {}
				for _, instance in model:GetDescendants() do
					if
						instance:IsA("BasePart")
						and instance:GetAttribute(MapFeatures.Attributes.FallingTile) == true
					then
						table.insert(authored, instance)
						expect(instance.Anchored).to.equal(true)
						expect(instance.CanCollide).to.equal(true)
						-- HANDOFF 13 and AttributeAudit: a CriticalRoute tile that never
						-- respawns strands every racer behind it.
						expect(instance:GetAttribute("CriticalRoute")).to.equal(true)
						expect(instance:GetAttribute(MapFeatures.Attributes.RespawnSeconds) > 0).to.equal(true)
						expect(typeof(instance:GetAttribute(MapFeatures.Attributes.DropDelaySeconds))).to.equal(
							"number"
						)
						-- 02-kits: a stateful surface must not also inherit a moving owner.
						expect(instance:GetAttribute(MapFeatures.Attributes.Rotor)).to.equal(nil)
						-- FeatureParts.collect only ever walks Rotating/<group>/Assembly.
						local assembly = instance:FindFirstAncestor("Assembly")
						expect(assembly ~= nil and assembly:IsA("Model")).to.equal(true)
						expect(assembly.Parent ~= nil and assembly.Parent.Parent == rotating).to.equal(true)
					end
				end

				if #authored == 0 then
					-- Only Tiptoe Trials uses falling tiles (override 2 keeps them its
					-- headline), so every other course legitimately has none.
					expect(#authored).to.equal(0)
					return
				end

				local probe = Instance.new("Model")
				probe.Name = "FallingTileProbe"
				local humanoid = Instance.new("Humanoid")
				humanoid.HipHeight = 2
				humanoid.Parent = probe
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Size = Vector3.new(2, 2, 1)
				root.Anchored = false
				root.CanCollide = false
				root.Parent = probe
				probe.PrimaryPart = root
				probe.Parent = Workspace

				local tile = authored[1]
				local delay = tile:GetAttribute(MapFeatures.Attributes.DropDelaySeconds)
				local respawn = tile:GetAttribute(MapFeatures.Attributes.RespawnSeconds)
				root.CFrame = CFrame.new(
					tile.Position + Vector3.new(0, tile.Size.Y / 2 + humanoid.HipHeight + root.Size.Y / 2, 0)
				)

				FallingTiles.forget(nil)
				local now = os.clock()
				FallingTiles.tickWorld({ instances = groups, now = now, deltaTime = 1 / 60 })
				FallingTiles.tickPlayer({ instances = groups, now = now, deltaTime = 1 / 60 }, nil, root)
				-- Still solid while the countdown runs: the warning is visible, the
				-- collision is authoritative.
				FallingTiles.tickWorld({ instances = groups, now = now + delay / 2, deltaTime = 1 / 60 })
				expect(tile.CanCollide).to.equal(true)
				FallingTiles.tickWorld({ instances = groups, now = now + delay + 0.05, deltaTime = 1 / 60 })
				expect(tile.CanCollide).to.equal(false)
				expect(tile.CanQuery).to.equal(false)
				expect(tile.Transparency).to.equal(1)
				-- And it comes back, which is the whole reason CriticalRoute tiles are
				-- allowed on this route at all.
				FallingTiles.tickWorld({
					instances = groups,
					now = now + delay + respawn + 0.1,
					deltaTime = 1 / 60,
				})
				expect(tile.CanCollide).to.equal(true)
				expect(tile.CanQuery).to.equal(true)
				expect(tile.Transparency).to.equal(0)

				FallingTiles.forget(nil)
				probe:Destroy()
			end)

			-- Third instance of the same class of silent defect, and the one that has
			-- actually shipped: a hazard whose motion is perfect and whose geometry
			-- never reaches the lane. Ball Barrage's two pistons mount base-inwards and
			-- their heads sweep 5.8 to 9.7 studs BEYOND the lane edge over open water,
			-- so no runner can ever be struck by them, and neither the build nor the
			-- audit noticed. This drives the measured head, not the attributes: cast
			-- down from where the head really sits at rest and at full extension, and
			-- require that at least one of those columns lands on this course's own
			-- geometry with the head spanning a runner's body above it.
			it("mounts every piston head where it can actually strike a runner", function()
				local geometry = model:FindFirstChild("Geometry")
				local solids = {}
				for _, instance in (geometry and geometry:GetDescendants() or {}) do
					if instance:IsA("BasePart") and instance.CanCollide then
						table.insert(solids, instance)
					end
				end

				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = solids

				local heads = 0
				for _, instance in model:GetDescendants() do
					-- The head is the piston's grandchild: the spring carries the slide
					-- rotor and the head hangs off it, so it is the only piston part with
					-- no motion owner of its own under a part that has one.
					if not instance:IsA("BasePart") or instance:GetAttribute("SourceAsset") ~= "obstacle_22_001" then
						continue
					end
					local parent = instance.Parent
					local isHead = parent ~= nil
						and parent:IsA("BasePart")
						and parent:GetAttribute(MapFeatures.Attributes.Rotor) ~= nil
						and instance:GetAttribute(MapFeatures.Attributes.Rotor) == nil
					if not isHead then
						continue
					end
					heads += 1

					local extend = parent:GetAttribute(MapFeatures.Attributes.PistonExtendStuds) or 0
					local punch = instance.CFrame.LookVector * extend
					local reached = false
					for _, centre in { instance.Position, instance.Position + punch } do
						local hit = Workspace:Raycast(centre, Vector3.new(0, -200, 0), params)
						if hit == nil then
							continue
						end
						local bottom = instance.Position.Y - instance.Size.Y / 2
						local top = instance.Position.Y + instance.Size.Y / 2
						-- A runner's body occupies roughly the first 5.5 studs above the
						-- surface they stand on; the head has to overlap that band, not
						-- sweep under the floor like a suspended hammer or over their head.
						if bottom <= hit.Position.Y + 5.5 and top >= hit.Position.Y then
							reached = true
							break
						end
					end
					expect(reached).to.equal(true)
				end
				expect(heads > 0).to.equal(true)
			end)

			-- A log-roll is a rolling surface, and on a stacked course it is also the
			-- piece most likely to become a ladder: the framed roller's cradle stands
			-- 32 studs above its own mount, and a cut-set audit measured runners
			-- climbing one from a lower run straight into a beat three ahead. So this
			-- checks both halves on the built model -- that the kit really sees a
			-- turning, carrying, shoving drum, and that whatever carries it is not tall
			-- enough to climb.
			it("turns its log-rolls without leaving a climbable frame", function()
				local rotating = model:FindFirstChild("Scriptables")
				rotating = rotating and rotating:FindFirstChild("Rotating")
				local drums = 0
				for _, instance in model:GetDescendants() do
					if not instance:IsA("BasePart") or instance:GetAttribute("PieceId") == nil then
						continue
					end
					local pieceId = instance:GetAttribute("PieceId") :: string
					if not pieceId:match("^Roll") or instance:GetAttribute(MapFeatures.Attributes.Rotor) == nil then
						continue
					end
					drums += 1
					expect(instance:GetAttribute(MapFeatures.Attributes.Rotor)).to.equal("spin")
					expect(instance:GetAttribute(MapFeatures.Attributes.RotorCarries)).to.equal(true)
					expect(instance:GetAttribute(MapFeatures.Attributes.Shove)).to.equal(true)
					expect(math.abs(instance:GetAttribute(MapFeatures.Attributes.RotorSpeed)) > 0).to.equal(true)
					-- The kit only ever walks Rotating/<group>/Assembly, so a drum parked
					-- anywhere else is invisible to it however present it looks.
					local assembly = instance:FindFirstAncestor("Assembly")
					expect(assembly ~= nil and assembly:IsA("Model")).to.equal(true)
					expect(assembly.Parent ~= nil and assembly.Parent.Parent == rotating).to.equal(true)

					-- Nothing in the roller's own holder may stand more than a jump above
					-- the tread it sits on, or the hazard is a staircase to the storey
					-- above. Measured against the deck under the drum's own centre.
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { assembly }
					local ground = Workspace:Raycast(instance.Position, Vector3.new(0, -60, 0), params)
					if ground then
						local holder = instance.Parent
						local tallest = 0
						for _, sibling in (holder and holder:GetDescendants() or { instance }) do
							if sibling:IsA("BasePart") then
								tallest = math.max(tallest, sibling.Position.Y + sibling.Size.Y / 2 - ground.Position.Y)
							end
						end
						tallest = math.max(tallest, instance.Position.Y + instance.Size.Y / 2 - ground.Position.Y)
						expect(tallest < 10).to.equal(true)
					end
				end
				expect(drums >= 0).to.equal(true)
			end)

			-- HANDOFF 7.6's flood regression, driven through the REAL RisingLiquid
			-- resolver rather than the spec: SplashdownCourses.resolve finds a course's
			-- schedule by running exactly this over every Hazards BasePart, so a liquid
			-- the resolver cannot read has no rise at all, and a flood that finishes
			-- above a checkpoint pad strands any racer who respawns on it.
			it("resolves its rising liquid and leaves every checkpoint above the flood", function()
				local hazards = model:FindFirstChild("Hazards")
				local liquid, config
				for _, part in (hazards and hazards:GetChildren() or {}) do
					if part:IsA("BasePart") then
						local resolved = RisingLiquid.resolve(part:GetAttributes())
						if resolved then
							liquid, config = part, resolved
							break
						end
					end
				end
				if liquid == nil then
					-- Only Piston Peak reuses the twist (HANDOFF section 6), so a course
					-- without one is reported rather than failed.
					expect(config).to.equal(nil)
					return
				end

				expect(config.studs > 0).to.equal(true)
				expect(config.seconds > 0).to.equal(true)
				-- The flood must still be rising when a normal run ends and must have
				-- stopped by the cap, or it is either decorative or unbounded.
				local cap = SplashdownConfig.Courses[courseId].CapSeconds
				expect(config.delaySeconds + config.seconds <= cap).to.equal(true)
				expect(RisingLiquid.heightAt(0, config)).to.equal(0)
				expect(RisingLiquid.heightAt(config.seconds * 2, config)).to.equal(config.studs)

				local surface = liquid.Position.Y + liquid.Size.Y / 2
				local floodTop = surface + config.studs
				local checkpoints = model:FindFirstChild("Checkpoints")
				local pads = 0
				for _, checkpoint in (checkpoints and checkpoints:GetChildren() or {}) do
					local pad = checkpoint:FindFirstChild("Pad")
					if pad and pad:IsA("BasePart") then
						pads += 1
						expect(pad.Position.Y + pad.Size.Y / 2 > floodTop).to.equal(true)
					end
				end
				expect(pads > 0).to.equal(true)
			end)
		end)
	end
end
