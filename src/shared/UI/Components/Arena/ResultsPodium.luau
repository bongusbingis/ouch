-- A world-space podium with candy nameplates; the scene owns its temporary camera lease.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Scene = require(script.Parent.Parent.Parent.Services.PostMatchScene)
local T = require(script.Parent.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Parent.Hooks.useReducedMotion)
local useReveal = require(script.Parent.Parent.Parent.Hooks.useReveal)
local Badge = require(script.Parent.Parent.Badge)
local CandySurface = require(script.Parent.Parent.CandySurface)
local c, C, R = React.createElement, T.Colors, T.Results

local function Nameplate(props)
	local entry = props.Entry
	local reduced = useReducedMotion()
	local shown = useReveal(props.Key, props.Delay, reduced)
	local ref = React.useRef(nil)
	React.useEffect(function()
		if shown and ref.current and not reduced then
			return Motion.popIn(ref.current)
		end
		return nil
	end, { shown, props.Key })
	local badge = props.BadgeSize
	local textLeft = math.floor(badge * 0.9) + 6
	local compact = props.Height < 56
	return c("Frame", {
		ref = ref,
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(props.X, 1),
		Size = UDim2.fromOffset(props.Width, props.Height),
		Visible = props.Visible and shown,
		ZIndex = 6,
	}, {
		Surface = c(CandySurface, {
			Color = C.SurfaceWarm,
			LipColor = C.WellLine,
			Radius = T.Shape.RadiusCard,
			Shadow = false,
			ZIndex = 6,
		}),
		Rank = c(Badge, {
			Text = tostring(entry.placement),
			Color = R.PlacementColors[math.clamp(entry.placement, 1, 3)],
			TextSize = math.floor(badge * 0.56),
			Visible = props.Visible and shown,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(math.floor(badge * 0.3), math.floor(badge * 0.34)),
				Size = UDim2.fromOffset(badge, badge),
				ZIndex = 12,
			},
		}),
		Name = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = T.Type.Display,
			Text = entry.displayName,
			TextColor3 = C.Ink,
			TextSize = if compact then T.Type.HudMinimum else 22,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(textLeft, 4),
			Size = UDim2.new(1, -textLeft - 8, 0.5, -2),
			ZIndex = 10,
		}),
		Score = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = T.Type.Label,
			Text = `{entry.score} {props.ScoreLabel}`,
			TextColor3 = C.InkSoft,
			TextSize = T.Type.HudMinimum,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(0, textLeft, 0.5, -2),
			Size = UDim2.new(1, -textLeft - 8, 0.5, -T.Shape.LipHeight),
			ZIndex = 10,
		}),
	})
end

return function(props)
	local region = React.useRef(nil)
	local entries = props.Entries or {}
	-- No placed finishers (a draw, a no-contest round): the viewer stands alone on a neutral
	-- centre pedestal instead of leaving the stage as an empty deck.
	local showcase = entries
	if #entries == 0 and props.Fallback ~= nil then
		local solo: any = table.clone(props.Fallback)
		solo.placement = 1
		solo.neutral = true
		showcase = { solo }
	end
	local identity = {}
	for _, entry in showcase do
		table.insert(
			identity,
			table.concat({
				entry.playerId,
				tostring(entry.placement),
				entry.colorId or "",
				entry.costumeId or "",
				entry.emoteId or "",
			}, ":")
		)
	end
	React.useEffect(function()
		return Scene.create(showcase, region.current)
	end, { props.ResultId, table.concat(identity, "|") })
	local labels = {}
	for index = 1, math.min(#entries, 3) do
		local entry = entries[index]
		labels[entry.playerId] = c(Nameplate, {
			Entry = entry,
			X = R.PodiumX[index],
			Width = props.PlateWidth,
			Height = props.PlateHeight,
			BadgeSize = props.BadgeSize,
			ScoreLabel = props.ScoreLabel,
			Delay = R.RevealDelay + (index - 1) * R.RevealStagger,
			Key = props.ResultId,
			Visible = props.ShowLabels ~= false,
		})
	end
	local top = props.TopInset or 0
	return c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Region = c("Frame", {
			ref = region,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.new(1, 0, 1, -top - props.PlateHeight - 8),
		}),
		Names = c("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, labels),
	})
end
