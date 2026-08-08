--!strict

-- Projects Roblox's local-player paid-random-item policy for storefront
-- controllers. Nil means the policy lookup is still pending.

type StartOptions = {
	policyService: any?,
	player: Player?,
	runAsync: ((callback: () -> ()) -> ())?,
}

local PaidRandomPolicyStore = {}

local started = false
local allowed: boolean? = nil
local callbacks: { (boolean) -> () } = {}

local function notify(value: boolean)
	for _, callback in callbacks do
		local ok, err = pcall(callback, value)
		if not ok then
			warn(`[PaidRandomPolicyStore] changed callback failed: {err}`)
		end
	end
end

function PaidRandomPolicyStore.start(options: StartOptions?)
	if started then
		return
	end
	started = true
	local policyService = if options and options.policyService
		then options.policyService
		else game:GetService("PolicyService")
	local player = if options and options.player then options.player else game:GetService("Players").LocalPlayer
	local runAsync = if options and options.runAsync
		then options.runAsync
		else function(callback)
			task.spawn(callback)
		end
	runAsync(function()
		local ok, policy = pcall(function()
			return policyService:GetPolicyInfoForPlayerAsync(player)
		end)
		allowed = ok and type(policy) == "table" and policy.ArePaidRandomItemsRestricted ~= true
		notify(allowed == true)
	end)
end

function PaidRandomPolicyStore.snapshot(): boolean?
	return allowed
end

function PaidRandomPolicyStore.onChanged(callback: (boolean) -> ()): () -> ()
	table.insert(callbacks, callback)
	if allowed ~= nil then
		callback(allowed)
	end
	local connected = true
	return function()
		if not connected then
			return
		end
		connected = false
		local index = table.find(callbacks, callback)
		if index then
			table.remove(callbacks, index)
		end
	end
end

function PaidRandomPolicyStore._resetForTest()
	started = false
	allowed = nil
	table.clear(callbacks)
end

return PaidRandomPolicyStore
