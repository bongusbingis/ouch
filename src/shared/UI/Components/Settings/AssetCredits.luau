-- Read-only asset attribution from the generated provenance manifest.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local Credits = require(ReplicatedStorage:WaitForChild("ThirdPartyCredits"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local usePreferredTextSize = require(script.Parent.Parent.Parent.Hooks.usePreferredTextSize)

local c = React.createElement

local function CreditText(props)
	local ref = React.useRef(nil)
	local height, setHeight = React.useState(1)
	React.useEffect(function()
		local label = ref.current
		local function measure()
			if label.AbsoluteSize.X > 0 then
				local bounds = TextService:GetTextSize(
					props.Text,
					props.TextSize,
					Enum.Font.Highway,
					Vector2.new(label.AbsoluteSize.X, 100000)
				)
				setHeight(math.ceil(bounds.Y) + 4)
			end
		end
		local changed = label:GetPropertyChangedSignal("AbsoluteSize"):Connect(measure)
		measure()
		return function()
			changed:Disconnect()
		end
	end, { props.Text, props.TextSize })
	return c("TextLabel", {
		ref = ref,
		BackgroundTransparency = 1,
		Font = Enum.Font.Highway,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, height),
		Text = props.Text,
		TextColor3 = UIConfig.ProgressionStyle.Ink,
		TextSize = props.TextSize,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 5,
	})
end

return function()
	local preferred = usePreferredTextSize()
	local scale = UIConfig.Text.PreferredScale[preferred.Name] or 1
	local entries = {
		Layout = c("UIListLayout", { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, credit in Credits do
		entries[tostring(index)] = c(CreditText, {
			LayoutOrder = index,
			Text = `{credit.author} — {credit.source_id}\n{credit.license}\n\n{credit.source_url}\n{credit.license_url}\n\n{credit.license_text}`,
			TextSize = math.round(18 * scale),
		})
	end
	return c("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
	}, entries)
end
