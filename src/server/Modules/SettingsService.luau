-- Description: The only writer of profile Settings, shared by both places: validates an incoming preference against the same shared registry and value-resolution path the client uses, then persists it. Never trusts the client's normalization alone.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local SettingsRegistry = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Settings")
		:WaitForChild("SettingsRegistry")
)
local SettingsValues = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Settings")
		:WaitForChild("SettingsValues")
)
local PlayerData = require(script.Parent:WaitForChild("PlayerData"))

local SettingsService = {}

local started = false

function SettingsService.set(player: Player, id: string, rawValue: any): (boolean, string?, any)
	local definition = SettingsRegistry.get(id)
	if definition == nil then
		return false, "unknown_setting"
	end
	if not SettingsRegistry.isPersisted(definition) then
		return false, "not_persisted"
	end
	local data = PlayerData.get(player)
	if data == nil then
		return false, "no_profile"
	end
	data.Settings[id] = SettingsValues.normalize(definition, rawValue)
	return true, nil, data.Settings[id]
end

function SettingsService.start()
	if started then
		return
	end
	started = true
	local middleware = {
		rateLimit = 5,
		validate = function(_player, id, _value)
			return typeof(id) == "string" and #id > 0 and #id <= 64, "invalid_id"
		end,
	}
	Network.handleProtected("SetClientSetting", middleware, SettingsService.set)
	Network.handleProtected("SetClientSettingRequest", middleware, SettingsService.set)
end

return SettingsService
