-- Description: Re-export of the shared UI analytics service so lobby client modules can require it from their own tree.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

return require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("UIAnalytics")
)
