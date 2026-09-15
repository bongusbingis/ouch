-- Description: Shared type declarations for the lobby matchmaking system: parties, members, snapshots, queue tickets, match records, and request payloads.

export type QueueId = "Arena" | "Splashdown"
export type GameMode = "FFA" | "TDM" | "Infection" | "Splashdown"
export type PartyPhase = "Lobby" | "Queued" | "Claimed" | "Assigned" | "Teleporting"

export type ModeSelection =
	{
		strategy: "Vote",
		options: { GameMode },
	}
	| {
		strategy: "Fixed",
		modeId: string,
	}

export type PartyMember = {
	userId: number,
	joinedAt: number,
	characterColorId: string?,
	costumeId: string?,
}

export type QueueTicket = {
	ticketId: string,
	partyId: string,
	queueId: QueueId,
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
	queueId: QueueId,
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
	leaderUserId: number,
	memberUserIds: { number },
}

export type MatchRecord = {
	schemaVersion: number,
	matchId: string,
	queueId: QueueId,
	modeSelection: ModeSelection,
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
	queueId: string,
	expectedPlayerCount: number,
	modeSelection: ModeSelection,
	party: {
		leaderUserId: number,
		memberUserIds: { number },
	}?,
}

return {}
