--!strict

-- Shared client-side animator for script cosmetic effects. It owns one
-- self-idling RenderStepped connection and destroys every registered root.

local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Runtime = {}

export type Layer = "Hero" | "Secondary" | "Tertiary"

export type Scope = {
	parent: Instance,
	camera: (() -> CFrame)?,
	destroyed: boolean,
	roots: { [Instance]: RBXScriptConnection },
}

export type Options = {
	delay: number?,
	layer: Layer?,
}

export type Stats = {
	activeAnimations: number,
	temporaryInstances: number,
	updateLoopActive: boolean,
}

type Animation = {
	root: Instance,
	scope: Scope?,
	duration: number,
	delay: number,
	elapsed: number,
	layer: Layer,
	update: (alpha: number, elapsed: number, delta: number) -> (),
}

local CONTAINER_NAME = "CosmeticEffects"
local MAX_ACTIVE = 320
local LAYER_LIMITS: { [Layer]: number } = {
	Hero = MAX_ACTIVE,
	Secondary = 270,
	Tertiary = 210,
}

local active: { Animation } = {}
local connection: RBXScriptConnection? = nil
local container: Folder? = nil
local listeners: { [number]: (Stats) -> () } = {}
local nextListenerId = 0
local owners: { [Instance]: Scope } = {}

local function effectContainer(): Folder
	if container ~= nil and container.Parent ~= nil then
		return container
	end
	local existing = Workspace:FindFirstChild(CONTAINER_NAME)
	if existing ~= nil then
		assert(existing:IsA("Folder"), `[CosmeticEffectRuntime] Workspace.{CONTAINER_NAME} must be a Folder`)
		container = existing
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = CONTAINER_NAME
	folder.Parent = Workspace
	container = folder
	return folder
end

function Runtime.container(scope: Scope?): Instance
	if scope then
		assert(not scope.destroyed, "[CosmeticEffectRuntime] scope is closed")
		return scope.parent
	end
	return effectContainer()
end

function Runtime.createScope(parent: Instance, camera: (() -> CFrame)?): Scope
	assert(parent:IsDescendantOf(Workspace), "[CosmeticEffectRuntime] scope must be in Workspace")
	return { parent = parent, camera = camera, destroyed = false, roots = {} }
end

function Runtime.mount(root: Instance, scope: Scope?)
	if scope and scope.destroyed then
		root:Destroy()
		error("[CosmeticEffectRuntime] cannot mount into a closed scope")
	end
	root.Parent = Runtime.container(scope)
	if scope then
		owners[root] = scope
		scope.roots[root] = root.Destroying:Once(function()
			owners[root] = nil
			scope.roots[root] = nil
		end)
	end
end

function Runtime.stats(): Stats
	local folder = effectContainer()
	return {
		activeAnimations = #active,
		temporaryInstances = #folder:GetDescendants(),
		updateLoopActive = connection ~= nil,
	}
end

local function notify()
	if next(listeners) == nil then
		return
	end
	local snapshot = Runtime.stats()
	for _, listener in listeners do
		local ok, err = pcall(listener, snapshot)
		if not ok then
			warn(`[CosmeticEffectRuntime] stats listener failed: {err}`)
		end
	end
end

local function disconnectIfIdle()
	if #active == 0 and connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
end

local function removeAt(index: number)
	local animation = active[index]
	if animation.root.Parent ~= nil then
		animation.root:Destroy()
	end
	table.remove(active, index)
end

local function step(delta: number)
	local changed = false
	for index = #active, 1, -1 do
		local animation = active[index]
		animation.elapsed += delta
		local localElapsed = animation.elapsed - animation.delay
		if localElapsed < 0 then
			continue
		end
		local alpha = math.clamp(localElapsed / animation.duration, 0, 1)
		local ok, err = pcall(animation.update, alpha, localElapsed, delta)
		if not ok then
			warn(`[CosmeticEffectRuntime] animation failed: {err}`)
		end
		if not ok or alpha >= 1 or animation.root.Parent == nil then
			removeAt(index)
			changed = true
		end
	end
	disconnectIfIdle()
	if changed then
		notify()
	end
end

local function startIfNeeded()
	if connection == nil then
		connection = RunService.RenderStepped:Connect(step)
	end
end

local function freeHeroSlot(scope: Scope?): boolean
	for _, layer in { "Tertiary", "Secondary" } :: { Layer } do
		for index = #active, 1, -1 do
			if active[index].layer == layer and active[index].scope == scope then
				removeAt(index)
				return true
			end
		end
	end
	return false
end

function Runtime.canSpawn(layer: Layer?, scope: Scope?): boolean
	local resolved = layer or "Secondary"
	local count = 0
	for _, animation in active do
		if animation.scope == scope then
			count += 1
		end
	end
	return (scope == nil or not scope.destroyed) and count < LAYER_LIMITS[resolved]
end

function Runtime.add(
	root: Instance,
	duration: number,
	update: (alpha: number, elapsed: number, delta: number) -> (),
	options: Options?
): boolean
	assert(duration > 0, "[CosmeticEffectRuntime] duration must be positive")
	local layer = if options and options.layer then options.layer else "Secondary"
	local scope = owners[root]
	if not Runtime.canSpawn(layer, scope) and (layer ~= "Hero" or not freeHeroSlot(scope)) then
		root:Destroy()
		return false
	end
	if root.Parent == nil then
		root.Parent = effectContainer()
	end
	table.insert(active, {
		root = root,
		scope = scope,
		duration = duration,
		delay = if options and options.delay then math.max(options.delay, 0) else 0,
		elapsed = 0,
		layer = layer,
		update = update,
	})
	startIfNeeded()
	notify()
	return true
end

function Runtime.scaledCount(count: number, layer: Layer): number
	local factor = 1
	if GuiService.ReducedMotionEnabled then
		factor = if layer == "Hero" then 1 else if layer == "Secondary" then 0.7 else 0
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		factor = if layer == "Hero" then 1 else if layer == "Secondary" then 0.8 else 0.55
	end
	local minimum = if layer == "Hero" and count > 0 then 1 else 0
	return math.max(math.floor(count * factor + 0.5), minimum)
end

function Runtime.observeStats(listener: (Stats) -> ()): () -> ()
	nextListenerId += 1
	local id = nextListenerId
	listeners[id] = listener
	listener(Runtime.stats())
	return function()
		listeners[id] = nil
	end
end

function Runtime.destroyScope(scope: Scope)
	if scope.destroyed then
		return
	end
	scope.destroyed = true
	for index = #active, 1, -1 do
		if active[index].scope == scope then
			removeAt(index)
		end
	end
	local roots = table.clone(scope.roots)
	table.clear(scope.roots)
	for root, signal in roots do
		signal:Disconnect()
		owners[root] = nil
	end
	for root in roots do
		root:Destroy()
	end
	disconnectIfIdle()
	notify()
end

function Runtime.clear()
	for index = #active, 1, -1 do
		if active[index].scope == nil then
			removeAt(index)
		end
	end
	disconnectIfIdle()
	notify()
end

return Runtime
