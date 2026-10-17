--!strict
-- Artwork-led queue choices. Activating a card delegates to the party queue owner.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local Spring = require(RS.Packages["react-spring"])
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local AnimatedButton = require(script.Parent.AnimatedButton)
local Surface = require(script.Parent.CandySurface)
local Icon = require(script.Parent.Icon)
local Text = require(script.Parent.LobbyText)
local c, C, S = React.createElement, T.Colors, T.ModePicker

export type Option = {
	id: string,
	title: string,
	description: string?,
	artwork: string?,
	comingSoon: boolean?,
}
export type Props = {
	Options: { Option },
	SelectedId: string?,
	Enabled: boolean,
	OnSelect: (string) -> (),
	Compact: boolean?,
	Stacked: boolean?,
	CardHeight: number?,
	-- The modal measures the copy and hands every card the same sizes, so siblings never differ.
	ArtHeight: number?,
	DescriptionSize: number?,
	DescriptionHeight: number?,
	SelectedButtonRef: any?,
	FirstButtonRef: any?,
	Native: { [any]: any }?,
}

local PILL_HEIGHT = 40
local CARD_INSET = 16
local DESCRIPTION_GAP = 8

local function ModeCard(props)
	local option, selected, compact, z = props.Option, props.Selected, props.Compact, props.ZIndex
	local comingSoon = option.comingSoon == true
	local cardSelected = selected and not comingSoon
	local cardEnabled = props.Enabled and not comingSoon
	local reduced = useReducedMotion()
	local styles, api = Spring.useSpring(function()
		return { Selected = if cardSelected then 1 else 0 }
	end)
	React.useEffect(function()
		api.start({ Selected = if cardSelected then 1 else 0, config = Motion.Control, immediate = reduced })
	end, { cardSelected, reduced })
	React.useEffect(function()
		return function()
			api.stop()
		end
	end, {})
	local fill = styles.Selected:map(function(value)
		return C.Surface:Lerp(C.Pink:Lerp(C.Surface, 0.89), math.clamp(value, 0, 1))
	end)
	local line = styles.Selected:map(function(value)
		return C.Ink:Lerp(C.Pink, math.clamp(value, 0, 1))
	end)
	local cardFill = if comingSoon then C.SurfaceWarm:Lerp(C.WellLine, 0.4) else fill
	local cardLine = if comingSoon then C.WellLine else line
	local lipColor = if comingSoon then C.WellLine else if cardSelected then C.PinkLip else C.WellLine
	local artHeight = props.ArtHeight or math.floor(props.Height * 0.46)
	local textX = if compact then UDim.new(0.39, 0) else UDim.new(0, 18)
	local textWidth = if compact then UDim.new(0.61, -16) else UDim.new(1, -36)
	local titleTop = if compact then 12 else artHeight + 18
	local descriptionTop = if compact then 52 else artHeight + 58
	local descriptionHeight = props.DescriptionHeight
		or math.max(props.Height - descriptionTop - CARD_INSET - PILL_HEIGHT - DESCRIPTION_GAP, T.Type.Minimum)
	local pillTextSize = if compact then T.Type.Minimum else T.Type.TileLabel
	return c(AnimatedButton, {
		ButtonRef = props.ButtonRef,
		Enabled = cardEnabled,
		Style = "Primary",
		HoverRotation = false,
		SelectionRadius = UDim.new(0, T.Shape.RadiusCard),
		Native = { BackgroundTransparency = 1, Image = "", LayoutOrder = props.Order, Size = props.Size, ZIndex = z },
		Visual = c(Surface, {
			Color = cardFill,
			LipColor = lipColor,
			StrokeColor = cardLine,
			Radius = T.Shape.RadiusCard,
			Shadow = false,
			ZIndex = z,
		}),
		OnActivated = function()
			if cardEnabled then
				props.OnSelect(option.id)
			end
		end,
	}, {
		Artwork = c("ImageLabel", {
			Image = option.artwork or S.PlaceholderArt,
			ScaleType = Enum.ScaleType.Crop,
			BackgroundColor3 = if comingSoon
				then C.WellLine
				elseif option.id == "Arena" then C.Cyan
				else C.Grape,
			ImageColor3 = if comingSoon then Color3.fromRGB(160, 160, 160) else Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 8),
			Size = if compact then UDim2.new(0.36, 0, 1, -16) else UDim2.new(1, -16, 0, artHeight),
			ClipsDescendants = true,
			ZIndex = z + 5,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }) }),
		Title = c(Text, {
			Text = option.title,
			Font = T.Type.Display,
			TextColor3 = if comingSoon then C.InkSoft else C.Ink,
			TextSize = if compact then 22 else 28,
			Position = UDim2.new(textX, UDim.new(0, titleTop)),
			Size = UDim2.new(textWidth, UDim.new(0, 34)),
			ZIndex = z + 6,
		}),
		Description = c(Text, {
			Text = option.description or option.title,
			Font = T.Type.Label,
			TextSize = props.DescriptionSize or T.Type.Minimum,
			TextColor3 = if comingSoon then C.WellLine:Lerp(C.InkSoft, 0.7) else C.InkSoft,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(textX, UDim.new(0, descriptionTop)),
			Size = UDim2.new(textWidth, UDim.new(0, descriptionHeight)),
			ZIndex = z + 6,
		}),
		Choice = c("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(textX, UDim.new(1, -CARD_INSET)),
			Size = UDim2.new(textWidth, UDim.new(0, PILL_HEIGHT)),
			ZIndex = z + 6,
		}, {
			-- The same candy pill as every button: pink once chosen, cream while it is still an offer, grey when coming soon.
			Pill = c(Surface, {
				Color = if comingSoon
					then C.WellLine
					elseif cardSelected then C.Pink
					else C.SurfaceWarm,
				LipColor = if comingSoon
					then C.WellLine:Lerp(C.Ink, 0.15)
					elseif cardSelected then C.PinkLip
					else C.WellLine,
				StrokeColor = if comingSoon then C.WellLine:Lerp(C.Ink, 0.15) else nil,
				Shadow = false,
				ZIndex = z + 6,
			}),
			Label = c("TextLabel", {
				BackgroundTransparency = 1,
				Font = T.Type.Display,
				Text = if comingSoon then "COMING SOON" elseif cardSelected then "SELECTED" else "SELECT MODE",
				TextSize = pillTextSize,
				TextColor3 = if comingSoon then C.InkSoft elseif cardSelected then C.Surface else C.Ink,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(if cardSelected then 20 else 0, 0),
				Size = UDim2.new(1, if cardSelected then -20 else 0, 1, -T.Shape.LipHeight),
				ZIndex = z + 10,
			}, {
				Outline = if cardSelected then c("UIStroke", { Color = C.Ink, Thickness = T.Type.Outline }) else nil,
			}),
			Check = if cardSelected
				then c(Icon, {
					Name = "Check",
					Color = C.Surface,
					Native = {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 14, 0.5, -T.Shape.LipHeight / 2),
						Size = UDim2.fromOffset(18, 18),
						ZIndex = z + 10,
					},
				})
				else nil,
		}),
	})
end

return function(props: Props)
	local native = table.clone(props.Native or {})
	native.BackgroundTransparency = 1
	local count, gap = math.max(#props.Options, 1), S.Gap
	local children = {
		Layout = c("UIListLayout", {
			FillDirection = if props.Stacked then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, option in props.Options do
		children[option.id] = c(ModeCard, {
			Option = option,
			Selected = option.id == props.SelectedId,
			Enabled = props.Enabled,
			OnSelect = props.OnSelect,
			Order = index,
			Compact = props.Compact,
			Height = props.CardHeight or S.CardMinHeight,
			ArtHeight = props.ArtHeight,
			DescriptionSize = props.DescriptionSize,
			DescriptionHeight = props.DescriptionHeight,
			ZIndex = native.ZIndex or 1,
			ButtonRef = if option.id == props.SelectedId and not option.comingSoon
				then props.SelectedButtonRef
				elseif index == 1 and not option.comingSoon then props.FirstButtonRef
				else nil,
			Size = if props.Stacked
				then UDim2.new(1, 0, 0, props.CardHeight or S.CompactCardMinHeight)
				else UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0),
		})
	end
	return c("Frame", native, children)
end
