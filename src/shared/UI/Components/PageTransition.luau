-- Description: Wrapper that animates a page in and out as the UI routes between screens, honouring the reduced-motion preference.

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
	Preset: string?,
	Render: (any, any?, any?) -> any,
}

return function(props: Props)
	local present, setPresent = React.useState(props.Active)
	local revision = React.useRef(0)
	local wasActive = React.useRef(props.Active)
	local reducedMotion = useReducedMotion()
	local preset = if props.Preset then Motion.LobbyPages[props.Preset] else nil
	local offscreen = if not preset
		then props.Offscreen
		elseif preset.Axis == "X" then UDim2.new(UDim.new(preset.OffscreenScale, 0), props.Onscreen.Y)
		else UDim2.new(props.Onscreen.X, UDim.new(preset.OffscreenScale, 0))
	local styles, api = ReactSpring.useSpring(function()
		return {
			Position = if props.Active then props.Onscreen else offscreen,
			Scale = if props.Active or not preset then 1 else preset.StartScale,
			Arrival = if props.Active then 1 else 0,
		}
	end)

	React.useEffect(function()
		revision.current += 1
		local currentRevision = revision.current
		local entering = props.Active and not wasActive.current
		wasActive.current = props.Active
		if props.Active then
			setPresent(true)
			if preset and entering and not reducedMotion then
				api.start({
					Position = props.Onscreen + UDim2.fromOffset(preset.ArrivalOffset.X, preset.ArrivalOffset.Y),
					Scale = preset.ArrivalScale,
					Arrival = 0.8,
					config = Motion.pageTiming(preset.Enter),
					immediate = false,
				}):andThen(function()
					if revision.current == currentRevision then
						api.start({
							Position = props.Onscreen,
							Scale = 1,
							Arrival = 1,
							config = Motion.pageTiming(preset.Settle),
							immediate = false,
						})
					end
				end)
			else
				api.start({
					Position = props.Onscreen,
					Scale = 1,
					Arrival = 1,
					config = if preset then Motion.pageTiming(preset.Settle) else Motion.Page,
					immediate = reducedMotion,
				})
			end
		else
			api.start({
				Position = offscreen,
				Scale = if preset then preset.StartScale else 1,
				Arrival = 0,
				config = if preset then Motion.pageTiming(preset.Exit, true) else Motion.Page,
				immediate = reducedMotion,
			}):andThen(function()
				if revision.current == currentRevision then
					setPresent(false)
				end
			end)
		end
		return function()
			revision.current += 1
			api.stop()
		end
	end, { props.Active, props.Onscreen, offscreen, preset, reducedMotion })

	React.useEffect(function()
		return function()
			api.stop()
		end
	end, {})

	if not present then
		return nil
	end
	return props.Render(styles.Position, styles.Scale, styles.Arrival)
end
