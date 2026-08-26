-- Name: ActivityDots.luau
-- Author: Jack C.
-- Description: Animated loading dots component used wherever the UI is waiting on the server, respecting the reduced-motion preference.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("UI"))
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)

local c = React.createElement

export type Props = {
	Active: boolean,
	Native: { [any]: any }?,
	Color: Color3?,
	DotSize: UDim2?,
	Padding: UDim?,
}

local function merge(...): { [any]: any }
	local result = {}
	for index = 1, select("#", ...) do
		local source = select(index, ...)
		if source then
			for key, value in source do
				result[key] = value
			end
		end
	end
	return result
end

return function(props: Props)
	local dotOneTransparency, setDotOneTransparency = React.useBinding(1)
	local dotTwoTransparency, setDotTwoTransparency = React.useBinding(1)
	local dotThreeTransparency, setDotThreeTransparency = React.useBinding(1)
	local reducedMotion = useReducedMotion()

	React.useEffect(function()
		local setters = { setDotOneTransparency, setDotTwoTransparency, setDotThreeTransparency }
		for index, setTransparency in setters do
			setTransparency(if props.Active and reducedMotion then (index - 1) * 0.35 else 1)
		end
		if not props.Active or reducedMotion then
			return
		end

		local pulseDuration = UIConfig.PartyState.DotPulseSeconds
		local staggerDuration = UIConfig.PartyState.DotStaggerSeconds
		local sequenceDuration = pulseDuration + staggerDuration * 2 + UIConfig.PartyState.SequencePauseSeconds
		local elapsed = 0
		local connection = RunService.RenderStepped:Connect(function(deltaTime)
			elapsed = (elapsed + deltaTime) % sequenceDuration
			for index, setTransparency in setters do
				local dotTime = elapsed - (index - 1) * staggerDuration
				local opacity = if dotTime >= 0 and dotTime <= pulseDuration
					then math.sin(math.pi * dotTime / pulseDuration)
					else 0
				setTransparency(1 - opacity)
			end
		end)
		return function()
			connection:Disconnect()
		end
	end, { props.Active, reducedMotion })

	local function dot(layoutOrder: number, transparency: any)
		return c("Frame", {
			BackgroundColor3 = props.Color or Color3.new(1, 1, 1),
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
			LayoutOrder = layoutOrder,
			Size = props.DotSize or UDim2.fromScale(0.22, 0.65),
		}, {
			UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),
			UICorner = c("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		})
	end

	return c(
		"Frame",
		merge({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			Visible = props.Active,
		}, props.Native),
		{
			UIListLayout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = props.Padding or UDim.new(0.08, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Dot1 = dot(1, dotOneTransparency),
			Dot2 = dot(2, dotTwoTransparency),
			Dot3 = dot(3, dotThreeTransparency),
		}
	)
end
