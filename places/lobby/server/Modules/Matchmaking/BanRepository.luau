--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BanPolicy = require(ReplicatedStorage.Shared.Game.Matchmaking.BanPolicy)
local Config = require(ReplicatedStorage.Shared.Matchmaking.Config)
local CloudRetry = require(script.Parent.CloudRetry)

local BanRepository = {}
BanRepository.__index = BanRepository

function BanRepository.new()
	return setmetatable({
		_store = DataStoreService:GetDataStore(Config.BanDataStoreName, Config.BanDataStoreScope),
	}, BanRepository)
end

function BanRepository:_checkUser(userId: number, now: number): (boolean?, string?)
	local success, record = CloudRetry.call("BanRepository.Get", function()
		return self._store:GetAsync(tostring(userId))
	end)
	if not success then
		return nil, "unavailable"
	end

	local status = BanPolicy.evaluate(record, now)
	if status == BanPolicy.Status.Invalid then
		warn(("[BanRepository] Invalid ban entry for user %d"):format(userId))
		return nil, "invalid_entry"
	end

	return status == BanPolicy.Status.Banned, nil
end

function BanRepository:HasBannedMember(userIds: { number }, now: number): (boolean?, string?)
	local remaining = #userIds
	if remaining == 0 then
		return false, nil
	end

	local banned = false
	local checkError = nil
	for _, userId in userIds do
		task.spawn(function()
			local success, isBanned, userError = pcall(self._checkUser, self, userId, now)
			if not success then
				warn(("[BanRepository] Ban check failed for user %d: %s"):format(userId, tostring(isBanned)))
				checkError = "unavailable"
			elseif isBanned == nil then
				checkError = userError or "unavailable"
			elseif isBanned then
				banned = true
			end
			remaining -= 1
		end)
	end

	while remaining > 0 do
		task.wait()
	end

	if checkError then
		return nil, checkError
	end
	return banned, nil
end

return BanRepository
