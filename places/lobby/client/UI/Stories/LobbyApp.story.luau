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

function mockPartyClient:getSnapshot()
	return snapshot
end

function mockPartyClient:isBusy()
	return false
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
function mockPartyClient:promptInvite() end
function mockPartyClient:kick(_targetUserId) end

return function(target: Instance)
	local root = ReactRoblox.createRoot(target)
	root:render(React.createElement(LobbyApp, {
		PartyClient = mockPartyClient,
		EconomyData = { Cash = 0, Cosmetics = { Owned = {}, Equipped = {} } },
		CameraEnabled = false,
		WorldPresentationEnabled = false,
	}))
	return function()
		root:unmount()
	end
end
