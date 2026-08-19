export type GameMode = "FFA" | "TDM" | "Infection"
export type PartyPhase = "Lobby" | "Queued" | "Claimed" | "Assigned" | "Teleporting"

export type PartyMember = {
	userId: number,
	joinedAt: number,
	characterColorId: string?,
}

export type QueueTicket = {
	ticketId: string,
	partyId: string,
	partySize: number,
	enqueuedAt: number,
}

export type PartyClaim = {
	claimId: string,
	expiresAt: number,
}

export type PartyRecord = {
	schemaVersion: number,
	partyId: string,
	joinCode: string,
	revision: number,
	leaderUserId: number,
	members: { PartyMember },
	allowFriendJoins: boolean,
	phase: PartyPhase,
	queueTicket: QueueTicket?,
	claim: PartyClaim?,
	matchId: string?,
	leaseUntil: number,
	createdAt: number,
	updatedAt: number,
}

export type PartySnapshot = PartyRecord

export type MatchParty = {
	partyId: string,
	memberUserIds: { number },
}

export type MatchRecord = {
	schemaVersion: number,
	matchId: string,
	modeSelection: {
		strategy: "Vote",
		options: { GameMode },
	},
	arenaPlaceId: number,
	targetPlayers: number,
	parties: { MatchParty },
	expectedUserIds: { number },
	reservedServerAccessCode: string,
	status: "Ready",
	createdAt: number,
}

export type TeleportData = {
	schemaVersion: number,
	matchId: string,
	partyId: string,
	expectedPlayerCount: number,
	modeSelection: {
		strategy: "Vote",
		options: { GameMode },
	},
}

return {}
