--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Overlay = require(script.Parent.Parent.Components.Onboarding.OnboardingOverlay)
local mount = require(script.Parent.StoryRoot)

return function(target: Instance)
	return mount(
		target,
		React.createElement(Overlay, {
			Snapshot = {
				active = true,
				cue = target:GetAttribute("Cue") or "Throw",
				step = target:GetAttribute("Step") or "NormalThrow",
				deviceClass = target:GetAttribute("DeviceClass") or "Touch",
				hintLevel = 2,
			},
			OnSkip = function() end,
		})
	)
end
