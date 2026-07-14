--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

-- Materializes the declarative input map as an InputContext under each Player.
-- InputContexts must be descendants of a Player so the engine knows ownership
-- and replicates action state into the shared simulation timeline. Also owns
-- the client-reported DeviceClass attribute the adapter stamps onto commands.

local InputSetup = {}

local VALID_DEVICE_CLASSES = { Mouse = true, Touch = true }

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
			binding.Parent = action
		end
	end

	context.Parent = player
end

function InputSetup.start()
	Network.handleProtected("ReportDeviceClass", {
		rateLimit = 5,
		validate = function(_player, deviceClass)
			if typeof(deviceClass) ~= "string" or not VALID_DEVICE_CLASSES[deviceClass] then
				return false, "invalid device class"
			end
			return true
		end,
	}, function(player, deviceClass)
		player:SetAttribute("DeviceClass", deviceClass)
	end)

	Players.PlayerAdded:Connect(buildContext)
	for _, player in Players:GetPlayers() do
		buildContext(player)
	end
end

return InputSetup
