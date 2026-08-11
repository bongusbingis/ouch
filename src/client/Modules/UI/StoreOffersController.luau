--!strict

-- Compatibility import for callers that have not moved to ShopController.
-- ShopController is the storefront's only state owner.

return require(script.Parent.ShopController)
