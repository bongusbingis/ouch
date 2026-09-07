-- Maps bounded, stable dimensions to Roblox's three accepted string fields.
--!strict

local Fields = {}

function Fields.resolve(schema: { { string } }, values: { [string]: any }): { [string]: string }
	local result = {}
	for index, choices in schema do
		if index > 3 then
			break
		end
		for _, key in choices do
			local value = values[key]
			local kind = type(value)
			if value ~= nil and (kind == "string" or kind == "number" or kind == "boolean") then
				if kind == "number" and (value ~= value or math.abs(value) == math.huge) then
					continue
				end
				result[string.format("CustomField%02d", index)] = key .. ":" .. string.sub(tostring(value), 1, 64)
				break
			end
		end
	end
	return result
end

return Fields
