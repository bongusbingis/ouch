--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Cosmetics = ReplicatedStorage.Shared.Game.Cosmetics
local Factory = require(Cosmetics.CosmeticEffectFactory)
local ScriptEffects = require(Cosmetics.Effects.ScriptEffects)
local Runtime = require(Cosmetics.Effects.Runtime)
local Primitives = require(Cosmetics.Effects.Primitives)
local EffectConfig =
	require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("CosmeticEffects"))

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

		it("cleans a classified selected failure before playing the default", function()
			local fallbackCount = 0
			injected.ResultTest = {
				play = function(context)
					Primitives.part("Partial", Color3.new(1, 1, 1), Vector3.one, CFrame.identity, nil, context.scope)
					return false, "selected effect fixture failed"
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
			expect(#parent:GetChildren()).to.equal(1)
			expect(parent:FindFirstChild("Partial")).to.equal(nil)
			Runtime.destroyScope(scope)
			expect(#parent:GetChildren()).to.equal(0)
			expect(next(scope.roots)).to.equal(nil)
			expect(other.Parent).to.equal(otherParent)
		end)

		it("does not turn an unexpected selected assertion into fallback", function()
			local fallbackCount = 0
			injected.ResultTest = {
				play = function(context)
					Primitives.part("Partial", Color3.new(1, 1, 1), Vector3.one, CFrame.identity, nil, context.scope)
					error("selected effect assertion", 0)
				end,
			}
			injected[EffectConfig.Categories.Impact.DefaultEffectId] = {
				play = function()
					fallbackCount += 1
				end,
			}
			local ok, err = pcall(Factory.play, "Impact", "ResultTest", { position = Vector3.zero, scope = scope })
			expect(ok).to.equal(false)
			expect(string.find(tostring(err), "selected effect assertion", 1, true) ~= nil).to.equal(true)
			expect(fallbackCount).to.equal(0)
			expect(#parent:GetChildren()).to.equal(0)
		end)

		it("preserves the requested result when the default also fails", function()
			local fallbackCount = 0
			injected.ResultTest = {
				play = function()
					return false, "selected effect fixture failed"
				end,
			}
			injected[EffectConfig.Categories.Impact.DefaultEffectId] = {
				play = function()
					fallbackCount += 1
					return false, "fallback fixture failed"
				end,
			}
			local succeeded, err = Factory.play("Impact", "ResultTest", { position = Vector3.zero, scope = scope })
			expect(succeeded).to.equal(false)
			expect(err).to.equal("selected effect fixture failed")
			expect(fallbackCount).to.equal(1)
		end)

		it("does not retry a failed direct default", function()
			local calls = 0
			injected[EffectConfig.Categories.Impact.DefaultEffectId] = {
				play = function()
					calls += 1
					return false, "direct default fixture failed"
				end,
			}
			local succeeded, reason = Factory.play("Impact", nil, { position = Vector3.zero, scope = scope })
			expect(succeeded).to.equal(false)
			expect(reason).to.equal("direct default fixture failed")
			expect(calls).to.equal(1)
		end)

		it("adopts successful roots into the preview scope", function()
			injected.ResultTest = {
				play = function(context)
					Primitives.part("Adopted", Color3.new(1, 1, 1), Vector3.one, CFrame.identity, nil, context.scope)
				end,
			}
			local succeeded = Factory.play("Impact", "ResultTest", { position = Vector3.zero, scope = scope })
			expect(succeeded).to.equal(true)
			expect(parent:FindFirstChild("Adopted")).to.be.ok()
			Runtime.destroyScope(scope)
			expect(parent:FindFirstChild("Adopted")).to.equal(nil)
		end)

		it("rejects malformed category configuration before activating a cue", function()
			local category = EffectConfig.Categories.Impact
			local original = category.DefaultEmitCount
			local played = 0
			injected.ResultTest = {
				play = function()
					played += 1
				end,
			}
			category.DefaultEmitCount = "bad"
			local ok, err = pcall(Factory.play, "Impact", "ResultTest", { position = Vector3.zero, scope = scope })
			category.DefaultEmitCount = original
			expect(ok).to.equal(false)
			expect(
				string.find(
					tostring(err),
					"Config.Cosmetics.CosmeticEffects.Categories.Impact.DefaultEmitCount",
					1,
					true
				) ~= nil
			).to.equal(true)
			expect(played).to.equal(0)
		end)

		it("preserves the owner Hero budget and evicts its lower layer only after adoption", function()
			local function animatedPart(name, owner, layer)
				local part = Instance.new("Part")
				part.Name = name
				Runtime.mount(part, owner)
				expect(Runtime.add(part, 3600, function() end, { layer = layer })).to.equal(true)
				return part
			end
			local oldTertiary = animatedPart("OldTertiary", scope, "Tertiary")
			for index = 1, 319 do
				animatedPart(`ExistingHero{index}`, scope, "Hero")
			end
			local failAttempt = true
			injected.ResultTest = {
				play = function(context)
					animatedPart("NewHero", context.scope, "Hero")
					if failAttempt then
						return false, "synthetic playback failure"
					end
				end,
			}
			injected[EffectConfig.Categories.Impact.DefaultEffectId] = { play = function() end }
			local firstOk = Factory.play("Impact", "ResultTest", { position = Vector3.zero, scope = scope })
			expect(firstOk).to.equal(false)
			expect(oldTertiary.Parent).to.equal(parent)
			expect(parent:FindFirstChild("NewHero")).to.equal(nil)
			failAttempt = false
			local secondOk = Factory.play("Impact", "ResultTest", { position = Vector3.zero, scope = scope })
			expect(secondOk).to.equal(true)
			expect(oldTertiary.Parent).to.equal(nil)
			expect(parent:FindFirstChild("NewHero")).to.be.ok()
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
