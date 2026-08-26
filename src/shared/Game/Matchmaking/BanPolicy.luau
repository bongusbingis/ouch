-- Name: BanPolicy.luau
-- Author: Jack C.
-- Description: Pure interpretation of a stored ban record, distinguishing permanent bans, live temporary bans, expired ones, and malformed entries.
-- Created: 2026-08-17

--!strict

local BanPolicy = {}

BanPolicy.Status = table.freeze({
	Banned = "Banned",
	Invalid = "Invalid",
	NotBanned = "NotBanned",
})

export type Status = "Banned" | "Invalid" | "NotBanned"

function BanPolicy.evaluate(record: any, now: number): Status
	if record == nil then
		return BanPolicy.Status.NotBanned
	end
	if
		typeof(record) ~= "number"
		or record ~= record
		or record == math.huge
		or record == -math.huge
		or record < 0
		or record % 1 ~= 0
	then
		return BanPolicy.Status.Invalid
	end

	if record == 0 or record > now then
		return BanPolicy.Status.Banned
	end

	return BanPolicy.Status.NotBanned
end

return table.freeze(BanPolicy)
