-- Description: The shared motion constants every animated component uses, so page, camera, control, and modal transitions all feel the same.

--!strict

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local T = require(script.Parent.Tokens)
local ScrollingClipping = require(script.Parent.Services.ScrollingClipping)
local celebration = Instance.new("BindableEvent")
local Motion = {
	Page = table.freeze({ mass = 1, tension = 2500, friction = 100 }),
	Camera = table.freeze({ mass = 1, tension = 170, friction = 26 }),
	-- Near-critical damping and a bounded finish keep labels from oscillating.
	Control = table.freeze({ mass = 1, tension = 1500, friction = 78, clamp = true }),
	Navigation = table.freeze({ mass = 1, tension = 640, friction = 51, clamp = true }),
	Modal = table.freeze({ mass = 1, tension = 700, friction = 45 }),
	Pop = table.freeze({ mass = 1, tension = 900, friction = 17 }),
	-- Lobby entrances have one authored arrival and one short, finite settle.
	-- Backpack keeps the existing Page spring plus PanelFrame pop.
	LobbyPages = table.freeze({
		Shop = table.freeze({
			Axis = "Y",
			OffscreenScale = 1.5,
			ArrivalOffset = Vector2.new(0, -8),
			StartScale = 0.97,
			ArrivalScale = 1.012,
			Enter = 0.26,
			Settle = 0.12,
			Exit = 0.18,
		}),
		Settings = table.freeze({
			Axis = "X",
			OffscreenScale = 1.5,
			ArrivalOffset = Vector2.new(-8, 0),
			StartScale = 1,
			ArrivalScale = 1,
			Enter = 0.22,
			Settle = 0.11,
			Exit = 0.16,
		}),
		SplashScreen = table.freeze({
			Axis = "Y",
			OffscreenScale = 1,
			ArrivalOffset = Vector2.new(0, -4),
			StartScale = 1,
			ArrivalScale = 1,
			Enter = 0.25,
			Settle = 0.13,
			Exit = 0.18,
			TrailingOffset = 32,
		}),
	}),
	Controls = table.freeze({
		Standard = table.freeze({ hover = 1.055, pressed = 0.93, rotation = -1 }),
		Primary = table.freeze({ hover = 1.035, pressed = 0.95, rotation = -0.5 }),
		Card = table.freeze({ hover = T.Motion.HoverScale, pressed = T.Motion.PressScale, rotation = -T.Shape.TiltTab }),
	}),
}

function Motion.pageTiming(duration: number, exiting: boolean?)
	return {
		duration = duration,
		easing = function(alpha)
			return TweenService:GetValue(
				alpha,
				Enum.EasingStyle.Cubic,
				if exiting then Enum.EasingDirection.In else Enum.EasingDirection.Out
			)
		end,
	}
end

local function animateScale(target: GuiObject, start: number, duration: number)
	if GuiService.ReducedMotionEnabled then
		return function() end
	end
	local scale = Instance.new("UIScale")
	scale.Name = "CandyMotionScale"
	scale.Scale = start
	scale.Parent = target
	local tween = TweenService:Create(
		scale,
		TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	)
	tween:Play()
	return function()
		tween:Cancel()
		scale:Destroy()
	end
end

function Motion.popIn(target: GuiObject)
	return animateScale(target, T.Motion.OpenScale, T.Motion.Open)
end

function Motion.stampBadge(target: GuiObject)
	return animateScale(target, T.Motion.BadgeScale, T.Motion.Stamp)
end

function Motion.tabSwitch(target: GuiObject)
	return animateScale(target, T.Motion.OpenScale, T.Motion.TabSwitch)
end

-- Fired only after the existing authoritative request accepts an equip/assignment.
function Motion.celebrate(category: string?, itemId: string?)
	celebration:Fire(category, itemId)
end

function Motion.onCelebrate(callback)
	local connection = celebration.Event:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function Motion.confettiBurst(parent: GuiObject)
	if GuiService.ReducedMotionEnabled then
		return function() end
	end
	local particles, tweens = {}, {}
	local rotatePieces = not ScrollingClipping.isInsideClippingScrollingFrame(parent)
	local colors = { T.Colors.Pink, T.Colors.Yellow, T.Colors.Cyan, T.Colors.Grape, T.Colors.Surface }
	for index = 1, T.Motion.BurstCount do
		local piece = Instance.new("Frame")
		piece.Name = "CandyConfetti"
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.BackgroundColor3 = colors[index % #colors + 1]
		piece.BorderSizePixel = 0
		piece.Size = UDim2.fromOffset(8, if index % 2 == 0 then 8 else 16)
		piece.Position = UDim2.fromScale(0.5, 0.45)
		piece.Rotation = index * 29
		piece.ZIndex = 40
		piece.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 3)
		corner.Parent = piece
		local angle = index / T.Motion.BurstCount * math.pi * 2
		local goal = {
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.46, 0.5 + math.sin(angle) * 0.42),
			BackgroundTransparency = 1,
		}
		if rotatePieces then
			goal.Rotation = piece.Rotation + 180
		end
		local tween = TweenService:Create(
			piece,
			TweenInfo.new(T.Motion.BurstDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			goal
		)
		table.insert(particles, piece)
		table.insert(tweens, tween)
		tween:Play()
	end
	local function cleanup()
		for _, tween in tweens do
			tween:Cancel()
		end
		for _, piece in particles do
			piece:Destroy()
		end
	end
	task.delay(T.Motion.BurstDuration, cleanup)
	return cleanup
end

return table.freeze(Motion)
