-- Exercises isolation, transport bounds, durable purchase history, and movement budgets.
--!strict
local T = require(script.Parent.TestKit)
local Game = script.Parent.Parent.Game
local Queue = require(Game.Input.IntentQueue)
local Packets = require(Game.Adapters.CombatEventPackets)
local History = require(Game.Economy.ReceiptHistory)
local Fields = require(Game.Economy.AnalyticsFields)
local Budget = require(Game.MapFeatures.MovementBudget)
local Order = require(Game.Sim.CommandOrder)

T.describe("Production reliability", function()
	T.it("admits all twenty players independently of a saturated sender", function()
		local q = Queue.new(2)
		q.push("spam", {})
		q.push("spam", {})
		T.expect(q.push("spam", {})):toEqual(false)
		for i = 1, 20 do
			T.expect(q.push(tostring(i), { playerId = tostring(i) })):toEqual(true)
		end
		T.expect(#q.drain()):toEqual(22)
		T.expect(q.takeRejected()):toEqual(1)
		T.expect(q.takeRejected()):toEqual(0)
		T.expect(#q.drain()):toEqual(0)
	end)
	T.it("retains accepted charge control order across ticks and forgets departed inputs", function()
		local q = Queue.new(4)
		q.push("1", { playerId = "1", kind = "CancelCharge" })
		q.push("1", { playerId = "1", kind = "BeginCharge" })
		local commands = q.drain()
		table.sort(commands, Order.less)
		T.expect(commands[1].kind):toEqual("CancelCharge")
		q.push("1", { kind = "Throw" })
		T.expect(q.drain()[1].sequence):toEqual(3)
		q.push("2", {})
		q.forget("2")
		T.expect(#q.drain()):toEqual(0)
	end)
	T.it("keeps simultaneous presentation events in bounded compatible packets", function()
		local events = {}
		for i = 1, 40 do
			table.insert(events, {
				kind = "BallCaught",
				tick = i,
				playerId = "1",
				position = vector.create(1, 2, 3),
				unbounded = string.rep("x", 2000),
			})
		end
		local packets = Packets.encode(events)
		T.expect(#packets):toEqual(40)
		for _, packet in packets do
			T.expect(#packet):toEqual(1)
			T.expect(packet[1].unbounded):toBeNil()
			T.expect(packet[1].position):toEqual(vector.create(1, 2, 3))
		end
		T.expect(#Packets.encode({
			{ kind = "Elim" },
			{ kind = string.rep("x", 65) },
			{ kind = "Hit", tick = 0 / 0 },
			{ kind = "Hit", position = vector.create(0, math.huge, 0) },
		})):toEqual(0)
	end)
	T.it("preserves receipt idempotence while bounding recent detail and accepting old numeric records", function()
		local records = { legacy = 10 }
		for i = 1, 100 do
			records[tostring(i)] = { at = i, productId = 42, payload = { productId = 42 } }
		end
		History.prune(records, 3, "1")
		local recent = History.recent(records, 10)
		T.expect(#recent):toEqual(3)
		T.expect(recent[1].id):toEqual("100")
		T.expect(recent[3].id):toEqual("1")
		T.expect(records["50"]):toEqual(50)
		T.expect(records.legacy):toEqual(10)
		local count = 0
		for _ in records do
			count += 1
		end
		T.expect(count):toEqual(101)
	end)
	T.it("sends only three supported bounded scalar analytics dimensions", function()
		local fields = Fields.resolve(
			{ { "device" }, { "bad", "zero" }, { "flag" }, { "extra" } },
			{ device = string.rep("x", 100), bad = math.huge, zero = 0, flag = false, extra = "ignored" }
		)
		T.expect(fields.CustomField01):toEqual("device:" .. string.rep("x", 64))
		T.expect(fields.CustomField02):toEqual("zero:0")
		T.expect(fields.CustomField03):toEqual("flag:false")
		T.expect(fields.CustomField04):toBeNil()
	end)
	T.it("allows normal movement with delayed replication but rejects sustained excess speed", function()
		local state = Budget.new(vector.zero, 0, 32)
		for i = 1, 30 do
			T.expect(Budget.step(state, vector.create(i * 4, 0, 0), i * 0.2, 24, 70, 32)):toEqual(true)
		end
		T.expect(Budget.step(state, vector.create(200, 0, 0), 6.1, 24, 70, 32)):toEqual(false)
		T.expect(state.position):toEqual(vector.create(120, 0, 0))
		local fast = Budget.new(vector.zero, 0, 32)
		T.expect(Budget.step(fast, vector.create(30, 0, 0), 0.1, 24, 70, 32)):toEqual(true)
		T.expect(Budget.step(fast, vector.create(60, 0, 0), 0.2, 24, 70, 32)):toEqual(false)
	end)
	T.it("permits falling and finite launch allowances without accepting invalid coordinates", function()
		local state = Budget.new(vector.zero, 0, 32)
		T.expect(Budget.step(state, vector.create(0, 25, 0), 0.2, 24, 130, 32)):toEqual(true)
		T.expect(Budget.step(state, vector.create(0, -100, 0), 0.4, 24, 70, 32)):toEqual(true)
		T.expect(Budget.finite(vector.create(0, 0 / 0, 0), 100000)):toEqual(false)
		T.expect(Budget.finite(vector.create(math.huge, 0, 0), 100000)):toEqual(false)
	end)
end)
return true
