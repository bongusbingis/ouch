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

		it("blocks paid Cash crates for restricted players and caches the policy", function()
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
						CashPack = { Enabled = true, Type = "Cash" },
					},
				},
			})

			local allowed, reason = PaidRandomPolicyService.canOpenCashCrate(player)
			expect(allowed).to.equal(false)
			expect(reason).to.equal("paid_random_restricted")
			PaidRandomPolicyService.canOpenCashCrate(player)
			expect(calls).to.equal(1)
		end)

		it("leaves earned-Cash crates available when paid offers are preview-only", function()
			local removing = signal()
			PaidRandomPolicyService.start({
				players = { PlayerRemoving = removing },
				policyService = {
					GetPolicyInfoForPlayerAsync = function()
						error("must not query")
					end,
				},
				products = { Catalog = { Cash500 = { CatalogStatus = "Preview", Type = "Cash" } } },
			})
			local allowed = PaidRandomPolicyService.canOpenCashCrate({ Name = "EarnedOnly" })
			expect(allowed).to.equal(true)
		end)
	end)
end
