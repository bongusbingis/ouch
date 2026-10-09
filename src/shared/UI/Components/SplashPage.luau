--!strict
-- Progression stays on the lobby; queue artwork lives in the on-demand mode picker.
local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local Spring = require(RS.Packages["react-spring"])
local T = require(script.Parent.Parent.Tokens)
local Motion = require(script.Parent.Parent.Motion)
local Layout = require(script.Parent.Parent.Models.SplashLayout)
local QuestLogic = require(RS.Shared.Game.Quests.QuestLogic)
local useSafeArea = require(script.Parent.Parent.Hooks.useSafeArea)
local useReducedMotion = require(script.Parent.Parent.Hooks.useReducedMotion)
local QueuePicker = require(script.Parent.QueuePicker)
local ProgressHub = require(script.Parent.LobbyProgressHub)
local Panel = require(script.Parent.CandyPanel)
local Button = require(script.Parent.PuffyButton)
local Text = require(script.Parent.LobbyText)
local c, C, S = React.createElement, T.Colors, T.Splash

export type Props = {
	PartyState: string,
	HeaderHeight: number?,
	ShowMatchmakingActivity: boolean,
	PlayText: string,
	PlayEnabled: boolean,
	QueueOptions: { QueuePicker.Option }?,
	SelectedQueueId: string?,
	QueueEnabled: boolean?,
	OnOpenModes: () -> (),
	OnPlay: () -> (),
	OnInvite: () -> (),
	OnJoinCode: () -> (),
	Position: any?,
	PageArrival: any?,
	PlayButtonRef: any?,
	ModeButtonRef: any?,
	WorldWindowRef: any?,
	DailyReward: any?,
	OnViewDailyReward: (() -> ())?,
	SeasonState: any?,
	QuestState: any?,
	OnClaimQuest: ((string) -> ())?,
	OnClaimSeason: (() -> ())?,
	OnViewSeasonRewards: (() -> ())?,
	PendingClaims: { [string]: boolean }?,
}

return function(props: Props)
	local safe = useSafeArea(Enum.ScreenInsets.CoreUISafeInsets)
	local selectedTab, setSelectedTab = React.useState("SEASON")
	local previousQuestCycle = React.useRef(nil :: string?)
	local questCycle = if props.QuestState then props.QuestState.dailyKey :: string? else nil
	React.useEffect(function()
		if QuestLogic.isNewDailyCycle(previousQuestCycle.current, questCycle) then
			setSelectedTab("QUESTS")
		end
		if questCycle ~= nil and questCycle ~= "" then
			previousQuestCycle.current = questCycle
		end
	end, { questCycle or "" })
	local reducedMotion = useReducedMotion()
	local status = if props.QueueEnabled then "" else props.PartyState
	local hasMode = props.SelectedQueueId ~= nil
	local layout = Layout.resolve(safe.size, status ~= "", selectedTab, hasMode, props.HeaderHeight)
	local compact = layout.compact
	local expandedMode = layout.modeExtra > 0
	local styles = Spring.useSpring({
		ProgressHeight = layout.progressHeight,
		ModeExtra = layout.modeExtra,
		ModeExpansion = if expandedMode then 1 else 0,
		config = Motion.Control,
		immediate = reducedMotion or compact,
	})
	local settledArrival = React.useBinding(1)
	local actionY = React.joinBindings({ Height = styles.ProgressHeight, Arrival = props.PageArrival or settledArrival })
		:map(function(value)
			return value.Height + (1 - math.clamp(value.Arrival, 0, 1)) * Motion.LobbyPages.SplashScreen.TrailingOffset
		end)
	local title = "SELECT MODE"
	local description = ""
	local artwork = T.ModePicker.PlaceholderArt
	for _, option in props.QueueOptions or {} do
		if option.id == props.SelectedQueueId then
			title = option.title
			description = option.description or ""
			artwork = option.artwork or artwork
		end
	end
	local playText = if props.PlayText == "PLAY" and hasMode then `PLAY {title}` else props.PlayText
	local function primary(native)
		return c(Button, {
			ButtonRef = props.PlayButtonRef,
			Text = playText,
			TextSize = if compact then T.Type.Body else T.Type.Tab,
			TextColor = if props.PlayEnabled then C.Surface else C.Ink,
			Color = C.Pink,
			LipColor = if props.PlayEnabled then C.PinkLip else C.WellLine,
			StrokeColor = C.Surface,
			Style = "Primary",
			Wrapped = compact,
			Enabled = props.PlayEnabled,
			Native = native,
			OnActivated = props.OnPlay,
		})
	end
	local function party(native, invite)
		return c(Button, {
			Text = if invite then (if compact then "INVITE" else "INVITE FRIENDS") else "JOIN PARTY",
			TextSize = T.Type.Minimum,
			TextColor = C.Ink,
			Color = C.Surface,
			LipColor = C.WellLine,
			Shadow = false,
			Native = native,
			OnActivated = if invite then props.OnInvite else props.OnJoinCode,
		})
	end
	local function mode(native)
		local function geometry(map)
			return styles.ModeExpansion:map(function(value)
				return map(math.clamp(value, 0, 1))
			end)
		end
		return c(
			Button,
			{
				ButtonRef = props.ModeButtonRef,
				Text = if compact then (if hasMode then "MODE" else "SELECT MODE") else nil,
				TextSize = T.Type.Minimum,
				Wrapped = compact,
				TextColor = C.Ink,
				Color = if hasMode then (if expandedMode then C.Surface else C.Well) else C.Pink,
				LipColor = if hasMode then C.WellLine else C.PinkLip,
				Radius = if expandedMode then T.Shape.RadiusCard else nil,
				Style = if expandedMode then "Primary" else "Standard",
				Shadow = false,
				Enabled = props.QueueEnabled == true,
				Native = native,
				OnActivated = props.OnOpenModes,
			},
			if compact
				then nil
				else {
					Thumbnail = if hasMode
						then c("ImageLabel", {
							Image = artwork,
							ScaleType = Enum.ScaleType.Crop,
							BackgroundColor3 = C.WellLine,
							BorderSizePixel = 0,
							Position = geometry(function(a)
								return UDim2.fromOffset(8, 5 + 3 * a)
							end),
							Size = geometry(function(a)
								return UDim2.new(S.ModeArtFraction * a, 36 * (1 - a), 1, -14 - 2 * a)
							end),
							ZIndex = 7,
						}, {
							Corner = c("UICorner", {
								CornerRadius = geometry(function(a)
									return UDim.new(0, 8 + 8 * a)
								end),
							}),
						})
						else nil,
					Name = c(Text, {
						Text = title,
						Font = T.Type.Display,
						TextSize = T.Type.TileLabel,
						Position = geometry(function(a)
							return UDim2.new(S.ModeTextFraction * a, (if hasMode then 54 else 18) * (1 - a), 0, 12 * a)
						end),
						Size = geometry(function(a)
							return UDim2.new(
								1 - S.ModeTextFraction * a,
								(if hasMode then -170 else -60) * (1 - a) - 18 * a,
								1 - a,
								-6 * (1 - a) + 28 * a
							)
						end),
					}),
					Description = c(Text, {
						Text = description,
						Font = Enum.Font.BuilderSans,
						TextColor3 = C.InkSoft,
						TextYAlignment = Enum.TextYAlignment.Top,
						Position = UDim2.new(S.ModeTextFraction, 0, 0, 46),
						Size = styles.ModeExtra:map(function(extra)
							return UDim2.new(1 - S.ModeTextFraction, -18, 0, math.max(0, extra + S.ModeRowHeight - 88))
						end),
						Visible = styles.ModeExtra:map(function(extra)
							return expandedMode and extra + S.ModeRowHeight >= S.ModeDescriptionMinHeight
						end),
						TextTransparency = geometry(function(a)
							return 1 - a
						end),
					}),
					Change = c(Text, {
						Text = if hasMode then "CHANGE  >" else ">",
						TextSize = T.Type.Minimum,
						TextXAlignment = Enum.TextXAlignment.Right,
						Position = geometry(function(a)
							return UDim2.new(1, -112, a, -36 * a)
						end),
						Size = geometry(function(a)
							return UDim2.new(0, 96, 1 - a, -6 * (1 - a) + 22 * a)
						end),
					}),
				}
		)
	end
	local statusHeight = if status ~= "" then S.StatusHeight + 4 else 0
	local progression = c(ProgressHub, {
		Native = { Size = styles.ProgressHeight:map(function(height)
			return UDim2.new(1, 0, 0, height)
		end) },
		SelectedTab = selectedTab,
		OnSelectTab = setSelectedTab,
		Compact = compact and not layout.portrait,
		Landscape = layout.landscape,
		QuestState = props.QuestState,
		SeasonState = props.SeasonState,
		DailyReward = props.DailyReward,
		PendingClaims = props.PendingClaims,
		OnClaimQuest = props.OnClaimQuest,
		OnClaimSeason = props.OnClaimSeason,
		OnViewSeasonRewards = props.OnViewSeasonRewards,
		OnViewDailyReward = props.OnViewDailyReward,
	})
	return c(
		"Frame",
		{ BackgroundTransparency = 1, Position = props.Position or UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 1) },
		{
			WorldWindow = c("Frame", {
				ref = props.WorldWindowRef,
				BackgroundTransparency = 1,
				Active = false,
				Position = UDim2.fromOffset(
					safe.position.X + layout.world.position.X,
					safe.position.Y + layout.world.position.Y
				),
				Size = UDim2.fromOffset(layout.world.size.X, layout.world.size.Y),
			}),
			Main = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(
					safe.position.X + layout.body.position.X,
					safe.position.Y + layout.body.position.Y
				),
				Size = UDim2.fromOffset(layout.body.size.X, layout.body.size.Y),
			}, {
				Progress = progression,
				Actions = if not compact
					then c(Panel, {
						Tilt = 0,
						Native = {
							Position = actionY:map(function(height)
								return UDim2.fromOffset(0, height + S.Gap)
							end),
							Size = styles.ModeExtra:map(function(extra)
								return UDim2.new(1, 0, 0, S.ActionPanelHeight + statusHeight + extra)
							end),
						},
					}, {
						Status = if status ~= ""
							then c(Text, {
								Text = status,
								TextColor3 = C.InkSoft,
								Position = UDim2.fromOffset(16, 10),
								Size = UDim2.new(1, -32, 0, S.StatusHeight),
								TextXAlignment = Enum.TextXAlignment.Center,
							})
							else nil,
						Mode = mode({
							Position = UDim2.fromOffset(16, 12 + statusHeight),
							Size = styles.ModeExtra:map(function(extra)
								return UDim2.new(1, -32, 0, S.ModeRowHeight + extra)
							end),
						}),
						PlayButton = primary({
							Position = styles.ModeExtra:map(function(extra)
								return UDim2.fromOffset(16, 64 + statusHeight + extra)
							end),
							Size = UDim2.new(1, -32, 0, 56),
						}),
						JoinWithCode = party({
							Position = styles.ModeExtra:map(function(extra)
								return UDim2.fromOffset(16, 132 + statusHeight + extra)
							end),
							Size = UDim2.new(0.5, -22, 0, 44),
						}, false),
						InviteFriends = party({
							Position = styles.ModeExtra:map(function(extra)
								return UDim2.new(0.5, 6, 0, 132 + statusHeight + extra)
							end),
							Size = UDim2.new(0.5, -22, 0, 44),
						}, true),
					})
					else nil,
			}),
			Footer = if compact
				then c("Frame", {
					BackgroundTransparency = 1,
					Position = actionY:map(function(height)
						return UDim2.fromOffset(
							safe.position.X + layout.footer.position.X,
							safe.position.Y
								+ (
									if layout.landscape
										then layout.footer.position.Y
										else layout.body.position.Y + height + S.CompactGap
								)
						)
					end),
					Size = UDim2.fromOffset(layout.footer.size.X, layout.footer.size.Y),
				}, {
					Status = if layout.landscape and status ~= ""
						then c(Text, {
							Text = status,
							TextSize = T.Type.Minimum,
							TextXAlignment = Enum.TextXAlignment.Right,
							Position = UDim2.fromOffset(0, -T.LobbyLandscape.StatusHeight - 4),
							Size = UDim2.new(1, 0, 0, T.LobbyLandscape.StatusHeight),
						})
						else nil,
					PlayButton = primary({
						Size = if layout.portrait then UDim2.new(1, 0, 0, 48) else UDim2.new(0.4, -8, 0, 48),
					}),
					Mode = mode({
						Position = if layout.portrait then UDim2.fromOffset(0, 56) else UDim2.new(0.4, 4, 0, 0),
						Size = if layout.portrait then UDim2.new(1 / 3, -8, 0, 48) else UDim2.new(0.2, -8, 0, 48),
					}),
					JoinWithCode = party({
						Position = if layout.portrait then UDim2.new(1 / 3, 4, 0, 56) else UDim2.new(0.6, 4, 0, 0),
						Size = if layout.portrait then UDim2.new(1 / 3, -8, 0, 48) else UDim2.new(0.2, -8, 0, 48),
					}, false),
					InviteFriends = party({
						Position = if layout.portrait then UDim2.new(2 / 3, 4, 0, 56) else UDim2.new(0.8, 4, 0, 0),
						Size = if layout.portrait then UDim2.new(1 / 3, -4, 0, 48) else UDim2.new(0.2, -4, 0, 48),
					}, true),
				})
				else nil,
		}
	)
end
