-- Results prioritize the earned showcase, personal rewards and a stable next action. Gameplay and party choices remain server-owned.
--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Config =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("ArenaPresentation"))
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local Model = require(script.Parent.Parent.Models.PostMatchViewModel)
local Layout = require(script.Parent.Parent.Models.PostMatchLayout)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local useReveal = require(script.Parent.Parent.Hooks.useReveal)
local UIFeedback = require(script.Parent.Parent.Services.UIFeedback)
local Selection = require(script.Parent.Parent.Services.Selection)
local CandyPanel = require(script.Parent.CandyPanel)
local CandySurface = require(script.Parent.CandySurface)
local CandyTitle = require(script.Parent.CandyTitle)
local PuffyButton = require(script.Parent.PuffyButton)
local Podium = require(script.Parent.Arena.ResultsPodium)
local Rewards = require(script.Parent.Arena.ResultProgress)
local c, C, R = React.createElement, T.Colors, T.Results

local PILL_PAD = 14

local function errorText(code)
	if code == nil then
		return nil
	end
	if code == "not_party_leader" then
		return "YOUR PARTY LEADER CHOOSES THE NEXT ROUND"
	end
	if code == "results_expired" then
		return "THE NEXT ROUND IS STARTING"
	end
	if code == "return_in_progress" then
		return "YOUR RETURN IS ALREADY IN PROGRESS"
	end
	if code == "rewards_pending" then
		return "FINISHING YOUR REWARDS · TRY AGAIN IN A MOMENT"
	end
	if code == "not_enough_players" then
		return "NOT ENOUGH PLAYERS · FIND SOME IN THE LOBBY"
	end
	if code == "reveal_in_progress" then
		return "YOUR RESULTS ARE STILL ARRIVING"
	end
	if code == "request_timed_out" then
		return "NO RESPONSE YET · YOU CAN TRY AGAIN"
	end
	return "THAT DIDN'T WORK · PLEASE TRY AGAIN"
end

local function selectable(button)
	return Selection.isSelectable(button)
end

-- One staged block: hidden until its turn, then popped in with the shared candy motion.
local function Reveal(props)
	local reduced = useReducedMotion()
	local ref = React.useRef(nil)
	React.useEffect(function()
		if props.Shown and ref.current and not reduced then
			return Motion.popIn(ref.current)
		end
		return nil
	end, { props.Shown, props.Key })
	local native = table.clone(props.Native)
	native.ref = ref
	native.BackgroundTransparency = 1
	native.Visible = props.Shown
	return c("Frame", native, props.children)
end

local function pill(props)
	local z = props.ZIndex or 12
	local native = table.clone(props.Native)
	native.BackgroundTransparency = 1
	native.ZIndex = z
	return c("Frame", native, {
		Surface = c(CandySurface, { Color = props.Color, LipColor = props.LipColor, Shadow = false, ZIndex = z }),
		Text = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = props.Font,
			Text = props.Text,
			TextColor3 = props.TextColor or C.Ink,
			TextSize = props.TextSize,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(PILL_PAD, 0),
			Size = UDim2.new(1, -PILL_PAD * 2, 1, -T.Shape.LipHeight),
			ZIndex = z + 6,
		}),
	})
end

local function pillWidth(text: string, size: number, font: Enum.Font, maximum: number): number
	local wanted = TextService:GetTextSize(text, size, font, Vector2.new(100000, 1000)).X + PILL_PAD * 2 + 4
	return math.floor(math.max(math.min(wanted, maximum), 0))
end

local function standingsRows(result, rowHeight: number)
	local appearance = result.personalAppearance
	local localId = if appearance then appearance.playerId else nil
	local localTeam = if appearance then appearance.teamId else nil
	local teamMode = result.placement == nil
	local rows = {
		Layout = c("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	local circle = rowHeight - 12
	local textSize = if rowHeight < 40 then 15 else 18
	local nameLeft = if teamMode then 14 else circle + 16
	for index, score in result.scores do
		local isLocal = if teamMode then score.id == localTeam else score.id == localId
		local rank = score.placement or index
		rows[score.id] = c("Frame", {
			BackgroundColor3 = if isLocal then C.Pink else C.SurfaceWarm,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, rowHeight),
			ZIndex = 17,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Outline = c("UIStroke", { Color = if isLocal then C.PinkLip else C.WellLine, Thickness = 2 }),
			Rank = if not teamMode
				then c("Frame", {
					BackgroundColor3 = R.PlacementColors[rank] or C.Well,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(6, 6),
					Size = UDim2.fromOffset(circle, circle),
					ZIndex = 18,
				}, {
					Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
					Outline = c("UIStroke", { Color = C.Ink, Thickness = 2 }),
					Text = c("TextLabel", {
						BackgroundTransparency = 1,
						Font = T.Type.Display,
						Text = tostring(rank),
						TextColor3 = C.Ink,
						TextSize = textSize,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 19,
					}),
				})
				else nil,
			Name = c("TextLabel", {
				BackgroundTransparency = 1,
				Font = T.Type.Label,
				Text = score.label .. (if isLocal and not teamMode then " (YOU)" else ""),
				TextColor3 = C.Ink,
				TextSize = textSize,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				Position = UDim2.fromOffset(nameLeft, 0),
				Size = UDim2.new(1, -nameLeft - 130, 1, 0),
				ZIndex = 18,
			}),
			Score = c("TextLabel", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Font = T.Type.Display,
				Text = `{score.score} {result.scoreLabel}`,
				TextColor3 = C.Ink,
				TextSize = textSize,
				TextXAlignment = Enum.TextXAlignment.Right,
				Position = UDim2.new(1, -12, 0, 0),
				Size = UDim2.fromOffset(120, rowHeight),
				ZIndex = 18,
			}),
		})
	end
	return rows
end

local function countdownChip(countdown, drain: number, rectPosition: Vector2, rectSize: Vector2)
	return c("Frame", {
		BackgroundColor3 = C.Well,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(rectPosition.X, rectPosition.Y),
		Size = UDim2.fromOffset(rectSize.X, rectSize.Y),
		ZIndex = 15,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 16) }),
		Outline = c("UIStroke", { Color = C.WellLine, Thickness = T.Shape.StrokeInner }),
		Caption = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = T.Type.CompactLabel,
			Text = countdown.caption,
			TextColor3 = C.InkSoft,
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(6, 5),
			Size = UDim2.new(1, -12, 0, 14),
			ZIndex = 16,
		}),
		Value = c("TextLabel", {
			BackgroundTransparency = 1,
			Font = T.Type.Display,
			Text = countdown.value,
			TextColor3 = C.Ink,
			TextSize = 24,
			Position = UDim2.fromOffset(0, 17),
			Size = UDim2.new(1, 0, 0, 24),
			ZIndex = 16,
		}),
		Track = c("Frame", {
			BackgroundColor3 = C.WellLine,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 10, 1, -R.CountdownBarHeight - 5),
			Size = UDim2.new(1, -20, 0, R.CountdownBarHeight),
			ZIndex = 16,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = c("Frame", {
				BackgroundColor3 = C.Pink,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(math.clamp(drain, 0, 1), 1),
				Visible = drain > 0,
				ZIndex = 17,
			}, { Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }) }),
		}),
	})
end

local function place(rect)
	return UDim2.fromOffset(rect.position.X, rect.position.Y), UDim2.fromOffset(rect.size.X, rect.size.Y)
end

return function(props)
	local result = props.Result
	local visible = props.Visible and result ~= nil
	local departing = props.Departing == true
	local safe = useSafeArea(Enum.ScreenInsets.None, Enum.ScreenInsets.CoreUISafeInsets)
	local reduced = useReducedMotion()
	local rootRef, primaryRef, returnRef = React.useRef(nil), React.useRef(nil), React.useRef(nil)
	local scoresRef = React.useRef(nil)
	local clearedOutsideSelection = React.useRef(false)
	local announced = React.useRef("")
	local now, setNow = React.useState(Workspace:GetServerTimeNow())
	local standings, setStandings = React.useState(false)
	local gamepad, setGamepad = React.useState(string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil)
	local key = if result then result.resultId else ""
	local interactive = visible and not departing and now >= result.interactiveAt
	local personalShown = useReveal(key, R.PersonalDelay, reduced or not visible)
	local footerShown = useReveal(key, R.FooterDelay, reduced or not visible)
	local headingShown = useReveal(key, R.RevealDelay, reduced or not visible)
	React.useEffect(function()
		local connection = UserInputService.LastInputTypeChanged:Connect(function(input)
			setGamepad(string.find(input.Name, "Gamepad") ~= nil)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})
	React.useEffect(function()
		setStandings(false)
		if not visible then
			return
		end
		if announced.current ~= result.resultId then
			announced.current = result.resultId
			UIFeedback.notification()
		end
		local accumulator = 0
		setNow(Workspace:GetServerTimeNow())
		local connection = RunService.Heartbeat:Connect(function(dt)
			accumulator += dt
			if accumulator >= Config.HUD.UpdateSeconds then
				accumulator = 0
				setNow(Workspace:GetServerTimeNow())
			end
		end)
		local previous = GuiService.SelectedObject
		local root = rootRef.current
		clearedOutsideSelection.current = false
		return function()
			connection:Disconnect()
			local selected = GuiService.SelectedObject
			if
				(root and selected and selected:IsDescendantOf(root))
				or (selected == nil and clearedOutsideSelection.current)
			then
				GuiService.SelectedObject = if string.find(UserInputService:GetLastInputType().Name, "Gamepad")
						and selectable(previous)
					then previous
					else nil
			end
		end
	end, { visible, key })
	React.useEffect(function()
		if not visible or props.FocusEnabled == false then
			return
		end
		local active = true
		local function updateSelection()
			if not active then
				return
			end
			local selected = GuiService.SelectedObject
			if selected and not selected:IsDescendantOf(Players.LocalPlayer.PlayerGui) then
				return
			end
			local selectedRoot = if selected then selected:FindFirstAncestorWhichIsA("ScreenGui") else nil
			local ownRoot = if rootRef.current then rootRef.current:FindFirstAncestorWhichIsA("ScreenGui") else nil
			if selectedRoot and ownRoot and selectedRoot.DisplayOrder > ownRoot.DisplayOrder then
				return
			end
			if not gamepad then
				if selected and rootRef.current and not selected:IsDescendantOf(rootRef.current) then
					clearedOutsideSelection.current = true
					GuiService.SelectedObject = nil
				end
				return
			end
			if not interactive then
				return
			end
			if selected and rootRef.current and selected:IsDescendantOf(rootRef.current) and selectable(selected) then
				return
			end
			for _, ref in { primaryRef, scoresRef, returnRef } do
				if selectable(ref.current) then
					GuiService.SelectedObject = ref.current
					break
				end
			end
		end
		task.defer(updateSelection)
		local connection = if not gamepad
			then GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(updateSelection)
			else nil
		return function()
			active = false
			if connection then
				connection:Disconnect()
			end
		end
	end, { visible, interactive, gamepad, props.Requesting, props.Status, props.FocusEnabled, footerShown })
	if not visible then
		return nil
	end

	local layout = Layout.resolve(safe.size, props.OnOpenShop ~= nil, result)
	local party = if props.Status and props.Status.party then props.Status.party else result.party
	local actions = Model.actions(
		Players.LocalPlayer.UserId,
		party,
		props.Status,
		props.Requesting == true,
		props.PendingAction,
		departing
	)
	local remaining = Model.remainingSeconds(result.endsAt, now)
	local countdown = Model.countdown(props.Status, actions.partySize, remaining, departing)
	local span = math.max(result.endsAt - result.interactiveAt, 1)
	local drain = if departing then 1 else math.clamp((result.endsAt - now) / span, 0, 1)
	local message = if departing then actions.statusText else errorText(props.Error) or actions.statusText
	local accent = R.Accents[result.presentation.accent] or C.Cyan
	local teamMode = result.placement == nil
	local tied = #result.scores >= 2 and result.scores[1].score == result.scores[2].score
	local podium = result.podium or {}
	local heading = Model.stageHeading(teamMode, #podium, tied, standings)
	local kicker = Model.kicker(result.modeName, result.presentation.eyebrow)
	local kickerWidth = pillWidth(kicker, T.Type.Minimum, T.Type.CompactLabel, layout.kicker.size.X)
	local detail = result.presentation.detail
	local detailWidth = if detail then pillWidth(detail, layout.detailSize, T.Type.Label, layout.detail.size.X) else 0
	local headingWidth = pillWidth(heading, T.Type.Minimum, T.Type.CompactLabel, layout.stage.size.X - 16)
	local stageTop = R.StageHeadingHeight + 8
	local done = actions.primaryStyle == "Done"
	local primaryEnabled = interactive and actions.primaryEnabled
	local secondaryEnabled = interactive and not actions.busy
	local returnCallback = if actions.returnAction == "LeaveParty" then props.OnLeaveParty else props.OnReturnToLobby
	local canvasPosition, canvasSize = place(layout.canvas)
	local kickerPosition = place(layout.kicker)
	local titlePosition, titleSize = place(layout.title)
	local detailPosition = place(layout.detail)
	local scoresPosition, scoresSize = place(layout.scores)
	local stagePosition, stageSize = place(layout.stage)
	local personalPosition, personalSize = place(layout.personal)
	local footerPosition, footerSize = place(layout.footer)
	local statusPosition, statusSize = place(layout.status)
	local secondaryPosition, secondarySize = place(layout.secondary)
	local primaryPosition, primarySize = place(layout.primary)
	if departing then
		statusSize = UDim2.fromOffset(
			layout.footer.size.X
				- layout.status.position.X
				- (if layout.compact then R.CompactFooterInset else R.FooterInset),
			layout.status.size.Y
		)
	end

	return c("Frame", {
		ref = rootRef,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = true,
		ZIndex = 10,
	}, {
		Canvas = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(
				safe.position.X + layout.canvas.position.X,
				safe.position.Y + layout.canvas.position.Y
			),
			Size = canvasSize,
			ZIndex = 11,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		}, {
			Header = c(Reveal, {
				Shown = true,
				Key = key,
				Native = { Size = UDim2.new(1, 0, 0, layout.headerHeight), ZIndex = 12 },
			}, {
				Kicker = pill({
					Text = kicker,
					Color = C.Yellow,
					LipColor = C.YellowLip,
					Font = T.Type.CompactLabel,
					TextSize = T.Type.Minimum,
					Native = {
						Position = kickerPosition,
						Size = UDim2.fromOffset(kickerWidth, layout.kicker.size.Y),
					},
				}),
				Title = c(CandyTitle, {
					Text = result.presentation.title,
					Color = accent,
					TextSize = layout.titleSize,
					Native = { Position = titlePosition, Size = titleSize, ZIndex = 14 },
				}),
				Detail = if detail
					then pill({
						Text = detail,
						Color = C.SurfaceWarm,
						LipColor = C.WellLine,
						Font = T.Type.Label,
						TextSize = layout.detailSize,
						ZIndex = 15,
						Native = {
							Position = detailPosition,
							Size = UDim2.fromOffset(detailWidth, layout.detail.size.Y),
						},
					})
					else nil,
				Scores = if layout.showStage
					then c(PuffyButton, {
						ButtonRef = scoresRef,
						Text = if standings then "PODIUM" else "SCORES",
						TextSize = 20,
						TextColor = C.Ink,
						Color = C.SurfaceWarm,
						LipColor = C.WellLine,
						Shadow = false,
						Native = { Position = scoresPosition, Size = scoresSize, ZIndex = 14 },
						OnActivated = function()
							setStandings(not standings)
						end,
					})
					else nil,
				Shop = if layout.shop and props.OnOpenShop
					then c(PuffyButton, {
						Text = "SHOP",
						TextSize = 20,
						TextColor = C.Ink,
						Color = C.Yellow,
						LipColor = C.YellowLip,
						Shadow = false,
						Enabled = interactive,
						Native = {
							Position = UDim2.fromOffset(layout.shop.position.X, layout.shop.position.Y),
							Size = UDim2.fromOffset(layout.shop.size.X, layout.shop.size.Y),
							ZIndex = 14,
						},
						OnActivated = props.OnOpenShop,
					})
					else nil,
			}),
			Stage = if layout.showStage
				then c("Frame", {
					BackgroundTransparency = 1,
					Position = stagePosition,
					Size = stageSize,
					ZIndex = 12,
				}, {
					Heading = c(Reveal, {
						Shown = headingShown,
						Key = key,
						Native = {
							Size = UDim2.fromOffset(headingWidth, R.StageHeadingHeight),
							ZIndex = 13,
						},
					}, {
						Pill = pill({
							Text = heading,
							Color = C.SurfaceWarm,
							LipColor = C.WellLine,
							Font = T.Type.CompactLabel,
							TextSize = T.Type.Minimum,
							Native = { Size = UDim2.fromScale(1, 1) },
						}),
					}),
					Podium = c(Podium, {
						Entries = podium,
						ResultId = key,
						ShowLabels = not standings,
						ScoreLabel = result.scoreLabel,
						PlateWidth = layout.nameplateWidth,
						PlateHeight = layout.nameplateHeight,
						BadgeSize = layout.nameplateBadge,
						TopInset = stageTop,
					}),
					Standings = if standings
						then c("Frame", {
							BackgroundColor3 = C.Well,
							BorderSizePixel = 0,
							Position = UDim2.fromOffset(0, stageTop),
							Size = UDim2.new(1, 0, 1, -stageTop),
							ZIndex = 16,
						}, {
							Corner = c("UICorner", { CornerRadius = UDim.new(0, T.Shape.RadiusCard) }),
							Outline = c("UIStroke", { Color = C.WellLine, Thickness = T.Shape.StrokeInner }),
							Scroll = c("ScrollingFrame", {
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								BackgroundTransparency = 1,
								BorderSizePixel = 0,
								CanvasSize = UDim2.new(),
								Position = UDim2.fromOffset(8, 8),
								ScrollBarImageColor3 = C.Pink,
								ScrollBarThickness = 4,
								ScrollingDirection = Enum.ScrollingDirection.Y,
								Selectable = false,
								Size = UDim2.new(1, -16, 1, -16),
								ZIndex = 17,
							}, standingsRows(result, layout.standingsRowHeight)),
						})
						else nil,
				})
				else nil,
			Personal = c(Reveal, {
				Shown = personalShown,
				Key = key,
				Native = { Position = personalPosition, Size = personalSize, ZIndex = 12 },
			}, {
				Panel = c(Rewards, {
					Result = result,
					Inset = layout.inset,
					ChipHeight = layout.rewardChipHeight,
					RowHeight = layout.statRowHeight,
					Shown = personalShown,
				}),
			}),
			Footer = c(Reveal, {
				Shown = footerShown,
				Key = key,
				Native = { Position = footerPosition, Size = footerSize, ZIndex = 13 },
			}, {
				Panel = c(CandyPanel, {
					Tilt = R.FooterTilt,
					Native = { Size = UDim2.fromScale(1, 1), ZIndex = 13 },
				}, {
					Countdown = countdownChip(countdown, drain, layout.countdown.position, layout.countdown.size),
					Status = if layout.showStatus or departing
						then c("TextLabel", {
							BackgroundTransparency = 1,
							Font = T.Type.Label,
							Text = message,
							TextColor3 = if props.Error and not departing then C.PinkLip else C.InkSoft,
							TextSize = if layout.compact then 15 else 18,
							TextWrapped = true,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextYAlignment = Enum.TextYAlignment.Center,
							Position = statusPosition,
							Size = statusSize,
							ZIndex = 15,
						})
						else nil,
					Secondary = if not departing
						then c(PuffyButton, {
							ButtonRef = returnRef,
							Text = actions.returnText,
							TextSize = if layout.compact then 20 else T.Type.Tab,
							TextColor = C.Ink,
							Color = C.Well,
							LipColor = if secondaryEnabled then C.WellLine else nil,
							Enabled = secondaryEnabled,
							Native = { Position = secondaryPosition, Size = secondarySize, ZIndex = 15 },
							OnActivated = returnCallback,
						})
						else nil,
					Primary = if departing
						then nil
						elseif done then pill({
							Text = actions.primaryText,
							Color = C.Lime,
							LipColor = C.LimeLip,
							Font = T.Type.Display,
							TextSize = if layout.compact then 20 else T.Type.Tab,
							ZIndex = 15,
							Native = { Position = primaryPosition, Size = primarySize },
						})
						else c(PuffyButton, {
							ButtonRef = primaryRef,
							Text = actions.primaryText,
							TextSize = if layout.compact then 20 else T.Type.Tab,
							TextColor = C.Surface,
							Color = C.Pink,
							LipColor = if primaryEnabled then C.PinkLip else nil,
							Style = "Primary",
							Enabled = primaryEnabled,
							Native = { Position = primaryPosition, Size = primarySize, ZIndex = 15 },
							OnActivated = props.OnPlayAgain,
						}),
				}),
			}),
		}),
	})
end
