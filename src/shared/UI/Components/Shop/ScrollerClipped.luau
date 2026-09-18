-- Name: ScrollerClipped.luau
-- Author: Jack C.
-- Description: Hides its tilted contents whenever they would poke outside the enclosing ScrollingFrame, because Roblox never clips rotated descendants; the storefront's overhanging stickers and stamps sit inside it so scrolling cannot leak them over the panel header.
-- Created: 2026-09-15
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))

local c = React.createElement

export type Props = {
	Margin: number?,
	Native: { [any]: any }?,
	children: { [any]: any }?,
}

return function(props: Props)
	local ref = React.useRef(nil)
	local margin = props.Margin or 12
	React.useEffect(function()
		local host = ref.current
		local scroller = if host then host:FindFirstAncestorWhichIsA("ScrollingFrame") else nil
		if not host or not scroller then
			return nil
		end
		local function update()
			local top = scroller.AbsolutePosition.Y
			local bottom = top + scroller.AbsoluteSize.Y
			host.Visible = host.AbsolutePosition.Y - margin >= top
				and host.AbsolutePosition.Y + host.AbsoluteSize.Y + margin <= bottom
		end
		update()
		local a = host:GetPropertyChangedSignal("AbsolutePosition"):Connect(update)
		local b = scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		return function()
			a:Disconnect()
			b:Disconnect()
		end
	end, {})
	local native = table.clone(props.Native or {})
	native.ref = ref
	native.BackgroundTransparency = 1
	native.BorderSizePixel = 0
	return c("Frame", native, props.children)
end
