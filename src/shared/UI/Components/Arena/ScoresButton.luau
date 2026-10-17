--!strict
local RS = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local React = require(RS.Packages.react)
local T = require(script.Parent.Parent.Parent.Tokens)
local PuffyButton = require(script.Parent.Parent.PuffyButton)
local c = React.createElement
local SCORES = require(RS:WaitForChild("Config"):WaitForChild("Interface"):WaitForChild("Input")).Hints.Scores

return function(props)
	local ref = React.useRef(nil)
	React.useEffect(function()
		local combat = require(StarterPlayer:WaitForChild("PlayerModule")).Combat
		local button = ref.current
		if not props.Visible or not button then
			combat.registerHudExclusion("MatchScores", nil)
			return
		end
		local function register()
			local p, s = button.AbsolutePosition, button.AbsoluteSize
			combat.registerHudExclusion("MatchScores", { minX = p.X, minY = p.Y, maxX = p.X + s.X, maxY = p.Y + s.Y })
		end
		register()
		local p = button:GetPropertyChangedSignal("AbsolutePosition"):Connect(register)
		local s = button:GetPropertyChangedSignal("AbsoluteSize"):Connect(register)
		return function()
			p:Disconnect()
			s:Disconnect()
			combat.registerHudExclusion("MatchScores", nil)
		end
	end, { props.Visible })
	return c(PuffyButton, {
		ButtonRef = ref,
		Text = "SCORES",
		-- "[TAB] SCORES" / "[View] SCORES": held, like the bind in MatchHUDClient.
		Hint = SCORES,
		TextSize = T.Type.HudMinimum,
		TextColor = T.Colors.Ink,
		Color = T.Colors.SurfaceWarm,
		LipColor = T.Colors.WellLine,
		Shadow = false,
		Native = {
			Selectable = false,
			Position = UDim2.fromOffset(props.Rect.position.X, props.Rect.position.Y),
			Size = UDim2.fromOffset(props.Rect.size.X, props.Rect.size.Y),
			Visible = props.Visible,
			ZIndex = 10,
		},
		OnActivated = props.OnActivated,
	})
end
