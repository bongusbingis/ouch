-- Name: OnboardingGestureLayer.luau
-- Author: Jack C.
-- Description: Mounts the active onboarding gesture in raw viewport space.
-- Created: 2026-08-28

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local GestureHint = require(script.Parent.GestureHint)
local useExternalStore = require(script.Parent.Parent.Parent.Hooks.useExternalStore)
local GestureViewModel = require(script.Parent.Parent.Parent.Models.OnboardingGestureViewModel)

local c = React.createElement

export type Props = {
	OnboardingClient: any,
}

return function(props: Props)
	local client = props.OnboardingClient
	local snapshot = useExternalStore(client.getSnapshot, client.subscribe)

	if not snapshot.active or snapshot.succeeded then
		return nil
	end
	local gesture = GestureViewModel.forCue(snapshot.cue or "", snapshot.deviceClass or "Mouse")
	if gesture == nil then
		return nil
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Hint = c(GestureHint, {
			Kind = gesture.kind,
			DeviceClass = snapshot.deviceClass or "Mouse",
			Label = gesture.label,
		}),
	})
end
