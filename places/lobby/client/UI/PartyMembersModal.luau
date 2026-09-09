-- Compact party management derives membership and actions from the lobby's existing adapter.
--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local DeviceClass = require(UI.Parent:WaitForChild("Game"):WaitForChild("Input"):WaitForChild("DeviceClass"))
local Surface = require(UI.Components.Arena.Surface)
local PriceButton = require(UI.Components.Shop.ShopPriceButton)
local ResponsiveText = require(UI.Components.ResponsiveText)
local ScrollFrame = require(UI.Components.ScrollFrame)
local Selection = require(UI.Services.Selection)
local useSafeArea = require(UI.Hooks.useSafeArea)

local modalSurface = require(ReplicatedStorage.Shared.UI.Components.ModalSurface)

local c = React.createElement
local Palette = Config.ProgressionStyle

export type Member = {
	userId: number,
	username: string?,
}

export type Props = {
	Open: boolean,
	FocusEnabled: boolean?,
	Members: { Member },
	LocalUserId: number,
	LeaderUserId: number?,
	CodeText: string,
	CodeVisible: boolean,
	CodeAvailable: boolean,
	CanRemove: boolean,
	OnToggleCode: () -> (),
	OnRemove: (number, string) -> (),
	OnClose: () -> (),
}

local function label(text, position, size, maximum, heading)
	return c(ResponsiveText, {
		MeasurementFont = if heading then Enum.Font.LuckiestGuy else Config.Text.BodyFont,
		MaxTextSize = maximum,
		Wrapped = not heading,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = if heading then Enum.Font.LuckiestGuy else Config.Text.BodyFont,
			Text = text,
			TextColor3 = Palette.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeColor3 = Palette.Ink,
			TextStrokeTransparency = 1,
			ZIndex = 4,
		},
	})
end

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local layout = Config.Layout.PartyCode.Members
	local margin, gap = layout.MarginPx, layout.GapPx
	local target = Config.Interaction.MinTargetPx
	local width = math.min(layout.MaxWidthPx, math.max(safeArea.size.X - margin * 2, 1))
	local codeTop = margin + target + gap
	local listTop = codeTop + target + gap
	local rowCount = math.max(#props.Members, 1)
	local contentHeight = rowCount * layout.RowHeightPx + (rowCount - 1) * gap + gap * 1.5
	local height =
		math.min(layout.MaxHeightPx, math.max(safeArea.size.Y - margin * 2, 1), listTop + contentHeight + margin)
	local backRef = React.useRef(nil)
	local modalRef = React.useRef(nil)
	local memberIds = {}
	for _, member in props.Members do
		table.insert(memberIds, tostring(member.userId))
	end
	local memberKey = table.concat(memberIds, ",")
	React.useEffect(function()
		if not props.Open or props.FocusEnabled == false then
			return
		end
		local previous = GuiService.SelectedObject
		local modal = modalRef.current
		local active = true
		local disconnect = DeviceClass.observe(function(input)
			if input == "Gamepad" then
				task.defer(function()
					if active and DeviceClass.current() == "Gamepad" and Selection.isSelectable(backRef.current) then
						local selected = GuiService.SelectedObject
						if
							not (
								selected
								and modal
								and selected:IsDescendantOf(modal)
								and Selection.isSelectable(selected)
							)
						then
							GuiService.SelectedObject = backRef.current
						end
					end
				end)
			end
		end)
		return function()
			active = false
			disconnect()
			local selected = GuiService.SelectedObject
			if
				DeviceClass.current() == "Gamepad"
				and (selected == nil or (modal and selected:IsDescendantOf(modal)))
				and Selection.isSelectable(previous)
			then
				GuiService.SelectedObject = previous
			end
		end
	end, { props.Open, props.FocusEnabled, memberKey, props.CanRemove })
	if not props.Open then
		return nil
	end
	local rows = {
		Layout = c("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, gap) }),
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, gap / 2),
			PaddingBottom = UDim.new(0, gap),
			PaddingLeft = UDim.new(0, gap / 2),
			PaddingRight = UDim.new(0, gap),
		}),
	}
	for index, member in props.Members do
		local localMember = member.userId == props.LocalUserId
		local leader = member.userId == props.LeaderUserId
		local removable = props.LocalUserId == props.LeaderUserId and not localMember
		local nameWidth = if removable then -layout.ActionWidthPx - gap * 3 else -gap * 2
		local status = if localMember and leader
			then "YOU · PARTY LEADER"
			elseif leader then "PARTY LEADER"
			elseif localMember then "YOU"
			else nil
		rows[tostring(member.userId)] = c(Surface, {
			Color = Palette.White,
			Shadow = false,
			Native = { LayoutOrder = index, Size = UDim2.new(1, 0, 0, layout.RowHeightPx) },
		}, {
			Name = label(
				member.username or "Loading…",
				UDim2.fromOffset(gap, if status then 4 else 0),
				UDim2.new(1, nameWidth, 0, if status then 30 else layout.RowHeightPx),
				21,
				false
			),
			Status = if status
				then label(status, UDim2.fromOffset(gap, 33), UDim2.new(1, nameWidth, 0, 18), 13, true)
				else nil,
			Remove = if removable
				then c(PriceButton, {
					Enabled = props.CanRemove and member.username ~= nil,
					Red = true,
					Compact = true,
					Text = "REMOVE",
					TextSize = 19,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -gap, 0.5, 0),
					Size = UDim2.fromOffset(layout.ActionWidthPx, target),
					OnActivated = function()
						if member.username then
							props.OnRemove(member.userId, member.username)
						end
					end,
				})
				else nil,
		})
	end
	if #props.Members == 0 then
		rows.Empty = label("Loading party…", UDim2.new(), UDim2.new(1, 0, 0, layout.RowHeightPx), 21, false)
	end
	return modalSurface({
		ref = modalRef,
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = Palette.Ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 110,
	}, {
		Panel = c(Surface, {
			Color = Palette.Panel,
			Native = {
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(width, height),
				SelectionGroup = true,
				SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
				SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
				SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
				SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
				ZIndex = 111,
			},
		}, {
			Title = label(
				"YOUR PARTY",
				UDim2.fromOffset(margin, margin),
				UDim2.new(1, -margin * 2 - layout.ActionWidthPx - gap, 0, target),
				32,
				true
			),
			Back = c(PriceButton, {
				Color = Palette.Ink,
				ButtonRef = backRef,
				Text = "BACK",
				TextSize = 22,
				Compact = true,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -margin, 0, margin),
				Size = UDim2.fromOffset(layout.ActionWidthPx, target),
				OnActivated = props.OnClose,
			}),
			Code = label(
				props.CodeText,
				UDim2.fromOffset(margin, codeTop),
				UDim2.new(1, -margin * 2 - layout.ActionWidthPx - gap, 0, target),
				25,
				true
			),
			ToggleCode = c(PriceButton, {
				Text = if props.CodeVisible then "HIDE CODE" else "SHOW CODE",
				TextSize = 18,
				Compact = true,
				Color = Palette.Yellow,
				TextColor = Palette.Ink,
				TextStroke = 0,
				Enabled = props.CodeAvailable,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -margin, 0, codeTop),
				Size = UDim2.fromOffset(layout.ActionWidthPx, target),
				OnActivated = props.OnToggleCode,
			}),
			Members = c(ScrollFrame, {
				Active = true,
				Selectable = not props.CanRemove,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarImageColor3 = Palette.White,
				ScrollBarThickness = 4,
				Position = UDim2.fromOffset(margin, listTop),
				Size = UDim2.new(1, -margin * 2, 0, math.max(height - listTop - margin, 1)),
			}, rows),
		}),
	})
end
