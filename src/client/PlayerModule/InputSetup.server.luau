-- Description: Server script that creates the input action and binding instances the player module expects and signals when input setup is complete.

--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local CommonUtils = require(script.Parent:WaitForChild("CommonUtils"))
local FlagUtil = CommonUtils.get("FlagUtil")
local PlayerModuleEventBus = CommonUtils.get("PlayerModuleEventBus")

local FFlagUserPlayerScriptsCCLIntegrationC = FlagUtil.getUserFlag("UserPlayerScriptsCCLIntegrationC")
local FFlagUserPlayerScriptsTapToMoveUsesIAS2 = FlagUtil.getUserFlag("UserPlayerScriptsTapToMoveUsesIAS2")
local FFlagUserPlayerScriptsCameraTouchUsesIAS = FlagUtil.getUserFlag("UserPlayerScriptsCameraTouchUsesIAS")
local FFlagUserPlayerScriptsDynamicThumbstickUsesIAS = FlagUtil.getUserFlag("UserPlayerScriptsDynamicThumbstickUsesIAS")
local FFlagUserPlayerScriptsClassicThumbstickUsesIAS = FlagUtil.getUserFlag("UserPlayerScriptsClassicThumbstickUsesIAS")
local FFlagUserPlayerScriptsUseScriptableBindings = FlagUtil.getUserFlag("UserPlayerScriptsUseScriptableBindings")
local FFlagUserPlayerScriptsThumbstickContext = FlagUtil.getUserFlag("UserPlayerScriptsThumbstickContext")
local FFlagUserPlayerScriptsPlayerControlState = FlagUtil.getUserFlag("UserPlayerScriptsPlayerControlState")

local AvatarAbilitiesInterface = if FFlagUserPlayerScriptsCCLIntegrationC
	then require(script.Parent:WaitForChild("ControlModule"):WaitForChild("AvatarAbilitiesInterface"))
	else nil
local InputReplication = if FFlagUserPlayerScriptsCCLIntegrationC
	then require(script.Parent:WaitForChild("ControlModule"):WaitForChild("InputReplication"))
	else nil

local CONNECTIONS = {
	INPUTS_SETUP = "INPUTS_SETUP",
}

if FFlagUserPlayerScriptsTapToMoveUsesIAS2 then
	local characterContext = StarterPlayer.PlayerModule.InputContexts.CharacterContext

	if not characterContext.ClickToMoveAction:FindFirstChild("TouchBinding") then
		local touchBinding = Instance.new("InputBinding")
		touchBinding.Name = "TouchBinding"
		touchBinding.KeyCode = Enum.KeyCode.TouchPosition
		touchBinding.Parent = characterContext.ClickToMoveAction
	end

	if not characterContext.ClickToMovePositionAction:FindFirstChild("TouchBinding") then
		local touchPositionBinding = Instance.new("InputBinding")
		touchPositionBinding.Name = "TouchBinding"
		touchPositionBinding.KeyCode = Enum.KeyCode.TouchPosition
		touchPositionBinding.Parent = characterContext.ClickToMovePositionAction
	end
end

if FFlagUserPlayerScriptsCameraTouchUsesIAS then
	local cameraContext = StarterPlayer.PlayerModule.InputContexts.CameraContext
	local cameraRotationAction = cameraContext.CameraRotationAction
	local cameraZoomAction = cameraContext.CameraZoomAction
	local cameraPanActiveAction = cameraContext.CameraPanActiveAction

	if not cameraRotationAction:FindFirstChild("TouchBinding") then
		local touchDeltaBinding = Instance.new("InputBinding")
		touchDeltaBinding.Name = "TouchBinding"
		touchDeltaBinding.KeyCode = Enum.KeyCode.TouchDelta
		touchDeltaBinding.Vector2Scale = Vector2.new(0.01745, 0.01152)
		touchDeltaBinding.Parent = cameraRotationAction
	end

	if not cameraZoomAction:FindFirstChild("TouchBinding") then
		local touchPinchBinding = Instance.new("InputBinding")
		touchPinchBinding.Name = "TouchBinding"
		touchPinchBinding.KeyCode = Enum.KeyCode.TouchPinch
		touchPinchBinding.Scale = -0.04
		touchPinchBinding.Parent = cameraZoomAction
	end

	if not cameraPanActiveAction:FindFirstChild("TouchBinding") then
		local touchPanBinding = Instance.new("InputBinding")
		touchPanBinding.Name = "TouchBinding"
		touchPanBinding.KeyCode = Enum.KeyCode.TouchPosition
		touchPanBinding.Parent = cameraPanActiveAction
	end
end

if FFlagUserPlayerScriptsDynamicThumbstickUsesIAS or FFlagUserPlayerScriptsClassicThumbstickUsesIAS then
	local inputContexts = StarterPlayer.PlayerModule.InputContexts
	local characterContext = inputContexts.CharacterContext

	local existingContext = if FFlagUserPlayerScriptsThumbstickContext
		then inputContexts:FindFirstChild("TransformerContext")
		else nil
	local owner: Instance = existingContext or characterContext

	if not owner:FindFirstChild("ThumbstickAction") then
		local thumbstickAction = Instance.new("InputAction")
		thumbstickAction.Name = "ThumbstickAction"
		thumbstickAction.Type = Enum.InputActionType.ViewportPosition
		thumbstickAction.Enabled = false

		if FFlagUserPlayerScriptsThumbstickContext then
			characterContext.Priority = 150

			local thumbstickContext = existingContext
			if thumbstickContext == nil then
				thumbstickContext = Instance.new("InputContext")
				thumbstickContext.Name = "TransformerContext"
				thumbstickContext.Priority = 300
				thumbstickContext.Sink = true
				thumbstickContext.Parent = inputContexts
			end
			thumbstickAction.Parent = thumbstickContext
		else
			thumbstickAction.Parent = characterContext
		end
	end
end

if FFlagUserPlayerScriptsUseScriptableBindings then
	local characterContext = StarterPlayer.PlayerModule.InputContexts.CharacterContext
	local cameraContext = StarterPlayer.PlayerModule.InputContexts.CameraContext
	local moveAction = characterContext:FindFirstChild("MoveAction")
	local jumpAction = characterContext:FindFirstChild("JumpAction")
	local cameraAction = cameraContext:FindFirstChild("CameraAction")
	local rotationAction = characterContext:FindFirstChild("RotationAction")

	local function ensureScriptableBinding(action: Instance?, bindingName: string)
		if action == nil then
			return
		end

		local existing = action:FindFirstChild(bindingName)
		if existing ~= nil then
			assert(existing:IsA("InputBinding"), `{action:GetFullName()}.{bindingName} must be an InputBinding`)
			existing.Type = Enum.InputBindingType.Scriptable
			return
		end

		local binding = Instance.new("InputBinding")
		binding.Name = bindingName
		binding.Type = Enum.InputBindingType.Scriptable
		binding.Parent = action
	end

	ensureScriptableBinding(moveAction, "DynamicThumbstickScriptableBinding")
	ensureScriptableBinding(moveAction, "ClassicThumbstickScriptableBinding")
	ensureScriptableBinding(moveAction, "ClickToMoveScriptableBinding")
	ensureScriptableBinding(jumpAction, "ClickToMoveScriptableBinding")
	ensureScriptableBinding(cameraAction, "CameraScriptableBinding")
	ensureScriptableBinding(rotationAction, "RotationScriptableBinding")
end

if not FFlagUserPlayerScriptsPlayerControlState then
	local function attemptCreateActionsIfAbsent(player: Player)
		local avatarAbilitiesInterface = AvatarAbilitiesInterface.get(player)

		local function createAction(abilityName: string)
			local inputContexts = player:FindFirstChild("InputContexts")
			if not inputContexts then
				return
			end
			local characterContext = inputContexts:FindFirstChild("CharacterContext")
			if not characterContext then
				return
			end

			local action = Instance.new("InputAction")
			action.Name = abilityName .. "Action"
			if FFlagUserPlayerScriptsUseScriptableBindings then
				local scriptableBinding = Instance.new("InputBinding")
				scriptableBinding.Name = "ScriptableBinding"
				scriptableBinding.Type = Enum.InputBindingType.Scriptable
				scriptableBinding.Parent = action
			end
			action.Parent = characterContext
		end

		if avatarAbilitiesInterface:isEnabled() then
			local inputContexts = player:FindFirstChild("InputContexts")
			if not inputContexts then
				task.spawn(function()
					InputReplication.CloneInputsIfAbsent(player)
				end)
			else
				local characterContext = inputContexts:FindFirstChild("CharacterContext")
				if characterContext then
					for _, abilityName in avatarAbilitiesInterface:GetAbilities() do
						local action = characterContext:FindFirstChild(abilityName .. "Action")
						if not action then
							task.spawn(function()
								createAction(abilityName)
							end)
						end
					end
				end
			end
		end
	end

	local function updatePlayer(player: Player)
		attemptCreateActionsIfAbsent(player)
		local avatarAbilitiesInterface = AvatarAbilitiesInterface.get(player)
		if avatarAbilitiesInterface:isEnabled() then
			InputReplication.SendInputToCCLCharacter(player)
		end
	end

	if FFlagUserPlayerScriptsCCLIntegrationC then
		Players.PlayerAdded:Connect(attemptCreateActionsIfAbsent)
		for _, player in Players:GetPlayers() do
			attemptCreateActionsIfAbsent(player)
		end

		RunService:BindToSimulation(function(dt)
			for _, player in Players:GetPlayers() do
				updatePlayer(player)
			end
		end, Enum.StepFrequency.Hz60)
	end
end

PlayerModuleEventBus.data.inputsSetupComplete = true
PlayerModuleEventBus:publish(CONNECTIONS.INPUTS_SETUP)
