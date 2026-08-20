--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ThrowPose = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("ThrowPose"))
local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))

-- Server owner of replicated throw charge: the one piece of pose information
-- other players need, so an opponent winding up is readable as counterplay.
--
-- The arm pose is solved per client and never replicates on its own -- IKControl
-- weights and targets are local to the machine that sets them. So each client
-- reports its charge at a low rate and it is projected here as an attribute on
-- the Player, which fans out through normal replication rather than a broadcast
-- of our own.
--
-- Cosmetic and treated as such. The value is clamped on arrival and is never
-- read by combat: hit resolution uses the aim direction submitted with the throw
-- itself, which the sim validates separately. A client lying here can make its
-- own character look like it is winding up and nothing more.

local CombatPoseService = {}

local CHARGE_ATTRIBUTE = "AimCharge"

local started = false

function CombatPoseService.start()
	if started then
		return
	end
	started = true

	-- Set above the configured report rate so ordinary jitter in a client's send
	-- loop is not punished, while a flood still is.
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

	-- A stale charge outliving the character it described would leave a corpse or
	-- a fresh spawn permanently wound up.
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
