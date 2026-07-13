--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Input"))

-- Materializes the declarative input map as an InputContext under each Player.
-- InputContexts must be descendants of a Player so the engine knows ownership
-- and replicates action state into the shared simulation timeline.

local InputSetup = {}

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
	Players.PlayerAdded:Connect(buildContext)
	for _, player in Players:GetPlayers() do
		buildContext(player)
	end
end

return InputSetup
