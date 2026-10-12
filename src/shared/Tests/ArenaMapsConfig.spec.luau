-- Description: Spec that the arena map ballot configuration is internally consistent: a valid default, unique ids, templates and sort orders, short uppercase labels, well-formed thumbnails, real accent colors, and a sorted enabled-only order.

--!strict

local T = require(script.Parent.TestKit)
local ArenaMaps = require(script.Parent.Parent.Parent.Config.Gameplay.ArenaMaps)
local Tokens = require(script.Parent.Parent.UI.Tokens)

T.describe("ArenaMaps config", function()
	T.it("names an enabled default map", function()
		local default = ArenaMaps.Maps[ArenaMaps.DefaultMapId]
		T.expect(default ~= nil):toBeTruthy()
		T.expect(default.Enabled):toBeTruthy()
	end)

	T.it("keeps ids, templates and sort orders unique and ids within the vote limit", function()
		local templates: { [string]: boolean } = {}
		local orders: { [number]: boolean } = {}
		for mapId, definition in ArenaMaps.Maps do
			T.expect(#mapId >= 1 and #mapId <= 32):toBeTruthy()
			T.expect(templates[definition.Template] == nil):toBeTruthy()
			T.expect(orders[definition.SortOrder] == nil):toBeTruthy()
			templates[definition.Template] = true
			orders[definition.SortOrder] = true
		end
	end)

	T.it("keeps labels short and uppercase", function()
		for _, definition in ArenaMaps.Maps do
			T.expect(definition.DisplayName == string.upper(definition.DisplayName)):toBeTruthy()
			T.expect(#definition.DisplayName <= 16):toBeTruthy()
			T.expect(#definition.ShortName >= 1 and #definition.ShortName <= 6):toBeTruthy()
		end
	end)

	T.it("uses empty or rbxassetid thumbnails", function()
		for _, definition in ArenaMaps.Maps do
			local id: string = definition.ThumbnailId
			T.expect(id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil):toBeTruthy()
		end
	end)

	T.it("accents with a real token color", function()
		for _, definition in ArenaMaps.Maps do
			T.expect((Tokens.Colors :: any)[definition.Accent] ~= nil):toBeTruthy()
		end
	end)

	T.it("orders only enabled maps by sort order", function()
		local enabled = 0
		for _, definition in ArenaMaps.Maps do
			if definition.Enabled then
				enabled += 1
			end
		end
		T.expect(#ArenaMaps.Order):toEqual(enabled)
		local previous = -math.huge
		for _, mapId in ArenaMaps.Order do
			local definition = ArenaMaps.Maps[mapId]
			T.expect(definition.Enabled):toBeTruthy()
			T.expect(definition.SortOrder > previous):toBeTruthy()
			previous = definition.SortOrder
		end
	end)
end)

return true
