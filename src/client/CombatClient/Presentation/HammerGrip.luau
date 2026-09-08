-- Description: Re-export of the shared hammer grip solver so arena presentation modules can require it from their own tree.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics"):WaitForChild("HammerGrip")
)
