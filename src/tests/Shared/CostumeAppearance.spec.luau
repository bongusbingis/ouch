--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cosmetics = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Cosmetics"):WaitForChild("Cosmetics"))
local Appearance = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CharacterAppearance")
)
local EmoteRig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Services"):WaitForChild("EmoteRig")
)
local CostumeVisualFactory = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Cosmetics")
		:WaitForChild("CostumeVisualFactory")
)
local TestAssets = require(script.Parent.Parent.Helpers.TestAssets)
local CharacterFixture = require(script.Parent.Parent.Helpers.CharacterFixture)

return function()
	describe("Shared costume assets and appearance", function()
		local roots, displays = {}, {}
		afterEach(function()
			for _, display in displays do
				display.destroy()
			end
			for _, root in roots do
				root:Destroy()
			end
			table.clear(roots)
			table.clear(displays)
		end)

		it("mounts every complete authored outfit on the unchanged victory attachment graph", function()
			local rigTemplate = TestAssets.get(ReplicatedStorage, "Assets", "Rigs", "CharacterRig")
			for itemId, item in Cosmetics.Items do
				if not item.Contents then
					continue
				end
				local covered = {}
				for _, componentId in item.Contents do
					local template = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", "Costumes", componentId)
					expect(template:IsA("Model")).to.equal(true)
					for _, part in template:GetDescendants() do
						if part:IsA("BasePart") then
							local target = TestAssets.get(rigTemplate, part:GetAttribute("BodyPart"))
							expect(part:GetAttribute("BodySize")).to.equal(target.Size)
							if part:GetAttribute("CoversBody") then
								expect(covered[target.Name]).to.equal(nil)
								expect(part:IsA("MeshPart")).to.equal(true)
								expect(part.MeshId).to.equal(target.MeshId)
								expect(part.Size).to.equal(target.Size)
								expect(part.BodyMount.Position.Magnitude < 0.001).to.equal(true)
								covered[target.Name] = true
							end
						end
					end
				end
				if item.Coverage == "Replace" then
					for _, name in CostumeVisualFactory.CoveredBody do
						expect(covered[name]).to.equal(true)
					end
				else
					expect(item.Coverage).to.equal("Layer")
					expect(next(covered)).to.equal(nil)
				end
				local world = Instance.new("WorldModel")
				table.insert(roots, world)
				local display = EmoteRig.create(world, "CharacterColorRed", itemId)
				table.insert(displays, display)
				for _, part in display.model.CostumeVisuals:GetDescendants() do
					if not part:IsA("BasePart") then
						continue
					end
					local target = display.model[part:GetAttribute("BodyPart")]
					expect((part.BodyMount.WorldCFrame.Position - target.Position).Magnitude < 0.001).to.equal(true)
					expect(part.Massless).to.equal(true)
					expect(part.CanCollide or part.CanQuery or part.CanTouch).to.equal(false)
				end
				display.destroy()
				expect(#world:GetChildren()).to.equal(0)
			end
		end)

		it("preserves authored clothing color and body behavior across live replacements", function()
			local rig = TestAssets.get(ReplicatedStorage, "Assets", "Rigs", "CharacterRig"):Clone()
			table.insert(roots, rig)
			local rootFrame = rig.HumanoidRootPart.CFrame
			local speed = rig.Humanoid.WalkSpeed
			local display = Appearance.create(rig, { costumeId = "FoamLeague" }, { live = true })
			table.insert(displays, display)
			local colors = {}
			for _, part in rig.CostumeVisuals:GetDescendants() do
				if part:IsA("BasePart") then
					colors[part] = part.Color
					expect(part.Anchored).to.equal(false)
					expect(part.CostumeMount.Part0).to.equal(rig[part:GetAttribute("BodyPart")])
				end
			end
			display.update({ costumeId = "FoamLeague", characterColorId = "CharacterColorPurple" })
			for part, color in colors do
				expect(part.Color).to.equal(color)
			end
			expect(rig.Head.Color).to.equal(Cosmetics.Items.CharacterColorPurple.PreviewColor)
			local head = rig.Head
			head.Parent = nil
			display.updateMounts()
			for part in colors do
				if part:GetAttribute("BodyPart") == "Head" then
					expect(part.Transparency).to.equal(1)
					expect(part.CostumeMount.Part0).to.equal(nil)
				end
			end
			head.Parent = rig
			display.updateMounts()
			for part in colors do
				if part:GetAttribute("BodyPart") == "Head" then
					expect(part.Transparency < 1).to.equal(true)
					expect(part.CostumeMount.Part0).to.equal(head)
				end
			end
			display.update({ costumeId = "RainHopper" })
			local count = 0
			for _, child in rig:GetChildren() do
				if child.Name == "CostumeVisuals" then
					count += 1
				end
			end
			expect(count).to.equal(1)
			display.update({})
			expect(rig:FindFirstChild("CostumeVisuals")).to.equal(nil)
			expect(rig.HumanoidRootPart.CFrame).to.equal(rootFrame)
			expect(rig.Humanoid.WalkSpeed).to.equal(speed)
		end)

		it("fits the actual loaded blob size and follows later body-size changes without moving the rig", function()
			local rig = CharacterFixture.createBlob()
			table.insert(roots, rig)
			local rootFrame = rig.HumanoidRootPart.CFrame
			local bodySize = rig.Head.Size
			local display = Appearance.create(rig, {}, { live = true })
			table.insert(displays, display)
			local rigTemplate = TestAssets.get(ReplicatedStorage, "Assets", "Rigs", "CharacterRig")
			for itemId, item in Cosmetics.Items do
				if not item.Contents then
					continue
				end
				display.update({ costumeId = itemId })
				for _, component in rig.CostumeVisuals:GetChildren() do
					local source = TestAssets.get(ReplicatedStorage, "Assets", "Cosmetics", "Costumes", component.Name)
					for _, part in component:GetDescendants() do
						if not part:IsA("BasePart") then
							continue
						end
						local authored = TestAssets.get(source, part.Name)
						local target = rig[part:GetAttribute("BodyPart")]
						local reference = rigTemplate[target.Name]
						local scale = target.Size.X / reference.Size.X
						expect((part.Size - authored.Size * scale).Magnitude < 0.0001).to.equal(true)
						local offset = authored.BodyMount.CFrame:Inverse()
						local position = target.CFrame:PointToObjectSpace(part.Position)
						expect((position - offset.Position * scale).Magnitude < 0.001).to.equal(true)
						expect((part.BodyMount.WorldCFrame.Position - target.Position).Magnitude < 0.001).to.equal(true)
					end
				end
			end
			display.update({ costumeId = "FoamLeague" })
			local previous, meshScales = {}, {}
			for _, part in rig.CostumeVisuals:GetDescendants() do
				if part:IsA("BasePart") then
					previous[part] = part.Size
				elseif part:IsA("SpecialMesh") then
					meshScales[part] = part.Scale
				end
			end
			rig.Head.Size = bodySize * 1.25
			task.wait()
			for part, size in previous do
				local scale = if part:GetAttribute("BodyPart") == "Head" then 1.25 else 1
				expect((part.Size - size * scale).Magnitude < 0.0001).to.equal(true)
				expect(part.CostumeMount.Part0).to.equal(rig[part:GetAttribute("BodyPart")])
			end
			for mesh, scale in meshScales do
				expect(mesh.Scale).to.equal(scale)
			end
			expect(rig.HumanoidRootPart.CFrame).to.equal(rootFrame)
			display.destroy()
			rig.Head.Size = bodySize
			task.wait()
			expect(rig:FindFirstChild("CostumeVisuals")).to.equal(nil)
		end)

		it("restores covered body transparency across swaps, missing targets and replacements", function()
			local rig = TestAssets.get(ReplicatedStorage, "Assets", "Rigs", "CharacterRig"):Clone()
			table.insert(roots, rig)
			local original = rig.UpperTorso
			original.Transparency = 0.4
			rig.LowerTorso.Transparency = 0.2
			local upperTransparency, lowerTransparency = original.Transparency, rig.LowerTorso.Transparency
			local display = Appearance.create(rig, { costumeId = "FoamLeague" }, { live = true })
			table.insert(displays, display)
			expect(original.Transparency).to.equal(1)
			expect(rig.LowerTorso.Transparency).to.equal(1)
			display.update({ costumeId = "RainHopper" })
			expect(original.Transparency).to.equal(1)
			display.update({})
			expect(original.Transparency).to.equal(upperTransparency)
			expect(rig.LowerTorso.Transparency).to.equal(lowerTransparency)
			display.update({ costumeId = "FoamLeague" })
			original.Parent = nil
			table.insert(roots, original)
			display.updateMounts()
			expect(original.Transparency).to.equal(upperTransparency)
			for _, part in rig.CostumeVisuals:GetDescendants() do
				if part:IsA("BasePart") and part:GetAttribute("BodyPart") == "UpperTorso" then
					expect(part.Transparency).to.equal(1)
					expect(part.CostumeMount.Part0).to.equal(nil)
				end
			end
			local replacement = original:Clone()
			replacement.Transparency = 0.35
			local replacementTransparency = replacement.Transparency
			replacement.Parent = rig
			display.updateMounts()
			expect(replacement.Transparency).to.equal(1)
			replacement.Size *= 1.1
			task.wait()
			for _, part in rig.CostumeVisuals:GetDescendants() do
				if part:IsA("BasePart") and part:GetAttribute("BodyPart") == "UpperTorso" then
					expect(part.CostumeMount.Part0).to.equal(replacement)
					if part:GetAttribute("CoversBody") then
						expect((part.Size - replacement.Size).Magnitude < 0.0001).to.equal(true)
					end
				end
			end
			display.destroy()
			expect(original.Transparency).to.equal(upperTransparency)
			expect(replacement.Transparency).to.equal(replacementTransparency)
			expect(rig.LowerTorso.Transparency).to.equal(lowerTransparency)
		end)
	end)
end
