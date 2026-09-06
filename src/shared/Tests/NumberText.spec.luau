--!strict

local T = require(script.Parent.TestKit)
local formatNumber = require(script.Parent.Parent.UI.Models.NumberText)

T.describe("NumberText", function()
	T.it("groups balances and refunds consistently without abbreviating their value", function()
		T.expect(formatNumber(0)):toEqual("0")
		T.expect(formatNumber(999)):toEqual("999")
		T.expect(formatNumber(1000)):toEqual("1,000")
		T.expect(formatNumber(12345678)):toEqual("12,345,678")
		T.expect(formatNumber(-1250)):toEqual("-1,250")
	end)
end)

return true
