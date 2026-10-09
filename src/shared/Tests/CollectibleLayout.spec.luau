--!strict
local Test = require(script.Parent.TestKit)
local Layout = require(script.Parent.Parent.UI.Models.CollectibleLayout)
local T = require(script.Parent.Parent.UI.Tokens)

local K = T.Collectible

Test.describe("Collectible card face", function()
	Test.it("keeps art clear of the seam tag and the tag clear of the name on every Backpack size", function()
		for width = T.LobbyLandscape.InventoryCardMin, T.Layout.CardMax do
			local face = Layout.card(width, width + K.ExtraHeight - T.Shape.LipHeight, { tag = true, name = true })
			local tag = face.tag :: any
			local name = face.name :: any
			-- Art ends above the tag's top edge (art is relative to the well).
			Test.expect(face.well.y + face.art.y + face.art.h <= tag.y):toBeTruthy()
			Test.expect(tag.y + tag.h <= name.y):toBeTruthy()
			Test.expect(name.y + name.h <= width + K.ExtraHeight - T.Shape.LipHeight):toBeTruthy()
			Test.expect(face.art.h >= 60):toBeTruthy()
			-- The widest tier label at the minimum type size fits inside the window.
			Test.expect(tag.maxWidth >= 110):toBeTruthy()
		end
	end)
	Test.it("reserves a corner chip row above the art and a footer below the name", function()
		local face = Layout.card(200, 264, { tag = true, name = true, footer = true, corner = true })
		local corner = face.corner :: any
		local footer = face.footer :: any
		local name = face.name :: any
		Test.expect(face.art.y >= corner.y + corner.h):toBeTruthy()
		Test.expect(footer.y):toEqual(name.y + name.h)
		Test.expect(footer.y + footer.h <= 264):toBeTruthy()
	end)
	Test.it("gives a nameless hero card bottom breathing room under the tag", function()
		local face = Layout.card(240, 240, { tag = true })
		local tag = face.tag :: any
		Test.expect(face.name):toBeNil()
		Test.expect(tag.y + tag.h <= 240):toBeTruthy()
		Test.expect(240 - (tag.y + tag.h) >= K.Pad - 1):toBeTruthy()
	end)
	Test.it("gives a one-line name grid its second line back", function()
		Test.expect(Layout.cardHeight(200)):toEqual(200 + K.ExtraHeight)
		Test.expect(Layout.cardHeight(200, 26)):toEqual(200 + K.ExtraHeight - (K.NameHeight - 26))
	end)
	Test.it("drops Default and redundant kind suffixes from CAPS card labels", function()
		Test.expect(Layout.label({ displayName = "Default Ball", category = "BallAssets" })):toEqual("BALL")
		Test.expect(Layout.label({ displayName = "Aqua Glaze Hammer", category = "HammerAssets" }))
			:toEqual("AQUA GLAZE")
		Test.expect(Layout.label({ displayName = "Confetti Twirl", category = "EmoteAssets" }))
			:toEqual("CONFETTI TWIRL")
	end)
	Test.it("snaps a Backpack grid so the first screen never ends inside a row's names", function()
		local lip = T.Shape.LipHeight
		for _, width in { 300, 414, 452, 716 } do
			for _, nameHeight in { 26, 48, 58 } do
				for visible = 180, 720, 3 do
					local spec = {
						width = width,
						visible = visible,
						top = 70,
						minimum = 150,
						maximum = 232,
						gap = 18,
						maxColumns = 3,
						nameHeight = nameHeight,
						lip = lip,
					}
					local grid = Layout.grid(spec)
					Test.expect(grid.height):toEqual(Layout.cardHeight(grid.size, nameHeight))
					Test.expect(grid.size <= 232):toBeTruthy()
					Test.expect(grid.size >= math.min(150, width)):toBeTruthy()
					-- Columns and the cell still fit the width.
					Test.expect(grid.columns * grid.size + (grid.columns - 1) * 18 <= width):toBeTruthy()
					-- Whenever the cards shrank, the row that was cut now fits whole.
					local base = Layout.grid({
						width = width,
						visible = 100000,
						top = 0,
						minimum = 150,
						maximum = 232,
						gap = 18,
						maxColumns = 3,
						nameHeight = nameHeight,
						lip = lip,
					})
					if grid.size < base.size then
						local available = visible - 70
						local full = math.floor((available + 18) / (grid.height + 18))
						local shown = available - full * (grid.height + 18)
						local face = Layout.card(
							grid.size,
							grid.height - lip,
							{ tag = true, name = true, nameHeight = nameHeight }
						)
						Test.expect(shown <= (face.name :: any).y - K.Pad or shown >= grid.height):toBeTruthy()
						Test.expect(grid.size >= math.floor(base.size * 0.85)):toBeTruthy()
					end
				end
			end
		end
	end)
	Test.it("fits one full Backpack row on the compact desktop well instead of cutting its names", function()
		-- 838x667 desktop: a 2-column, two-line-name card (222 tall) would end 5 px below the window.
		local grid = Layout.grid({
			width = 414,
			visible = 287,
			top = 70,
			minimum = 150,
			maximum = 232,
			gap = 18,
			maxColumns = 3,
			nameHeight = K.NameHeight,
			lip = T.Shape.LipHeight,
		})
		Test.expect(grid.columns):toEqual(2)
		Test.expect(grid.height <= 287 - 70):toBeTruthy()
		Test.expect(grid.size >= 180):toBeTruthy()
	end)
end)

return true
