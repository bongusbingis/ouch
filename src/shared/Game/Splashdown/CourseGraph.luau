-- Name: CourseGraph.luau
-- Author: Jack C.
-- Description: Pure walkable-route graph search and cut-set proof, with no Studio Instance dependency. CourseQA builds the Node/Edge data from real raycasts and mechanism sampling; this module only reasons about the resulting graph, so it is independently headless-tested against seeded bypass fixtures.
-- Created: 2026-09-15

--!strict

local CourseGraph = {}

export type NodeId = string
export type EdgeKind = "Walk" | "Jump" | "Launch" | "Ride"
export type Node = {
	Id: NodeId,
	Beat: string,
	Position: Vector3,
	RequiresState: string?,
}
export type Edge = {
	From: NodeId,
	To: NodeId,
	Kind: EdgeKind,
	RequiresState: string?,
	GateVolume: { Min: Vector3, Max: Vector3 }?,
}
export type Graph = {
	Nodes: { [NodeId]: Node },
	Edges: { Edge },
}

function CourseGraph.new(): Graph
	return { Nodes = {}, Edges = {} }
end

function CourseGraph.addNode(graph: Graph, node: Node)
	assert(graph.Nodes[node.Id] == nil, `[CourseGraph] duplicate node id "{node.Id}"`)
	graph.Nodes[node.Id] = node
end

function CourseGraph.addEdge(graph: Graph, edge: Edge)
	assert(graph.Nodes[edge.From] ~= nil, `[CourseGraph] edge references missing node "{edge.From}"`)
	assert(graph.Nodes[edge.To] ~= nil, `[CourseGraph] edge references missing node "{edge.To}"`)
	table.insert(graph.Edges, edge)
end

local function coordInBox(x: number, y: number, z: number, box: { Min: Vector3, Max: Vector3 }): boolean
	return x >= box.Min.X and x <= box.Max.X and y >= box.Min.Y and y <= box.Max.Y and z >= box.Min.Z and z <= box.Max.Z
end

-- An edge is cut by a gate if either endpoint sits inside the gate volume, or the
-- straight segment between them passes through it (sampled, not just endpoints:
-- a long ride/launch edge must not tunnel through a thin gate wall undetected).
-- Component-wise lerp only: the headless test Vector3 shim has no operator overloads.
local function edgeCutByGate(graph: Graph, edge: Edge, gate: { Min: Vector3, Max: Vector3 }): boolean
	local a = graph.Nodes[edge.From].Position
	local b = graph.Nodes[edge.To].Position
	local samples = 12
	for i = 0, samples do
		local t = i / samples
		local x = a.X + (b.X - a.X) * t
		local y = a.Y + (b.Y - a.Y) * t
		local z = a.Z + (b.Z - a.Z) * t
		if coordInBox(x, y, z, gate) then
			return true
		end
	end
	return false
end

export type ReachOptions = {
	BlockedNodes: { [NodeId]: boolean }?,
	Gates: { { Min: Vector3, Max: Vector3 } }?,
	ActiveState: string?,
}

-- BFS reachability under an optional set of blocked nodes and gate volumes. An edge
-- or node tagged RequiresState only participates when it matches options.ActiveState
-- (nil ActiveState means "state-agnostic query": only state-agnostic nodes/edges apply).
function CourseGraph.reachableFrom(graph: Graph, sources: { NodeId }, options: ReachOptions?): { [NodeId]: boolean }
	local opts = options or {}
	local blocked = opts.BlockedNodes or {}
	local gates = opts.Gates or {}
	local activeState = opts.ActiveState

	local adjacency: { [NodeId]: { Edge } } = {}
	for _, edge in graph.Edges do
		if edge.RequiresState ~= nil and edge.RequiresState ~= activeState then
			continue
		end
		local cut = false
		for _, gate in gates do
			if edgeCutByGate(graph, edge, gate) then
				cut = true
				break
			end
		end
		if cut then
			continue
		end
		if not adjacency[edge.From] then
			adjacency[edge.From] = {}
		end
		table.insert(adjacency[edge.From], edge)
	end

	local visited: { [NodeId]: boolean } = {}
	local queue: { NodeId } = {}
	for _, sourceId in sources do
		local node = graph.Nodes[sourceId]
		if node and not blocked[sourceId] and (node.RequiresState == nil or node.RequiresState == activeState) then
			if not visited[sourceId] then
				visited[sourceId] = true
				table.insert(queue, sourceId)
			end
		end
	end

	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, edge in adjacency[current] or {} do
			local targetNode = graph.Nodes[edge.To]
			if
				targetNode
				and not blocked[edge.To]
				and not visited[edge.To]
				and (targetNode.RequiresState == nil or targetNode.RequiresState == activeState)
			then
				visited[edge.To] = true
				table.insert(queue, edge.To)
			end
		end
	end
	return visited
end

-- Reverse reachability: every node that can still reach one of `targets` under the
-- same blocking/gate/state rules. One traversal answers "does EVERY spawn reach
-- this waypoint" and "does ANY spawn still slip past this gate", which the forward
-- form can only answer with one traversal per source.
function CourseGraph.reachingNodes(graph: Graph, targets: { NodeId }, options: ReachOptions?): { [NodeId]: boolean }
	local opts = options or {}
	local blocked = opts.BlockedNodes or {}
	local gates = opts.Gates or {}
	local activeState = opts.ActiveState

	local incoming: { [NodeId]: { Edge } } = {}
	for _, edge in graph.Edges do
		if edge.RequiresState ~= nil and edge.RequiresState ~= activeState then
			continue
		end
		local cut = false
		for _, gate in gates do
			if edgeCutByGate(graph, edge, gate) then
				cut = true
				break
			end
		end
		if cut then
			continue
		end
		if not incoming[edge.To] then
			incoming[edge.To] = {}
		end
		table.insert(incoming[edge.To], edge)
	end

	local visited: { [NodeId]: boolean } = {}
	local queue: { NodeId } = {}
	for _, targetId in targets do
		local node = graph.Nodes[targetId]
		if node and not blocked[targetId] and (node.RequiresState == nil or node.RequiresState == activeState) then
			if not visited[targetId] then
				visited[targetId] = true
				table.insert(queue, targetId)
			end
		end
	end

	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for _, edge in incoming[current] or {} do
			local sourceNode = graph.Nodes[edge.From]
			if
				sourceNode
				and not blocked[edge.From]
				and not visited[edge.From]
				and (sourceNode.RequiresState == nil or sourceNode.RequiresState == activeState)
			then
				visited[edge.From] = true
				table.insert(queue, edge.From)
			end
		end
	end
	return visited
end

function CourseGraph.canReach(graph: Graph, from: NodeId, to: NodeId, options: ReachOptions?): boolean
	local visited = CourseGraph.reachableFrom(graph, { from }, options)
	return visited[to] == true
end

-- Feasibility proof for section 8.2.7: from EVERY source, an ordered walk through
-- waypoints (checkpoints..., finish) must each be reachable from the previous stop.
export type RouteFailure = { Source: NodeId, FromWaypoint: NodeId, ToWaypoint: NodeId }
function CourseGraph.assertOrderedRouteFromAllSources(
	graph: Graph,
	sources: { NodeId },
	waypoints: { NodeId },
	options: ReachOptions?
): { RouteFailure }
	local failures: { RouteFailure } = {}
	for _, sourceId in sources do
		local previous = sourceId
		for _, waypoint in waypoints do
			if not CourseGraph.canReach(graph, previous, waypoint, options) then
				table.insert(failures, { Source = sourceId, FromWaypoint = previous, ToWaypoint = waypoint })
			end
			previous = waypoint
		end
	end
	return failures
end

-- Cut-set proof for section 8.2.8: after removing every node/edge that intersects
-- `gate`, no source may still reach `target`. Returns the list of sources that
-- illegally still reach it (empty = the gate is a true cut).
function CourseGraph.gateCutsAllRoutes(
	graph: Graph,
	sources: { NodeId },
	target: NodeId,
	gate: { Min: Vector3, Max: Vector3 },
	baseOptions: ReachOptions?
): { NodeId }
	local opts: ReachOptions = {
		BlockedNodes = (baseOptions and baseOptions.BlockedNodes) or {},
		Gates = { gate },
		ActiveState = baseOptions and baseOptions.ActiveState,
	}
	if baseOptions and baseOptions.Gates then
		local merged = table.clone(baseOptions.Gates)
		table.insert(merged, gate)
		opts.Gates = merged
	end
	local leaks: { NodeId } = {}
	for _, sourceId in sources do
		if CourseGraph.canReach(graph, sourceId, target, opts) then
			table.insert(leaks, sourceId)
		end
	end
	return leaks
end

return CourseGraph
