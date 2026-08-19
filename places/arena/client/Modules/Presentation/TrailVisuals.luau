--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedTrailVisuals = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics"):WaitForChild("TrailVisuals")
)

export type Handle = SharedTrailVisuals.Handle

return SharedTrailVisuals
