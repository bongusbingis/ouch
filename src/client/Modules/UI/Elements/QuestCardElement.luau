--!strict

local ElementFactory = require(script.Parent.ElementFactory)
local ElementTypes = require(script.Parent.ElementTypes)
local ButtonElement = require(script.Parent.ButtonElement)

type QuestCardData = ElementTypes.QuestCardData
type QuestCardProps = ElementTypes.QuestCardProps
type QuestCardHandle = ElementTypes.QuestCardHandle
type ColorValue = ElementTypes.ColorValue

type MountOptions = {
	template: GuiObject?,
	buttonElement: any?,
	buttonOptions: any?,
	config: any?,
}

local QuestCardElement = {}

local function resolveTemplate(): GuiObject
	return ElementFactory.resolveTemplate("QuestCard", "GuiObject") :: GuiObject
end

local function resolveConfig(options: MountOptions?): any
	if options and options.config then
		return options.config
	end
	local replicatedStorage = game:GetService("ReplicatedStorage")
	return require(replicatedStorage:WaitForChild("Config"):WaitForChild("Quests"))
end

local function waitText(parent: Instance, name: string): TextLabel
	local child = parent:WaitForChild(name)
	assert(child:IsA("TextLabel"), `[QuestCardElement] QuestCard.{name} must be a TextLabel`)
	return child
end

local function waitGui(parent: Instance, name: string): GuiObject
	local child = parent:WaitForChild(name)
	assert(child:IsA("GuiObject"), `[QuestCardElement] QuestCard.{name} must be a GuiObject`)
	return child
end

local function waitGradient(progress: Instance): UIGradient
	local gradient = progress:WaitForChild("UIGradient")
	assert(gradient:IsA("UIGradient"), "[QuestCardElement] QuestCard.Progress.UIGradient must be a UIGradient")
	return gradient
end

local function collectDividers(progress: Instance): { Frame }
	local dividers = {}
	for _, child in progress:GetChildren() do
		if child:IsA("Frame") then
			table.insert(dividers, child :: Frame)
		end
	end
	table.sort(dividers, function(left, right)
		return left.Position.X.Scale < right.Position.X.Scale
	end)
	assert(#dividers > 0, "[QuestCardElement] QuestCard.Progress must include at least one divider Frame")
	return dividers
end

local function positionFor(index: number, steps: number): UDim2
	if UDim2 == nil then
		return ({
			X = { Scale = index / steps, Offset = 0 },
			Y = { Scale = 0.5, Offset = 0 },
		} :: any) :: UDim2
	end
	return UDim2.fromScale(index / steps, 0.5)
end

local function vector2(x: number, y: number): Vector2
	if Vector2 == nil then
		return ({ X = x, Y = y } :: any) :: Vector2
	end
	return Vector2.new(x, y)
end

local function scalePosition(x: number, y: number): UDim2
	if UDim2 == nil then
		return ({
			X = { Scale = x, Offset = 0 },
			Y = { Scale = y, Offset = 0 },
		} :: any) :: UDim2
	end
	return UDim2.fromScale(x, y)
end

local function visualFillRatio(data: QuestCardData): number
	return math.clamp(data.progress / math.max(data.goal, 1), 0, 1)
end

local function visualSteps(data: QuestCardData, config): number
	local maxSteps = math.max(math.floor(config.Progress.MaxSteps or 5), 1)
	return math.clamp(math.floor(data.steps), 1, maxSteps)
end

local function setGradientFill(gradient: UIGradient, ratio: number, fillColor: Color3, emptyColor: Color3)
	local clamped = math.clamp(ratio, 0, 1)
	gradient.Offset = vector2(clamped - 0.5, 0)
	if ColorSequence == nil or typeof(fillColor) ~= "Color3" or typeof(emptyColor) ~= "Color3" then
		local gradientAny = gradient :: any
		gradientAny.FillRatio = clamped
		gradientAny.GradientStop = 0.5
		return
	end
	if clamped <= 0 then
		gradient.Color = ColorSequence.new(emptyColor)
	elseif clamped >= 1 then
		gradient.Color = ColorSequence.new(fillColor)
	else
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, fillColor),
			ColorSequenceKeypoint.new(0.4995, fillColor),
			ColorSequenceKeypoint.new(0.5005, emptyColor),
			ColorSequenceKeypoint.new(1, emptyColor),
		})
	end
end

local function rewardText(data: QuestCardData): string
	if data.claimed then
		return "Claimed"
	end
	return "Claim"
end

local function rewardLabelText(data: QuestCardData): string
	local reward = data.reward
	if reward.kind == "Cash" and reward.amount then
		return `{reward.amount} coins`
	end
	if reward.amount then
		return `{reward.amount} {string.lower(reward.kind)}`
	end
	if reward.itemId then
		return reward.itemId
	end
	return "Reward"
end

local function buttonColor(data: QuestCardData, config): ColorValue
	if data.claimed then
		return config.Button.ClaimedColor
	end
	if data.completed then
		return config.Button.EnabledColor
	end
	return config.Button.DisabledColor
end

local function positionButton(button: ImageButton, config)
	button.AnchorPoint = vector2(1, 1)
	button.Position = scalePosition(config.Button.Position.x, config.Button.Position.y)
	button.Size = scalePosition(config.Button.Size.x, config.Button.Size.y)
end

function QuestCardElement.mount(parent: Instance, props: QuestCardProps, options: MountOptions?): QuestCardHandle
	local template = if options and options.template then options.template else resolveTemplate()
	local card, handle = ElementFactory.cloneMount(template, parent)
	card.Visible = true
	local title = waitText(card, "Title")
	local count = waitText(card, "Count")
	local rewards = waitText(card, "Rewards")
	local progress = waitGui(card, "Progress")
	local gradient = waitGradient(progress)
	local initialDividers = collectDividers(progress)
	local dividerTemplate = initialDividers[1]
	local buttonHandle: ElementTypes.ButtonHandle? = nil
	local config = resolveConfig(options)

	handle:add(function()
		if buttonHandle then
			buttonHandle:destroy()
			buttonHandle = nil
		end
	end)

	local function ensureDividers(steps: number): { Frame }
		local needed = math.max(steps - 1, 0)
		local dividers = collectDividers(progress)
		for index = #dividers, needed + 1, -1 do
			if dividers[index] ~= dividerTemplate then
				dividers[index]:Destroy()
				table.remove(dividers, index)
			end
		end
		while #dividers < needed do
			local clone = dividerTemplate:Clone()
			clone.Parent = progress
			table.insert(dividers, clone)
		end
		return dividers
	end

	local function render(data: QuestCardData)
		card.Name = `QuestCard_{data.questId}`
		card.LayoutOrder = data.slot
		title.Text = `{data.slot}. {data.title}`
		count.Text = `{math.min(data.progress, data.goal)}/{data.goal}`
		rewards.Text = rewardLabelText(data)

		local steps = visualSteps(data, config)
		local dividers = ensureDividers(steps)
		for index, divider in dividers do
			local visible = index <= steps - 1
			divider.Visible = visible
			if visible then
				divider.AnchorPoint = vector2(0.5, 0.5)
				divider.Position = positionFor(index, steps)
			end
		end

		gradient.Rotation = dividerTemplate.Rotation
		setGradientFill(gradient, visualFillRatio(data), config.Progress.FillColor, config.Progress.EmptyColor)

		if buttonHandle then
			buttonHandle:destroy()
			buttonHandle = nil
		end

		local element = if options and options.buttonElement then options.buttonElement else ButtonElement
		buttonHandle = element.mount(card, {
			text = rewardText(data),
			name = "ClaimButton",
			color = buttonColor(data, config),
			layoutOrder = 100,
			activated = function()
				if props.claim and data.completed and not data.claimed then
					props.claim(data.questId)
				end
			end,
		}, if options then options.buttonOptions else nil)
		positionButton(buttonHandle.instance, config)
		buttonHandle:setEnabled(data.completed and not data.claimed)
	end

	render(props.data)

	local cardHandle = handle :: any
	cardHandle.instance = card
	function cardHandle:setData(data: QuestCardData)
		render(data)
	end

	return cardHandle :: QuestCardHandle
end

return QuestCardElement
