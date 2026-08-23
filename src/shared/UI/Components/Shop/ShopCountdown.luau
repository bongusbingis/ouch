--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local useExternalStore = require(script.Parent.Parent.Parent.Hooks.useExternalStore)
local ShopClock = require(script.Parent.Parent.Parent.Services.ShopClock)
local ResponsiveText = require(script.Parent.Parent.ResponsiveText)

local c = React.createElement

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
		return string.format("%02d:%02d:%02d", hours, minutes, secs)
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
		MeasurementFont = Enum.Font.SourceSansBold,
		MaxTextSize = props.MaxTextSize or 28,
		Native = {
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = props.Position,
			Size = props.Size or UDim2.fromScale(0.3, 1),
			Text = if expired then "REFRESHING" else formatRemaining(props.ExpiresAt - now),
			TextColor3 = props.TextColor3 or Color3.new(1, 1, 1),
			TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Right,
			ZIndex = props.ZIndex or 6,
		},
	})
end
