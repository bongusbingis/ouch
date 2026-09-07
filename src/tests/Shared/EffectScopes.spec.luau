--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Effects =
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Cosmetics"):WaitForChild("Effects")
local Runtime = require(Effects.Runtime)
local Primitives = require(Effects.Primitives)
local ParticleKit = require(Effects.ParticleKit)

return function()
	describe("Effect render scopes", function()
		local first, second, firstScope, secondScope, worldPart
		beforeEach(function()
			first = Instance.new("Folder")
			first.Name = "EffectScopeTest"
			first.Parent = Workspace
			second = Instance.new("Folder")
			second.Name = "OtherEffectScopeTest"
			second.Parent = Workspace
			firstScope = Runtime.createScope(first, function()
				return CFrame.Angles(0, math.pi / 2, 0)
			end)
			secondScope = Runtime.createScope(second)
		end)
		afterEach(function()
			Runtime.destroyScope(firstScope)
			Runtime.destroyScope(secondScope)
			first:Destroy()
			second:Destroy()
			if worldPart then
				worldPart:Destroy()
				worldPart = nil
			end
		end)

		it("cancels only its own geometry and leaves gameplay and another scope intact", function()
			local part = Primitives.part("Preview", Color3.new(1, 1, 1), Vector3.one, CFrame.identity, nil, firstScope)
			local other = Primitives.part("Other", Color3.new(1, 1, 1), Vector3.one, CFrame.identity, nil, secondScope)
			worldPart = Primitives.part("Gameplay", Color3.new(1, 1, 1), Vector3.one, CFrame.identity)
			Runtime.destroyScope(firstScope)
			Runtime.destroyScope(firstScope)
			expect(part.Parent).to.equal(nil)
			expect(other.Parent).to.equal(second)
			expect(worldPart.Parent).to.equal(Runtime.container())
		end)

		it("tracks particle-only anchors and prevents playback into a canceled scope", function()
			local definition = { emitters = { { Texture = "rbxassetid://243660364", EmitCount = 1 } } }
			ParticleKit.play(definition, { position = Vector3.zero, scope = firstScope })
			expect(#first:GetChildren()).to.equal(1)
			Runtime.destroyScope(firstScope)
			expect(#first:GetChildren()).to.equal(0)
			ParticleKit.play(definition, { position = Vector3.zero, scope = firstScope })
			expect(#first:GetChildren()).to.equal(0)
		end)

		it("destroys nested bubble pieces and beam attachments without orphaned roots", function()
			Primitives.bubble("Bubble", Color3.new(1, 1, 1), Vector3.zero, 2, firstScope)
			Primitives.ribbon("Ribbon", Color3.new(1, 1, 1), Vector3.zero, 1, firstScope)
			Runtime.destroyScope(firstScope)
			expect(#first:GetDescendants()).to.equal(0)
			expect(next(firstScope.roots)).to.equal(nil)
		end)

		it("uses the scope camera basis without replacing the world camera", function()
			local current = Workspace.CurrentCamera
			expect(
				(Primitives.cameraRight(firstScope) - CFrame.Angles(0, math.pi / 2, 0).RightVector).Magnitude < 0.001
			).to.equal(true)
			expect(Workspace.CurrentCamera).to.equal(current)
		end)
	end)
end
