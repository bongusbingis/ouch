-- One bounded update loop serves visible UI previews and stops when the last preview unmounts.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI")).Preview
local PreviewScheduler = {}
local active = {}
local pending = {}
local connection: RBXScriptConnection? = nil
local accumulator = 0

local function overlaps(position: Vector2, size: Vector2, clipPosition: Vector2, clipSize: Vector2): boolean
	return position.X < clipPosition.X + clipSize.X
		and position.X + size.X > clipPosition.X
		and position.Y < clipPosition.Y + clipSize.Y
		and position.Y + size.Y > clipPosition.Y
end

function PreviewScheduler.isVisible(viewport: GuiObject): boolean
	if viewport.Parent == nil then
		return false
	end
	local ancestor: Instance? = viewport
	while ancestor do
		if ancestor:IsA("GuiObject") then
			if not ancestor.Visible then
				return false
			end
			if ancestor ~= viewport and (ancestor.ClipsDescendants or ancestor:IsA("ScrollingFrame")) then
				local size = if ancestor:IsA("ScrollingFrame")
					then ancestor.AbsoluteWindowSize
					else ancestor.AbsoluteSize
				if not overlaps(viewport.AbsolutePosition, viewport.AbsoluteSize, ancestor.AbsolutePosition, size) then
					return false
				end
			end
		elseif ancestor:IsA("ScreenGui") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end
	local camera = Workspace.CurrentCamera
	return camera ~= nil
		and overlaps(viewport.AbsolutePosition, viewport.AbsoluteSize, Vector2.zero, camera.ViewportSize)
end

local function idle(): boolean
	return next(active) == nil and next(pending) == nil
end

local function stopWhenIdle()
	if idle() and connection then
		connection:Disconnect()
		connection = nil
		accumulator = 0
	end
end

-- A page that mounts twenty previews at once would otherwise clone twenty
-- models in one frame. Each preview waits here until it is actually on screen,
-- and only a few are handed their model per frame, so opening a page costs the
-- previews the player can see rather than every preview in the scroll canvas.
local function runBuilds()
	if next(pending) == nil then
		return
	end
	local budget = Config.BuildsPerFrame
	local finished: { any } = {}
	for entry in pending do
		if budget <= 0 then
			break
		end
		if entry.viewport.Parent == nil then
			table.insert(finished, entry)
		elseif PreviewScheduler.isVisible(entry.viewport) then
			table.insert(finished, entry)
			budget -= 1
			-- Building may yield on an asset that has not replicated yet, so it
			-- runs on its own thread and cannot stall the frame loop.
			task.spawn(function()
				local ok, err = pcall(entry.build)
				if not ok then
					warn(`[PreviewScheduler] preview build failed: {err}`)
				end
			end)
		end
	end
	for _, entry in finished do
		pending[entry] = nil
	end
end

local function step(dt: number)
	runBuilds()
	accumulator += dt
	if accumulator < 1 / Config.MaxHz then
		stopWhenIdle()
		return
	end
	local budget = math.min(accumulator, Config.MaxDeltaSeconds)
	accumulator = 0
	for preview in active do
		if PreviewScheduler.isVisible(preview.viewport) then
			preview.elapsed += budget
			if preview.elapsed >= preview.interval then
				local elapsed = preview.elapsed
				preview.elapsed = 0
				local ok, err = pcall(preview.update, elapsed)
				if not ok then
					active[preview] = nil
					warn(`[PreviewScheduler] preview update failed: {err}`)
				end
			end
		else
			preview.elapsed = 0
		end
	end
	stopWhenIdle()
end

local function ensureConnection()
	if connection == nil then
		connection = RunService.RenderStepped:Connect(step)
	end
end

-- Hands `build` back once the viewport is on screen and the frame has room for
-- it. Cancelling before it runs drops the work entirely, so a card scrolled
-- past or unmounted during a page change never builds its model.
function PreviewScheduler.build(viewport: GuiObject, build: () -> ()): () -> ()
	local entry = { viewport = viewport, build = build }
	pending[entry] = true
	ensureConnection()
	return function()
		pending[entry] = nil
		stopWhenIdle()
	end
end

function PreviewScheduler.register(viewport: GuiObject, update: (number) -> (), rate: number?): () -> ()
	local entry = {
		viewport = viewport,
		update = update,
		interval = 1 / math.clamp(rate or Config.MaxHz, 1, Config.MaxHz),
		elapsed = 0,
	}
	active[entry] = true
	ensureConnection()
	return function()
		active[entry] = nil
		stopWhenIdle()
	end
end

return PreviewScheduler
