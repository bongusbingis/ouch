-- Name: CourseGraph.spec.luau
-- Author: Jack C.
-- Description: Spec for the pure course route graph: directed reachability, ordered waypoint feasibility, and gate cut-set proofs that must reject seeded bypass fixtures (an added shortcut edge, a gate that only checks endpoints) rather than trust spec annotations.
-- Created: 2026-09-15

--!strict

local T = require(script.Parent.TestKit)
local CourseGraph = require(script.Parent.Parent.Game.Splashdown.CourseGraph)

local function node(id: string, x: number, y: number, z: number)
	return { Id = id, Beat = "test", Position = Vector3.new(x, y, z) }
end

T.describe("CourseGraph", function()
	T.it("reaches forward along a directed chain but not backward", function()
		local graph = CourseGraph.new()
		CourseGraph.addNode(graph, node("A", 0, 0, 0))
		CourseGraph.addNode(graph, node("B", 10, 0, 0))
		CourseGraph.addNode(graph, node("C", 20, 0, 0))
		CourseGraph.addEdge(graph, { From = "A", To = "B", Kind = "Walk" })
		CourseGraph.addEdge(graph, { From = "B", To = "C", Kind = "Walk" })

		T.expect(CourseGraph.canReach(graph, "A", "C")):toBeTruthy()
		T.expect(CourseGraph.canReach(graph, "C", "A")):toBeFalsy()
	end)

	T.it("proves an ordered route from every spawn through checkpoints to finish", function()
		local graph = CourseGraph.new()
		for _, id in { "Spawn1", "Spawn2", "CP1", "CP2", "Finish" } do
			CourseGraph.addNode(graph, node(id, 0, 0, 0))
		end
		CourseGraph.addEdge(graph, { From = "Spawn1", To = "CP1", Kind = "Walk" })
		CourseGraph.addEdge(graph, { From = "Spawn2", To = "CP1", Kind = "Walk" })
		CourseGraph.addEdge(graph, { From = "CP1", To = "CP2", Kind = "Walk" })
		CourseGraph.addEdge(graph, { From = "CP2", To = "Finish", Kind = "Walk" })

		local failures = CourseGraph.assertOrderedRouteFromAllSources(
			graph,
			{ "Spawn1", "Spawn2" },
			{ "CP1", "CP2", "Finish" }
		)
		T.expect(#failures):toEqual(0)
	end)

	T.it("reports the exact failing leg when a waypoint is unreachable", function()
		local graph = CourseGraph.new()
		for _, id in { "Spawn1", "CP1", "CP2", "Finish" } do
			CourseGraph.addNode(graph, node(id, 0, 0, 0))
		end
		CourseGraph.addEdge(graph, { From = "Spawn1", To = "CP1", Kind = "Walk" })
		-- CP1 -> CP2 is missing: the route is broken.
		CourseGraph.addEdge(graph, { From = "CP2", To = "Finish", Kind = "Walk" })

		local failures = CourseGraph.assertOrderedRouteFromAllSources(graph, { "Spawn1" }, { "CP1", "CP2", "Finish" })
		T.expect(#failures):toEqual(1)
		T.expect(failures[1].FromWaypoint):toEqual("CP1")
		T.expect(failures[1].ToWaypoint):toEqual("CP2")
	end)

	T.it("a gate volume across the only route is a true cut", function()
		local graph = CourseGraph.new()
		CourseGraph.addNode(graph, node("Spawn", -20, 0, 0))
		CourseGraph.addNode(graph, node("Mid", 0, 0, 0))
		CourseGraph.addNode(graph, node("Finish", 20, 0, 0))
		CourseGraph.addEdge(graph, { From = "Spawn", To = "Mid", Kind = "Walk" })
		CourseGraph.addEdge(graph, { From = "Mid", To = "Finish", Kind = "Walk" })

		local gate = { Min = Vector3.new(-5, -5, -5), Max = Vector3.new(5, 5, 5) }
		local leaks = CourseGraph.gateCutsAllRoutes(graph, { "Spawn" }, "Finish", gate)
		T.expect(#leaks):toEqual(0)
	end)

	T.it("rejects a seeded bypass edge that routes around the gate node", function()
		local graph = CourseGraph.new()
		CourseGraph.addNode(graph, node("Spawn", -20, 0, 0))
		CourseGraph.addNode(graph, node("Mid", 0, 0, 0))
		CourseGraph.addNode(graph, node("Finish", 20, 0, 0))
		CourseGraph.addEdge(graph, { From = "Spawn", To = "Mid", Kind = "Walk" })
		CourseGraph.addEdge(graph, { From = "Mid", To = "Finish", Kind = "Walk" })
		-- Seeded mutation: an unintended perimeter walkway that never enters the gate box.
		CourseGraph.addNode(graph, node("Bypass", -20, 0, 20))
		CourseGraph.addEdge(graph, { From = "Spawn", To = "Bypass", Kind = "Walk" })
		CourseGraph.addEdge(graph, { From = "Bypass", To = "Finish", Kind = "Walk" })

		local gate = { Min = Vector3.new(-5, -5, -5), Max = Vector3.new(5, 5, 5) }
		local leaks = CourseGraph.gateCutsAllRoutes(graph, { "Spawn" }, "Finish", gate)
		T.expect(#leaks):toEqual(1)
		T.expect(leaks[1]):toEqual("Spawn")
	end)

	T.it("catches a long edge that tunnels through the gate without either endpoint sitting inside it", function()
		local graph = CourseGraph.new()
		CourseGraph.addNode(graph, node("Spawn", -50, 0, 0))
		CourseGraph.addNode(graph, node("Finish", 50, 0, 0))
		-- A single "Launch" edge whose endpoints are both far outside the small gate
		-- box at the origin, but whose straight path passes directly through it.
		CourseGraph.addEdge(graph, { From = "Spawn", To = "Finish", Kind = "Launch" })

		local gate = { Min = Vector3.new(-2, -2, -2), Max = Vector3.new(2, 2, 2) }
		local leaks = CourseGraph.gateCutsAllRoutes(graph, { "Spawn" }, "Finish", gate)
		T.expect(#leaks):toEqual(0)
	end)

	T.it("only allows a state-gated edge to be used while its state is active", function()
		local graph = CourseGraph.new()
		CourseGraph.addNode(graph, node("Before", 0, 0, 0))
		CourseGraph.addNode(graph, node("After", 10, 0, 0))
		CourseGraph.addEdge(graph, { From = "Before", To = "After", Kind = "Walk", RequiresState = "DoorOpen" })

		T.expect(CourseGraph.canReach(graph, "Before", "After", { ActiveState = "DoorOpen" })):toBeTruthy()
		T.expect(CourseGraph.canReach(graph, "Before", "After", { ActiveState = "DoorClosed" })):toBeFalsy()
		T.expect(CourseGraph.canReach(graph, "Before", "After")):toBeFalsy()
	end)

	T.it("honors explicitly blocked nodes independent of gate volumes", function()
		local graph = CourseGraph.new()
		CourseGraph.addNode(graph, node("A", 0, 0, 0))
		CourseGraph.addNode(graph, node("B", 10, 0, 0))
		CourseGraph.addEdge(graph, { From = "A", To = "B", Kind = "Walk" })

		T.expect(CourseGraph.canReach(graph, "A", "B", { BlockedNodes = { B = true } })):toBeFalsy()
	end)
end)

return true
