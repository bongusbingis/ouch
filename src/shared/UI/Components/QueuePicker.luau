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

export type Option = { id: string, title: string, description: string?, artwork: string? }
export type Props = {
	Options: { Option },
	SelectedId: string?,
	Enabled: boolean,
	OnSelect: (string) -> (),
	Compact: boolean?,
	Stacked: boolean?,
	CardHeight: number?,
	SelectedButtonRef: any?,
	FirstButtonRef: any?,
	Native: { [any]: any }?,
}

local function ModeCard(props)
	local option, selected, compact, z = props.Option, props.Selected, props.Compact, props.ZIndex
	local reduced = useReducedMotion()
	local styles, api = Spring.useSpring(function()
		return { Selected = if selected then 1 else 0 }
	end)
	React.useEffect(function()
		api.start({ Selected = if selected then 1 else 0, config = Motion.Control, immediate = reduced })
	end, { selected, reduced })
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
	local artHeight = math.floor(props.Height * 0.52)
	local textX = if compact then UDim.new(0.39, 0) else UDim.new(0, 18)
	local textWidth = if compact then UDim.new(0.61, -16) else UDim.new(1, -36)
	return c(AnimatedButton, {
		ButtonRef = props.ButtonRef,
		Enabled = props.Enabled,
		Style = "Primary",
		HoverRotation = false,
		SelectionRadius = UDim.new(0, T.Shape.RadiusCard),
		Native = { BackgroundTransparency = 1, Image = "", LayoutOrder = props.Order, Size = props.Size, ZIndex = z },
		Visual = c(Surface, {
			Color = fill,
			LipColor = if selected then C.PinkLip else C.WellLine,
			StrokeColor = line,
			Radius = T.Shape.RadiusCard,
			Shadow = false,
			ZIndex = z,
		}),
		OnActivated = function()
			if props.Enabled then
				props.OnSelect(option.id)
			end
		end,
	}, {
		Artwork = c("ImageLabel", {
			Image = option.artwork or S.PlaceholderArt,
			ScaleType = Enum.ScaleType.Crop,
			BackgroundColor3 = if option.id == "Arena" then C.Cyan else C.Grape,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 8),
			Size = if compact then UDim2.new(0.36, 0, 1, -16) else UDim2.new(1, -16, 0, artHeight),
			ClipsDescendants = true,
			ZIndex = z + 5,
		}, { Corner = c("UICorner", { CornerRadius = UDim.new(0, 16) }) }),
		Title = c(Text, {
			Text = option.title,
			Font = T.Type.Display,
			TextSize = if compact then 22 else 28,
			Position = UDim2.new(textX, UDim.new(0, if compact then 12 else artHeight + 18)),
			Size = UDim2.new(textWidth, UDim.new(0, 34)),
			ZIndex = z + 6,
		}),
		Description = c(Text, {
			Text = option.description or option.title,
			Font = Enum.Font.BuilderSans,
			TextColor3 = C.InkSoft,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.new(textX, UDim.new(0, if compact then 52 else artHeight + 58)),
			Size = UDim2.new(textWidth, UDim.new(0, if compact then 80 else 64)),
			ZIndex = z + 6,
		}),
		Choice = c("Frame", {
			BackgroundColor3 = if selected then C.Pink else C.Well,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(textX, UDim.new(1, -16)),
			Size = UDim2.new(textWidth, UDim.new(0, 34)),
			ZIndex = z + 6,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Label = c(Text, {
				Text = if selected then "SELECTED" else "SELECT MODE",
				TextSize = 18,
				TextColor3 = if selected then C.Surface else C.Ink,
				TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(if selected then 20 else 0, 0),
				Size = UDim2.new(1, if selected then -20 else 0, 1, 0),
				ZIndex = z + 7,
			}),
			Check = if selected
				then c(Icon, {
					Name = "Check",
					Color = C.Surface,
					Native = { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(18, 18), ZIndex = z + 7 },
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
			ZIndex = native.ZIndex or 1,
			ButtonRef = if option.id == props.SelectedId
				then props.SelectedButtonRef
				elseif index == 1 then props.FirstButtonRef
				else nil,
			Size = if props.Stacked
				then UDim2.new(1, 0, 0, props.CardHeight or S.CompactCardMinHeight)
				else UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0),
		})
	end
	return c("Frame", native, children)
end
