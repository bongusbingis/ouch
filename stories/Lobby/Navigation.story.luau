--[[
    The lobby's page navigation in every width it ships at, side by side: the desktop rail
    (LobbyNavigation at its 680 px authored width and 88 px height), the compact phone rail (314 x
    56) and the icon-only rail TopBar falls back to on the narrowest screens. Each rail is live --
    pressing a tab moves the pink selection pillow -- so the selection motion can be checked at
    every size.

    Below them, the two full-width bars that host the rail: LobbyHeader (the shipped lobby header;
    DecorationTarget = false skips its PlayerGui-portalled world decoration, which needs a player)
    and the classic TopBar with its own default tab definitions. Both lay out from the camera
    viewport, so they are Screen frames.

    Migrated from LobbyNavigation.story (Width/Compact/IconOnly attributes -> three states),
    LobbyHeader.story and TopBar.story.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local T = StoryRoot.Tokens
local Components = StoryRoot.Components
local LobbyNavigation = require(Components:WaitForChild("LobbyNavigation"))
local LobbyHeader = require(Components:WaitForChild("LobbyHeader"))
local TopBar = require(Components:WaitForChild("TopBar"))

local c = React.createElement
local N = T.LobbyNavigation

local function tabs(): { any }
	local list = {}
	for _, tab in Fixtures.LobbyTabs do
		table.insert(list, table.clone(tab))
	end
	return list
end

local function Rail(props: { Width: number, Height: number, Compact: boolean?, IconOnly: boolean? })
	local page, setPage = React.useState("SplashScreen")
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(props.Width, props.Height),
	}, {
		Navigation = c(LobbyNavigation, {
			Tabs = tabs(),
			CurrentPage = page,
			OnNavigate = setPage,
			Width = props.Width,
			Compact = props.Compact,
			IconOnly = props.IconOnly,
		}),
	})
end

local function Header()
	local page, setPage = React.useState("SplashScreen")
	return c(LobbyHeader, {
		Tabs = tabs(),
		CurrentPage = page,
		OnNavigate = setPage,
		DecorationTarget = false,
	})
end

local function Bar()
	local page, setPage = React.useState("SplashScreen")
	return c(TopBar, { CurrentPage = page, OnNavigate = setPage })
end

local iconOnlyWidth = #Fixtures.LobbyTabs * T.Layout.MinTarget + (#Fixtures.LobbyTabs - 1) * N.MobileEdge

return StoryRoot.story({
	Title = "Lobby navigation",
	Summary = "LobbyNavigation at desktop, compact and icon-only widths (all interactive), then LobbyHeader and TopBar at the live viewport.",
	States = {
		{
			Name = "Desktop rail",
			Note = "Width 680, height 88 -- the authored landscape rail.",
			Size = Vector2.new(760, 140),
			Element = c(Rail, { Width = 680, Height = N.Height }),
		},
		{
			Name = "Compact rail",
			Note = "Phone: MobileWidth x MobileHeight, Compact labels.",
			Size = Vector2.new(400, 110),
			Element = c(Rail, { Width = N.MobileWidth, Height = N.MobileHeight, Compact = true }),
		},
		{
			Name = "Icon only",
			Note = "Narrowest fallback: 44 px targets, no labels.",
			Size = Vector2.new(280, 110),
			Element = c(Rail, { Width = iconOnlyWidth, Height = N.MobileHeight, Compact = true, IconOnly = true }),
		},
		{
			Name = "Lobby header",
			Note = "Shipped header; world decoration omitted (needs a PlayerGui).",
			Screen = true,
			Element = c(Header),
		},
		{
			Name = "Top bar",
			Note = "Classic band with its default tab definitions.",
			Screen = true,
			Element = c(Bar),
		},
	},
})
