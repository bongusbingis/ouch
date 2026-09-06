--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local request = require(ReplicatedStorage.Shared.Game.Data.ClientRequest)
local Config = require(ReplicatedStorage.Config.Infra.ClientRequests)

return function()
	describe("Bounded client requests", function()
		it("preserves nil return slots and reports thrown failures", function()
			local ok, first, second, third = request(function()
				return "accepted", nil, 7
			end)
			expect(ok).to.equal(true)
			expect(first).to.equal("accepted")
			expect(second).to.equal(nil)
			expect(third).to.equal(7)
			expect(request(function()
				error("offline")
			end)).to.equal(false)
		end)
		it("times out and cancels late projection work", function()
			local previous = Config.TimeoutSeconds
			Config.TimeoutSeconds = 0.03
			local late = false
			local ok, reason = request(function()
				task.wait(0.2)
				late = true
				return "stale"
			end)
			Config.TimeoutSeconds = previous
			task.wait(0.25)
			expect(ok).to.equal(false)
			expect(reason).to.equal("request_timed_out")
			expect(late).to.equal(false)
		end)
	end)
end
