-- Name: PageTransition.luau
-- Author: Jack C.
-- Description: Wrapper that animates a page in and out as the UI routes between screens, honouring the reduced-motion preference.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactSpring = require(Packages:WaitForChild("react-spring"))
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)

export type Props = {
	Active: boolean,
	Onscreen: UDim2,
	Offscreen: UDim2,
	Render: (any) -> any,
}

return function(props: Props)
	local present, setPresent = React.useState(props.Active)
	local revision = React.useRef(0)
	local reducedMotion = useReducedMotion()
	local styles, api = ReactSpring.useSpring(function()
		return { Position = if props.Active then props.Onscreen else props.Offscreen }
	end)

	React.useEffect(function()
		revision.current += 1
		local currentRevision = revision.current
		if props.Active then
			setPresent(true)
			api.start({ Position = props.Onscreen, config = Motion.Page, immediate = reducedMotion })
		else
			api.start({ Position = props.Offscreen, config = Motion.Page, immediate = reducedMotion })
				:andThen(function()
					if revision.current == currentRevision then
						setPresent(false)
					end
				end)
		end
		return function()
			revision.current += 1
		end
	end, { props.Active, props.Onscreen, props.Offscreen, reducedMotion })

	React.useEffect(function()
		return function()
			api.stop()
		end
	end, {})

	if not present then
		return nil
	end
	return props.Render(styles.Position)
end
