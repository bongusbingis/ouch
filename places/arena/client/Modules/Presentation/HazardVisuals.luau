-- Visual-only overlays for hazard feedback. Source parts remain untouched.
--!strict
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Network = require(RS.Shared.Network)
local HazardVisuals = {}

type Modifier = { offset: CFrame, scale: Vector3, hidden: boolean }
type State = { ghost: BasePart, transparency: number, modifiers: { [string]: Modifier } }
local active: { [BasePart]: State } = {}
type TileState = { revision: number, state: string, dropAt: number? }
local tileStates: { [BasePart]: TileState } = {}
local watched: { [BasePart]: { RBXScriptConnection } } = {}
local rootConnections: { [Instance]: { RBXScriptConnection } } = {}
local timed: { [BasePart]: { [string]: { generation: number, connection: RBXScriptConnection? } } } = {}
local render: RBXScriptConnection? = nil
local remote: RBXScriptConnection? = nil
local rootAdded: RBXScriptConnection? = nil
local rootRemoved: RBXScriptConnection? = nil

local function cloneVisual(part: BasePart): BasePart
	local ghost = part:Clone()
	for _, child in ghost:GetChildren() do
		if
			not child:IsA("DataModelMesh")
			and not child:IsA("Decal")
			and not child:IsA("Texture")
			and not child:IsA("SurfaceAppearance")
		then
			child:Destroy()
		end
	end
	ghost.Name = "HazardVisualGhost"
	for _, tag in CollectionService:GetTags(ghost) do
		CollectionService:RemoveTag(ghost, tag)
	end
	for name in ghost:GetAttributes() do
		ghost:SetAttribute(name, nil)
	end
	ghost.Anchored, ghost.CanCollide, ghost.CanTouch, ghost.CanQuery = true, false, false, false
	ghost.Parent = Workspace
	return ghost
end

local function clearTimers(part: BasePart)
	local entries = timed[part]
	if not entries then
		return
	end
	for _, entry in entries do
		if entry.connection then
			entry.connection:Disconnect()
		end
	end
	timed[part] = nil
end

local function clearState(part: BasePart)
	local state = active[part]
	if not state then
		return
	end
	clearTimers(part)
	if part.Parent then
		part.LocalTransparencyModifier = state.transparency
	end
	state.ghost:Destroy()
	active[part] = nil
end

local function stateFor(part: BasePart): State?
	if not part:IsDescendantOf(Workspace) then
		return nil
	end
	local state = active[part]
	if state then
		return state
	end
	state = { ghost = cloneVisual(part), transparency = part.LocalTransparencyModifier, modifiers = {} }
	active[part] = state
	part.LocalTransparencyModifier = 1
	return state
end

-- Effects compose by key. The returned function is safe to call repeatedly.
function HazardVisuals.setEffect(
	part: BasePart,
	key: string,
	offset: CFrame?,
	scale: Vector3?,
	hidden: boolean?
): () -> ()
	local state = stateFor(part)
	if not state then
		return function() end
	end
	state.modifiers[key] = { offset = offset or CFrame.identity, scale = scale or Vector3.one, hidden = hidden == true }
	local cleared = false
	return function()
		if cleared then
			return
		end
		cleared = true
		local current = active[part]
		if not current then
			return
		end
		current.modifiers[key] = nil
		if next(current.modifiers) == nil then
			clearState(part)
		end
	end
end

local function setTimed(part: BasePart, key: string, kind: string, duration: number)
	local timers = timed[part]
	if not timers then
		timers = {}
		timed[part] = timers
	end
	local prior = timers[key]
	if prior and prior.connection then
		prior.connection:Disconnect()
	end
	local generation = if prior then prior.generation + 1 else 1
	local entry = { generation = generation, connection = nil }
	timers[key] = entry
	local started = os.clock()
	local clear = HazardVisuals.setEffect(part, key)
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		if timed[part] ~= timers or timers[key] ~= entry or entry.generation ~= generation then
			if connection then
				connection:Disconnect()
			end
			return
		end
		local t = os.clock() - started
		if t >= duration or not part.Parent then
			if connection then
				connection:Disconnect()
			end
			timers[key] = nil
			clear()
			return
		end
		local envelope = 1 - t / duration
		if kind == "shake" then
			HazardVisuals.setEffect(part, key, CFrame.Angles(0, 0, math.sin(t * 70) * 0.035 * envelope))
		else
			local squash = math.sin(t * math.pi / duration) * 0.12 * envelope
			HazardVisuals.setEffect(part, key, CFrame.identity, Vector3.new(1 + squash / 2, 1 - squash, 1 + squash / 2))
		end
	end)
	entry.connection = connection
end

local function reconcileTile(part: BasePart)
	local revision, tileState = part:GetAttribute("HazardTileRevision"), part:GetAttribute("HazardTileState")
	local dropAt = part:GetAttribute("HazardTileDropAt")
	if typeof(revision) ~= "number" or typeof(tileState) ~= "string" then
		return
	end
	local numericDropAt = if typeof(dropAt) == "number" then dropAt else nil
	local observed = tileStates[part]
	if
		observed
		and observed.revision == revision
		and observed.state == tileState
		and observed.dropAt == numericDropAt
	then
		return
	end
	tileStates[part] = { revision = revision, state = tileState, dropAt = numericDropAt }
	if tileState == "hidden" then
		HazardVisuals.setEffect(part, "tile", CFrame.identity, Vector3.one, true)
	elseif tileState == "solid" then
		local state = active[part]
		if state then
			state.modifiers.tile = nil
			if next(state.modifiers) == nil then
				clearState(part)
			end
		end
	elseif tileState == "armed" then
		local remaining = if numericDropAt
			then math.clamp(numericDropAt - Workspace:GetServerTimeNow(), 0.05, 2)
			else 0.35
		setTimed(part, "tile", "shake", remaining)
	end
end

local function watch(part: BasePart)
	if watched[part] then
		return
	end
	watched[part] = {
		part:GetAttributeChangedSignal("HazardTileState"):Connect(function()
			reconcileTile(part)
		end),
		part:GetAttributeChangedSignal("HazardTileRevision"):Connect(function()
			reconcileTile(part)
		end),
		part:GetAttributeChangedSignal("HazardTileDropAt"):Connect(function()
			reconcileTile(part)
		end),
	}
	reconcileTile(part)
end

local function unwatch(part: BasePart)
	local connections = watched[part]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		watched[part] = nil
	end
	clearState(part)
	tileStates[part] = nil
end

local function addRoot(root: Instance)
	if rootConnections[root] then
		return
	end
	local connections = {
		root.DescendantAdded:Connect(function(instance)
			if instance:IsA("BasePart") then
				watch(instance)
			end
		end),
		root.DescendantRemoving:Connect(function(instance)
			if instance:IsA("BasePart") then
				unwatch(instance)
			end
		end),
	}
	rootConnections[root] = connections
	for _, instance in root:GetDescendants() do
		if instance:IsA("BasePart") then
			watch(instance)
		end
	end
end

local function removeRoot(root: Instance)
	local connections = rootConnections[root]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
		rootConnections[root] = nil
	end
	for part in watched do
		if part:IsDescendantOf(root) then
			unwatch(part)
		end
	end
end

function HazardVisuals.start()
	if render then
		return
	end
	remote = Network.on("HazardVisual", function(part, kind, duration)
		if
			typeof(part) == "Instance"
			and part:IsA("BasePart")
			and (kind == "impact" or kind == "shake")
			and typeof(duration) == "number"
		then
			setTimed(part, "event", kind, math.clamp(duration, 0.05, 10))
		end
	end)
	render = RunService.RenderStepped:Connect(function()
		for part, state in active do
			if not part.Parent or part.Transparency >= 1 then
				clearState(part)
				continue
			end
			local offset, scale, hidden = CFrame.identity, Vector3.one, false
			for _, key in { "bumper", "jumpPad", "event", "tile", "door" } do
				local modifier = state.modifiers[key]
				if modifier then
					offset *= modifier.offset
					scale *= modifier.scale
					hidden = hidden or modifier.hidden
				end
			end
			state.ghost.CFrame, state.ghost.Size = part.CFrame * offset, part.Size * scale
			state.ghost.Transparency = if hidden then 1 else part.Transparency
		end
	end)
	rootAdded = CollectionService:GetInstanceAddedSignal("ScriptableRoot"):Connect(addRoot)
	rootRemoved = CollectionService:GetInstanceRemovedSignal("ScriptableRoot"):Connect(removeRoot)
	for _, root in CollectionService:GetTagged("ScriptableRoot") do
		addRoot(root)
	end
end

function HazardVisuals.stop()
	for _, connection in { render, remote, rootAdded, rootRemoved } do
		if connection then
			connection:Disconnect()
		end
	end
	render, remote, rootAdded, rootRemoved = nil, nil, nil, nil
	for part in active do
		clearState(part)
	end
	for root in rootConnections do
		removeRoot(root)
	end
	table.clear(watched)
	table.clear(tileStates)
	table.clear(timed)
end
return HazardVisuals
