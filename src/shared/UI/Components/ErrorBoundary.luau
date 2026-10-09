-- Description: React error boundary that confines one UI subtree's runtime error to that subtree, so a single crashing component never unmounts the rest of the lobby or arena UI.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("react"))

export type Props = {
	-- Names the subtree in the one-time warning so a crash is traceable.
	Name: string,
	-- Rendered in place of the failed subtree. Defaults to nothing: keep the
	-- player playing, never block input and never show a failure screen.
	Fallback: any?,
	-- Changing this value gives a failed subtree one fresh attempt.
	ResetKey: any?,
	-- Called once per failure after the subtree is dropped, so a parent that was
	-- waiting on the subtree (e.g. a "presented" handshake) can stop waiting.
	OnError: ((err: any) -> ())?,
	children: any?,
}

local ErrorBoundary = React.Component:extend("ErrorBoundary") :: any

function ErrorBoundary:init()
	self.state = { failed = false }
	self.warned = false
end

function ErrorBoundary.getDerivedStateFromError(_err: any)
	return { failed = true }
end

function ErrorBoundary:componentDidCatch(err: any, info: any)
	local props = self.props :: Props
	if not self.warned then
		self.warned = true
		local stack = if type(info) == "table" and info.componentStack then `\n{info.componentStack}` else ""
		warn(`[ErrorBoundary] {props.Name} crashed and was dropped: {tostring(err)}{stack}`)
	end
	if props.OnError then
		local ok, callbackError = pcall(props.OnError, err)
		if not ok then
			warn(`[ErrorBoundary] {props.Name} OnError failed: {tostring(callbackError)}`)
		end
	end
end

function ErrorBoundary:componentDidUpdate(previousProps: Props)
	local props = self.props :: Props
	if self.state.failed and previousProps.ResetKey ~= props.ResetKey then
		self.warned = false
		self:setState({ failed = false })
	end
end

function ErrorBoundary:render()
	local props = self.props :: Props
	if self.state.failed then
		return props.Fallback
	end
	return props.children
end

return ErrorBoundary :: any
