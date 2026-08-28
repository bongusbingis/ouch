-- Name: OnboardingApp.luau
-- Author: Jack C.
-- Description: React root for the first-session training overlay, subscribing to the onboarding client's snapshot and handing its actions back to the server adapter.
-- Created: 2026-08-27

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local SharedUI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local OnboardingOverlay = require(SharedUI:WaitForChild("Components"):WaitForChild("OnboardingOverlay"))
local useExternalStore = require(SharedUI:WaitForChild("Hooks"):WaitForChild("useExternalStore"))

local OnboardingClient = require(
	Players.LocalPlayer
		:WaitForChild("PlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Modules")
		:WaitForChild("Onboarding")
		:WaitForChild("OnboardingClient")
)

local c = React.createElement

export type Props = {
	OnPresented: (() -> ())?,
}

return function(props: Props)
	local snapshot = useExternalStore(OnboardingClient.getSnapshot, OnboardingClient.subscribe)
	local presented = React.useRef(false)

	React.useEffect(function()
		if not presented.current and props.OnPresented then
			presented.current = true
			props.OnPresented()
		end
	end, { props.OnPresented })

	return c(OnboardingOverlay, {
		Snapshot = snapshot,
		OnSkip = OnboardingClient.skip,
		OnJoinPartyMatch = OnboardingClient.joinPartyMatch,
		OnKeepTraining = OnboardingClient.keepTraining,
	})
end
