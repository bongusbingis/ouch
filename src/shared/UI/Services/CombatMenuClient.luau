-- Description: Owns the in-combat overlay menu state shared by both places: which page is open, layered close handling, input-method awareness, and the interception hook other screens use to claim the close action.

--!strict

local Listeners = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Util")
		:WaitForChild("Listeners")
)

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
local DeviceClass = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Input"):WaitForChild("DeviceClass")
)

-- M / ButtonY (Input.Hints.Menu): MenuToggle shows the same binding as its hint.
local MENU_BINDING =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Input")).Hints.Menu

local CombatMenuClient = {}

export type Page = "Inventory" | "Shop" | "Settings"
export type InputMethod = "KeyboardMouse" | "Gamepad" | "Touch"
export type Snapshot = {
	open: boolean,
	page: Page,
	available: boolean,
	inputMethod: InputMethod,
}

local TOGGLE_ACTION = "ToggleCombatMenu"
local CURSOR_REASON = "CombatMenu"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 1

local started = false
local closeInterceptor: (() -> boolean)? = nil
local listeners: Listeners.Collection<Snapshot> = Listeners.new("CombatMenuClient", false, "listener failed")
local deviceDisconnect: (() -> ())? = nil
local state: Snapshot = {
	open = false,
	page = "Shop",
	available = false,
	inputMethod = "KeyboardMouse",
}

local function methodFor(class: DeviceClass.Class): InputMethod
	if class == "Touch" then
		return "Touch"
	elseif class == "Gamepad" then
		return "Gamepad"
	end
	return "KeyboardMouse"
end

local function publish(changes: { [string]: any })
	local nextState = table.clone(state)
	local changed = false
	for key, value in changes do
		if nextState[key] ~= value then
			nextState[key] = value
			changed = true
		end
	end
	if not changed then
		return
	end
	state = nextState :: Snapshot
	listeners.emitWith(function(callback)
		callback(state)
	end)
end

local function setOpen(open: boolean)
	local nextOpen = open and state.available
	if nextOpen == state.open then
		return
	end
	if nextOpen then
		Combat.requestCursor(CURSOR_REASON)
	else
		Combat.releaseCursor(CURSOR_REASON)
	end
	publish({ open = nextOpen })
end

local function closeTopLayer(): boolean
	if closeInterceptor == nil then
		return false
	end
	local ok, handled = pcall(closeInterceptor)
	if not ok then
		warn(`[CombatMenuClient] close interceptor failed: {handled}`)
		return false
	end
	return handled == true
end

local function handleToggle(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if not state.available or UserInputService:GetFocusedTextBox() ~= nil then
		return Enum.ContextActionResult.Pass
	end
	if inputState == Enum.UserInputState.Begin then
		if state.open and closeTopLayer() then
			return Enum.ContextActionResult.Sink
		end
		setOpen(not state.open)
	end
	return Enum.ContextActionResult.Sink
end

function CombatMenuClient.start()
	if started then
		return
	end
	started = true
	deviceDisconnect = DeviceClass.observe(function(class)
		publish({ inputMethod = methodFor(class) })
	end)
	ContextActionService:BindActionAtPriority(
		TOGGLE_ACTION,
		handleToggle,
		false,
		ACTION_PRIORITY,
		MENU_BINDING.Keyboard,
		MENU_BINDING.Gamepad
	)
end

function CombatMenuClient.getSnapshot(): Snapshot
	return state
end

function CombatMenuClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	CombatMenuClient.start()
	local unsubscribe = listeners.add(listener)
	listener(state)
	return unsubscribe
end

function CombatMenuClient.setAvailable(available: boolean)
	if not available then
		setOpen(false)
	end
	publish({ available = available })
end

function CombatMenuClient.toggle()
	if state.open and closeTopLayer() then
		return
	end
	setOpen(not state.open)
end

function CombatMenuClient.open()
	setOpen(true)
end

function CombatMenuClient.close()
	setOpen(false)
end

function CombatMenuClient.navigate(page: Page)
	if page ~= "Inventory" and page ~= "Shop" and page ~= "Settings" then
		return
	end
	publish({ page = page })
end

function CombatMenuClient.setCloseInterceptor(interceptor: (() -> boolean)?)
	closeInterceptor = interceptor
end

function CombatMenuClient.destroy()
	ContextActionService:UnbindAction(TOGGLE_ACTION)
	if deviceDisconnect then
		deviceDisconnect()
		deviceDisconnect = nil
	end
	Combat.releaseCursor(CURSOR_REASON)
	closeInterceptor = nil
	state = {
		open = false,
		page = "Shop",
		available = false,
		inputMethod = "KeyboardMouse",
	}
	listeners.clear()
	started = false
end

return CombatMenuClient
