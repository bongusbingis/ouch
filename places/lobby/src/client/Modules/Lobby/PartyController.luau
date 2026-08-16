local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Network = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Network"))
local Protocol = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Matchmaking"):WaitForChild("Protocol"))
local PartyCharacterRenderer = require(script.Parent.PartyCharacterRenderer)
local JoinCodeInput = require(script.Parent.JoinCodeInput)
local PartyStore = require(script.Parent.PartyStore)

local PartyController = {}

local ERROR_MESSAGES = {
	arena_not_configured = "MATCH PLACE IS NOT CONFIGURED",
	busy = "PLEASE WAIT...",
	internal_error = "PARTY SERVICE UNAVAILABLE",
	invalid_args = "INVALID PARTY REQUEST",
	invalid_code = "PARTY CODE NOT FOUND",
	invalid_request = "INVALID PARTY REQUEST",
	invite_unavailable = "INVITES ARE UNAVAILABLE",
	match_forming = "MATCH IS ALREADY FORMING",
	not_party_leader = "ONLY THE PARTY LEADER CAN DO THAT",
	party_full = "THAT PARTY IS FULL",
	party_not_found = "PARTY NOT FOUND",
	party_not_ready = "PARTY IS STILL LOADING",
	rate_limited = "TOO MANY REQUESTS",
	teleport_failed = "TELEPORT FAILED - TRY AGAIN",
}

local JOIN_CODE_ERROR_MESSAGES = {
	invalid_code = "PARTY CODE NOT FOUND",
	party_full = "THAT PARTY IS FULL",
	party_not_found = "PARTY CODE NOT FOUND",
}

local function formatCode(code, visible)
	if not visible then
		return "PARTY CODE: XXX-XXX"
	end

	return ("PARTY CODE: %s-%s"):format(string.sub(code, 1, 3), string.sub(code, 4, 6))
end

function PartyController.start(screenGui, notifications)
	local player = Players.LocalPlayer
	local baseClip = screenGui:WaitForChild("BaseClip")
	local hud = baseClip:WaitForChild("HUD")
	local splash = baseClip:WaitForChild("Views"):WaitForChild("SplashScreen")
	local partyState = splash:WaitForChild("BottomMiddle"):WaitForChild("PartyState")
	local playButton = splash:WaitForChild("BottomRight"):WaitForChild("PlayButton")
	local playText = playButton:WaitForChild("TextLabel")
	local joinButton = splash:WaitForChild("BottomRight"):WaitForChild("JoinWithCode")
	local inviteButton = splash:WaitForChild("BottomRight"):WaitForChild("InviteFriends")
	local partyCode = hud:WaitForChild("PartyCode")
	local showCodeButton = partyCode:WaitForChild("ShowCode")
	local codeLabel = partyCode:WaitForChild("Code"):WaitForChild("TextLabel")

	local joinModal = baseClip:WaitForChild("Modals"):WaitForChild("JoinCode")

	local store = PartyStore.new()
	local codeVisible = false
	local requestBusy = false
	local normalPlayColor = playButton.ImageColor3

	local function setPlayEnabled(enabled)
		playButton.Active = enabled
		playButton.Selectable = enabled
		playButton.AutoButtonColor = enabled
		playButton.ImageColor3 = enabled and normalPlayColor or Color3.fromRGB(110, 110, 110)
	end

	local function render(snapshot)
		local isLeader = snapshot.leaderUserId == player.UserId
		codeLabel.Text = formatCode(snapshot.joinCode, codeVisible)

		if snapshot.phase == "Lobby" then
			partyState.Text = isLeader and "PRESS PLAY TO MATCHMAKE" or "WAITING FOR PARTY LEADER..."
			playText.Text = "PLAY"
			setPlayEnabled(isLeader and not requestBusy)
		elseif snapshot.phase == "Queued" then
			partyState.Text = "SEARCHING FOR PLAYERS..."
			playText.Text = "CANCEL"
			setPlayEnabled(isLeader and not requestBusy)
		elseif snapshot.phase == "Claimed" then
			partyState.Text = "FORMING MATCH..."
			playText.Text = "PLAY"
			setPlayEnabled(false)
		elseif snapshot.phase == "Assigned" then
			partyState.Text = "MATCH FOUND!"
			playText.Text = "PLAY"
			setPlayEnabled(false)
		else
			partyState.Text = "TRAVELING TO MATCH..."
			playText.Text = "PLAY"
			setPlayEnabled(false)
		end
	end

	local function showError(errorCode)
		local message = ERROR_MESSAGES[errorCode] or "PARTY REQUEST FAILED"
		local snapshot = store:GetSnapshot()
		if snapshot then
			render(snapshot)
		end

		notifications:Notify({
			title = "PARTY NOTICE",
			description = message,
			buttonText = "CONFIRM",
		})
	end

	local function request(action, payload, reportError)
		if requestBusy then
			return nil, "busy"
		end

		requestBusy = true
		local snapshot = store:GetSnapshot()
		if snapshot then
			render(snapshot)
		end

		local success, response, networkError = pcall(Network.call, "PartyRequest", action, payload)
		requestBusy = false

		if not success then
			if reportError ~= false then
				showError("internal_error")
			end
			return nil, "internal_error"
		end
		if not response or not response.ok then
			local errorCode = response and response.error or networkError or "internal_error"
			if reportError ~= false then
				showError(errorCode)
			end
			return response, errorCode
		end

		if response.snapshot then
			store:ApplySnapshot(response.snapshot, action)
		end
		return response
	end

	local characterRenderer = PartyCharacterRenderer.new(player.UserId, function(targetUserId, username)
		notifications:Confirm({
			title = "KICK PLAYER?",
			description = ("ARE YOU SURE YOU WANT TO REMOVE %s FROM YOUR PARTY?"):format(string.upper(username)),
			confirmText = "KICK",
			cancelText = "CANCEL",
		}, function(confirmed)
			if confirmed then
				request(Protocol.Actions.KickMember, {
					targetUserId = targetUserId,
				})
			end
		end)
	end)

	local joinCodeInput = JoinCodeInput.new(joinModal, function(code)
		local response, errorCode = request(Protocol.Actions.JoinByCode, {
			code = code,
		}, false)
		if response and response.ok then
			return true
		end

		local message = JOIN_CODE_ERROR_MESSAGES[errorCode]
		if not message then
			showError(errorCode or "internal_error")
		end
		return false, message
	end)

	store:Subscribe(function(snapshot, previous, reason)
		render(snapshot)
		if reason == "MemberKicked" and previous and previous.partyId ~= snapshot.partyId then
			notifications:Notify({
				title = "REMOVED FROM PARTY",
				description = "YOU WERE REMOVED FROM THE PARTY.",
				buttonText = "CONFIRM",
			})
		end
	end)
	store:Subscribe(function(snapshot)
		characterRenderer:Render(snapshot)
	end)

	Network.on("PartyPacket", function(packet)
		if typeof(packet) ~= "table" then
			return
		end
		if packet.kind == "Snapshot" then
			store:ApplySnapshot(packet.snapshot, packet.reason)
		elseif packet.kind == "Error" then
			showError(packet.error)
		end
	end)

	showCodeButton.MouseButton1Click:Connect(function()
		codeVisible = not codeVisible
		local snapshot = store:GetSnapshot()
		if snapshot then
			render(snapshot)
		end
		showCodeButton.TextLabel.Text = `{codeVisible and "HIDE" or "SHOW"} CODE`
	end)

	joinButton.MouseButton1Click:Connect(function()
		print("aaa")
		joinCodeInput:Open()
	end)

	playButton.MouseButton1Click:Connect(function()
		local snapshot = store:GetSnapshot()
		if not snapshot or snapshot.leaderUserId ~= player.UserId then
			return
		end

		if snapshot.phase == "Lobby" then
			request(Protocol.Actions.StartMatchmaking)
		elseif snapshot.phase == "Queued" then
			request(Protocol.Actions.CancelMatchmaking)
		end
	end)

	inviteButton.MouseButton1Click:Connect(function()
		local snapshot = store:GetSnapshot()
		if not snapshot then
			return
		end

		local success, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if not success then
			warn(("[PartyController] Invite eligibility check failed: %s"):format(tostring(canInvite)))
			showError("invite_unavailable")
			return
		end
		if not canInvite then
			showError("invite_unavailable")
			return
		end

		local options = Instance.new("ExperienceInviteOptions")
		options.LaunchData = Protocol.inviteData(snapshot.partyId, player.UserId)
		local prompted, promptError = pcall(SocialService.PromptGameInvite, SocialService, player, options)
		if not prompted then
			warn(("[PartyController] %s"):format(tostring(promptError)))
			showError("invite_unavailable")
		end
	end)

	partyState.Text = "LOADING PARTY..."
	setPlayEnabled(false)
	joinCodeInput:Close()

	task.spawn(function()
		local lastError = "internal_error"
		for _ = 1, 10 do
			if store:GetSnapshot() then
				return
			end

			local response, errorCode = request(Protocol.Actions.GetSnapshot, nil, false)
			if response and response.ok then
				return
			end
			lastError = errorCode or lastError
			task.wait(1)
		end

		if not store:GetSnapshot() then
			showError(if lastError == "party_not_ready" then "internal_error" else lastError)
		end
	end)
end

return PartyController
