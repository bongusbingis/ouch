--!strict

local dataModel: any = script
while dataModel.Parent do
	dataModel = dataModel.Parent
end
local ReplicatedStorage = dataModel:WaitForChild("ReplicatedStorage")

return require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Economy"):WaitForChild("EconomyStore")
)
