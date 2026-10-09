-- Description: Studio story that mounts the lobby app against mocked party and shop clients so the whole lobby UI can be previewed without a server.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local LobbyApp = require(script.Parent.Parent.LobbyApp)

local snapshot = {
	partyId = "story",
	joinCode = "123456",
	revision = 1,
	leaderUserId = game:GetService("Players").LocalPlayer.UserId,
	phase = "Lobby",
	members = {},
}

local mockPartyClient = {
	ErrorMessages = {},
	JoinCodeErrorMessages = {},
}

local shopState = {
	status = "Ready",
	shopState = {
		serverNow = os.time(),
		offers = {},
		offersExpireAt = os.time() + 86400,
		featured = { kind = "Crate", id = "DodgeballCrate" },
		featuredExpireAt = os.time() + 604800,
		bundle = {
			bundleId = "StarterOutfitBundle",
			displayName = "Starter Outfit Bundle",
			description = "A complete look, cheaper than buying the pieces.",
			status = "Preview",
			itemIds = {},
		},
		bundleExpireAt = os.time() + 604800,
	},
	metadata = {},
	ownedPasses = {},
	pending = {},
	reveal = nil,
	grant = nil,
}

local function projection(state)
	return {
		snapshot = function()
			return state
		end,
		subscribe = function()
			return function() end
		end,
		claim = function()
			return nil, "preview"
		end,
		claimAll = function()
			return nil, "preview"
		end,
	}
end

local mockShopClient = {}

function mockShopClient.snapshot()
	return shopState
end

function mockShopClient.subscribe(_callback)
	return function() end
end

function mockShopClient.refresh()
	return true
end

function mockShopClient.purchaseCosmetic(_cardId, _itemId)
	return true
end

function mockShopClient.openCrate(_cardId, _crateId)
	return true
end

function mockShopClient.promptProduct(_cardId, _productId)
	return true
end

function mockShopClient.promptGamePass(_cardId, _passId)
	return true
end

function mockShopClient.clearReveal() end
function mockShopClient.clearGrant() end

function mockPartyClient:getSnapshot()
	return snapshot
end

function mockPartyClient:isBusy()
	return false
end

function mockPartyClient:getTeleportStatus()
	return nil
end

function mockPartyClient:subscribe(callback)
	callback(snapshot, nil, "Subscribed")
	return function() end
end

function mockPartyClient:subscribeErrors(_callback)
	return function() end
end

function mockPartyClient:joinByCode(_code)
	return { ok = true }
end

function mockPartyClient:toggleMatchmaking() end
function mockPartyClient:setQueue(_queueId) end
function mockPartyClient:promptInvite() end
function mockPartyClient:kick(_targetUserId) end
function mockPartyClient:retryInitialization() end

return function(target: Instance)
	local root = ReactRoblox.createRoot(target)
	root:render(React.createElement(LobbyApp, {
		PartyClient = mockPartyClient,
		ShopClient = mockShopClient,
		DailyRewardStore = projection(nil),
		SeasonStore = projection({ active = false, tiers = {} }),
		QuestStore = projection({ dailyKey = "story", resetAt = 0, quests = {} }),
		EconomyData = { Bonks = 0, Cosmetics = { Owned = {}, Equipped = {} } },
		CameraEnabled = false,
		WorldPresentationEnabled = false,
	}))
	return function()
		root:unmount()
	end
end
