-- Name: WriteThroughProxy.spec.luau
-- Author: Jack C.
-- Description: Spec that the write-through proxy stores assigned tables raw while replicating the same value and keeps repeated nested reads bounded and writable.
-- Created: 2026-08-23

--!strict

local T = require(script.Parent.TestKit)
local WriteThroughProxy = require(script.Parent.Parent.Game.Data.WriteThroughProxy)

local function fixture()
	local writes = {}
	local writer = {}

	function writer:Set(path, value)
		table.insert(writes, {
			path = table.clone(path),
			value = value,
		})
	end

	local raw = {
		Shop = {
			Bucket = -1,
			Offers = {},
		},
	}

	return raw, WriteThroughProxy.wrap(raw, writer), writes
end

T.describe("WriteThroughProxy", function()
	T.it("stores assigned tables raw while replicating the same value", function()
		local raw, proxy, writes = fixture()
		local shop = {
			Bucket = 42,
			Offers = { "BallRed", "BallBlue" },
		}

		proxy.Shop = shop

		T.expect(raw.Shop == shop):toBeTruthy()
		T.expect(writes[1].value == shop):toBeTruthy()
		local offers = {}
		for index, itemId in proxy.Shop.Offers do
			offers[index] = itemId
		end
		T.expect(table.concat(offers, ",")):toEqual("BallRed,BallBlue")
	end)

	T.it("keeps repeated nested reads bounded and writable", function()
		local raw, proxy, writes = fixture()

		for _ = 1, 1000 do
			T.expect(proxy.Shop.Bucket):toEqual(-1)
		end

		proxy.Shop.Bucket = 9
		T.expect(raw.Shop.Bucket):toEqual(9)
		T.expect(table.concat(writes[1].path, ".")):toEqual("Shop.Bucket")
	end)
end)

return true
