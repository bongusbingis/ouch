--!strict
-- Persistent instructions over a three-shot cinematic. Only the decorative
-- candy face tilts; titles, copy and progress remain upright.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local Model = require(script.Parent.Parent.Models.SplashdownIntroModel)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local CandySurface = require(script.Parent.CandySurface)
local c, C, L = React.createElement, T.Colors, T.CourseIntro

local function label(text: string, size: number, font: Enum.Font, color: Color3, position: UDim2, dimensions: UDim2)
	return c("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		Font = font,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Position = position,
		Size = dimensions,
		ZIndex = 35,
	})
end

return function(props)
	local safe = useSafeArea(Enum.ScreenInsets.None)
	local narrow = safe.size.X < L.NarrowWidth
	local short = safe.size.Y < L.ShortHeight
	local compact = narrow or short
	local edge = if compact then L.CompactEdge else L.Edge
	local inset = if compact then L.CompactInset else L.Inset
	local width = math.min(L.Width, safe.size.X - edge * 2)
	local height = if narrow then L.PortraitHeight elseif short then L.CompactHeight else L.Height
	local titleSize = if narrow then L.PortraitTitle elseif short then L.CompactTitle else L.Title
	local titleHeight = titleSize + T.Layout.CompactGap
	local bodySize = if compact then L.CompactBody else L.Body
	local cardRef = React.useRef(nil)
	local progress, setProgress = React.useBinding(0)
	local cover, setCover = React.useBinding(1)
	local course = Model.course(props.CourseId)

	React.useEffect(function()
		local function update()
			local sample = Model.sample(props.CourseId, props.EndsAt, Workspace:GetServerTimeNow())
			setProgress(sample.progress)
			setCover(sample.cover)
		end
		update()
		local connection = RunService.RenderStepped:Connect(update)
		local cleanup = if cardRef.current then Motion.popIn(cardRef.current) else nil
		return function()
			connection:Disconnect()
			if cleanup then
				cleanup()
			end
		end
	end, { props.CourseId, props.EndsAt })

	local segments = {}
	local count = #course.Shots
	for index = 1, count do
		segments[`Shot{index}`] = c("Frame", {
			BackgroundColor3 = C.WellLine,
			BorderSizePixel = 0,
			Position = UDim2.new((index - 1) / count, L.ProgressGap / 2, 0, 0),
			Size = UDim2.new(1 / count, -L.ProgressGap, 1, 0),
			ZIndex = 35,
		}, {
			Fill = c("Frame", {
				BackgroundColor3 = C.Pink,
				BorderSizePixel = 0,
				Size = progress:map(function(value)
					return UDim2.fromScale(math.clamp(value * count - index + 1, 0, 1), 1)
				end),
				ZIndex = 36,
			}),
		})
	end

	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20 }, {
		Cut = c("Frame", {
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = cover:map(function(value)
				return 1 - value
			end),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,
		}),
		LowerScrim = c("Frame", {
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = L.ScrimTransparency,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, height + edge * 3),
			ZIndex = 21,
		}, { Fade = c("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }) }),
		TopBar = c("Frame", {
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, L.LetterboxHeight),
			ZIndex = 22,
		}),
		BottomBar = c("Frame", {
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, L.LetterboxHeight),
			ZIndex = 22,
		}),
		Card = c("Frame", {
			ref = cardRef,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromOffset(
				safe.position.X + edge,
				safe.position.Y + safe.size.Y - edge - L.LetterboxHeight
			),
			Size = UDim2.fromOffset(width, height),
			ZIndex = 30,
		}, {
			Face = c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Rotation = T.Shape.TiltPanel,
				ZIndex = 30,
			}, { Surface = c(CandySurface, { Color = C.SurfaceWarm, Radius = T.Shape.RadiusCard, ZIndex = 30 }) }),
			Kicker = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(inset, -L.KickerHeight / 2),
				Size = UDim2.fromOffset(math.min(L.KickerWidth, width - inset * 2), L.KickerHeight),
				ZIndex = 31,
			}, {
				Surface = c(CandySurface, { Color = C.Yellow, Shadow = false, ZIndex = 31 }),
				Text = label(
					`SPLASHDOWN / {props.RoundLabel}`,
					T.Type.Minimum,
					T.Type.CompactLabel,
					C.Ink,
					UDim2.fromOffset(T.Layout.CompactGap, 0),
					UDim2.new(1, -T.Layout.CompactGap * 2, 1, -T.Shape.LipHeight)
				),
			}),
			Title = label(
				props.Title,
				titleSize,
				T.Type.Display,
				C.Ink,
				UDim2.fromOffset(inset, inset),
				UDim2.new(1, -inset * 2, 0, titleHeight)
			),
			Description = label(
				course.Description,
				bodySize,
				T.Type.Label,
				C.InkSoft,
				UDim2.fromOffset(inset, inset + titleHeight),
				UDim2.new(1, -inset * 2, 1, -inset * 3 - titleHeight)
			),
			Progress = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, inset, 1, -inset),
				Size = UDim2.new(1, -inset * 2, 0, L.ProgressHeight),
				ZIndex = 35,
			}, segments),
		}),
	})
end
