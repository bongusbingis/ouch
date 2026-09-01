-- Name: HammerGrip.luau
-- Author: Jack C.
-- Description: Re-export of the shared hammer grip solver so arena presentation modules can require it from their own tree.
-- Created: 2026-07-25

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics"):WaitForChild("HammerGrip")
)
