-- Description: Player-shaped test doubles for service seams that only read the player surface, since real players cannot exist in the cloud execution environment.

--!strict

export type FakePlayer = {
	UserId: number,
	Name: string,
	DisplayName: string,
	Character: Model?,
	CharacterRemoving: any,
	Parent: Instance?,
	GetAttribute: (self: FakePlayer, name: string) -> any,
	SetAttribute: (self: FakePlayer, name: string, value: any) -> (),
	IsA: (self: FakePlayer, className: string) -> boolean,
	IsDescendantOf: (self: FakePlayer, ancestor: Instance) -> boolean,
}

local FakePlayer = {}

local function signal()
	local listeners = {}
	local event = {}
	function event:Connect(callback)
		local connection = {}
		listeners[connection] = callback
		function connection.Disconnect()
			listeners[connection] = nil
		end
		return connection
	end
	function event:Fire(...)
		for connection, callback in table.clone(listeners) do
			if listeners[connection] then
				callback(...)
			end
		end
	end
	return event
end

function FakePlayer.new(userId: number, name: string?): FakePlayer
	local attributes: { [string]: any } = {}
	local playerName = name or ("TestPlayer" .. tostring(userId))

	local player = {
		UserId = userId,
		Name = playerName,
		DisplayName = playerName,
		Character = nil :: Model?,
		CharacterRemoving = signal(),
		Parent = nil :: Instance?,
	}

	function player.GetAttribute(_self, attributeName: string): any
		return attributes[attributeName]
	end

	function player.SetAttribute(_self, attributeName: string, value: any)
		attributes[attributeName] = value
	end

	function player.IsA(_self, className: string): boolean
		return className == "Player" or className == "Instance"
	end

	function player.IsDescendantOf(_self, _ancestor: Instance): boolean
		return false
	end

	return (player :: any) :: FakePlayer
end

return FakePlayer
