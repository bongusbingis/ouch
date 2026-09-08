-- Planning errors must block publication even when TestEZ reports zero failed tests.
--!nonstrict

local TestEZ = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("testEZ"))
local assertCloudTestSuccess = require(script.Parent.Parent.Helpers.CloudTestGate)

local function runFixture(method)
	local modules = {}
	if method then
		table.insert(modules, {
			method = method,
			path = { "CloudTestGateFixture" },
			pathStringForSorting = "cloudtestgatefixture",
		})
	end
	return TestEZ.TestRunner.runPlan(TestEZ.TestPlanner.createPlan(modules))
end

local function accepts(results)
	local ok = pcall(assertCloudTestSuccess, results.successCount, results.failureCount, results.errors)
	return ok
end

return function()
	describe("CloudTestGate", function()
		it("rejects planning errors alongside otherwise passing tests", function()
			local results = runFixture(function()
				describe("broken planning", function()
					it("passes", function() end)
					error("fixture planning failed")
				end)
			end)
			expect(results.successCount).to.equal(1)
			expect(results.failureCount).to.equal(0)
			expect(#results.errors).to.equal(1)
			expect(accepts(results)).to.equal(false)
		end)

		it("rejects an empty suite", function()
			local results = runFixture()
			expect(results.successCount + results.failureCount + results.skippedCount).to.equal(0)
			expect(accepts(results)).to.equal(false)
		end)

		it("rejects a fully skipped suite", function()
			local results = runFixture(function()
				xit("skipped", function() end)
			end)
			expect(results.skippedCount).to.equal(1)
			expect(accepts(results)).to.equal(false)
		end)

		it("rejects failing tests", function()
			local results = runFixture(function()
				it("fails", function()
					error("fixture test failed")
				end)
			end)
			expect(results.failureCount).to.equal(1)
			expect(accepts(results)).to.equal(false)
		end)

		it("accepts passing tests with intentional skips", function()
			local results = runFixture(function()
				it("passes", function() end)
				xit("skipped", function() end)
			end)
			expect(results.successCount).to.equal(1)
			expect(results.skippedCount).to.equal(1)
			expect(accepts(results)).to.equal(true)
		end)
	end)
end
