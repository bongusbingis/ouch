-- Name: EmoteWheelController.luau
-- Author: Jack C.
-- Description: Owns the radial emote selector's open/hover/commit state and every device's input binding (hold B, hold DPad Down, touch button) so the lobby, arena and results screens share one wheel behaviour and only supply how an emote is played.
-- Created: 2026-09-09
--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage:WaitForChild("Config")
local Input = require(Config:WaitForChild("Interface"):WaitForChild("Input"))
local Emotes = require(Config:WaitForChild("Cosmetics"):WaitForChild("Emotes"))
local EmoteWheelModel = require(script.Parent.Parent.Models.EmoteWheelModel)
local UIFeedback = require(script.Parent.UIFeedback)
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local useExternalStore = require(script.Parent.Parent.Hooks.useExternalStore)

local EmoteWheelController = {}

export type DeviceClass = "Keyboard" | "Gamepad" | "Touch"

export type Snapshot = {
	open: boolean,
	selected: number?,
	slots: { string? },
	capacity: number,
	deviceClass: DeviceClass,
	pointer: Vector2,
}

export type Options = {
	onPlay: (emoteId: string) -> (),
	isEnabled: (() -> boolean)?,
}

local snapshot: Snapshot = {
	open = false,
	selected = nil,
	slots = {},
	capacity = Emotes.BaseSlots,
	deviceClass = "Keyboard",
	pointer = Vector2.zero,
}
local listeners: { [number]: (Snapshot) -> () } = {}
local nextListenerId = 0
local connections: { RBXScriptConnection } = {}
local options: Options? = nil
local holdKey: Enum.KeyCode? = nil
local accumulated = Vector2.zero
local touchSticky = false
local activeTouch: InputObject? = nil

-- Only the right stick selects, so the left stick keeps moving the character
-- while the wheel is held open. Keyboard-emulated and accessibility gamepads
-- send that stick as digital directions, which select the same way.
local DIGITAL_STICK: { [Enum.KeyCode]: Vector2 } = {
	[Enum.KeyCode.Thumbstick2Up] = Vector2.new(0, 1),
	[Enum.KeyCode.Thumbstick2Down] = Vector2.new(0, -1),
	[Enum.KeyCode.Thumbstick2Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.Thumbstick2Right] = Vector2.new(1, 0),
}

local function emit()
	snapshot = table.clone(snapshot)
	for _, listener in listeners do
		listener(snapshot)
	end
end

local function deviceClassFor(inputType: Enum.UserInputType): DeviceClass
	local name = inputType.Name
	if string.find(name, "Gamepad", 1, true) == 1 then
		return "Gamepad"
	elseif inputType == Enum.UserInputType.Touch then
		return "Touch"
	end
	return "Keyboard"
end

local function readSlots()
	local player = Players.LocalPlayer
	local slots = {}
	for index = 1, Emotes.MaxSlots do
		local value = player:GetAttribute("EmoteSlot_" .. index)
		slots[index] = if type(value) == "string" and value ~= "" then value else nil
	end
	snapshot.slots = slots
	snapshot.capacity = EmoteWheelModel.capacity(player:GetAttribute("EmoteSlotCapacity"))
end

local function viewportCenter(): Vector2
	local ok, core = pcall(GuiService.GetInsetArea, GuiService, Enum.ScreenInsets.CoreUISafeInsets)
	if ok and typeof(core) == "Rect" then
		return (core.Min + core.Max) / 2
	end
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return size / 2
end

local function layout()
	local camera = Workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return EmoteWheelModel.layout(size, snapshot.capacity, EmoteWheelModel.captionReserve(size))
end

local function setSelected(index: number?)
	if index ~= nil and index > snapshot.capacity then
		index = nil
	end
	if snapshot.selected ~= index then
		snapshot.selected = index
		if index ~= nil then
			UIFeedback.hover()
		end
		emit()
	end
end

local function hoverAt(offset: Vector2)
	snapshot.pointer = offset
	setSelected(EmoteWheelModel.hitTest(offset, layout(), snapshot.capacity))
	emit()
end

-- InputObject positions and GetInsetArea rects share ScreenGui space (both
-- exclude the top bar inset), so the wheel centre compares directly.
local function hoverAtEvent(input: InputObject)
	hoverAt(Vector2.new(input.Position.X, input.Position.Y) - viewportCenter())
end

local function enabled(): boolean
	local current = options
	if current == nil then
		return false
	end
	return current.isEnabled == nil or current.isEnabled()
end

local function open(key: Enum.KeyCode?, sticky: boolean)
	if snapshot.open or not enabled() then
		return
	end
	readSlots()
	holdKey = key
	touchSticky = sticky
	accumulated = Vector2.zero
	activeTouch = nil
	snapshot.open = true
	snapshot.selected = nil
	snapshot.pointer = Vector2.zero
	UIFeedback.click()
	emit()
end

local function close()
	if not snapshot.open then
		return
	end
	snapshot.open = false
	snapshot.selected = nil
	holdKey = nil
	touchSticky = false
	activeTouch = nil
	emit()
end

local function commit()
	if not snapshot.open then
		return
	end
	local index = snapshot.selected
	local emoteId = if index then snapshot.slots[index] else nil
	local current = options
	close()
	if emoteId ~= nil and Emotes.Clips[emoteId] ~= nil and current ~= nil then
		UIFeedback.click()
		current.onPlay(emoteId)
	end
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local bindings = Input.EmoteWheel
	if input.KeyCode == bindings.Keyboard and snapshot.deviceClass ~= "Touch" then
		open(bindings.Keyboard, false)
	elseif input.KeyCode == bindings.Gamepad then
		open(bindings.Gamepad, false)
	elseif snapshot.open and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
		close()
	elseif snapshot.open and DIGITAL_STICK[input.KeyCode] then
		hoverAt(EmoteWheelModel.stickOffset(DIGITAL_STICK[input.KeyCode], layout()))
	elseif snapshot.open and touchSticky and input.UserInputType == Enum.UserInputType.Touch then
		activeTouch = input
		hoverAtEvent(input)
	end
end

local function onInputChanged(input: InputObject)
	if not snapshot.open then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			accumulated += Vector2.new(input.Delta.X, input.Delta.Y)
			hoverAt(accumulated)
		else
			hoverAtEvent(input)
		end
	elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
		hoverAt(EmoteWheelModel.stickOffset(Vector2.new(input.Position.X, input.Position.Y), layout()))
	elseif input.UserInputType == Enum.UserInputType.Touch and input == activeTouch then
		hoverAtEvent(input)
	end
end

local function onInputEnded(input: InputObject)
	if not snapshot.open then
		return
	end
	if holdKey ~= nil and input.KeyCode == holdKey then
		commit()
	elseif input.UserInputType == Enum.UserInputType.Touch and input == activeTouch then
		if snapshot.selected ~= nil and snapshot.slots[snapshot.selected] ~= nil then
			commit()
		else
			close()
		end
	end
end

function EmoteWheelController.start(newOptions: Options)
	EmoteWheelController.stop()
	options = newOptions
	snapshot.deviceClass = deviceClassFor(UserInputService:GetLastInputType())
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		snapshot.deviceClass = "Touch"
	end
	readSlots()
	emit()
	local player = Players.LocalPlayer
	for index = 1, Emotes.MaxSlots do
		table.insert(
			connections,
			player:GetAttributeChangedSignal("EmoteSlot_" .. index):Connect(function()
				readSlots()
				emit()
			end)
		)
	end
	table.insert(
		connections,
		player:GetAttributeChangedSignal("EmoteSlotCapacity"):Connect(function()
			readSlots()
			emit()
		end)
	)
	table.insert(
		connections,
		UserInputService.LastInputTypeChanged:Connect(function(inputType)
			local class = deviceClassFor(inputType)
			if inputType == Enum.UserInputType.MouseMovement and snapshot.deviceClass == "Keyboard" then
				return
			end
			if class ~= snapshot.deviceClass then
				snapshot.deviceClass = class
				emit()
			end
		end)
	)
	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))
	table.insert(connections, UserInputService.InputChanged:Connect(onInputChanged))
	table.insert(connections, UserInputService.InputEnded:Connect(onInputEnded))
end

function EmoteWheelController.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	options = nil
	close()
end

function EmoteWheelController.openTouch()
	if snapshot.open then
		close()
		return
	end
	open(nil, true)
end

function EmoteWheelController.cancel()
	close()
end

function EmoteWheelController.isOpen(): boolean
	return snapshot.open
end

function EmoteWheelController.getSnapshot(): Snapshot
	return snapshot
end

function EmoteWheelController.subscribe(listener: (Snapshot) -> ()): () -> ()
	nextListenerId += 1
	local id = nextListenerId
	listeners[id] = listener
	return function()
		listeners[id] = nil
	end
end

function EmoteWheelController.useSnapshot(): Snapshot
	return useExternalStore(EmoteWheelController.getSnapshot, EmoteWheelController.subscribe)
end

-- Hosts block the wheel through the EmoteWheelBlocked player attribute; UI that
-- opens the wheel follows it so nothing invites a tap the wheel would refuse.
function EmoteWheelController.useBlocked(): boolean
	local player = Players.LocalPlayer
	local blocked, setBlocked = React.useState(player ~= nil and player:GetAttribute("EmoteWheelBlocked") == true)
	React.useEffect(function()
		if player == nil then
			return nil
		end
		local connection = player:GetAttributeChangedSignal("EmoteWheelBlocked"):Connect(function()
			setBlocked(player:GetAttribute("EmoteWheelBlocked") == true)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	return blocked
end

return EmoteWheelController
