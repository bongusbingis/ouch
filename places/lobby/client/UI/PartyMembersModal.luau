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
local ModalClose = require(UI.Components.ModalClose)
local ResponsiveText = require(UI.Components.ResponsiveText)
local PageTitle = require(UI.Components.PageTitle)
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

local function label(text, position, size, maximum, muted)
	return c(ResponsiveText, {
		MeasurementFont = Config.Text.BodyFont,
		MinTextSize = 14,
		MaxTextSize = maximum,
		Wrapped = true,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = Config.Text.BodyFont,
			Text = text,
			TextColor3 = if muted then Palette.Muted else Palette.White,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
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
	local codeHeight = target + gap * 2
	local listTop = codeTop + codeHeight + gap
	local rowCount = math.max(#props.Members, 1)
	local contentHeight = rowCount * layout.RowHeightPx + (rowCount - 1) * gap + 4
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
		Layout = c("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, gap),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
		}),
	}
	for index, member in props.Members do
		local localMember = member.userId == props.LocalUserId
		local leader = member.userId == props.LeaderUserId
		local removable = props.LocalUserId == props.LeaderUserId and not localMember
		local nameWidth = if removable then -layout.ActionWidthPx - 32 else -24
		local status = if localMember and leader
			then "YOU · PARTY LEADER"
			elseif leader then "PARTY LEADER"
			elseif localMember then "YOU"
			else nil
		rows[tostring(member.userId)] = c(Surface, {
			Color = Palette.Claimed,
			Radius = 8,
			StrokeTransparency = 0.6,
			Shadow = false,
			Native = { LayoutOrder = index, Size = UDim2.new(1, -4, 0, layout.RowHeightPx) },
		}, {
			Name = label(
				member.username or "Loading…",
				UDim2.fromOffset(12, if status then 6 else 0),
				UDim2.new(1, nameWidth, 0, if status then 28 else layout.RowHeightPx),
				21,
				false
			),
			Status = if status
				then label(
					status,
					UDim2.fromOffset(12, 32),
					UDim2.new(1, nameWidth, 0, 24),
					Config.Text.CaptionMinPx,
					true
				)
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
			Title = c(PageTitle, {
				Text = "YOUR PARTY",
				TextSize = 32,
				Alignment = Enum.TextXAlignment.Left,
				Native = {
					Position = UDim2.fromOffset(margin, margin + 2),
					Size = UDim2.new(1, -margin * 2 - layout.ActionWidthPx - gap, 0, target),
				},
			}),
			Back = c(ModalClose, {
				ButtonRef = backRef,
				Position = UDim2.new(1, -margin, 0, margin),
				SizePx = target,
				OnActivated = props.OnClose,
				ZIndex = 112,
			}),
			Code = c(Surface, {
				Color = Palette.Claimed,
				Radius = 8,
				Shadow = false,
				StrokeTransparency = 0.6,
				Native = {
					Position = UDim2.fromOffset(margin, codeTop),
					Size = UDim2.new(1, -margin * 2, 0, codeHeight),
				},
			}, {
				Label = c(PageTitle, {
					Text = props.CodeText,
					TextSize = 22,
					Alignment = Enum.TextXAlignment.Left,
					Native = {
						Position = UDim2.fromOffset(12, gap),
						Size = UDim2.new(1, -layout.ActionWidthPx - 32, 0, target),
						ZIndex = 113,
					},
				}),
				ToggleCode = c(PriceButton, {
					Text = if props.CodeVisible then "HIDE CODE" else "SHOW CODE",
					TextSize = 18,
					Compact = true,
					Color = Palette.Yellow,
					TextColor = Palette.Ink,
					TextStroke = 0,
					Enabled = props.CodeAvailable,
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -gap, 0, gap),
					Size = UDim2.fromOffset(layout.ActionWidthPx, target),
					OnActivated = props.OnToggleCode,
				}),
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
				Position = UDim2.fromOffset(margin - 2, listTop),
				Size = UDim2.new(1, -margin * 2 + 4, 0, math.max(height - listTop - margin, 1)),
			}, rows),
		}),
	})
end
