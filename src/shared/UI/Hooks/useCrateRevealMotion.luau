--!strict
-- Presentation only: reveal the already-awarded results in 1.8–2.3 seconds.
-- Skip, dismissal, replay and reduced motion cancel every outstanding tween/task.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.react)
local UIFeedback = require(script.Parent.Parent.Services.UIFeedback)

return function(reveal, reducedMotion: boolean)
	local count = if reveal then #reveal.results else 0
	local phase, setPhase = React.useState("Idle")
	local revealedCount, setRevealedCount = React.useState(0)
	local charge, setCharge = React.useBinding(0)
	local turn, setTurn = React.useBinding(0)
	local landing, setLanding = React.useBinding(0)
	local pulse, setPulse = React.useBinding(1)
	local burst, setBurst = React.useBinding(0)
	local cancel = React.useRef(nil)
	local finish = React.useCallback(function()
		if cancel.current then
			cancel.current()
		end
		setCharge(0)
		setTurn(0)
		setLanding(0)
		setPulse(1)
		setBurst(0)
		setRevealedCount(count)
		setPhase("Done")
	end, { count })

	React.useEffect(function()
		if not reveal then
			setPhase("Idle")
			setRevealedCount(0)
			return
		end
		if reducedMotion then
			finish()
			return
		end
		local alive = true
		local sources, connections, tweens = {}, {}, {}
		local thread = nil
		local function value(initial, update)
			local source = Instance.new("NumberValue")
			source.Value = initial
			update(initial)
			table.insert(sources, source)
			table.insert(connections, source.Changed:Connect(update))
			return source
		end
		local energy = value(0, setCharge)
		local rotation = value(0, setTurn)
		local drop = value(-12, setLanding)
		local title = value(1, setPulse)
		local flash = value(0, setBurst)
		local function tween(source, target, seconds, easing, repeats, reverses)
			local animation = TweenService:Create(
				source,
				TweenInfo.new(seconds, easing, Enum.EasingDirection.Out, repeats or 0, reverses or false),
				{ Value = target }
			)
			table.insert(tweens, animation)
			animation:Play()
			return animation
		end
		local function stop()
			if not alive then
				return
			end
			alive = false
			for _, animation in tweens do
				animation:Cancel()
			end
			if thread and thread ~= coroutine.running() then
				pcall(task.cancel, thread)
			end
			for _, connection in connections do
				connection:Disconnect()
			end
			for _, source in sources do
				source:Destroy()
			end
		end
		cancel.current = stop
		setPhase("Shake")
		setRevealedCount(0)
		thread = task.spawn(function()
			local breathing = tween(title, 1.035, 0.42, Enum.EasingStyle.Elastic, -1, true)
			tween(rotation, 200, 1.18, Enum.EasingStyle.Back)
			tween(energy, 1, 1.18, Enum.EasingStyle.Back).Completed:Wait()
			if not alive then
				return
			end
			setPhase("Landing")
			tween(energy, 0.82, 0.38, Enum.EasingStyle.Elastic)
			tween(drop, 0, 0.38, Enum.EasingStyle.Elastic).Completed:Wait()
			if not alive then
				return
			end
			breathing:Cancel()
			title.Value = 1
			setPhase("Burst")
			UIFeedback.notification()
			flash.Value = 1
			tween(flash, 0, 0.42, Enum.EasingStyle.Back)
			task.wait(0.22)
			if not alive then
				return
			end
			setPhase("Item")
			for index = 1, count do
				if not alive then
					return
				end
				setRevealedCount(index)
				if count > 1 then
					UIFeedback.click()
				end
				if index < count then
					task.wait(0.055)
				end
			end
			if alive then
				setPhase("Done")
				-- Let the landing burst finish before disposing its driver.
				task.wait(0.22)
				if alive then
					stop()
				end
			end
		end)
		return function()
			stop()
			if cancel.current == stop then
				cancel.current = nil
			end
		end
	end, { reveal, reducedMotion })
	return {
		phase = phase,
		revealedCount = revealedCount,
		finish = finish,
		charge = charge,
		turn = turn,
		landing = landing,
		pulse = pulse,
		burst = burst,
	}
end
