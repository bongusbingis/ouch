--!strict
-- Art for effects with no authored image: an outlined candy seal in the
-- effect's own colours (Tokens.Collectible.EffectAccent) filling the art window,
-- a pale core and two outlined sparkle stickers on the seal's spikes. Impacts
-- hold the item glyph in ink; sounds hold a candy equalizer instead of a stock
-- speaker glyph. Nothing rotates, so the art clips correctly inside scrollers.
-- Hover plays a confetti pop (impacts) or bounces the equalizer (sounds); the
-- full effect still opens in the inspection scene. Reduced motion stays still.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local Icon = require(script.Parent.Icon)
local c, C, K = React.createElement, T.Colors, T.Collectible

local OUTLINE_OFFSETS = {
	Vector2.new(-1, 0),
	Vector2.new(1, 0),
	Vector2.new(0, -1),
	Vector2.new(0, 1),
	Vector2.new(-0.7, -0.7),
	Vector2.new(0.7, -0.7),
	Vector2.new(-0.7, 0.7),
	Vector2.new(0.7, 0.7),
}
local SEAL = "Explosion"
-- The seal fills the art square (the Explosion silhouette's spikes reach its
-- edges); the window already insets the art clear of the seam tag.
local SEAL_FILL = 1
local SPARK = "Sparkle"
-- Equalizer bars inside the core: resting heights per pattern (picked from the
-- item id so a row of sounds is not identical) and the hover bounce peaks.
local EQ_PATTERNS = { { 0.5, 0.82, 0.62 }, { 0.7, 0.46, 0.84 }, { 0.84, 0.6, 0.44 } }
local EQ_WIDTH = 0.15
local EQ_STEP = 0.21
local EQ_BASE = 0.76
local EQ_MIN = 0.22

local function accentsFor(props): (Color3, Color3)
	if props.Category == "ElimEffectAssets" then
		return K.SoundAccent[1], K.SoundAccent[2]
	end
	local definition = props.Definition or {}
	local pair = K.EffectAccent[definition.EffectId or ""] or K.EffectAccent.DefaultImpact
	return pair[1], pair[2]
end

local function seal(color: Color3, offset: Vector2, z: number)
	return c(Icon, {
		Name = SEAL,
		Color = color,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, offset.X, 0.5, offset.Y),
			Size = UDim2.fromScale(1, 1),
			ZIndex = z,
		},
	})
end

-- A sparkle sticker pinned on one of the seal's spikes: the licensed Sparkle
-- glyph in a candy colour over an ink outline, the same recipe as the seal.
local function spark(color: Color3, position: UDim2, scale: number, z: number)
	local layers = {}
	for index, direction in OUTLINE_OFFSETS do
		layers["Outline" .. index] = c(Icon, {
			Name = SPARK,
			Color = C.Ink,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, direction.X * 2, 0.5, direction.Y * 2),
				ZIndex = z,
			},
		})
	end
	layers.Fill = c(Icon, {
		Name = SPARK,
		Color = color,
		Native = { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = z + 1 },
	})
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = position,
		Size = UDim2.fromScale(scale, scale),
		ZIndex = z,
	}, layers)
end

local function patternFor(itemId: string?): { number }
	local sum = 0
	for index = 1, #(itemId or "") do
		sum += string.byte(itemId :: string, index)
	end
	return EQ_PATTERNS[sum % #EQ_PATTERNS + 1]
end

return function(props)
	local ref = React.useRef(nil)
	local sound = props.Category == "ElimEffectAssets"
	local z = props.ZIndex or 1
	local primary, secondary = accentsFor(props)
	local definition = props.Definition or {}
	local glyph = definition.Icon or SEAL
	local pattern = patternFor(props.ItemId)
	React.useEffect(function()
		local target = ref.current
		if not target or not props.Playing or GuiService.ReducedMotionEnabled then
			return nil
		end
		if not sound then
			return Motion.confettiBurst(target)
		end
		local tweens = {}
		for index = 1, 3 do
			local bar = target:FindFirstChild("Wave" .. index, true)
			if bar then
				-- Each bar bounces between a low and its own peak, out of phase.
				bar.Size = UDim2.fromScale(EQ_WIDTH, EQ_MIN)
				local tween = TweenService:Create(
					bar,
					TweenInfo.new(0.2 + index * 0.07, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Size = UDim2.fromScale(EQ_WIDTH, EQ_BASE - EQ_MIN + 0.02 - (index - 2) * 0.04) }
				)
				table.insert(tweens, tween)
				tween:Play()
			end
		end
		return function()
			for _, tween in tweens do
				tween:Cancel()
			end
			for index = 1, 3 do
				local bar = target:FindFirstChild("Wave" .. index, true)
				if bar then
					bar.Size = UDim2.fromScale(EQ_WIDTH, pattern[index] * (EQ_BASE - EQ_MIN))
				end
			end
		end
	end, { props.Playing })

	local stroke = K.SealStroke
	local sealChildren = {}
	for index, direction in OUTLINE_OFFSETS do
		sealChildren["Outline" .. index] = seal(C.Ink, direction * stroke, z)
	end
	sealChildren.Drop = seal(C.Ink, Vector2.new(0, stroke + K.SealDrop), z)
	sealChildren.Lip = seal(primary:Lerp(C.Ink, 0.22), Vector2.new(0, K.SealDrop), z + 1)
	sealChildren.Fill = seal(primary, Vector2.zero, z + 2)
	sealChildren.Gloss = c(Icon, {
		Name = SEAL,
		Color = C.Surface,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			ImageTransparency = T.Shape.HighlightTransparency,
			Position = UDim2.fromScale(0.5, 0.46),
			Size = UDim2.fromScale(0.86, 0.86),
			ZIndex = z + 3,
		},
	}, {
		Fade = c("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.45, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	local coreChildren: { [string]: any } = {
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Outline = c("UIStroke", { Color = C.Ink, Thickness = T.Shape.StrokeInner }),
	}
	if sound then
		-- A candy equalizer sitting on one baseline inside the core, never on the seal edge.
		for index = 1, 3 do
			coreChildren["Wave" .. index] = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = if index == 2 then primary else secondary,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5 + (index - 2) * EQ_STEP, EQ_BASE),
				Size = UDim2.fromScale(EQ_WIDTH, pattern[index] * (EQ_BASE - EQ_MIN)),
				ZIndex = z + 5,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Outline = c("UIStroke", { Color = C.Ink, Thickness = 2 }),
			})
		end
	else
		coreChildren.Glyph = c(Icon, {
			Name = glyph,
			Color = C.Ink,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(K.GlyphScale, K.GlyphScale),
				ZIndex = z + 5,
			},
		})
	end
	sealChildren.Core = c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = primary:Lerp(C.Surface, 0.7),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(K.CoreScale, K.CoreScale),
		ZIndex = z + 4,
	}, coreChildren)
	sealChildren.SparkA = spark(secondary, UDim2.fromScale(0.84, 0.16), K.SparkScale * 1.7, z + 6)
	sealChildren.SparkB = spark(C.Surface, UDim2.fromScale(0.15, 0.83), K.SparkScale * 1.25, z + 6)
	return c("Frame", {
		ref = ref,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
	}, {
		Seal = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(SEAL_FILL, SEAL_FILL),
			ZIndex = z,
		}, sealChildren),
		Aspect = c("UIAspectRatioConstraint", { AspectRatio = 1 }),
	})
end
