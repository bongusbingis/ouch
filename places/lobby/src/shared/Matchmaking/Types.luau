export type GameMode = "FFA" | "TDM" | "BR"
export type PartyPhase = "Lobby" | "Queued" | "Claimed" | "Assigned" | "Teleporting"

export type PartyMember = {
	userId: number,
	joinedAt: number,
}

export type PartySelection = {
	mode: GameMode,
	brTeamSize: number?,
	fill: boolean,
}

export type QueueTicket = {
	ticketId: string,
	partyId: string,
	partyRevision: number,
	mode: GameMode,
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
	selection: PartySelection,
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
	mode: GameMode,
	mapKey: string,
	arenaPlaceId: number,
	targetPlayers: number,
	parties: { MatchParty },
	expectedUserIds: { number },
	reservedServerAccessCode: string,
	status: "Ready",
	createdAt: number,
}

return {}
