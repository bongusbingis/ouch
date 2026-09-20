-- Compact party management derives membership and actions from the lobby's existing adapter.
--!strict

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local Spring = require(Packages:WaitForChild("react-spring"))
local UI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI")
local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local DeviceClass = require(UI.Parent:WaitForChild("Game"):WaitForChild("Input"):WaitForChild("DeviceClass"))
local T = require(UI:WaitForChild("Tokens"))
local Motion = require(UI:WaitForChild("Motion"))
local Components = UI:WaitForChild("Components")
local CandyPanel = require(Components:WaitForChild("CandyPanel"))
local CandySurface = require(Components:WaitForChild("CandySurface"))
local CandyTitle = require(Components:WaitForChild("CandyTitle"))
local ModalClose = require(Components:WaitForChild("ModalClose"))
local PuffyButton = require(Components:WaitForChild("PuffyButton"))
local ResponsiveText = require(Components:WaitForChild("ResponsiveText"))
local ScrollFrame = require(Components:WaitForChild("ScrollFrame"))
local SectionHeader = require(Components:WaitForChild("SectionHeader"))
local Well = require(Components:WaitForChild("Well"))
local modalSurface = require(Components:WaitForChild("ModalSurface"))
local Selection = require(UI:WaitForChild("Services"):WaitForChild("Selection"))
local useReducedMotion = require(UI:WaitForChild("Hooks"):WaitForChild("useReducedMotion"))
local useSafeArea = require(UI:WaitForChild("Hooks"):WaitForChild("useSafeArea"))

local c = React.createElement
local C = T.Colors
local S = T.PartyModal

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
	CanLeave: boolean,
	OnToggleCode: () -> (),
	OnRemove: (number, string) -> (),
	OnLeave: () -> (),
	OnClose: () -> (),
}

local function label(text: string, position: UDim2, size: UDim2, maximum: number, muted: boolean, zIndex: number)
	local font = if muted then Enum.Font.BuilderSansBold else T.Type.Label
	return c(ResponsiveText, {
		MeasurementFont = font,
		MinTextSize = if muted then 12 else 14,
		MaxTextSize = maximum,
		Wrapped = true,
		Native = {
			BackgroundTransparency = 1,
			Position = position,
			Size = size,
			Font = font,
			Text = text,
			TextColor3 = if muted then C.InkSoft else C.Ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			ZIndex = zIndex,
		},
	})
end

return function(props: Props)
	local safeArea = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local legacyLayout = Config.Layout.PartyCode.Members
	local short = safeArea.size.Y <= Config.Layout.ShortLandscapeMaxHeightPx
	local edge = if short then S.CompactEdge else S.Edge
	local inset = if short then S.CompactInset else S.Inset
	local contentInset = if short then S.CompactContentInset else S.ContentInset
	local gap = if short then S.CompactGap else S.Gap
	local sectionGap = if short then S.CompactSectionGap else S.SectionGap
	local headerHeight = if short then S.CompactHeaderHeight else S.HeaderHeight
	local codeHeight = if short then S.CompactCodeHeight else S.CodeHeight
	local sectionHeight = if short then S.CompactSectionHeight else S.SectionHeight
	local rowHeight = if short then S.CompactRowHeight else S.RowHeight
	local cardInset = if short then S.CompactCardInset else S.CardInset
	local actionWidth = if short then S.CompactActionWidth else S.ActionWidth
	local minimumHeight = if short then S.CompactMinHeight else S.MinHeight
	local memberStrokeInset = S.MemberStrokeInset
	-- Keep each card inside the padded canvas area. The scrolling frame reserves
	-- the scrollbar inset on the right, but a full-width child would still span
	-- the unpadded canvas and be clipped at that edge.
	local rowWidth = UDim2.new(1, -(S.ScrollBar + memberStrokeInset * 2 + 2), 0, rowHeight)
	local width = math.min(legacyLayout.MaxWidthPx, math.max(safeArea.size.X - edge * 2, 1))
	local listTop = contentInset + codeHeight + gap + sectionHeight + sectionGap
	local rowCount = math.max(#props.Members, 1)
	local listContentHeight = memberStrokeInset * 2 + rowCount * rowHeight + math.max(rowCount - 1, 0) * gap
	local desiredHeight = headerHeight + inset + listTop + listContentHeight + contentInset
	local availableHeight = math.max(safeArea.size.Y - edge * 2, 1)
	local height = math.min(legacyLayout.MaxHeightPx, availableHeight, math.max(minimumHeight, desiredHeight))
	local wellHeight = math.max(height - headerHeight - inset, 1)
	local backRef = React.useRef(nil)
	local modalRef = React.useRef(nil)
	local reducedMotion = useReducedMotion()
	local styles = Spring.useSpring({
		Scale = if props.Open then 1 else 0.9,
		config = Motion.Modal,
		immediate = reducedMotion,
	})
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

	local rows: { [string]: any } = {
		Layout = c("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, gap),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, memberStrokeInset),
			PaddingBottom = UDim.new(0, memberStrokeInset),
			PaddingLeft = UDim.new(0, memberStrokeInset),
			PaddingRight = UDim.new(0, S.ScrollBar + memberStrokeInset + 2),
		}),
	}
	for index, member in props.Members do
		local localMember = member.userId == props.LocalUserId
		local leader = member.userId == props.LeaderUserId
		local removable = props.LocalUserId == props.LeaderUserId and not localMember
		local removeEnabled = props.CanRemove and member.username ~= nil
		local leaveEnabled = localMember and props.CanLeave
		local hasAction = removable or leaveEnabled
		local accentColor = if localMember then C.Pink elseif leader then C.Yellow else nil
		local textLeft = cardInset + (if accentColor then 10 else 0)
		local textRight = if hasAction then actionWidth + gap + cardInset else cardInset
		local faceHeight = rowHeight - T.Shape.LipHeight
		local status = if localMember and leader
			then "YOU / PARTY LEADER"
			elseif leader then "PARTY LEADER"
			elseif localMember then "YOU"
			else nil

		rows[tostring(member.userId)] = c("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = rowWidth,
			ZIndex = 5,
		}, {
			Surface = c(CandySurface, {
				Color = C.SurfaceWarm,
				LipColor = C.WellLine,
				Radius = T.Shape.RadiusCard,
				Shadow = false,
				ZIndex = 5,
			}),
			Accent = if accentColor
				then c("Frame", {
					BackgroundColor3 = accentColor,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(cardInset - 2, 10),
					Size = UDim2.fromOffset(5, math.max(faceHeight - 20, 1)),
					ZIndex = 9,
				}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) })
				else nil,
			Name = label(
				member.username or "Loading...",
				UDim2.fromOffset(textLeft, if status then (if short then 3 else 6) else 0),
				UDim2.new(1, -textLeft - textRight, 0, if status then 28 else faceHeight),
				if short then 19 else 22,
				false,
				10
			),
			Status = if status
				then label(
					status,
					UDim2.fromOffset(textLeft, if short then 29 else 34),
					UDim2.new(1, -textLeft - textRight, 0, if short then 18 else 22),
					if short then 13 else 15,
					true,
					10
				)
				else nil,
			Action = if removable
				then c(PuffyButton, {
					Text = "REMOVE",
					TextSize = if short then 16 else 18,
					TextColor = if removeEnabled then C.Surface else C.InkSoft,
					Color = C.Orange,
					LipColor = if removeEnabled then C.OrangeLip else C.WellLine,
					Shadow = false,
					Enabled = removeEnabled,
					Native = {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -cardInset, 0, faceHeight / 2),
						Size = UDim2.fromOffset(actionWidth, T.Layout.MinTarget),
						ZIndex = 10,
					},
					OnActivated = function()
						if member.username then
							props.OnRemove(member.userId, member.username)
						end
					end,
				})
				elseif leaveEnabled then c(PuffyButton, {
					Text = "LEAVE",
					TextSize = if short then 16 else 18,
					TextColor = C.Surface,
					Color = C.Orange,
					LipColor = C.OrangeLip,
					Shadow = false,
					Native = {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -cardInset, 0, faceHeight / 2),
						Size = UDim2.fromOffset(actionWidth, T.Layout.MinTarget),
						ZIndex = 10,
					},
					OnActivated = props.OnLeave,
				})
				else nil,
		})
	end
	if #props.Members == 0 then
		rows.Empty = c("Frame", {
			BackgroundTransparency = 1,
			Size = rowWidth,
		}, {
			Surface = c(CandySurface, {
				Color = C.SurfaceWarm,
				LipColor = C.WellLine,
				Radius = T.Shape.RadiusCard,
				Shadow = false,
				ZIndex = 5,
			}),
			Label = label(
				"Loading party...",
				UDim2.fromOffset(cardInset, 0),
				UDim2.new(1, -cardInset * 2, 1, -T.Shape.LipHeight),
				21,
				true,
				10
			),
		})
	end

	local codeButtonEnabled = props.CodeAvailable and props.FocusEnabled ~= false
	return modalSurface({
		ref = modalRef,
		Active = true,
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Selectable = false,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 110,
	}, {
		Panel = c(CandyPanel, {
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
			Entrance = c("UIScale", { Scale = styles.Scale }),
			Title = c(CandyTitle, {
				Text = "YOUR PARTY",
				TextSize = if short then 26 else 42,
				Native = {
					Position = UDim2.fromOffset(inset + (if short then 8 else 12), if short then 2 else -18),
					Size = UDim2.fromOffset(
						if short then S.CompactTitleWidth else S.TitleWidth,
						if short then 48 else 70
					),
					ZIndex = 120,
				},
			}),
			Close = c(ModalClose, {
				ButtonRef = backRef,
				Position = UDim2.new(1, -inset, 0, if short then 8 else 14),
				SizePx = T.Layout.MinTarget,
				OnActivated = props.OnClose,
				ZIndex = 124,
			}),
			Main = c(Well, {
				Candy = true,
				Native = {
					Position = UDim2.fromOffset(inset, headerHeight),
					Size = UDim2.new(1, -inset * 2, 0, wellHeight),
					ZIndex = 113,
				},
			}, {
				Code = c("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.fromOffset(contentInset, contentInset),
					Size = UDim2.new(1, -contentInset * 2, 0, codeHeight),
					ZIndex = 115,
				}, {
					Surface = c(CandySurface, {
						Color = C.SurfaceWarm,
						LipColor = C.WellLine,
						Radius = T.Shape.RadiusCard,
						Shadow = false,
						ZIndex = 115,
					}),
					Label = label(
						props.CodeText,
						UDim2.fromOffset(cardInset, 0),
						UDim2.new(1, -actionWidth - cardInset * 2 - gap, 1, -T.Shape.LipHeight),
						if short then 18 else 21,
						false,
						120
					),
					ToggleCode = c(PuffyButton, {
						Text = if props.CodeVisible then "HIDE CODE" else "SHOW CODE",
						TextSize = if short then 16 else 18,
						TextColor = if codeButtonEnabled then C.Ink else C.InkSoft,
						Wrapped = true,
						Color = C.Yellow,
						LipColor = if codeButtonEnabled then C.YellowLip else C.WellLine,
						Shadow = false,
						Enabled = codeButtonEnabled,
						Native = {
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, -cardInset, 0, (codeHeight - T.Shape.LipHeight) / 2),
							Size = UDim2.fromOffset(actionWidth, T.Layout.MinTarget),
							ZIndex = 120,
						},
						OnActivated = props.OnToggleCode,
					}),
				}),
				MembersHeader = c(SectionHeader, {
					Text = "MEMBERS",
					Candy = true,
					HeightPx = sectionHeight,
					TextSize = if short then 20 else T.Type.TileLabel,
					Position = UDim2.fromOffset(contentInset, contentInset + codeHeight + gap),
					Size = UDim2.new(1, -contentInset * 2, 0, sectionHeight),
					ZIndex = 116,
				}),
				Members = c(ScrollFrame, {
					Active = true,
					Selectable = not props.CanRemove,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(1, 0, 0, listContentHeight),
					ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
					Position = UDim2.fromOffset(contentInset, listTop),
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ScrollBarImageColor3 = C.Pink,
					ScrollBarThickness = S.ScrollBar,
					Size = UDim2.new(1, -contentInset * 2, 0, math.max(wellHeight - listTop - contentInset, 1)),
					VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
					ZIndex = 115,
				}, rows),
			}),
		}),
	})
end
