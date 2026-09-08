-- Description: Materializes the declarative input map as an InputContext, InputAction, and InputBinding tree under each player, and owns the validated device-class attribute the sim adapter reads.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Input"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local InputSetup = {}

local VALID_DEVICE_CLASSES = { Mouse = true, Touch = true, Gamepad = true }
local started = false

function InputSetup.setDeviceClass(player: Player, deviceClass: string): boolean
	if not VALID_DEVICE_CLASSES[deviceClass] then
		return false
	end
	player:SetAttribute("DeviceClass", deviceClass)
	return true
end

local function buildContext(player: Player)
	if player:FindFirstChild(InputConfig.ContextName) then
		return
	end

	local context = Instance.new("InputContext")
	context.Name = InputConfig.ContextName

	for _, actionDef in InputConfig.Actions do
		local action = Instance.new("InputAction")
		action.Name = actionDef.Name
		action.Type = actionDef.Type
		action.Parent = context

		for _, bindingDef in actionDef.Bindings do
			local binding = Instance.new("InputBinding")
			binding.Name = bindingDef.Name or "Binding"
			if bindingDef.Scriptable then
				binding.Type = Enum.InputBindingType.Scriptable
			elseif bindingDef.KeyCode then
				binding.KeyCode = bindingDef.KeyCode
			end
			if bindingDef.DisplayName then
				binding.DisplayName = bindingDef.DisplayName
			end
			binding.Parent = action
		end
	end

	context.Parent = player
end

function InputSetup.start()
	if started then
		return
	end
	started = true

	Network.handleProtected("ReportDeviceClass", {
		rateLimit = 5,
		validate = function(_player, deviceClass)
			if typeof(deviceClass) ~= "string" or not VALID_DEVICE_CLASSES[deviceClass] then
				return false, "invalid device class"
			end
			return true
		end,
	}, function(player, deviceClass)
		InputSetup.setDeviceClass(player, deviceClass)
	end)

	Players.PlayerAdded:Connect(buildContext)
	for _, player in Players:GetPlayers() do
		buildContext(player)
	end
end

return InputSetup
