--!strict

local T = require(script.Parent.TestKit)
local BanPolicy = require(script.Parent.Parent.Game.Matchmaking.BanPolicy)

T.describe("BanPolicy", function()
	T.it("treats a missing entry as not banned", function()
		T.expect(BanPolicy.evaluate(nil, 100)):toEqual(BanPolicy.Status.NotBanned)
	end)

	T.it("treats zero as a permanent ban", function()
		T.expect(BanPolicy.evaluate(0, 100)):toEqual(BanPolicy.Status.Banned)
	end)

	T.it("treats future timestamps as temporary bans", function()
		T.expect(BanPolicy.evaluate(101, 100)):toEqual(BanPolicy.Status.Banned)
	end)

	T.it("ignores expired bans", function()
		T.expect(BanPolicy.evaluate(100, 100)):toEqual(BanPolicy.Status.NotBanned)
		T.expect(BanPolicy.evaluate(99, 100)):toEqual(BanPolicy.Status.NotBanned)
	end)

	T.it("rejects malformed entries", function()
		T.expect(BanPolicy.evaluate(true, 100)):toEqual(BanPolicy.Status.Invalid)
		T.expect(BanPolicy.evaluate({}, 100)):toEqual(BanPolicy.Status.Invalid)
		T.expect(BanPolicy.evaluate("101", 100)):toEqual(BanPolicy.Status.Invalid)
		T.expect(BanPolicy.evaluate(-1, 100)):toEqual(BanPolicy.Status.Invalid)
		T.expect(BanPolicy.evaluate(100.5, 100)):toEqual(BanPolicy.Status.Invalid)
	end)
end)

return true
