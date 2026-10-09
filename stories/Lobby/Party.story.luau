--[[
    Party surfaces. PartyCode is the lobby's code card: in landscape the code panel + SHOW/HIDE
    CODE button (code hidden as •••-••• and revealed as 123-456, toggle is live), and the compact
    yellow pill used on short phones (Compact, and the OnOpen variant that opens the members
    modal). It positions itself on the viewport, so the landscape states are Screen frames.

    PartyStatus is the small activity pill (active dots vs idle). JoinCodeModal is the six-digit
    join-code entry (submitting always fails with PARTY CODE NOT FOUND so the error state shows).
    PartyMembersModal is lobby-only (StarterPlayerScripts.Client.UI); it shows a 4-member party
    led by the local player, and a notice in the arena place.

    Data: Fixtures.partySnapshot / Fixtures.Players. Migrated from PartyCode.story and
    JoinCodeModal.story.
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local React = StoryRoot.React
local Components = StoryRoot.Components
local PartyCode = require(Components:WaitForChild("PartyCode"))
local PartyStatus = require(Components:WaitForChild("PartyStatus"))
local JoinCodeModal = require(Components:WaitForChild("JoinCodeModal"))

local c = React.createElement
local log = Fixtures.log

local function Code(props: { Compact: boolean?, Open: boolean?, Visible: boolean? })
	local visible, setVisible = React.useState(props.Visible == true)
	return c(PartyCode, {
		CodeText = if visible then "123-456" else "•••-•••",
		CodeVisible = visible,
		Compact = props.Compact,
		Position = if props.Compact then UDim2.fromScale(0.5, 0.5) else nil,
		OnOpen = if props.Open then log("Party", "PartyCode.OnOpen") else nil,
		OnToggle = function()
			setVisible(not visible)
		end,
	})
end

local function Members()
	local visible, setVisible = React.useState(true)
	local module = StoryRoot.placeModule({ "UI", "PartyMembersModal" })
	if module == nil then
		return StoryRoot.Notice("PartyMembersModal is lobby-only. Open this story in the lobby place.")
	end
	local PartyMembersModal = (require :: any)(module)
	local snapshot = Fixtures.partySnapshot(4)
	local members = {}
	for _, member in snapshot.members do
		table.insert(members, { userId = member.userId, username = member.name })
	end
	return c(PartyMembersModal, {
		Open = true,
		FocusEnabled = false,
		Members = members,
		LocalUserId = Fixtures.LocalUserId,
		LeaderUserId = snapshot.leaderUserId,
		CodeText = if visible then "123-456" else "•••-•••",
		CodeVisible = visible,
		CodeAvailable = true,
		CanRemove = true,
		CanLeave = true,
		OnToggleCode = function()
			setVisible(not visible)
		end,
		OnRemove = log("Party", "OnRemove"),
		OnLeave = log("Party", "OnLeave"),
		OnClose = log("Party", "OnClose"),
	})
end

local function status(active: boolean, text: string): any
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 0, 44),
	}, { Status = c(PartyStatus, { Active = active, Text = text }) })
end

return StoryRoot.story({
	Title = "Party",
	Summary = "PartyCode (hidden / shown / compact pill), PartyStatus, JoinCodeModal and the lobby's PartyMembersModal.",
	States = {
		{ Name = "Code hidden", Note = "Landscape card.", Screen = true, Fit = 0.5, Element = c(Code, {}) },
		{ Name = "Code shown", Screen = true, Fit = 0.5, Element = c(Code, { Visible = true }) },
		{
			Name = "Compact pill",
			Note = "Short phone: tap toggles.",
			Size = Vector2.new(320, 100),
			Element = c(Code, { Compact = true }),
		},
		{
			Name = "Compact pill → members",
			Note = "With OnOpen: opens the members modal.",
			Size = Vector2.new(320, 100),
			Element = c(Code, { Compact = true, Open = true }),
		},
		{
			Name = "Status searching",
			Size = Vector2.new(520, 90),
			Element = status(true, "MATCHMAKING IN PROGRESS — SEARCHING FOR PLAYERS"),
		},
		{ Name = "Status idle", Size = Vector2.new(520, 90), Element = status(false, "WAITING FOR PARTY LEADER") },
		{
			Name = "Join code",
			Note = "Submit always fails: PARTY CODE NOT FOUND.",
			Screen = true,
			Fit = 0.5,
			Element = c(JoinCodeModal, {
				Open = true,
				FocusEnabled = false,
				OnClose = log("Party", "JoinCode.OnClose"),
				OnSubmit = function()
					return false, "PARTY CODE NOT FOUND"
				end,
			}),
		},
		{ Name = "Members", Note = "Lobby place only.", Screen = true, Fit = 0.5, Element = c(Members) },
	},
})
