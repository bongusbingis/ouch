-- Keeps the existing modal input/focus owner full-viewport while its content stays core-safe.
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.react)
local useHeaderInsets = require(script.Parent.Parent.Hooks.useHeaderInsets)

local c = React.createElement

local function ModalSurface(props: { Native: any, children: any })
	local insets = useHeaderInsets()
	local native = table.clone(props.Native)
	local className = native.ClassName or "TextButton"
	native.ClassName = nil
	-- Coordinate observers describe the original core-safe content, including
	-- JoinCode's conversion from native keyboard coordinates.
	local onPosition = native[React.Change.AbsolutePosition]
	native[React.Change.AbsolutePosition] = nil
	native.Position = UDim2.fromOffset(-insets.coreOffset.X, -insets.coreOffset.Y)
	native.Size = UDim2.fromOffset(insets.viewport.X, insets.viewport.Y)
	return c(className, native, {
		CoreContent = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(insets.coreOffset.X, insets.coreOffset.Y),
			Size = UDim2.fromOffset(insets.coreSize.X, insets.coreSize.Y),
			ZIndex = native.ZIndex or 1,
			[React.Change.AbsolutePosition] = onPosition,
		}, props.children),
	})
end

return function(native: any, children: any?)
	return c(ModalSurface, { Native = native }, children)
end
