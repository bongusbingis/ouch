--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ShopPage = require(script.Parent.Parent.Components.ShopPage)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(target, React.createElement(ShopPage))
end
