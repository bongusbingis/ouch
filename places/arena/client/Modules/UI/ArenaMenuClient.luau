-- Name: ArenaMenuClient.luau
-- Author: Jack C.
-- Description: Owns arena in-match menu state: which page is open, layered close handling, input-method awareness, and the interception hook other screens use to claim the close action.
-- Created: 2026-08-24

--!strict

local ContextActionService = game:GetService("ContextActionService")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat

local ArenaMenuClient = {}

export type Page = "Inventory" | "Shop" | "Settings"
export type InputMethod = "KeyboardMouse" | "Gamepad" | "Touch"
export type Snapshot = {
	open: boolean,
	page: Page,
	available: boolean,
	inputMethod: InputMethod,
}

local TOGGLE_ACTION = "ToggleArenaMenu"
local CURSOR_REASON = "ArenaMenu"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 1

local started = false
local closeInterceptor: (() -> boolean)? = nil
local listeners: { (Snapshot) -> () } = {}
local connections: { RBXScriptConnection } = {}
local state: Snapshot = {
	open = false,
	page = "Shop",
	available = false,
	inputMethod = "KeyboardMouse",
}

local function inputMethod(inputType: Enum.UserInputType): InputMethod
	if inputType == Enum.UserInputType.Touch then
		return "Touch"
	end
	if string.find(inputType.Name, "Gamepad", 1, true) == 1 then
		return "Gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
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
	for _, listener in listeners do
		local ok, err = pcall(listener, state)
		if not ok then
			warn(`[ArenaMenuClient] listener failed: {err}`)
		end
	end
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
		warn(`[ArenaMenuClient] close interceptor failed: {handled}`)
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

function ArenaMenuClient.start()
	if started then
		return
	end
	started = true
	publish({ inputMethod = inputMethod(UserInputService:GetLastInputType()) })
	table.insert(
		connections,
		UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
			publish({ inputMethod = inputMethod(lastInputType) })
		end)
	)
	ContextActionService:BindActionAtPriority(
		TOGGLE_ACTION,
		handleToggle,
		false,
		ACTION_PRIORITY,
		Enum.KeyCode.M,
		Enum.KeyCode.ButtonY
	)
end

function ArenaMenuClient.getSnapshot(): Snapshot
	return state
end

function ArenaMenuClient.subscribe(listener: (Snapshot) -> ()): () -> ()
	ArenaMenuClient.start()
	table.insert(listeners, listener)
	listener(state)
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function ArenaMenuClient.setAvailable(available: boolean)
	if not available then
		setOpen(false)
	end
	publish({ available = available })
end

function ArenaMenuClient.toggle()
	if state.open and closeTopLayer() then
		return
	end
	setOpen(not state.open)
end

function ArenaMenuClient.open()
	setOpen(true)
end

function ArenaMenuClient.close()
	setOpen(false)
end

function ArenaMenuClient.navigate(page: Page)
	if page ~= "Inventory" and page ~= "Shop" and page ~= "Settings" then
		return
	end
	publish({ page = page })
end

function ArenaMenuClient.setCloseInterceptor(interceptor: (() -> boolean)?)
	closeInterceptor = interceptor
end

function ArenaMenuClient.destroy()
	ContextActionService:UnbindAction(TOGGLE_ACTION)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	Combat.releaseCursor(CURSOR_REASON)
	closeInterceptor = nil
	state = {
		open = false,
		page = "Shop",
		available = false,
		inputMethod = "KeyboardMouse",
	}
	table.clear(listeners)
	started = false
end

return ArenaMenuClient
