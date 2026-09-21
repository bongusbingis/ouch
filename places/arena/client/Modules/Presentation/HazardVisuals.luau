-- Visual-only overlays for hazard feedback. Source parts remain untouched.
--!strict
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Network = require(RS.Shared.Network)
local MapFeatures = require(RS.Config.Gameplay.MapFeatures)
local HazardVisuals = {}

type Modifier = { offset: CFrame, scale: Vector3, hidden: boolean }
type State = { ghost: BasePart, transparency: number, modifiers: { [string]: Modifier } }
local active: { [BasePart]: State } = {}
type TileState = { revision: number, state: string, dropAt: number? }
local tileStates: { [BasePart]: TileState } = {}
local watched: { [BasePart]: { RBXScriptConnection } } = {}
local rootConnections: { [Instance]: { RBXScriptConnection } } = {}
type TimedEffect = { started: number, duration: number, kind: string, startAmount: number? }
type Pulse = { started: number, duration: number, opacity: number, highlight: Highlight? }
local timed: { [BasePart]: { [string]: TimedEffect } } = {}
local pulses: { [BasePart]: Pulse } = {}
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
	for _, descendant in ghost:GetDescendants() do
		for _, tag in CollectionService:GetTags(descendant) do
			CollectionService:RemoveTag(descendant, tag)
		end
		for name in descendant:GetAttributes() do
			descendant:SetAttribute(name, nil)
		end
	end
	ghost.Anchored, ghost.CanCollide, ghost.CanTouch, ghost.CanQuery = true, false, false, false
	ghost.Parent = Workspace
	return ghost
end

local function clearTimers(part: BasePart)
	timed[part] = nil
	local pulse = pulses[part]
	if pulse then
		if pulse.highlight then
			pulse.highlight:Destroy()
		end
		pulses[part] = nil
	end
end

local function clearState(part: BasePart)
	local state = active[part]
	if not state then
		return
	end
	local pulse = pulses[part]
	if pulse and pulse.highlight and pulse.highlight.Parent == state.ghost then
		pulse.highlight:Destroy()
		pulse.highlight = nil
	end
	pcall(function()
		part.LocalTransparencyModifier = state.transparency
	end)
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
	local success, ghost = pcall(cloneVisual, part)
	if not success or not ghost then
		return nil
	end
	state = { ghost = ghost, transparency = part.LocalTransparencyModifier, modifiers = {} }
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
		if current ~= state then
			return
		end
		current.modifiers[key] = nil
		if next(current.modifiers) == nil then
			clearState(part)
		end
	end
end

local function smoothstep(value: number): number
	local s = math.clamp(value, 0, 1)
	return s * s * (3 - 2 * s)
end

local function between(t: number, firstTime: number, firstValue: number, lastTime: number, lastValue: number): number
	return firstValue + (lastValue - firstValue) * smoothstep((t - firstTime) / (lastTime - firstTime))
end

local function softAmount(t: number, startAmount: number): number
	if t < 0.055 then
		return between(t, 0, startAmount, 0.055, 1)
	elseif t < 0.15 then
		return between(t, 0.055, 1, 0.15, -0.35)
	end
	return between(t, 0.15, -0.35, 0.34, 0)
end

local function bigBallScale(part: BasePart, amount: number): Vector3
	local size = part.Size
	if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
		return Vector3.one
	end
	local q = math.min(0.09, 0.9 / size.Y, 0.88 / size.X, 0.88 / size.Z)
	local compression = q * amount
	return Vector3.new(1 + compression / 2, 1 - compression, 1 + compression / 2)
end

function HazardVisuals.pulse(part: BasePart, duration: number, opacity: number)
	if not part:IsDescendantOf(Workspace) or part.Transparency >= 1 then
		return
	end
	if not pulses[part] then
		local count = 0
		for _ in pulses do
			count += 1
		end
		if count >= 16 then
			return
		end
	end
	local previous = pulses[part]
	pulses[part] = {
		started = os.clock(),
		duration = duration,
		opacity = opacity,
		highlight = if previous then previous.highlight else nil,
	}
end

local function setTimed(part: BasePart, key: string, kind: string, duration: number)
	if not part:IsDescendantOf(Workspace) then
		return
	end
	local hard = kind == "impact" and typeof(part:GetAttribute(MapFeatures.Attributes.Rotor)) == "string"
	local bigBall = kind == "impact"
		and not hard
		and part:GetAttribute(MapFeatures.Attributes.BigBall) == true
		and part:GetAttribute(MapFeatures.Attributes.BeachBall) ~= true
	if bigBall then
		kind = "bigBall"
		duration = 0.34
	elseif hard then
		kind = "hard"
		duration = 0.16
	end
	if key == "event" and kind == "impact" then
		HazardVisuals.pulse(part, math.min(duration, 0.2), 0.16)
	elseif key == "event" and (bigBall or hard) then
		HazardVisuals.pulse(part, 0.2, 0.16)
	end
	if hard then
		local timers = timed[part]
		if timers then
			timers.event = nil
		end
		local state = active[part]
		if state then
			state.modifiers.event = nil
			if next(state.modifiers) == nil then
				clearState(part)
			end
		end
		return
	end
	local state = stateFor(part)
	if not state then
		return
	end
	local timers = timed[part]
	if not timers then
		timers = {}
		timed[part] = timers
	end
	local now = os.clock()
	local startAmount = 0
	local prior = timers[key]
	if kind == "bigBall" and prior and prior.kind == "bigBall" and not GuiService.ReducedMotionEnabled then
		local elapsed = now - prior.started
		if elapsed < prior.duration then
			startAmount = softAmount(elapsed, prior.startAmount or 0)
		end
	end
	timers[key] = { started = now, duration = duration, kind = kind, startAmount = startAmount }
	state.modifiers[key] = {
		offset = CFrame.identity,
		scale = if kind == "bigBall" then bigBallScale(part, startAmount) else Vector3.one,
		hidden = false,
	}
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
		if timed[part] then
			timed[part].tile = nil
		end
		HazardVisuals.setEffect(part, "tile", CFrame.identity, Vector3.one, true)
	elseif tileState == "solid" then
		if timed[part] then
			timed[part].tile = nil
		end
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
	clearTimers(part)
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
			and duration == duration
			and duration > -math.huge
			and duration < math.huge
		then
			setTimed(part, "event", kind, math.clamp(duration, 0.05, 10))
		end
	end)
	render = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local reducedMotion = GuiService.ReducedMotionEnabled
		for part, timers in timed do
			if not part:IsDescendantOf(Workspace) then
				clearTimers(part)
				clearState(part)
				continue
			end
			local state = active[part]
			for key, timer in timers do
				local t = now - timer.started
				if t >= timer.duration then
					timers[key] = nil
					if state then
						state.modifiers[key] = nil
					end
				elseif state then
					local offset, scale = CFrame.identity, Vector3.one
					if timer.kind == "bigBall" then
						if not reducedMotion then
							scale = bigBallScale(part, softAmount(t, timer.startAmount or 0))
						end
					elseif timer.kind == "shake" then
						local envelope = 1 - t / timer.duration
						offset = CFrame.Angles(0, 0, math.sin(t * 70) * 0.035 * envelope)
					elseif not reducedMotion then
						local envelope = 1 - t / timer.duration
						local squash = math.sin(t * math.pi / timer.duration) * 0.12 * envelope
						scale = Vector3.new(1 + squash / 2, 1 - squash, 1 + squash / 2)
					end
					state.modifiers[key] = { offset = offset, scale = scale, hidden = false }
				end
			end
			if next(timers) == nil then
				timed[part] = nil
			end
			if state and next(state.modifiers) == nil then
				clearState(part)
			end
		end
		for part, state in active do
			if not part:IsDescendantOf(Workspace) or part.Transparency >= 1 then
				clearTimers(part)
				clearState(part)
				continue
			end
			local offset, scale, hidden = CFrame.identity, Vector3.one, false
			for _, key in { "bumper", "jumpPad", "event", "tile", "door" } do
				local modifier = state.modifiers[key]
				if modifier and not (reducedMotion and (key == "bumper" or key == "jumpPad" or key == "event")) then
					offset *= modifier.offset
					scale *= modifier.scale
					hidden = hidden or modifier.hidden
				end
			end
			state.ghost.CFrame, state.ghost.Size = part.CFrame * offset, part.Size * scale
			state.ghost.Transparency = if hidden then 1 else part.Transparency
		end
		for part, pulse in pulses do
			local elapsed = now - pulse.started
			if elapsed >= pulse.duration or not part:IsDescendantOf(Workspace) or part.Transparency >= 1 then
				if pulse.highlight then
					pulse.highlight:Destroy()
				end
				pulses[part] = nil
				continue
			end
			local state = active[part]
			local target = if state then state.ghost else part
			if target.Transparency >= 1 then
				if pulse.highlight then
					pulse.highlight.Enabled = false
				end
				continue
			end
			local highlight = pulse.highlight
			if not highlight then
				local success, created = pcall(Instance.new, "Highlight")
				if not success or not created then
					pulses[part] = nil
					continue
				end
				highlight = created
				highlight.Name = "HazardImpactHighlight"
				highlight.DepthMode = Enum.HighlightDepthMode.Occluded
				highlight.FillColor = Color3.new(1, 1, 1)
				highlight.OutlineTransparency = 1
				pulse.highlight = highlight
			end
			highlight.Adornee = target
			highlight.Parent = target
			highlight.Enabled = true
			local strength = if reducedMotion
				then if elapsed < 0.12 then math.min(pulse.opacity, 0.1) else 0
				else pulse.opacity * (1 - smoothstep(elapsed / pulse.duration))
			highlight.FillTransparency = 1 - strength
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
	for part in pulses do
		clearTimers(part)
	end
	for root in rootConnections do
		removeRoot(root)
	end
	table.clear(watched)
	table.clear(tileStates)
	table.clear(timed)
end
return HazardVisuals
