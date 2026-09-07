-- Camera projection must center the stage in its UI region rather than beneath the reward panel.
--!strict
local Framing = require(game.ReplicatedStorage.Shared.UI.Models.StageFraming)

return function()
	describe("StageFraming", function()
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
