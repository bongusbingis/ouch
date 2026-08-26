-- Name: StoreCatalog.spec.luau
-- Author: Jack C.
-- Description: Spec that the storefront projection lists only enabled offers in deterministic order with stable tie breakers, keeps previews visible, and omits hidden offers.
-- Created: 2026-08-08

--!strict

local T = require(script.Parent.TestKit)
local StoreCatalog = require(script.Parent.Parent.Game.Economy.StoreCatalog)

T.describe("StoreCatalog", function()
	T.it("projects only enabled offers in deterministic configured order", function()
		local offers = StoreCatalog.build({
			LaterPass = {
				Id = 20,
				Enabled = true,
				DisplayName = "Later Pass",
				Description = "Later",
				DisplayOrder = 20,
			},
			HiddenPass = {
				Id = nil,
				Enabled = false,
				DisplayName = "Hidden",
				Description = "Hidden",
				DisplayOrder = 1,
			},
		}, {
			FirstProduct = {
				Id = 10,
				Enabled = true,
				DisplayName = "First Product",
				Description = "First",
				DisplayOrder = 10,
			},
		})

		T.expect(#offers):toEqual(2)
		T.expect(offers[1].key):toEqual("FirstProduct")
		T.expect(offers[1].kind):toEqual("Product")
		T.expect(offers[2].key):toEqual("LaterPass")
		T.expect(offers[2].kind):toEqual("GamePass")
	end)

	T.it("uses kind and key as stable tie breakers", function()
		local offers = StoreCatalog.build({
			Beta = {
				Id = 2,
				Enabled = true,
				DisplayName = "Beta",
				Description = "Beta",
				DisplayOrder = 10,
			},
			Alpha = {
				Id = 1,
				Enabled = true,
				DisplayName = "Alpha",
				Description = "Alpha",
				DisplayOrder = 10,
			},
		}, {
			Product = {
				Id = 3,
				Enabled = true,
				DisplayName = "Product",
				Description = "Product",
				DisplayOrder = 10,
			},
		})

		T.expect(offers[1].key):toEqual("Alpha")
		T.expect(offers[2].key):toEqual("Beta")
		T.expect(offers[3].key):toEqual("Product")
	end)
	T.it("keeps previews visible without ids and omits hidden offers", function()
		local offers = StoreCatalog.build({
			PreviewPass = {
				Id = nil,
				CatalogStatus = "Preview",
				DisplayName = "Preview",
				Description = "Preview",
				DisplayOrder = 1,
			},
			HiddenPass = {
				Id = nil,
				CatalogStatus = "Hidden",
				DisplayName = "Hidden",
				Description = "Hidden",
				DisplayOrder = 2,
			},
		}, {})
		T.expect(#offers):toEqual(1)
		T.expect(offers[1].key):toEqual("PreviewPass")
		T.expect(offers[1].status):toEqual("Preview")
		T.expect(offers[1].id):toBeNil()
	end)
end)

return true
