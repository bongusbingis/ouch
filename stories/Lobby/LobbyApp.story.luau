--[[
    The whole lobby UI (LobbyApp) mounted against inert party, shop and progression clients, so
    the page flow -- header navigation, Play, Shop, Backpack, Settings, join code, modals -- can be
    walked end to end without a server. Pages and modals are live; every server call returns
    "preview_only" or does nothing.

    Not stubbable in edit mode: LobbyApp lives in the lobby place only
    (StarterPlayerScripts.Client.UI.LobbyApp) and pulls in client services (Network,
    PresentationCamera, CosmeticPreviewClient, PartyCharacterRenderer) that expect a running
    client, so this story shows a notice unless it is opened in the lobby place during a Play
    session (Players.LocalPlayer present). CameraEnabled and WorldPresentationEnabled are off so it
    never drives the world camera. Migrated from places/lobby/client/UI/Stories/LobbyApp.story
    (which read LocalPlayer.UserId at require time and so failed in edit mode).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)
local Fixtures = require(script.Parent.Parent.Fixtures)

local Players = game:GetService("Players")

local React = StoryRoot.React

local c = React.createElement

local function shopSnapshot(): any
	local now = os.time()
	return {
		status = "Ready",
		shopState = {
			serverNow = now,
			offers = {},
			offersExpireAt = now + 86400,
			featured = { kind = "Crate", id = "DodgeballCrate" },
			featuredExpireAt = now + 604800,
			bundle = {
				bundleId = "StarterOutfitBundle",
				displayName = "Starter Outfit Bundle",
				description = "A complete look, cheaper than buying the pieces.",
				status = "Preview",
				itemIds = {},
			},
			bundleExpireAt = now + 604800,
		},
		metadata = {},
		ownedPasses = {},
		pending = {},
		reveal = nil,
		grant = nil,
	}
end

local function App()
	local module = StoryRoot.placeModule({ "UI", "LobbyApp" })
	if module == nil then
		return StoryRoot.Notice("LobbyApp is lobby-only. Open this story in the lobby place.")
	end
	if not StoryRoot.hasLocalPlayer() then
		return StoryRoot.Notice("LobbyApp needs a running client. Start Play in the lobby place, then open this story.")
	end
	local LobbyApp = (require :: any)(module)
	local localPlayer = Players.LocalPlayer
	local userId = if localPlayer then localPlayer.UserId else Fixtures.LocalUserId
	return c(LobbyApp, {
		PartyClient = Fixtures.partyClient(Fixtures.partySnapshot(0, userId)),
		ShopClient = Fixtures.shopClient(shopSnapshot()),
		DailyRewardStore = Fixtures.projection(nil),
		SeasonStore = Fixtures.projection({ active = false, tiers = {} }),
		QuestStore = Fixtures.projection(Fixtures.quests("Empty")),
		EconomyData = { Bonks = 0, Cosmetics = { Owned = {}, Equipped = {} } },
		CameraEnabled = false,
		WorldPresentationEnabled = false,
	})
end

return StoryRoot.story({
	Title = "Lobby app",
	Summary = "The full LobbyApp on inert clients (lobby place, Play session only).",
	States = {
		{ Name = "Lobby app", Note = "Lobby place + Play session.", Screen = true, Element = c(App) },
	},
})
