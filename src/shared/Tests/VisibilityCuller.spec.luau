--!strict

local T = require(script.Parent.TestKit)
local VisibilityCuller = require(script.Parent.Parent.Game.Util.VisibilityCuller)

local function makeCamera(pos: Vector3, forward: Vector3, viewport: Vector2)
	return {
		CFrame = {
			Position = pos,
		},
		ViewportSize = viewport,
		WorldToViewportPoint = function(_self, point: Vector3)
			local dx = point.X - pos.X
			local dy = point.Y - pos.Y
			local dz = point.Z - pos.Z
			local dot = dx * forward.X + dy * forward.Y + dz * forward.Z
			local distSq = dx * dx + dy * dy + dz * dz
			local isBehind = dot <= 0
			if isBehind then
				return Vector3.new(-100, -100, -1), false
			end
			local x = viewport.X / 2 + dx * 10
			local y = viewport.Y / 2 + dy * 10
			local onScreen = x >= 0 and x <= viewport.X and y >= 0 and y <= viewport.Y
			return Vector3.new(x, y, math.sqrt(distSq)), onScreen
		end,
	}
end

T.describe("VisibilityCuller", function()
	T.it("checks basic point visibility and distance cutoff", function()
		local cam = makeCamera(Vector3.new(0, 0, 0), Vector3.new(0, 0, 1), Vector2.new(800, 600))

		-- Directly in front, distance 50 studs <= 100 maxDistance
		local inView, dist = VisibilityCuller.isInView(Vector3.new(0, 0, 50), 100, 32, cam)
		T.expect(inView):toBeTruthy()
		T.expect(math.floor(dist + 0.5)):toEqual(50)

		-- Behind camera
		local behindView, _ = VisibilityCuller.isInView(Vector3.new(0, 0, -20), 100, 32, cam)
		T.expect(behindView):toBeFalsy()

		-- Beyond maxDistance
		local farView, farDist = VisibilityCuller.isInView(Vector3.new(0, 0, 150), 100, 32, cam)
		T.expect(farView):toBeFalsy()
		T.expect(math.floor(farDist + 0.5)):toEqual(150)
	end)

	T.it("supports viewport edge margins", function()
		local cam = makeCamera(Vector3.new(0, 0, 0), Vector3.new(0, 0, 1), Vector2.new(800, 600))

		-- Positioned slightly outside screen bounds: x = 800 / 2 + 42 * 10 = 820 px (> 800, but <= 800 + 32)
		local insideMargin, _ = VisibilityCuller.isInView(Vector3.new(42, 0, 10), 100, 32, cam)
		T.expect(insideMargin):toBeTruthy()

		-- Far outside margin: x = 800 / 2 + 60 * 10 = 1000 px (> 832)
		local outsideMargin, _ = VisibilityCuller.isInView(Vector3.new(60, 0, 10), 100, 32, cam)
		T.expect(outsideMargin):toBeFalsy()
	end)

	T.it("tracks entries and enforces capacity limits (maxVisible)", function()
		local cam = makeCamera(Vector3.new(0, 0, 0), Vector3.new(0, 0, 1), Vector2.new(800, 600))
		local group = VisibilityCuller.createGroup({
			activateDistance = 100,
			deactivateDistance = 120,
			viewportMarginPx = 32,
			maxVisible = 2, -- Only allow top 2
			checkHz = 1000,
			camera = cam,
		})

		local visibleMap = {}
		local trackOptions = function(id: string, zPos: number)
			return {
				target = Vector3.new(0, 0, zPos),
				onVisible = function()
					visibleMap[id] = true
				end,
				onHidden = function()
					visibleMap[id] = false
				end,
			}
		end

		group.track("p1", trackOptions("p1", 20)) -- nearest (dist 20)
		group.track("p2", trackOptions("p2", 40)) -- second nearest (dist 40)
		group.track("p3", trackOptions("p3", 60)) -- third (dist 60)

		group.step(1) -- trigger evaluation

		-- p1 and p2 should be visible, p3 should be culled by capacity
		T.expect(visibleMap["p1"]):toBeTruthy()
		T.expect(visibleMap["p2"]):toBeTruthy()
		T.expect(visibleMap["p3"]):toBeFalsy()
		T.expect(group.countVisible()):toEqual(2)

		-- Untrack p1, step again -> p3 should now be promoted to visible!
		group.untrack("p1")
		T.expect(visibleMap["p1"]):toBeFalsy()

		group.step(1)
		T.expect(visibleMap["p2"]):toBeTruthy()
		T.expect(visibleMap["p3"]):toBeTruthy()
		T.expect(group.countVisible()):toEqual(2)

		group.destroy()
		T.expect(visibleMap["p2"]):toBeFalsy()
		T.expect(visibleMap["p3"]):toBeFalsy()
		T.expect(group.countVisible()):toEqual(0)
	end)

	T.it("respects distance hysteresis", function()
		local cam = makeCamera(Vector3.new(0, 0, 0), Vector3.new(0, 0, 1), Vector2.new(800, 600))
		local group = VisibilityCuller.createGroup({
			activateDistance = 50,
			deactivateDistance = 70,
			viewportMarginPx = 32,
			maxVisible = 10,
			checkHz = 1000,
			camera = cam,
		})

		local isVis = false
		group.track("target", {
			target = Vector3.new(0, 0, 45),
			onChange = function(v)
				isVis = v
			end,
		})

		group.step(1)
		T.expect(isVis):toBeTruthy()

		-- Move target to 60 studs (between activate 50 and deactivate 70)
		group.updateTarget("target", Vector3.new(0, 0, 60))
		group.step(1)
		-- Hysteresis: stays visible because it has not exceeded deactivateDistance
		T.expect(isVis):toBeTruthy()

		-- Move target to 75 studs (beyond deactivate 70)
		group.updateTarget("target", Vector3.new(0, 0, 75))
		group.step(1)
		T.expect(isVis):toBeFalsy()

		-- Move target back to 60 studs: does NOT activate because activateDistance is 50
		group.updateTarget("target", Vector3.new(0, 0, 60))
		group.step(1)
		T.expect(isVis):toBeFalsy()

		-- Move target back to 40 studs: now activates!
		group.updateTarget("target", Vector3.new(0, 0, 40))
		group.step(1)
		T.expect(isVis):toBeTruthy()

		group.destroy()
	end)
end)

return true
