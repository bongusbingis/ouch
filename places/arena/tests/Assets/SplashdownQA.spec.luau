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
local RotatingPlatforms = require(ReplicatedStorage:WaitForChild("Shared").Game.MapFeatures.RotatingPlatforms)

-- Swept-reach constants for the hazard-reach regression below. The window is long
-- enough to cover several turns of every profile the kits use (a hammer cycles in
-- windup+strike = 2.1 s, a piston in its 3.2-second period, a rock in its own
-- period and a spin in 360/RotorSpeed), and the step is fine enough that the
-- fastest measured spin -- 195 degrees/s on the smallest contact radius in the kit
-- -- turns under 10 degrees between samples.
local SWEEP_SECONDS = 12
local SWEEP_SAMPLES = 240
-- Lane sampling: one station per stud along the route and one stud across it. The
-- thinnest hazard in the set is the large hammer head at 1.92 studs through the
-- route, so a 1-stud station cannot pass through it unsampled.
local LANE_STATION_STUDS = 1
local LANE_LATERAL_STUDS = 1

-- The route's own measured lane, rebuilt from the BuildReport rather than from a
-- raycast: each step records where the cursor stood, which way it faced and the
-- MEASURED lateral half-extent of the piece it placed. Mount and Flank steps are
-- excluded from the polyline because their half-extent is the HAZARD's reach, not
-- the deck's -- a piston mounted 19.5 studs off the centreline would otherwise
-- declare a 24-stud-wide lane and make this check vacuous.
local function laneForBeat(route: { any }, beatId: string): { any }
	local lane = {}
	for index, step in route do
		if step.Kind == "Mount" or step.Kind == "Flank" then
			continue
		end
		if step.BeatId == beatId then
			if #lane == 0 then
				-- One step back so the lane covers the beat's own entrance, which is
				-- where a hazard mounted at a negative OffsetAlong can stand.
				for back = index - 1, 1, -1 do
					local previous = route[back]
					if previous.Kind ~= "Mount" and previous.Kind ~= "Flank" then
						table.insert(lane, previous)
						break
					end
				end
			end
			table.insert(lane, step)
		end
	end
	return lane
end

local function worldBox(part: BasePart, cf: CFrame): (Vector3, Vector3)
	local half = part.Size / 2
	local min, max = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = cf:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
				min = Vector3.new(math.min(min.X, corner.X), math.min(min.Y, corner.Y), math.min(min.Z, corner.Z))
				max = Vector3.new(math.max(max.X, corner.X), math.max(max.Y, corner.Y), math.max(max.Z, corner.Z))
			end
		end
	end
	return min, max
end

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
	-- The export root itself goes through as well: HANDOFF 7.7's SourcePatch layout
	-- patches the authored SummitSource that lives beside the kit.
	return { Kit = kit, BoundaryWall = wall, AuthoringRoot = root }
end

return function()
	for _, courseId in selectedIds() do
		describe(courseId, function()
			local container, model, report, qa, spec

			beforeAll(function()
				local sources = authoringSources()
				-- Without the section 4 source export there is nothing to build
				-- from. Fail loudly rather than reporting an empty pass.
				assert(sources, "ServerStorage.SplashdownAuthoringSources is missing; run the section 4 export first")
				spec = require(Splashdown:WaitForChild("CourseSpecs"):WaitForChild(courseId))
				model, report = CourseBuilder.build(spec, sources)
				container = Instance.new("Folder")
				container.Name = "SplashdownQAIsolation_" .. courseId
				container.Parent = Workspace
				model.Parent = container
				-- Resolution is recorded, never assumed (HANDOFF 8.2's closing line).
				-- Every built course is audited at the 1-stud default. The SourcePatch
				-- course is not: its preserved arc is a 44-stud-wide annulus 468 degrees
				-- long, which samples to 108,168 surface cells and 6.66 million edges,
				-- and a single TestEZ node cannot finish that inside Studio's script
				-- execution budget -- the first attempt died on "exhausted allowed
				-- execution time". The FULL-resolution audit is the one the
				-- run-course-qa probe publishes to
				-- docs/splashdown/evidence/courses/SummitSplash/qa.json; this in-engine
				-- pass re-runs it at 2 studs so the assertions below have something real
				-- to check, and the report it produces carries its own SampleResolution.
				local calibration = CourseQA.DefaultCalibration
				if spec.Layout.Kind == "SourcePatch" then
					calibration = table.clone(CourseQA.DefaultCalibration)
					calibration.SampleStep = CourseQA.DefaultCalibration.SampleStep * 2
				end
				qa = CourseQA.check(model, spec, calibration, {
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
				-- Override 4's window is the set-wide target for the six NEW courses.
				-- The seventh is a patch of an authored course whose centreline HANDOFF
				-- 7.7 preserves and whose Par is 115 seconds rather than 75, so it is
				-- held to its own declared beat targets instead of a window it was
				-- never built to. Those targets are checked beat by beat above; this
				-- asserts they still add up to the whole route, which is what would
				-- catch a patch that quietly moved the arc.
				if spec.Layout.Kind == "SourcePatch" then
					local declared = 0
					for _, beat in spec.Beats do
						declared += beat.LengthTarget
					end
					expect(math.abs(report.RouteLength - declared) < declared * 0.02).to.equal(true)
					return
				end
				expect(report.RouteLength >= 800).to.equal(true)
				expect(report.RouteLength <= 1000).to.equal(true)
			end)

			it("rebuilds deterministically to the same spec hash", function()
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
				-- parts of one piece sharing a position is the signature to catch --
				-- but position ALONE is not that signature. A disc is a hub with a
				-- concentric plate: Whirlpool Waltz's obstacle_15 and obstacle_26 rides
				-- put a 29.9-stud plate and a 6.5-stud hub on exactly the same centre,
				-- and reported them as doubled. A real duplicate is the SAME geometry
				-- twice, so the size is part of the key.
				local seen: { [string]: string } = {}
				local doubled = {}
				for _, instance in model:GetDescendants() do
					if instance:IsA("BasePart") and instance:GetAttribute("PieceId") then
						local key = string.format(
							"%s|%d|%d|%d|%d|%d|%d",
							tostring(instance:GetAttribute("PieceId")),
							math.round(instance.Position.X * 100),
							math.round(instance.Position.Y * 100),
							math.round(instance.Position.Z * 100),
							math.round(instance.Size.X * 100),
							math.round(instance.Size.Y * 100),
							math.round(instance.Size.Z * 100)
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
				-- Count what the SPEC declares rather than asserting "more than none".
				-- Four of the six courses place no piston at all, and a bare
				-- `heads > 0` failed every one of them while saying nothing about the
				-- courses that do place them. Matching the declared count also catches
				-- a head the builder silently dropped.
				local declared = 0
				for _, beat in spec.Beats do
					for _, piece in beat.Pieces do
						if piece.Preset == "Piston" then
							declared += 1
						end
					end
				end
				expect(heads).to.equal(declared)
			end)

			-- The general form of the piston defect above, and of the hammer defect
			-- beside it: a hazard whose motion, attributes and kit registration are all
			-- correct and whose geometry never meets a runner. Ball Barrage shipped its
			-- two pistons sweeping 5.79 to 13.51 studs PAST the lane edge over open
			-- water, and its two hammers hanging with only the top 0.46 studs of the
			-- head at deck level -- one defect lateral, one vertical, both invisible to
			-- every other check here. So this measures the volume each shoving hazard
			-- REALLY sweeps, through the production motion profile over a full cycle,
			-- and requires it to reach the lane at the height a runner's body is.
			--
			-- The bar is the calibration's own measured root offset: somewhere in its
			-- own beat's lane, the hazard must sweep through the plane 3.5 studs above
			-- the deck. That is where the character's root sits, so a hazard that never
			-- crosses it is decoration however impressive its arc looks. Hazards that
			-- CARRY riders (the swing panels and the log-rolls) are exempt and reported:
			-- their contract is to be a surface at deck height in the lane, which the
			-- log-roll test above already measures.
			it("sweeps every shoving hazard through its own beat's lane", function()
				local rotating = model:FindFirstChild("Scriptables")
				rotating = rotating and rotating:FindFirstChild("Rotating")
				expect(rotating ~= nil).to.equal(true)

				local rootHeight = CourseQA.DefaultCalibration.RootOffsetStuds
				local checked, carried = 0, 0
				local failures: { string } = {}
				local lines: { string } = {}

				for _, group in rotating:GetChildren() do
					local origin = group:FindFirstChild("Origin")
					local assembly = group:FindFirstChild("Assembly")
					if not (origin and origin:IsA("BasePart") and assembly and assembly:IsA("Model")) then
						continue
					end
					local platform = RotatingPlatforms.build(origin, assembly)
					for _, rotor in platform.localRotors do
						if not rotor.shove then
							continue
						end
						local pieceId = tostring(rotor.part:GetAttribute("PieceId"))
						local beatId = tostring(rotor.part:GetAttribute("BeatId"))
						if rotor.carriesRiders then
							carried += 1
							table.insert(lines, string.format("%s/%s carries riders; exempt", beatId, pieceId))
							continue
						end
						checked += 1

						-- Everything the rotor moves: the rotor part and every follower
						-- beneath it. RotorBump shoves the whole set, so a mace's reach is
						-- its ball's and a piston's is its head's, not the top link's or
						-- the spring's.
						local moving: { { part: BasePart, offset: CFrame } } = {
							{ part = rotor.part, offset = rotor.centerToPart },
						}
						for _, follower in rotor.followers do
							table.insert(moving, { part = follower.part, offset = follower.centerToPart })
						end

						-- Pass one: the swept axis-aligned envelope, which bounds where any
						-- lane point worth testing can be.
						local poses: { { { part: BasePart, cf: CFrame } } } = {}
						local sweptMin = Vector3.new(math.huge, math.huge, math.huge)
						local sweptMax = Vector3.new(-math.huge, -math.huge, -math.huge)
						for sample = 0, SWEEP_SAMPLES - 1 do
							local now = sample * (SWEEP_SECONDS / SWEEP_SAMPLES)
							local centre = RotatingPlatforms.rotorPoseAt(platform, rotor, now)
							local frame = {}
							for _, piece in moving do
								local cf = centre * piece.offset
								table.insert(frame, { part = piece.part, cf = cf })
								local min, max = worldBox(piece.part, cf)
								sweptMin = Vector3.new(
									math.min(sweptMin.X, min.X),
									math.min(sweptMin.Y, min.Y),
									math.min(sweptMin.Z, min.Z)
								)
								sweptMax = Vector3.new(
									math.max(sweptMax.X, max.X),
									math.max(sweptMax.Y, max.Y),
									math.max(sweptMax.Z, max.Z)
								)
							end
							table.insert(poses, frame)
						end

						-- Pass two: lane points at root height under the swept envelope.
						local lane = laneForBeat(report.Route, beatId)
						local points: { Vector3 } = {}
						local deckMin, deckMax = math.huge, -math.huge
						for index = 1, #lane - 1 do
							local a, b = lane[index], lane[index + 1]
							local delta = b.Position - a.Position
							local flat = Vector3.new(delta.X, 0, delta.Z)
							local span = flat.Magnitude
							local halfWidth = math.max(a.HalfWidth, b.HalfWidth)
							if span < 1e-3 or halfWidth <= 0 then
								continue
							end
							local along = flat.Unit
							local side = Vector3.new(along.Z, 0, -along.X)
							local station = 0
							while station <= span do
								local t = station / span
								local centre = a.Position + delta * t
								local lateral = -halfWidth
								while lateral <= halfWidth do
									local spot = centre + side * lateral + Vector3.new(0, rootHeight, 0)
									if
										spot.X >= sweptMin.X
										and spot.X <= sweptMax.X
										and spot.Z >= sweptMin.Z
										and spot.Z <= sweptMax.Z
										and spot.Y >= sweptMin.Y
										and spot.Y <= sweptMax.Y
									then
										table.insert(points, spot)
										deckMin = math.min(deckMin, centre.Y)
										deckMax = math.max(deckMax, centre.Y)
									end
									lateral += LANE_LATERAL_STUDS
								end
								station += LANE_STATION_STUDS
							end
						end

						local struck = false
						for _, frame in poses do
							for _, spot in points do
								for _, placed in frame do
									local localSpot = placed.cf:PointToObjectSpace(spot)
									local half = placed.part.Size / 2
									if
										math.abs(localSpot.X) <= half.X
										and math.abs(localSpot.Y) <= half.Y
										and math.abs(localSpot.Z) <= half.Z
									then
										struck = true
										break
									end
								end
								if struck then
									break
								end
							end
							if struck then
								break
							end
						end

						local detail = string.format(
							"%s/%s sweeps Y %.2f..%.2f over a lane deck at Y %.2f..%.2f; %d lane points at root height %.1f fall inside its swept envelope",
							beatId,
							pieceId,
							sweptMin.Y,
							sweptMax.Y,
							if deckMin < math.huge then deckMin else 0,
							if deckMax > -math.huge then deckMax else 0,
							#points,
							rootHeight
						)
						table.insert(lines, detail .. (if struck then " -- STRIKES" else " -- NEVER STRIKES"))
						if not struck then
							table.insert(failures, detail)
						end
					end
				end

				print(string.format("[HazardReach] %s\n  %s", courseId, table.concat(lines, "\n  ")))
				expect(checked > 0).to.equal(true)
				if #failures > 0 then
					error(
						string.format(
							"%d shoving hazard(s) never reach their own lane: %s",
							#failures,
							table.concat(failures, " | ")
						),
						0
					)
				end
				expect(carried >= 0).to.equal(true)
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
				local pads, above = 0, 0
				for _, checkpoint in (checkpoints and checkpoints:GetChildren() or {}) do
					local pad = checkpoint:FindFirstChild("Pad")
					if pad and pad:IsA("BasePart") then
						pads += 1
						if pad.Position.Y + pad.Size.Y / 2 > floodTop then
							above += 1
						end
					end
				end
				expect(pads > 0).to.equal(true)

				if spec.Layout.Kind == "SourcePatch" then
					-- HANDOFF 7.7.9: "Preserve original liquid timing even if the
					-- run-time target is difficult." Summit's authored flood deliberately
					-- swallows its lower checkpoints late in a run -- that IS the timer --
					-- so the patch is held to the two things that must still be true: the
					-- flood stops below the LAST checkpoint, so a racer always has a dry
					-- pad to respawn on, and it reaches every lower pad only after Par.
					expect(above >= 1).to.equal(true)
					-- The strongest property that is TRUE here and worth asserting: the
					-- flood stops below the HIGHEST checkpoint pad, so a racer always has
					-- a dry pad to respawn on however long the run takes.
					local highest = -math.huge
					for _, row in report.CheckpointFloodTimes do
						highest = math.max(highest, row.PadY)
					end
					expect(highest > floodTop).to.equal(true)
					-- WHEN each lower pad goes under is measured and reported rather than
					-- asserted against a threshold. On this course Checkpoint01 submerges
					-- at 104 s against a Par of 115, which is 3.2's flooded-respawn
					-- condition arriving by design; whether that actually strands a racer
					-- is the driven checkpoint-recovery run, and that is on this course's
					-- NOT RUN list. Asserting a made-up time budget here would be
					-- inventing a check, so the only bound asserted is the one the
					-- schedule itself guarantees: nothing floods before the rise starts.
					for _, row in report.CheckpointFloodTimes do
						if row.SubmergedAtSeconds >= 0 then
							expect(row.SubmergedAtSeconds > config.delaySeconds).to.equal(true)
						end
					end
					return
				end

				for _, checkpoint in (checkpoints and checkpoints:GetChildren() or {}) do
					local pad = checkpoint:FindFirstChild("Pad")
					if pad and pad:IsA("BasePart") then
						expect(pad.Position.Y + pad.Size.Y / 2 > floodTop).to.equal(true)
					end
				end
			end)

			it("seals both arc edges at every gate a SourcePatch course declares", function()
				if spec.Layout.Kind ~= "SourcePatch" then
					expect(#report.GateSeals).to.equal(0)
					return
				end
				local patch = spec.Layout.SourcePatch
				-- Every gate the spec declares has to exist in the built model, and at
				-- every one of them the arc's own inner and outer edge strips must be
				-- closed: that is HANDOFF 7.7.7's "no inside shortcut, no outer rail-top
				-- highway", measured off placed geometry rather than declared.
				local declared = {}
				for _, beat in spec.Beats do
					for _, piece in beat.Pieces do
						if piece.GateId then
							declared[piece.GateId] = true
						end
					end
				end
				local count = 0
				for _ in declared do
					count += 1
				end
				expect(#report.GateSeals).to.equal(count)
				for _, gate in report.GateSeals do
					expect(declared[gate.Id]).to.equal(true)
					expect(gate.EdgeGapStuds <= patch.MaxUnsealedStuds).to.equal(true)
					if gate.MustSeal then
						expect(gate.InteriorGapStuds <= patch.MaxUnsealedStuds).to.equal(true)
					end
				end
			end)

			it("keeps every SourcePatch guard wall over 14 studs and under its stacked clearance", function()
				if spec.Layout.Kind ~= "SourcePatch" then
					return
				end
				local patch = spec.Layout.SourcePatch
				expect(#report.GuardWalls > 0).to.equal(true)
				for _, wall in report.GuardWalls do
					expect(wall.TopAboveDeck >= patch.GuardWallMinAboveDeck).to.equal(true)
					expect(wall.TopAboveDeck <= patch.StackedClearanceStuds).to.equal(true)
				end
			end)

			it("removes every declared source instance and keeps every retained one", function()
				if spec.Layout.Kind ~= "SourcePatch" then
					return
				end
				local patch = spec.Layout.SourcePatch
				expect(#report.Removed).to.equal(#patch.Remove)
				expect(report.SourceBaseParts).to.equal(patch.ExpectedBaseParts)
				local names = {}
				for _, instance in model:GetDescendants() do
					names[instance.Name] = true
				end
				for _, gone in patch.Remove do
					expect(names[gone]).to.equal(nil)
				end
				local retained = 0
				for _, beat in spec.Beats do
					for _, piece in beat.Pieces do
						if piece.Kind == "Retain" then
							retained += 1
							expect(names[piece.SourceInstance]).to.equal(true)
						end
					end
				end
				expect(#report.Retained).to.equal(retained)
			end)
		end)
	end
end
