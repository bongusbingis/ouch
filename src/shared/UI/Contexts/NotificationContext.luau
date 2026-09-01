-- Name: NotificationContext.luau
-- Author: Jack C.
-- Description: React context that lets any screen queue a notification or confirmation modal and await the player's response.
-- Created: 2026-08-17

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))
local UIFeedback = require(script.Parent.Parent.Services.UIFeedback)

local c = React.createElement
local Context = React.createContext(nil)
local NotificationContext = {}

export type Api = {
	notify: (options: { title: string, description: string, buttonText: string? }, callback: ((boolean) -> ())?) -> (),
	confirm: (
		options: { title: string, description: string, confirmText: string?, cancelText: string? },
		callback: (boolean) -> ()
	) -> (),
	close: (result: any) -> (),
	request: any?,
}

function NotificationContext.Provider(props)
	local request, setRequest = React.useState(nil)
	local callbackRef = React.useRef(nil)

	local close = React.useCallback(function(result: any)
		local callback = callbackRef.current
		callbackRef.current = nil
		setRequest(nil)
		if callback then
			task.spawn(callback, result)
		end
	end, {})

	local notify = React.useCallback(function(options, callback)
		if callbackRef.current then
			task.spawn(callbackRef.current, nil)
		end
		callbackRef.current = callback
		setRequest({
			Title = options.title,
			Description = options.description,
			Buttons = { { Color = "Blue", Text = options.buttonText or "OK", Value = true } },
		})
		UIFeedback.notification()
	end, {})
	local confirm = React.useCallback(function(options, callback)
		if callbackRef.current then
			task.spawn(callbackRef.current, nil)
		end
		callbackRef.current = callback
		setRequest({
			Title = options.title,
			Description = options.description,
			Buttons = {
				{ Color = "Red", Text = options.confirmText or "CONFIRM", Value = true },
				{ Color = "Blue", Text = options.cancelText or "CANCEL", Value = false },
			},
		})
		UIFeedback.notification()
	end, {})
	local api: Api = React.useMemo(function()
		return {
			notify = notify,
			confirm = confirm,
			close = close,
			request = request,
		}
	end, { notify, confirm, close, request })
	React.useEffect(function()
		return function()
			local callback = callbackRef.current
			callbackRef.current = nil
			if callback then
				task.spawn(callback, nil)
			end
		end
	end, {})

	return c(Context.Provider, { value = api }, props.children)
end

function NotificationContext.useNotification(): Api
	local value = React.useContext(Context)
	assert(value ~= nil, "[NotificationContext] provider is missing")
	return value
end

return NotificationContext
