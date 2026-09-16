-- Description: Edit-mode preview of the self-contained cosmetic effect tile.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local CandyEffectPreview = require(script.Parent.Parent.Components.CandyEffectPreview)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(
		target,
		React.createElement(CandyEffectPreview, {
			Category = target:GetAttribute("Category") or "ImpactEffectAssets",
			Definition = { Icon = "Explosion" },
			Playing = true,
			ZIndex = 1,
		})
	)
end
