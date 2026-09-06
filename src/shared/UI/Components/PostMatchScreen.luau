-- Results prioritize the earned showcase, personal rewards and a stable next action. Gameplay and party choices remain server-owned.
--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage.Packages.react)
local Config = require(ReplicatedStorage.Config.Interface.ArenaPresentation)
local Model = require(script.Parent.Parent.Models.PostMatchViewModel)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local UIFeedback = require(script.Parent.Parent.Services.UIFeedback)
local Selection = require(script.Parent.Parent.Services.Selection)
local Label = require(script.Parent.Arena.Label)
local Surface = require(script.Parent.Arena.Surface)
local ActionButton = require(script.Parent.Arena.ActionButton)
local Podium = require(script.Parent.Arena.ResultsPodium)
local Progress = require(script.Parent.Arena.ResultProgress)
local c = React.createElement
local colors = Config.Colors

local function errorText(code)
	if code == nil then
		return nil
	end
	if code == "not_party_leader" then
		return "Your party leader chooses the next round."
	end
	if code == "results_expired" then
		return "The next round is starting."
	end
	if code == "return_in_progress" then
		return "Your return is already in progress."
	end
	if code == "rewards_pending" then
		return "Finishing your rewards. Try again in a moment."
	end
	if code == "not_enough_players" then
		return "We need more players. Find your next match below."
	end
	if code == "reveal_in_progress" then
		return "Your results are still arriving."
	end
	if code == "request_timed_out" then
		return "No response yet. You can try again."
	end
	return "That didn’t work. Please try again."
end

local function selectable(button)
	return Selection.isSelectable(button)
end

return function(props)
	local result = props.Result
	local visible = props.Visible and result ~= nil
	local safe = useSafeArea(Enum.ScreenInsets.None)
	local rootRef, primaryRef, returnRef = React.useRef(nil), React.useRef(nil), React.useRef(nil)
	local scoresRef = React.useRef(nil)
	local announced = React.useRef("")
	local now, setNow = React.useState(Workspace:GetServerTimeNow())
	local standings, setStandings = React.useState(false)
	local gamepad, setGamepad = React.useState(string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil)
	local interactive = visible and now >= result.interactiveAt
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
		return function()
			connection:Disconnect()
			local selected = GuiService.SelectedObject
			if root and selected and selected:IsDescendantOf(root) then
				GuiService.SelectedObject = if selectable(previous) then previous else nil
			end
		end
	end, { visible, if result then result.resultId else "" })
	React.useEffect(function()
		if not visible or not interactive or not gamepad or props.FocusEnabled == false then
			return
		end
		local active = true
		task.defer(function()
			if not active then
				return
			end
			local selected = GuiService.SelectedObject
			local selectedRoot = if selected then selected:FindFirstAncestorWhichIsA("ScreenGui") else nil
			local ownRoot = if rootRef.current then rootRef.current:FindFirstAncestorWhichIsA("ScreenGui") else nil
			if selectedRoot and ownRoot and selectedRoot.DisplayOrder > ownRoot.DisplayOrder then
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
		end)
		return function()
			active = false
		end
	end, { visible, interactive, gamepad, props.Requesting, props.Status, props.FocusEnabled })
	if not visible then
		return nil
	end

	local party = if props.Status and props.Status.party then props.Status.party else result.party
	local actions =
		Model.actions(Players.LocalPlayer.UserId, party, props.Status, props.Requesting == true, props.PendingAction)
	local short = safe.size.Y < Config.Results.ShortHeightPx
	local width = math.min(safe.size.X - Config.Results.EdgePx * 2, Config.Results.MaxWidthPx)
	local height = math.max(safe.size.Y - Config.Results.EdgePx * 2, 180)
	if safe.size.Y > safe.size.X then
		height = math.min(height, width * 0.75)
	end
	local headerHeight = if short then Config.Results.ShortHeaderPx else Config.Results.HeaderPx
	local footerHeight = if short then 78 else 104
	local bodyTop = headerHeight + 12
	local bodyHeight = math.max(height - bodyTop - footerHeight - 8, 80)
	local detailWidth = if width < 850 then 0.32 else 0.28
	local stageWidth = 1 - detailWidth
	local accent = colors[result.presentation.accent] or colors.Cyan
	local remaining = Model.remainingSeconds(result.endsAt, now)
	local message = errorText(props.Error) or actions.statusText
	local destination = Model.destination(props.Status, actions.partySize)
	local primaryText = if actions.busy
		then "PLEASE WAIT…"
		else if not actions.isLeader
			then "LEADER CHOOSES"
			else if actions.replaySelected or (props.Status and props.Status.canReplay == false)
				then actions.primaryText
				else "PLAY AGAIN"
	local returnText = if actions.returnAction == "LeaveParty" then "LEAVE PARTY" else "LOBBY"
	local returnCallback = if actions.returnAction == "LeaveParty" then props.OnLeaveParty else props.OnReturnToLobby
	local rows = { Layout = c("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for index, score in result.scores do
		rows[score.id] = c(
			Surface,
			{ Shadow = false, Color = colors.Raised, Native = { Size = UDim2.new(1, -8, 0, 44), LayoutOrder = index } },
			{
				Rank = c(Label, {
					Text = if score.placement then tostring(score.placement) else "",
					Title = true,
					Size = 25,
					Native = { Size = UDim2.fromScale(0.14, 1) },
				}),
				Name = c(Label, {
					Text = score.label,
					Size = 22,
					Align = Enum.TextXAlignment.Left,
					Native = { Position = UDim2.fromScale(0.16, 0), Size = UDim2.fromScale(0.6, 1) },
				}),
				Score = c(Label, {
					Text = tostring(score.score),
					Title = true,
					Size = 28,
					Color = colors.Yellow,
					Native = { Position = UDim2.fromScale(0.78, 0), Size = UDim2.fromScale(0.2, 1) },
				}),
			}
		)
	end
	return c("Frame", {
		ref = rootRef,
		BackgroundColor3 = colors.Ink,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Active = true,
		ZIndex = 10,
	}, {
		Gradient = c("UIGradient", { Color = ColorSequence.new(colors.Surface, colors.Ink), Rotation = 75 }),
		Pattern = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "rbxassetid://6794188517",
			ImageTransparency = 0.95,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(180, 180),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 10,
		}),
		Canvas = c("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(safe.position.X + safe.size.X / 2, safe.position.Y + safe.size.Y / 2),
			Size = UDim2.fromOffset(width, height),
			ZIndex = 11,
			SelectionGroup = true,
			SelectionBehaviorDown = Enum.SelectionBehavior.Stop,
			SelectionBehaviorUp = Enum.SelectionBehavior.Stop,
			SelectionBehaviorLeft = Enum.SelectionBehavior.Stop,
			SelectionBehaviorRight = Enum.SelectionBehavior.Stop,
		}, {
			Title = c(Label, {
				Text = result.presentation.title,
				Title = true,
				Size = if short then 34 else 52,
				Color = accent,
				Align = Enum.TextXAlignment.Left,
				Native = { Size = UDim2.new(1, -148, 0, headerHeight * 0.64) },
			}),
			Subtitle = c(Label, {
				Text = result.modeName
					.. (if result.presentation.detail then "  •  " .. result.presentation.detail else ""),
				Size = if short then 15 else 21,
				Align = Enum.TextXAlignment.Left,
				Color = colors.Muted,
				Native = {
					Position = UDim2.fromOffset(0, headerHeight * 0.68),
					Size = UDim2.new(1, -148, 0, headerHeight * 0.3),
				},
			}),
			StandingsButton = c(ActionButton, {
				Text = if standings then "PODIUM" else "SCORES",
				ButtonRef = scoresRef,
				TextSize = 22,
				Color = colors.Raised,
				Native = { Position = UDim2.new(1, -134, 0, 0), Size = UDim2.fromOffset(128, 44) },
				OnActivated = function()
					setStandings(not standings)
				end,
			}),
			Stage = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, bodyTop),
				Size = UDim2.new(stageWidth, -18, 0, bodyHeight),
				ZIndex = 12,
			}, {
				Heading = c(Label, {
					Text = if standings
						then "FINAL STANDINGS"
						else if not result.podium or #result.podium == 0
							then "READY FOR THE NEXT ONE"
							else if result.modeId == "TDM" then "WINNING TEAM STANDOUTS" else "TOP FINISHERS",
					Title = true,
					Color = colors.Muted,
					Size = if short then 15 else 20,
					Native = { Size = UDim2.new(1, 0, 0, 24) },
				}),
				Podium = if not standings
					then c("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(0, 24),
						Size = UDim2.new(1, 0, 1, -24),
					}, { Content = c(Podium, { Entries = result.podium, Compact = short }) })
					else nil,
				Standings = if standings
					then c("ScrollingFrame", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(4, 32),
						Size = UDim2.new(1, -8, 1, -36),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(),
						ScrollBarThickness = 4,
						ScrollBarImageColor3 = colors.Cyan,
					}, rows)
					else nil,
			}),
			Personal = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(stageWidth, 0, 0, bodyTop),
				Size = UDim2.new(detailWidth, -6, 0, bodyHeight),
				ZIndex = 12,
			}, { Content = c(Progress, { Result = result, Compact = short }) }),
			Footer = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 1, -footerHeight),
				Size = UDim2.new(1, 0, 0, footerHeight),
				ZIndex = 15,
			}, {
				Status = c(Label, {
					Text = if props.Error or actions.busy or not destination then message else destination,
					Size = if short then 15 else 19,
					Color = if props.Error then colors.Pink else colors.Muted,
					Align = Enum.TextXAlignment.Left,
					Native = { Size = UDim2.new(1, -72, 0, 26) },
				}),
				Countdown = c(Label, {
					Text = `{remaining}s`,
					Title = true,
					Size = 23,
					Color = colors.Yellow,
					Align = Enum.TextXAlignment.Right,
					Native = { Position = UDim2.new(1, -64, 0, 0), Size = UDim2.fromOffset(58, 26) },
				}),
				PlayAgain = c(ActionButton, {
					ButtonRef = primaryRef,
					Text = primaryText,
					Primary = true,
					TextSize = if short then 22 else 29,
					Enabled = interactive and actions.primaryEnabled,
					Native = {
						Position = UDim2.fromOffset(0, 30),
						Size = UDim2.new(0.65, -10, 0, if short then 44 else 58),
					},
					OnActivated = props.OnPlayAgain,
				}),
				Lobby = c(ActionButton, {
					ButtonRef = returnRef,
					Text = returnText,
					TextSize = if short then 22 else 29,
					Color = colors.Raised,
					Enabled = interactive and not actions.busy,
					Native = {
						Position = UDim2.new(0.65, 4, 0, 30),
						Size = UDim2.new(0.35, -10, 0, if short then 44 else 58),
					},
					OnActivated = returnCallback,
				}),
				Destination = if not short
					then c(Label, {
						Text = if props.Status and props.Status.canReplay == false
							then "Find players keeps your party together"
							else if actions.replaySelected
								then if actions.partySize > 1
									then "Your party is staying together"
									else "You're staying for the next round"
								else if actions.partySize > 1
									then "Choose together • Your party leader controls the group"
									else "Play again or head to the lobby to customize",
						Size = 13,
						Color = colors.Muted,
						Native = { Position = UDim2.fromOffset(0, 91), Size = UDim2.new(1, -6, 0, 13) },
					})
					else nil,
			}),
		}),
	})
end
