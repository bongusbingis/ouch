--!strict

-- Server appearance owner for the two equip projections; stale character work is canceled before rebuilding.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterAppearance = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CharacterAppearance")
)
local CostumeVisualFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CostumeVisualFactory")
)

local CharacterColorService = {}
local started = false
local bindings: { [Player]: any } = {}

local function cancelWork(binding)
	if binding.worker and coroutine.status(binding.worker) ~= "dead" then
		task.cancel(binding.worker)
	end
	binding.worker = nil
end

local function clearCharacter(binding)
	if binding.appearance then
		binding.appearance.destroy()
		binding.appearance = nil
	end
	for _, connection in binding.children do
		connection:Disconnect()
	end
	table.clear(binding.children)
	binding.character = nil
end

local function refresh(player: Player)
	local binding = bindings[player]
	if not binding then
		return
	end
	cancelWork(binding)
	binding.worker = task.defer(function()
		local character = player.Character
		if binding.character ~= character then
			clearCharacter(binding)
			binding.character = character
			if character then
				local function bodyChanged(child)
					if CostumeVisualFactory.BodyParts[child.Name] then
						refresh(player)
					end
				end
				table.insert(binding.children, character.ChildAdded:Connect(bodyChanged))
				table.insert(binding.children, character.ChildRemoved:Connect(bodyChanged))
			end
		end
		if not character then
			return
		end
		local appearance = {
			characterColorId = player:GetAttribute("Equip_CharacterColor"),
			costumeId = player:GetAttribute("Equip_CostumeAssets"),
		}
		if binding.appearance then
			binding.appearance.update(appearance)
		else
			binding.appearance = CharacterAppearance.create(character, appearance, { live = true })
		end
	end)
end

local function bindPlayer(player: Player)
	if bindings[player] then
		return
	end
	local binding: any = { connections = {}, children = {} }
	bindings[player] = binding
	for _, attribute in { "Equip_CharacterColor", "Equip_CostumeAssets" } do
		table.insert(
			binding.connections,
			player:GetAttributeChangedSignal(attribute):Connect(function()
				refresh(player)
			end)
		)
	end
	table.insert(
		binding.connections,
		player.CharacterAdded:Connect(function()
			refresh(player)
		end)
	)
	table.insert(
		binding.connections,
		player.CharacterAppearanceLoaded:Connect(function()
			refresh(player)
		end)
	)
	table.insert(
		binding.connections,
		player.CharacterRemoving:Connect(function()
			cancelWork(binding)
			clearCharacter(binding)
		end)
	)
	refresh(player)
end

local function unbindPlayer(player: Player)
	local binding = bindings[player]
	if not binding then
		return
	end
	bindings[player] = nil
	cancelWork(binding)
	for _, connection in binding.connections do
		connection:Disconnect()
	end
	clearCharacter(binding)
end

function CharacterColorService.start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(unbindPlayer)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
end

return CharacterColorService
