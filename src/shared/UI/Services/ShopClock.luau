--!strict

local ShopClock = {}

local callbacks: { (number) -> () } = {}
local running = false
local current = os.time()
local generation = 0

local function run()
	if running then
		return
	end
	running = true
	generation += 1
	local runGeneration = generation
	task.spawn(function()
		while runGeneration == generation and #callbacks > 0 do
			current = os.time()
			for _, callback in callbacks do
				callback(current)
			end
			task.wait(1)
		end
		if runGeneration == generation then
			running = false
		end
	end)
end

function ShopClock.now(): number
	return current
end

function ShopClock.subscribe(callback: (number) -> ()): () -> ()
	table.insert(callbacks, callback)
	run()
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
		if #callbacks == 0 then
			generation += 1
			running = false
		end
	end
end

return ShopClock
