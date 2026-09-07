--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Cosmetics = ReplicatedStorage.Shared.Game.Cosmetics
local Factory = require(Cosmetics.CosmeticEffectFactory)
local ScriptEffects = require(Cosmetics.Effects.ScriptEffects)
local Runtime = require(Cosmetics.Effects.Runtime)
local Primitives = require(Cosmetics.Effects.Primitives)
local EffectConfig = require(ReplicatedStorage.Config.Cosmetics.CosmeticEffects)

return function()
	describe("Cosmetic effect playback results", function()
		local originalGet, injected, parent, otherParent, scope, otherScope
		beforeEach(function()
			injected = {}
			originalGet = ScriptEffects.get
			ScriptEffects.get = function(id)
				return injected[id] or originalGet(id)
			end
			parent = Instance.new("Folder")
			parent.Name = "EffectResultTest"
			parent.Parent = Workspace
			otherParent = Instance.new("Folder")
			otherParent.Name = "OtherEffectResultTest"
			otherParent.Parent = Workspace
			scope = Runtime.createScope(parent)
			otherScope = Runtime.createScope(otherParent)
		end)
		afterEach(function()
			ScriptEffects.get = originalGet
			Runtime.destroyScope(scope)
			Runtime.destroyScope(otherScope)
			parent:Destroy()
			otherParent:Destroy()
		end)

		it("reports success only when the resolved requested effect plays", function()
			local played = 0
			injected.ResultTest = {
				play = function()
					played += 1
				end,
			}
			local succeeded, err = Factory.play("Impact", "ResultTest", { position = Vector3.zero, scope = scope })
			expect(succeeded).to.equal(true)
			expect(err).to.equal(nil)
			expect(played).to.equal(1)
		end)

		it("reports the selected failure while retaining gameplay fallback and isolated cleanup", function()
			local fallbackCount = 0
			injected.ResultTest = {
				play = function(context)
					Primitives.part("Partial", Color3.new(1, 1, 1), Vector3.one, CFrame.identity, nil, context.scope)
					error("selected effect fixture failed", 0)
				end,
			}
			injected[EffectConfig.Categories.Impact.DefaultEffectId] = {
				play = function(context)
					fallbackCount += 1
					Primitives.part("Fallback", Color3.new(1, 1, 1), Vector3.one, CFrame.identity, nil, context.scope)
				end,
			}
			local other = Primitives.part("Other", Color3.new(1, 1, 1), Vector3.one, CFrame.identity, nil, otherScope)
			local succeeded, err = Factory.play("Impact", "ResultTest", { position = Vector3.zero, scope = scope })
			expect(succeeded).to.equal(false)
			expect(err).to.equal("selected effect fixture failed")
			expect(fallbackCount).to.equal(1)
			expect(#parent:GetChildren()).to.equal(2)
			Runtime.destroyScope(scope)
			expect(#parent:GetChildren()).to.equal(0)
			expect(next(scope.roots)).to.equal(nil)
			expect(other.Parent).to.equal(otherParent)
		end)

		it("preserves the requested error when the fallback also fails", function()
			local fallbackCount = 0
			injected.ResultTest = {
				play = function()
					error("selected effect fixture failed", 0)
				end,
			}
			injected[EffectConfig.Categories.Impact.DefaultEffectId] = {
				play = function()
					fallbackCount += 1
					error("fallback fixture failed", 0)
				end,
			}
			local succeeded, err = Factory.play("Impact", "ResultTest", { position = Vector3.zero, scope = scope })
			expect(succeeded).to.equal(false)
			expect(err).to.equal("selected effect fixture failed")
			expect(fallbackCount).to.equal(1)
		end)

		it("rejects a canceled scope before either selected or fallback playback", function()
			local played = 0
			injected.ResultTest = {
				play = function()
					played += 1
				end,
			}
			Runtime.destroyScope(scope)
			local succeeded, err = Factory.play("Impact", "ResultTest", { position = Vector3.zero, scope = scope })
			expect(succeeded).to.equal(false)
			expect(err).to.equal("effect scope is closed")
			expect(played).to.equal(0)
			expect(#parent:GetChildren()).to.equal(0)
		end)
	end)
end
