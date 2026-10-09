-- Description: Paid-random policy remains authoritative for pooled Bonks even when current offers are hidden.

--!nonstrict

local ServerScriptService = game:GetService("ServerScriptService")

local PaidRandomPolicyService =
	require(ServerScriptService:WaitForChild("Server"):WaitForChild("Modules"):WaitForChild("PaidRandomPolicyService"))

local function signal()
	local callbacks = {}
	local object = {}
	function object:Connect(callback)
		local connection = { connected = true }
		function connection:Disconnect()
			self.connected = false
		end
		table.insert(callbacks, { callback = callback, connection = connection })
		return connection
	end
	function object:Fire(...)
		for _, entry in callbacks do
			if entry.connection.connected then
				entry.callback(...)
			end
		end
	end
	return object
end

return function()
	describe("PaidRandomPolicyService", function()
		beforeEach(function()
			PaidRandomPolicyService._resetForTest()
		end)

		afterEach(function()
			PaidRandomPolicyService._resetForTest()
		end)

		it("blocks paid Bonks crates for restricted players and caches the policy", function()
			local removing = signal()
			local calls = 0
			local player = { Name = "Restricted" }
			PaidRandomPolicyService.start({
				players = { PlayerRemoving = removing },
				policyService = {
					GetPolicyInfoForPlayerAsync = function()
						calls += 1
						return { ArePaidRandomItemsRestricted = true }
					end,
				},
				products = {
					Catalog = {
						BonksPack = { Enabled = true, Type = "Bonks" },
					},
				},
			})

			local allowed, reason = PaidRandomPolicyService.canReceivePaidRandom(player)
			expect(allowed).to.equal(false)
			expect(reason).to.equal("paid_random_restricted")
			PaidRandomPolicyService.canReceivePaidRandom(player)
			expect(calls).to.equal(1)
		end)

		it("keeps restrictions when current paid offers are preview-only", function()
			local removing = signal()
			PaidRandomPolicyService.start({
				players = { PlayerRemoving = removing },
				policyService = {
					GetPolicyInfoForPlayerAsync = function()
						return { ArePaidRandomItemsRestricted = true }
					end,
				},
				products = { Catalog = { Bonks500 = { CatalogStatus = "Preview", Type = "Bonks" } } },
			})
			local allowed = PaidRandomPolicyService.canReceivePaidRandom({ Name = "EarnedOnly" })
			expect(allowed).to.equal(false)
		end)

		it("treats malformed policy as unavailable and bounds repeated failures", function()
			local calls, now = 0, 0
			PaidRandomPolicyService.start({
				players = { PlayerRemoving = signal() },
				clock = function()
					return now
				end,
				policyService = {
					GetPolicyInfoForPlayerAsync = function()
						calls += 1
						return {}
					end,
				},
			})
			local player = { Name = "Unavailable" }
			for _ = 1, 10 do
				local allowed, reason = PaidRandomPolicyService.canReceivePaidRandom(player)
				expect(allowed).to.equal(false)
				expect(reason).to.equal("policy_unavailable")
			end
			expect(calls).to.equal(1)
			now = 6
			PaidRandomPolicyService.canReceivePaidRandom(player)
			expect(calls).to.equal(2)
		end)
	end)
end
