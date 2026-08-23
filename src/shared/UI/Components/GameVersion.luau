--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local ResponsiveText = require(script.Parent.ResponsiveText)

local c = React.createElement

local function displayText(assetVersion: number?): string
	local parts = {}
	local buildVersion = game:GetAttribute("BuildVersion")
	if buildVersion ~= nil and tostring(buildVersion) ~= "" then
		table.insert(parts, `BUILD {buildVersion}`)
	end
	if assetVersion ~= nil then
		table.insert(parts, `PLACE {assetVersion}`)
	end
	return table.concat(parts, "  |  ")
end

return function()
	local versionText, setVersionText = React.useState(displayText(nil))

	React.useEffect(function()
		local cancelled = false
		task.spawn(function()
			if game.PlaceId <= 0 then
				return
			end
			local success, info = pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, game.PlaceId)
			if cancelled then
				return
			end
			local assetVersion = if success
					and type(info) == "table"
					and type(info.AssetVersion) == "number"
				then info.AssetVersion
				else nil
			setVersionText(displayText(assetVersion))
		end)
		return function()
			cancelled = true
		end
	end, {})

	if versionText == "" then
		return nil
	end

	return c(ResponsiveText, {
		MeasurementFont = Enum.Font.SourceSansBold,
		MinTextSize = 10,
		MaxTextSize = 14,
		Native = {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundTransparency = 1,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Bold,
				Enum.FontStyle.Normal
			),
			Position = UDim2.fromScale(0.01, 0.99),
			Size = UDim2.fromScale(0.2, 0.025),
			Text = versionText,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 0.55,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 5,
		},
	})
end
