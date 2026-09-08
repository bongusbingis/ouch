-- Description: Applies the authored combat idle pose to characters as they spawn so players stand in the combat stance rather than the default one.

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThrowPose = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Infra"):WaitForChild("ThrowPose"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

local CombatPoseService = {}

local CHARGE_ATTRIBUTE = "AimCharge"

local started = false

function CombatPoseService.start()
	if started then
		return
	end
	started = true

	local limit = math.max(math.ceil(ThrowPose.Remote.ReportHz * 2), 10)

	Network.handleProtected("ReportAimPose", {
		rateLimit = limit,
		validate = function(_player, charge)
			if typeof(charge) ~= "number" or charge ~= charge or charge < 0 or charge > 1 then
				return false, "invalid_charge"
			end
			return true
		end,
	}, function(player: Player, charge: number)
		player:SetAttribute(CHARGE_ATTRIBUTE, math.clamp(charge, 0, 1))
	end)

	local function observe(player: Player)
		player.CharacterRemoving:Connect(function()
			player:SetAttribute(CHARGE_ATTRIBUTE, nil)
		end)
	end
	Players.PlayerAdded:Connect(observe)
	for _, player in Players:GetPlayers() do
		observe(player)
	end
end

return CombatPoseService
