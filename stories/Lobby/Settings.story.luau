--[[
    Settings. First the whole page (SettingsPage) for each place it ships in -- Lobby and Arena
    register different settings (SettingsRegistry.forPlace) -- as Screen frames, since the page
    sizes itself from the viewport. The page reads and writes the shared SettingsStore, so changes
    made here persist only for this Studio session.

    Then every Lobby setting as a bare SettingRow (toggle and slider controls), in the wide row
    layout and the compact stacked layout, enabled and disabled (with the disabled reason). Row
    values are local story state, so toggles and sliders are live.

    Migrated from SettingsPage.story and SettingsControls.story (Compact / Disabled attributes ->
    the four row states).
]]

local StoryRoot = require(script.Parent.Parent.StoryRoot)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = StoryRoot.React
local Components = StoryRoot.Components
local SettingsPage = require(Components:WaitForChild("SettingsPage"))
local SettingRow = require(Components:WaitForChild("Settings"):WaitForChild("SettingRow"))
local UIConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("UI"))
local Registry = require(
	ReplicatedStorage:WaitForChild("Shared")
		:WaitForChild("Game")
		:WaitForChild("Settings")
		:WaitForChild("SettingsRegistry")
)

local c = React.createElement

local function Rows(props: { Compact: boolean, Disabled: boolean? })
	local values, setValues = React.useState({})
	local heights = UIConfig.Layout.SettingsControls.RowHeight[if props.Compact then "Compact" else "Wide"]
	local children: { [string]: any } = {
		Padding = c(
			"UIPadding",
			{ PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12) }
		),
		Layout = c("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	}
	for index, definition in Registry.forPlace("Lobby") do
		children[definition.Id] = c(SettingRow, {
			Definition = definition,
			Value = if values[definition.Id] ~= nil then values[definition.Id] else definition.Default,
			Enabled = not props.Disabled,
			DisabledReason = "UNAVAILABLE DURING A MATCH",
			Compact = props.Compact,
			Height = if definition.Description then heights.Description else heights.Plain,
			LayoutOrder = index,
			OnChange = function(id, value)
				setValues(function(previous)
					local updated = table.clone(previous)
					updated[id] = value
					return updated
				end)
			end,
		})
	end
	return c("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = UIConfig.ProgressionStyle.Surface,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Size = UDim2.fromScale(1, 1),
	}, children)
end

return StoryRoot.story({
	Title = "Settings",
	Summary = "SettingsPage for Lobby and Arena, then every Lobby SettingRow wide / compact, enabled / disabled.",
	States = {
		{ Name = "Page — lobby", Screen = true, Fit = 0.5, Element = c(SettingsPage, { Place = "Lobby" }) },
		{ Name = "Page — arena", Screen = true, Fit = 0.5, Element = c(SettingsPage, { Place = "Arena" }) },
		{ Name = "Rows wide", Size = Vector2.new(760, 560), Element = c(Rows, { Compact = false }) },
		{
			Name = "Rows wide disabled",
			Size = Vector2.new(760, 560),
			Element = c(Rows, { Compact = false, Disabled = true }),
		},
		{
			Name = "Rows compact",
			Note = "Phone: control under the label.",
			Size = Vector2.new(420, 640),
			Element = c(Rows, { Compact = true }),
		},
		{
			Name = "Rows compact disabled",
			Size = Vector2.new(420, 640),
			Element = c(Rows, { Compact = true, Disabled = true }),
		},
	},
})
