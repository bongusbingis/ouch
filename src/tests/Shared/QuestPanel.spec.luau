-- The rendered claim callback must use the server's public quest identity.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestLogic = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Game"):WaitForChild("Quests"):WaitForChild("QuestLogic")
)
local Packages = ReplicatedStorage:WaitForChild("Packages")
local React = require(Packages:WaitForChild("react"))
local ReactRoblox = require(Packages:WaitForChild("react-roblox"))
local Quests = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Progression"):WaitForChild("Quests"))
local Panel = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Components"):WaitForChild("QuestsPanel")
)

-- Panel and QuestRow use hooks, so they may only be invoked while React renders. This mounts a
-- probe component that evaluates `produce` during a real render and returns its element tree.
local function renderOnce(produce: () -> any): any
	local host = Instance.new("Folder")
	host.Name = "QuestPanelSpecHost"
	host.Parent = ReplicatedStorage
	local root = ReactRoblox.createRoot(host)
	local captured = nil
	local function Probe()
		captured = produce()
		return nil
	end
	root:render(React.createElement(Probe))
	local deadline = os.clock() + 3
	while captured == nil and os.clock() < deadline do
		task.wait()
	end
	root:unmount()
	host:Destroy()
	return captured
end

return function()
	describe("Quest panel contract", function()
		it("claims the public quest ID and projects its pending state", function()
			local definition = Quests.Definitions[1]
			local quest = QuestLogic.publicQuest(definition, { progress = definition.goal, claimed = false }, 1)
			local received = nil
			local element = renderOnce(function()
				return Panel({
					State = { quests = { quest } },
					PendingClaims = { [quest.questId] = true },
					OnClaim = function(id)
						received = id
					end,
				})
			end)
			expect(element).to.be.ok()
			local row = element.props.children.QuestList.props.children.Quest1
			expect(row.props.Pending).to.equal(true)
			local rendered = renderOnce(function()
				return row.type(row.props)
			end)
			expect(rendered).to.be.ok()
			local button = rendered.props.children.RightSection.props.children.ClaimButton
			expect(button.props.Enabled).to.equal(false)
			button.props.OnActivated()
			expect(received).to.equal(definition.id)
		end)
	end)
end
