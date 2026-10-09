-- Description: React hook for the live DeviceClass ("Mouse" | "Touch" | "Gamepad"); re-renders only when the resolved class changes, so input hints switch the moment the player picks up another device.

--!strict

local RS = game:GetService("ReplicatedStorage")
local React = require(RS.Packages.react)
local DeviceClass = require(RS.Shared.Game.Input.DeviceClass)

return function(): DeviceClass.Class
	local class, setClass = React.useState(DeviceClass.current)
	React.useEffect(function()
		return DeviceClass.observe(setClass)
	end, {})
	return class
end
