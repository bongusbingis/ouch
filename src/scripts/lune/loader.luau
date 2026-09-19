-- Description: Builds a fake instance tree from Rojo's sourcemap so modules written with Roblox-style requires can be loaded and run headlessly under Lune.

--!strict

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

type SourcemapEntry = {
	name: string,
	className: string,
	filePaths: { string }?,
	children: { SourcemapEntry }?,
}

export type Node = any

local Loader = {}

local fakeCFrameMeta = {}
function fakeCFrameMeta.__mul(left, _right)
	return left
end

local FakeCFrame = {
	new = function(position: vector?)
		return setmetatable({ Position = position or vector.zero }, fakeCFrameMeta)
	end,
	Angles = function(_x: number, _y: number, _z: number)
		return setmetatable({ Position = vector.zero }, fakeCFrameMeta)
	end,
	identity = setmetatable({ Position = vector.zero }, fakeCFrameMeta),
}

local function fakeColor3(r: number, g: number, b: number)
	local color = { R = r, G = g, B = b, r = r, g = g, b = b }
	function color:Lerp(other, alpha)
		return fakeColor3(r + (other.R - r) * alpha, g + (other.G - g) * alpha, b + (other.B - b) * alpha)
	end
	return color
end

local FakeColor3 = {
	fromRGB = function(r: number, g: number, b: number)
		return fakeColor3(r / 255, g / 255, b / 255)
	end,
	new = function(r: number?, g: number?, b: number?)
		return fakeColor3(r or 0, g or 0, b or 0)
	end,
}

local FakeVector3 = {
	new = function(x: number?, y: number?, z: number?)
		return { X = x or 0, Y = y or 0, Z = z or 0 }
	end,
	zero = { X = 0, Y = 0, Z = 0 },
	one = { X = 1, Y = 1, Z = 1 },
}

local FakeVector2Meta = {}
local function fakeVector2(x: number, y: number)
	return setmetatable({ X = x, Y = y }, FakeVector2Meta)
end
local function vec2Component(value: any, key: string): number
	return if type(value) == "table" then value[key] else value
end
FakeVector2Meta.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	elseif key == "Unit" then
		local magnitude = math.sqrt(self.X * self.X + self.Y * self.Y)
		if magnitude <= 0 then
			return fakeVector2(0, 0)
		end
		return fakeVector2(self.X / magnitude, self.Y / magnitude)
	end
	return nil
end
FakeVector2Meta.__add = function(a, b)
	return fakeVector2(a.X + b.X, a.Y + b.Y)
end
FakeVector2Meta.__sub = function(a, b)
	return fakeVector2(a.X - b.X, a.Y - b.Y)
end
FakeVector2Meta.__unm = function(a)
	return fakeVector2(-a.X, -a.Y)
end
FakeVector2Meta.__mul = function(a, b)
	return fakeVector2(vec2Component(a, "X") * vec2Component(b, "X"), vec2Component(a, "Y") * vec2Component(b, "Y"))
end
FakeVector2Meta.__div = function(a, b)
	return fakeVector2(vec2Component(a, "X") / vec2Component(b, "X"), vec2Component(a, "Y") / vec2Component(b, "Y"))
end
FakeVector2Meta.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y
end
local FakeVector2 = {
	new = function(x: number?, y: number?)
		return fakeVector2(x or 0, y or 0)
	end,
	zero = fakeVector2(0, 0),
	one = fakeVector2(1, 1),
}

local FakeNumberRange = {
	new = function(min: number, max: number?)
		return { Min = min, Max = max or min }
	end,
}

-- Enum members are only ever compared and passed through by the pure modules
-- under test, so each one resolves to a single stable table carrying its name.
-- Two references to the same member are the same value, which is all an
-- equality check or a lookup key needs.
local FakeEnum = setmetatable({}, {
	__index = function(enums, enumName: string)
		local members = setmetatable({}, {
			__index = function(self, memberName: string)
				local member = { Name = memberName, EnumType = enumName }
				rawset(self, memberName, member)
				return member
			end,
		})
		rawset(enums, enumName, members)
		return members
	end,
})

function Loader.build(sourcemapPath: string): (Node, (node: Node) -> any)
	local map: SourcemapEntry = serde.decode("json", fs.readFile(sourcemapPath))
	local moduleCache: { [Node]: any } = {}

	local function fullName(node: Node): string
		local parts = {}
		local current = node
		while current do
			table.insert(parts, 1, rawget(current, "Name"))
			current = rawget(current, "Parent")
		end
		return table.concat(parts, ".")
	end

	local nodeMeta = {}
	nodeMeta.__index = function(self: Node, key: string): any
		local child = rawget(self, "_children")[key]
		if child then
			return child
		end
		if key == "FindFirstChild" or key == "WaitForChild" or key == "GetService" then
			return function(node: Node, name: string)
				local found = rawget(node, "_children")[name]
				if key == "WaitForChild" and found == nil then
					error(`WaitForChild: no child "{name}" under {fullName(node)}`)
				end
				return found
			end
		end
		if key == "GetChildren" then
			return function(node: Node)
				local out = {}
				for _, c in rawget(node, "_children") do
					table.insert(out, c)
				end
				table.sort(out, function(a, b)
					return rawget(a, "Name") < rawget(b, "Name")
				end)
				return out
			end
		end
		if key == "IsA" then
			return function(node: Node, className: string)
				return rawget(node, "ClassName") == className
			end
		end
		return nil
	end
	nodeMeta.__tostring = fullName

	local function makeNode(entry: SourcemapEntry, parent: Node?): Node
		local node = setmetatable({
			Name = entry.name,
			ClassName = entry.className,
			Parent = parent,
			_children = {},
			_filePaths = entry.filePaths,
		}, nodeMeta)
		for _, childEntry in entry.children or {} do
			node._children[childEntry.name] = makeNode(childEntry, node)
		end
		return node
	end

	local root = makeNode(map, nil)

	local function moduleSourcePath(node: Node): string?
		for _, path in (rawget(node, "_filePaths") :: { string }?) or {} do
			if string.match(path, "%.luau$") or string.match(path, "%.lua$") then
				return path
			end
		end
		return nil
	end

	local function requireImpl(node: Node): any
		if type(node) ~= "table" or rawget(node, "ClassName") ~= "ModuleScript" then
			error(`require target is not a ModuleScript node: {tostring(node)}`)
		end
		if moduleCache[node] ~= nil then
			return moduleCache[node]
		end
		local path = moduleSourcePath(node)
		if path == nil then
			error(`no source file for module {fullName(node)}`)
		end
		local fn = luau.load(luau.compile(fs.readFile(path)), {
			debugName = fullName(node),
			environment = {
				script = node,
				require = requireImpl,
				vector = vector,
				CFrame = FakeCFrame,
				Color3 = FakeColor3,
				Vector3 = FakeVector3,
				Vector2 = FakeVector2,
				NumberRange = FakeNumberRange,
				Enum = FakeEnum,
			},
			injectGlobals = true,
		})
		local result = fn()
		if result == nil then
			error(`module {fullName(node)} returned nil`)
		end
		moduleCache[node] = result
		return result
	end

	return root, requireImpl
end

return Loader
