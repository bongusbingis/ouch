-- Description: Generic visibility and viewport culling manager for cosmetic effects and scene adornments (e.g. Highlights, VFX, billboarding).
-- Only activates/renders tracked targets when they fall inside the local player's camera viewport and distance limits, with a hard capacity fallback.

--!strict

local hasGame = typeof(game) == "Instance" or typeof(game) == "table"
local RunService: any = if hasGame and game.GetService then game:GetService("RunService") else nil
local Workspace: any = if hasGame and game.GetService then game:GetService("Workspace") else nil

local VisibilityCuller = {}

export type Target = Vector3 | BasePart | Model | (() -> Vector3?)

export type CullerConfig = {
	-- Distance thresholds with hysteresis (in studs)
	activateDistance: number,
	deactivateDistance: number?, -- Defaults to activateDistance * 1.15

	-- Extra margin outside screen bounds (in pixels) to prevent pop-in at viewport edges
	viewportMarginPx: number?, -- Defaults to 32

	-- Capacity fallback: maximum simultaneous active targets (e.g. 20 for Highlights to respect the 31 engine limit)
	maxVisible: number?,

	-- Throttle rate: how many times per second visibility is re-evaluated (default: 10 Hz)
	checkHz: number?,

	-- Optional camera override (useful for testing or sub-viewports)
	camera: any?,
}

export type TrackOptions = {
	target: Target,
	priorityOffset: number?, -- Higher values prioritize this target when maxVisible capacity is reached
	onVisible: (() -> ())?,
	onHidden: (() -> ())?,
	onChange: ((isVisible: boolean) -> ())?,
}

type Entry = {
	id: any,
	target: Target,
	priorityOffset: number,
	onVisible: (() -> ())?,
	onHidden: (() -> ())?,
	onChange: ((isVisible: boolean) -> ())?,
	isVisible: boolean,
}

export type Group = {
	track: (id: any, options: TrackOptions) -> () -> (),
	updateTarget: (id: any, target: Target) -> (),
	untrack: (id: any) -> (),
	isTargetVisible: (id: any) -> boolean,
	countVisible: () -> number,
	step: (delta: number) -> (),
	destroy: () -> (),
}

local function resolvePosition(target: Target): Vector3?
	local targetType = typeof(target)
	if targetType == "Vector3" then
		return target :: Vector3
	elseif
		type(target) == "table"
		and (target :: any).X ~= nil
		and (target :: any).Y ~= nil
		and (target :: any).Z ~= nil
	then
		return target :: any
	elseif targetType == "Instance" then
		local instance = target :: Instance
		if instance:IsA("BasePart") then
			return instance.Position
		elseif instance:IsA("Model") then
			local primary = instance.PrimaryPart
			if primary then
				return primary.Position
			end
			return instance:GetPivot().Position
		end
	elseif targetType == "function" then
		return (target :: () -> Vector3?)()
	end
	return nil
end

-- Fast single-point check for one-off effects (e.g. sound triggers, splat particles)
function VisibilityCuller.isInView(
	position: Vector3,
	maxDistance: number,
	marginPx: number?,
	camera: any?
): (boolean, number)
	local cam = camera or (if Workspace then Workspace.CurrentCamera else nil)
	if cam == nil then
		return false, math.huge
	end

	local camCFrame: CFrame = cam.CFrame
	local camPos = camCFrame.Position
	local dx = position.X - camPos.X
	local dy = position.Y - camPos.Y
	local dz = position.Z - camPos.Z
	local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
	if distance > maxDistance then
		return false, distance
	end

	local margin = marginPx or 32
	local projected: Vector3, onScreen: boolean = cam:WorldToViewportPoint(position)
	if projected.Z <= 0 then
		return false, distance
	end

	if margin <= 0 then
		return onScreen, distance
	end

	local viewport: Vector2 = cam.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return onScreen, distance
	end

	local inBounds = projected.X >= -margin
		and projected.X <= viewport.X + margin
		and projected.Y >= -margin
		and projected.Y <= viewport.Y + margin

	return inBounds, distance
end

-- Continuous tracker group for persistent visual adornments
function VisibilityCuller.createGroup(config: CullerConfig): Group
	local activateDist = config.activateDistance
	local deactivateDist = config.deactivateDistance or (activateDist * 1.15)
	local margin = config.viewportMarginPx or 32
	local maxVisible = config.maxVisible or math.huge
	local checkInterval = 1 / math.max(config.checkHz or 10, 1)

	local entries: { [any]: Entry } = {}
	local sinceCheck = 0
	local connection: RBXScriptConnection? = nil
	local destroyed = false

	local group = {}

	local function step(delta: number)
		if destroyed then
			return
		end

		sinceCheck += delta
		if sinceCheck < checkInterval then
			return
		end
		sinceCheck = 0

		local cam = config.camera or (if Workspace then Workspace.CurrentCamera else nil)
		if cam == nil then
			return
		end

		-- 1. Evaluate candidate visibility for each tracked entry
		type Candidate = { entry: Entry, effectiveDist: number }
		local candidates: { Candidate } = {}
		local wantsVisibleMap: { [Entry]: boolean } = {}

		for _, entry in entries do
			local pos = resolvePosition(entry.target)
			if pos == nil then
				wantsVisibleMap[entry] = false
				continue
			end

			-- Apply distance hysteresis: existing active targets use deactivateDist to avoid boundary flickering
			local threshold = if entry.isVisible then deactivateDist else activateDist
			local inView, distance = VisibilityCuller.isInView(pos, threshold, margin, cam)

			if inView then
				local effectiveDist = distance - entry.priorityOffset
				table.insert(candidates, { entry = entry, effectiveDist = effectiveDist })
			else
				wantsVisibleMap[entry] = false
			end
		end

		-- 2. Enforce hard capacity fallback if visible candidates exceed maxVisible
		if #candidates > maxVisible then
			table.sort(candidates, function(a, b)
				return a.effectiveDist < b.effectiveDist
			end)
			for i, cand in candidates do
				wantsVisibleMap[cand.entry] = (i <= maxVisible)
			end
		else
			for _, cand in candidates do
				wantsVisibleMap[cand.entry] = true
			end
		end

		-- 3. Apply state transitions
		for _, entry in entries do
			local shouldBeVisible = wantsVisibleMap[entry] == true
			if shouldBeVisible and not entry.isVisible then
				entry.isVisible = true
				if entry.onVisible then
					entry.onVisible()
				end
				if entry.onChange then
					entry.onChange(true)
				end
			elseif not shouldBeVisible and entry.isVisible then
				entry.isVisible = false
				if entry.onHidden then
					entry.onHidden()
				end
				if entry.onChange then
					entry.onChange(false)
				end
			end
		end
	end

	local function ensureLoop()
		if connection == nil and not destroyed and next(entries) ~= nil and RunService ~= nil then
			connection = RunService.Heartbeat:Connect(step)
		end
	end

	local function stopLoopIfIdle()
		if connection ~= nil and next(entries) == nil then
			connection:Disconnect()
			connection = nil
			sinceCheck = 0
		end
	end

	function group.track(id: any, options: TrackOptions): () -> ()
		if destroyed then
			return function() end
		end

		local existing = entries[id]
		if existing and existing.isVisible then
			existing.isVisible = false
			if existing.onHidden then
				existing.onHidden()
			end
			if existing.onChange then
				existing.onChange(false)
			end
		end

		local entry: Entry = {
			id = id,
			target = options.target,
			priorityOffset = options.priorityOffset or 0,
			onVisible = options.onVisible,
			onHidden = options.onHidden,
			onChange = options.onChange,
			isVisible = false,
		}
		entries[id] = entry
		ensureLoop()

		return function()
			group.untrack(id)
		end
	end

	function group.updateTarget(id: any, target: Target)
		local entry = entries[id]
		if entry then
			entry.target = target
		end
	end

	function group.untrack(id: any)
		local entry = entries[id]
		if entry == nil then
			return
		end
		entries[id] = nil
		if entry.isVisible then
			entry.isVisible = false
			if entry.onHidden then
				entry.onHidden()
			end
			if entry.onChange then
				entry.onChange(false)
			end
		end
		stopLoopIfIdle()
	end

	function group.isTargetVisible(id: any): boolean
		local entry = entries[id]
		return entry ~= nil and entry.isVisible
	end

	function group.countVisible(): number
		local count = 0
		for _, entry in entries do
			if entry.isVisible then
				count += 1
			end
		end
		return count
	end

	function group.step(delta: number)
		step(delta)
	end

	function group.destroy()
		if destroyed then
			return
		end
		destroyed = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		for _, entry in entries do
			if entry.isVisible then
				entry.isVisible = false
				if entry.onHidden then
					entry.onHidden()
				end
				if entry.onChange then
					entry.onChange(false)
				end
			end
		end
		table.clear(entries)
	end

	return group
end

return table.freeze(VisibilityCuller)
