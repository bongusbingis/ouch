-- Description: Countdown label showing the time remaining until the next shop or featured rotation, driven by the shared shop clock.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local useExternalStore = require(script.Parent.Parent.Parent.Hooks.useExternalStore)
local ShopClock = require(script.Parent.Parent.Parent.Services.ShopClock)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

local c = React.createElement
local T = require(script.Parent.Parent.Parent.Tokens)

local function formatRemaining(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local days = total // 86400
	local hours = (total % 86400) // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if days > 0 then
		return `{days}D {hours}H`
	end
	if hours > 0 then
		return `{hours}H {minutes}M`
	end
	return string.format("%02d:%02d", minutes, secs)
end

return function(props)
	local now = useExternalStore(ShopClock.now, ShopClock.subscribe)
	local expired = now >= props.ExpiresAt
	local notified = React.useRef(false)
	React.useEffect(function()
		if expired and not notified.current then
			notified.current = true
			if props.OnExpired then
				props.OnExpired()
			end
		elseif not expired then
			notified.current = false
		end
	end, { expired, props.ExpiresAt, props.OnExpired })
	return c(ResponsiveText, {
		HostName = props.HostName or "Countdown",
		MeasurementFont = T.Type.Label,
		MinTextSize = T.Type.Minimum,
		MaxTextSize = props.MaxTextSize or 18,
		Native = {
			AnchorPoint = props.AnchorPoint,
			BackgroundColor3 = T.Colors.Ink,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Font = T.Type.Label,
			Position = props.Position,
			Size = props.Size or UDim2.fromScale(0.3, 1),
			Text = if expired then "UPDATING" else formatRemaining(props.ExpiresAt - now),
			TextColor3 = props.TextColor3 or Color3.new(1, 1, 1),
			TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
			ZIndex = props.ZIndex or 6,
		},
	}, {
		UICorner = c("UICorner", { CornerRadius = UDim.new(0, UIConfig.Radius.Tile) }),
		UIPadding = c("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),
	})
end
