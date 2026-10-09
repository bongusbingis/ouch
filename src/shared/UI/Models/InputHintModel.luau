-- Description: Pure input-hint selection shared by the InputHint component and its spec: which binding a device shows (keycap text, controller glyph, or nothing on touch), how much width the hint reserves beside a label, and wrap-around tab cycling for gamepad shoulder buttons.

--!strict

local T = require(script.Parent.Parent.Tokens)

local InputHintModel = {}

export type Binding = {
	Keyboard: Enum.KeyCode?,
	Gamepad: Enum.KeyCode?,
}

export type Hint =
	{ kind: "None" }
	| { kind: "Key", text: string }
	| {
		kind: "Glyph",
		keyCode: Enum.KeyCode,
		-- Shown when the platform has no glyph image (Studio with no pad, old clients).
		fallback: string,
	}

local KEY_TEXT: { [string]: string } = {
	Escape = "ESC",
	Tab = "TAB",
	Return = "ENTER",
	Space = "SPACE",
	LeftShift = "SHIFT",
	LeftControl = "CTRL",
	LeftAlt = "ALT",
	Backspace = "⌫",
	Zero = "0",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
}

local PAD_TEXT: { [string]: string } = {
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonSelect = "VIEW",
	DPadDown = "↓",
	DPadUp = "↑",
	DPadLeft = "←",
	DPadRight = "→",
}

function InputHintModel.keyText(keyCode: Enum.KeyCode): string
	return KEY_TEXT[keyCode.Name] or string.upper(keyCode.Name)
end

function InputHintModel.padText(keyCode: Enum.KeyCode): string
	return PAD_TEXT[keyCode.Name] or string.upper(keyCode.Name)
end

-- deviceClass is DeviceClass.Class ("Mouse" | "Touch" | "Gamepad"); "Keyboard"
-- (EmoteWheelController's name for the same class) is accepted too.
function InputHintModel.resolve(deviceClass: string, binding: Binding?): Hint
	if binding == nil or deviceClass == "Touch" then
		return { kind = "None" }
	end
	if deviceClass == "Gamepad" then
		local keyCode = binding.Gamepad
		if keyCode == nil then
			return { kind = "None" }
		end
		return { kind = "Glyph", keyCode = keyCode, fallback = InputHintModel.padText(keyCode) }
	end
	local keyCode = binding.Keyboard
	if keyCode == nil then
		return { kind = "None" }
	end
	return { kind = "Key", text = InputHintModel.keyText(keyCode) }
end

-- Width the hint occupies at token size (keycaps grow for words like ESC/TAB).
-- textWidth is the measured key text; callers without TextService pass nil.
function InputHintModel.width(hint: Hint, textWidth: number?): number
	local S = T.InputHint
	if hint.kind == "None" then
		return 0
	elseif hint.kind == "Glyph" then
		return S.Size
	end
	local measured = textWidth or (#(hint :: any).text * S.TextSize * 0.6)
	return math.max(S.Size, math.ceil(measured) + S.KeyPadding * 2)
end

-- Extra width a "[hint] LABEL" button needs over its unhinted size.
function InputHintModel.reserve(hint: Hint, textWidth: number?): number
	local width = InputHintModel.width(hint, textWidth)
	return if width > 0 then width + T.InputHint.Gap else 0
end

-- Next enabled id in order, wrapping; returns current when nothing else is enabled.
function InputHintModel.cycle(ids: { string }, enabled: { [string]: boolean }?, current: string, step: number): string
	local count = #ids
	local start = table.find(ids, current) or (if step > 0 then 0 else 1)
	for offset = 1, count do
		local index = ((start - 1 + step * offset) % count) + 1
		local id = ids[index]
		if id ~= current and (enabled == nil or enabled[id] ~= false) then
			return id
		end
	end
	return current
end

return table.freeze(InputHintModel)
