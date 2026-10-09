-- Description: Pure decisions for the arena loading overlay: its title and detail copy, when a lone player has waited long enough to be offered a RETURN, and which actions it shows.

--!strict

local ArenaLoadingViewModel = {}

-- How long a ready player may sit in Idle with no ballot before the overlay
-- says the arena is waiting for players and offers RETURN.
ArenaLoadingViewModel.RosterWaitSeconds = 12

-- The gate released, nothing is voting, and no round is on the way: a roster
-- too short for any mode lands here, and only another arrival or leaving helps.
function ArenaLoadingViewModel.isWaitingForRoster(loading, vote, teleportStatus): boolean
	local returning = teleportStatus ~= nil and teleportStatus.state ~= "Complete"
	return loading.fixedModeId == nil
		and loading.admission ~= "Rejected"
		and loading.localReady
		and loading.gateReleased
		and loading.matchPhase == "Idle"
		and not vote.open
		and not returning
end

function ArenaLoadingViewModel.copy(loading, vote, teleportStatus, hasResult: boolean, rosterStalled: boolean)
	local fixed = loading.fixedModeId ~= nil
	if teleportStatus then
		if teleportStatus.state == "Failed" then
			if teleportStatus.waitingForParty then
				return "WAITING FOR YOUR PARTY", "YOUR PARTY IS STILL TRAVELING"
			elseif teleportStatus.reason == "rewards_pending" then
				return "REWARDS ARE STILL SAVING", "TRY AGAIN TO CHECK YOUR REWARDS AND RETURN"
			end
			return "RETURN FAILED", "WE COULD NOT REACH THE LOBBY"
		elseif teleportStatus.state == "Retrying" then
			return "RECONNECTING", `ATTEMPT {teleportStatus.attempt} OF {teleportStatus.maxAttempts}`
		elseif teleportStatus.state == "Attempting" then
			return "RETURNING TO LOBBY", "TRAVELING FROM THE ARENA"
		elseif teleportStatus.state == "Delayed" then
			return "RETURNING TO LOBBY", "THIS IS TAKING LONGER THAN USUAL"
		end
	end
	if loading.admission == "Rejected" then
		return "UNABLE TO JOIN MATCH", "PLEASE RETURN TO THE LOBBY"
	elseif not loading.localReady then
		if loading.preloadReady and not loading.simulationReady then
			return "LOADING ARENA", "STARTING GAMEPLAY SYSTEMS"
		elseif loading.preloadReady then
			return if fixed then "GETTING THE RACE READY" else "GETTING THE VOTE READY", nil
		end
		-- The title already says it; the progress bar carries the rest.
		return "LOADING ARENA", nil
	elseif not loading.gateReleased then
		if loading.arrivedPlayerCount < loading.expectedPlayerCount then
			return "WAITING FOR PLAYERS", `{loading.arrivedPlayerCount} OF {loading.expectedPlayerCount} IN ARENA`
		end
		return "GETTING EVERYONE READY", `{loading.readyPlayerCount} OF {loading.expectedPlayerCount} READY`
	elseif vote.open then
		return "GETTING THE VOTE READY", nil
	elseif loading.matchPhase == "Results" and not hasResult then
		return "JOINING NEXT ROUND", "THIS ROUND IS WRAPPING UP"
	elseif rosterStalled then
		return "WAITING FOR PLAYERS", "NOT ENOUGH PLAYERS TO START"
	elseif fixed then
		return "GETTING THE RACE READY", "THE NEXT RACE STARTS SOON"
	end
	return "JOINING MATCH", nil
end

-- Returns the primary and secondary action kinds ("Retry", "Stay", "Return"), either nil.
-- A failed return offers TRY AGAIN/STAY only while the server would honor them; a
-- player waiting on a partymate's teleport has nothing to press until it settles.
function ArenaLoadingViewModel.actions(loading, teleportStatus, rosterStalled: boolean): (string?, string?)
	if teleportStatus and teleportStatus.state == "Failed" then
		return if teleportStatus.canRetry ~= false then "Retry" else nil,
			if teleportStatus.canStay ~= false then "Stay" else nil
	elseif loading.admission == "Rejected" or rosterStalled then
		return "Return", nil
	end
	return nil, nil
end

return ArenaLoadingViewModel
