-- Camera projection must center the stage in its UI region rather than beneath the reward panel.
--!strict
local Framing = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Models")
		:WaitForChild("StageFraming")
)
local UIConfig =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local ResponsiveLayout = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("UI")
		:WaitForChild("Models")
		:WaitForChild("ResponsiveLayout")
)

local function project(frame: CFrame, point: Vector3, viewport: Vector2, fov: number): Vector2
	local localPoint = frame:PointToObjectSpace(point)
	assert(localPoint.Z < 0, "world bounds must remain in front of the camera")
	local halfHeight = -localPoint.Z * math.tan(math.rad(fov / 2))
	return Vector2.new(
		viewport.X / 2 + localPoint.X / halfHeight * viewport.Y / 2,
		viewport.Y / 2 - localPoint.Y / halfHeight * viewport.Y / 2
	)
end

local function expectBoundsInside(frame, minimum, maximum, position, size, viewport, fov)
	for _, x in { minimum.X, maximum.X } do
		for _, y in { minimum.Y, maximum.Y } do
			for _, z in { minimum.Z, maximum.Z } do
				local point = project(frame, Vector3.new(x, y, z), viewport, fov)
				assert(
					point.X >= position.X - 0.01 and point.X <= position.X + size.X + 0.01,
					`projected corner X {point.X} must fit [{position.X}, {position.X + size.X}]`
				)
				assert(
					point.Y >= position.Y - 0.01 and point.Y <= position.Y + size.Y + 0.01,
					`projected corner Y {point.Y} must fit [{position.Y}, {position.Y + size.Y}]`
				)
			end
		end
	end
end

return function()
	describe("StageFraming", function()
		it(
			"frames outfits closely while retaining the tallest outfit and held idle motion on the appropriate tabs",
			function()
				local spawn = Vector3.new(84.723, 54.5625, 321.501)
				local reference = CFrame.new(80.7171, 55.3988, 328.7516) * CFrame.Angles(math.rad(12), 0, 0)
				local direction = Vector3.new(reference.Position.X - spawn.X, 0, reference.Position.Z - spawn.Z).Unit
				local facing = CFrame.fromMatrix(spawn, Vector3.yAxis:Cross(-direction), Vector3.yAxis, -direction)
				local measured = {
					{
						envelope = UIConfig.Layout.WorldFraming.InventoryBody,
						minimum = Vector3.new(-2.08, -2.8, -2.12),
						maximum = Vector3.new(2.08, 4.34, 2),
					},
					{
						envelope = UIConfig.Layout.WorldFraming.InventorySkins,
						minimum = Vector3.new(-2.29, -2.8, -3.48),
						maximum = Vector3.new(3.1, 5.25, 3.29),
					},
				}
				local body = UIConfig.Layout.WorldFraming.CharacterBody
				expect(body.Minimum:Min(measured[1].minimum)).to.equal(body.Minimum)
				expect(body.Maximum:Max(measured[1].maximum)).to.equal(body.Maximum)
				for _, viewport in
					{
						Vector2.new(568, 320),
						Vector2.new(666, 374),
						Vector2.new(851, 392),
						Vector2.new(1366, 768),
						Vector2.new(1920, 1080),
					}
				do
					local world =
						ResponsiveLayout.inventoryComposition(viewport - Vector2.new(0, 58), UIConfig.Layout).world
					local padding = UIConfig.Layout.WorldFraming.PixelPadding
					local position = world.position + Vector2.new(padding, 58 + padding)
					local size = world.size - Vector2.one * padding * 2
					local frames = {}
					for _, fixture in measured do
						local points = Framing.boxPoints(facing, fixture.envelope.Minimum, fixture.envelope.Maximum)
						local frame = Framing.pointsCamera(reference, points, position, size, viewport, 50, spawn)
						table.insert(frames, frame)
						local finalDirection =
							Vector3.new(frame.Position.X - spawn.X, 0, frame.Position.Z - spawn.Z).Unit
						expect((finalDirection - direction).Magnitude < 0.0001).to.equal(true)
						for _, point in Framing.boxPoints(facing, fixture.minimum, fixture.maximum) do
							local pixel = project(frame, point, viewport, 50)
							expect(pixel.X >= position.X - 0.01 and pixel.X <= position.X + size.X + 0.01).to.equal(
								true
							)
							expect(pixel.Y >= position.Y - 0.01 and pixel.Y <= position.Y + size.Y + 0.01).to.equal(
								true
							)
						end
					end
					expect((frames[1].Position - spawn).Magnitude < (frames[2].Position - spawn).Magnitude).to.equal(
						true
					)
				end
			end
		)

		it("fits all reserved party slots without framing empty corners between the staggered platforms", function()
			local spawns = {
				Vector3.new(84.723, 54.5625, 321.501),
				Vector3.new(81.6104, 54.5625, 318.6664),
				Vector3.new(87.9489, 54.5625, 318.242),
				Vector3.new(77.9779, 54.5625, 316.1792),
			}
			local minimum, maximum = Vector3.one * math.huge, Vector3.one * -math.huge
			local points = {}
			for _, spawn in spawns do
				local low, high = spawn + Vector3.new(-3, -3, -2), spawn + Vector3.new(3, 6, 2)
				minimum, maximum = minimum:Min(low), maximum:Max(high)
				for _, x in { low.X, high.X } do
					for _, y in { low.Y, high.Y } do
						for _, z in { low.Z, high.Z } do
							table.insert(points, Vector3.new(x, y, z))
						end
					end
				end
			end
			local reference = CFrame.new(86.0276, 55.3988, 334.1032) * CFrame.Angles(math.rad(12), 0, 0)
			local target = (minimum + maximum) / 2 - Vector3.new(0, 1.5, 0)
			for _, region in
				{
					{ viewport = Vector2.new(666, 374), position = Vector2.new(18, 146), size = Vector2.new(402, 124) },
					{
						viewport = Vector2.new(1366, 768),
						position = Vector2.new(506, 243),
						size = Vector2.new(421, 507),
					},
					{
						viewport = Vector2.new(1920, 1080),
						position = Vector2.new(592, 321),
						size = Vector2.new(714, 741),
					},
				}
			do
				local frame =
					Framing.pointsCamera(reference, points, region.position, region.size, region.viewport, 50, target)
				local union = Framing.boundsCamera(
					reference,
					minimum,
					maximum,
					region.position,
					region.size,
					region.viewport,
					50,
					target
				)
				for _, spawn in spawns do
					expectBoundsInside(
						frame,
						spawn + Vector3.new(-3, -3, -2),
						spawn + Vector3.new(3, 6, 2),
						region.position,
						region.size,
						region.viewport,
						50
					)
				end
				expect((frame.Position - target).Magnitude <= (union.Position - target).Magnitude + 0.001).to.equal(
					true
				)
				if region.viewport.X > 1000 then
					expect((frame.Position - target).Magnitude < (union.Position - target).Magnitude * 0.9).to.equal(
						true
					)
				end
			end
		end)

		it("keeps a single-box camera compatible and retains the authored camera for an empty point set", function()
			local reference = CFrame.new(80.7, 55.4, 328.8) * CFrame.Angles(math.rad(12), 0, 0)
			local minimum, maximum = Vector3.new(79.223, 51.5625, 319.501), Vector3.new(90.223, 60.5625, 323.501)
			local points = {}
			for _, x in { minimum.X, maximum.X } do
				for _, y in { minimum.Y, maximum.Y } do
					for _, z in { minimum.Z, maximum.Z } do
						table.insert(points, Vector3.new(x, y, z))
					end
				end
			end
			local viewport, position, size = Vector2.new(666, 374), Vector2.new(392, 88), Vector2.new(254, 266)
			local frame = Framing.pointsCamera(reference, points, position, size, viewport, 50)
			local previous = Framing.boundsCamera(reference, minimum, maximum, position, size, viewport, 50)
			expect((frame.Position - previous.Position).Magnitude < 0.0001).to.equal(true)
			expect((frame.LookVector - previous.LookVector).Magnitude < 0.0001).to.equal(true)
			expect(Framing.pointsCamera(reference, {}, position, size, viewport, 50)).to.equal(reference)
		end)

		it("fits every party-envelope corner into offset phone and desktop windows", function()
			local reference = CFrame.new(86, 55.4, 334) * CFrame.Angles(math.rad(12), 0, 0)
			local minimum = Vector3.new(74.9779, 51.5625, 314.1792)
			local maximum = Vector3.new(90.9489, 60.5625, 323.501)
			for _, region in
				{
					{ viewport = Vector2.new(666, 374), position = Vector2.new(18, 88), size = Vector2.new(405, 182) },
					{ viewport = Vector2.new(851, 392), position = Vector2.new(77, 88), size = Vector2.new(454, 200) },
					{
						viewport = Vector2.new(1920, 1080),
						position = Vector2.new(18, 398),
						size = Vector2.new(1280, 380),
					},
				}
			do
				local frame =
					Framing.boundsCamera(reference, minimum, maximum, region.position, region.size, region.viewport, 50)
				expectBoundsInside(frame, minimum, maximum, region.position, region.size, region.viewport, 50)
				local center = project(frame, (minimum + maximum) / 2, region.viewport, 50)
				expect((center - region.position - region.size / 2).Magnitude < 0.01).to.equal(true)
			end
		end)

		it("preserves the authored viewing side and elevation in an offset inventory window", function()
			local reference = CFrame.new(80.7, 55.4, 328.8) * CFrame.Angles(math.rad(12), math.rad(25), math.rad(-4))
			local minimum, maximum = Vector3.new(79.223, 51.5625, 319.501), Vector3.new(90.223, 60.5625, 323.501)
			local viewport, position, size = Vector2.new(666, 374), Vector2.new(392, 88), Vector2.new(254, 266)
			local center = (minimum + maximum) / 2
			local viewTarget = center - Vector3.new(0, 1.5, 0)
			local frame = Framing.boundsCamera(reference, minimum, maximum, position, size, viewport, 50, viewTarget)
			local expectedDirection = (reference.Position - viewTarget).Unit
			expect(((frame.Position - center).Unit - expectedDirection).Magnitude < 0.0001).to.equal(true)
			expect(frame.Position.Y > center.Y).to.equal(true)
			expect((project(frame, center, viewport, 50) - position - size / 2).Magnitude < 0.01).to.equal(true)
			expectBoundsInside(frame, minimum, maximum, position, size, viewport, 50)
		end)

		it("retains the authored camera while the viewport or window is uninitialized", function()
			local reference = CFrame.new(86, 55.4, 334) * CFrame.Angles(math.rad(12), 0, 0)
			for _, dimensions in
				{
					{ viewport = Vector2.one, size = Vector2.new(400, 140) },
					{ viewport = Vector2.new(666, 374), size = Vector2.new(0, 140) },
					{ viewport = Vector2.new(666, 374), size = Vector2.new(400, -14) },
				}
			do
				local frame = Framing.boundsCamera(
					reference,
					Vector3.zero,
					Vector3.one,
					Vector2.zero,
					dimensions.size,
					dimensions.viewport,
					50
				)
				expect(frame).to.equal(reference)
			end
		end)

		it("accounts for foreground depth when the world window sits at the viewport edge", function()
			local minimum, maximum = Vector3.new(-6, -4, -7), Vector3.new(6, 4, 7)
			local viewport, position, size = Vector2.new(1280, 720), Vector2.new(1000, 100), Vector2.new(264, 580)
			local frame = Framing.boundsCamera(CFrame.identity, minimum, maximum, position, size, viewport, 50)
			expectBoundsInside(frame, minimum, maximum, position, size, viewport, 50)
		end)

		it("centers the scene inside desktop and landscape-phone regions", function()
			for _, viewport in { Vector2.new(1920, 1080), Vector2.new(667, 375), Vector2.new(1024, 768) } do
				local position = Vector2.new(16, 100)
				local size = Vector2.new(viewport.X * 0.64, viewport.Y - 200)
				local target = Vector3.new(0, 10005, 1000)
				local frame = Framing.camera(target, Vector2.new(25, 13), position, size, viewport, 40)
				local point = frame:PointToObjectSpace(target)
				local halfHeight = -point.Z * math.tan(math.rad(20))
				local projected = Vector2.new(
					viewport.X / 2 + point.X / halfHeight * viewport.Y / 2,
					viewport.Y / 2 - point.Y / halfHeight * viewport.Y / 2
				)
				expect(math.abs(projected.X - (position.X + size.X / 2)) < 0.01).to.equal(true)
				expect(math.abs(projected.Y - (position.Y + size.Y / 2)) < 0.01).to.equal(true)
			end
		end)

		it("moves farther away when the unobstructed viewport shrinks", function()
			local target = Vector3.zero
			local viewport = Vector2.new(1280, 720)
			local full = Framing.camera(target, Vector2.new(25, 13), Vector2.zero, viewport, viewport, 40)
			local half = Framing.camera(
				target,
				Vector2.new(25, 13),
				Vector2.zero,
				Vector2.new(viewport.X / 2, viewport.Y / 2),
				viewport,
				40
			)
			expect(half.Position.Magnitude > full.Position.Magnitude * 1.9).to.equal(true)
		end)
	end)
end
