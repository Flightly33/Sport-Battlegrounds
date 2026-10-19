--[[
	Minimal signal (event) implementation for module-to-module communication.
]]

export type Connection = { Disconnect: (self: Connection) -> () }

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { _handlers: { { fn: (...any) -> (), connected: boolean } } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, fn: (...any) -> ()): Connection
	local entry = { fn = fn, connected = true }
	table.insert(self._handlers, entry)
	local handlers = self._handlers
	return {
		Disconnect = function()
			entry.connected = false
			local index = table.find(handlers, entry)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal.Fire(self: Signal, ...: any)
	for _, entry in table.clone(self._handlers) do
		if entry.connected then
			task.spawn(entry.fn, ...)
		end
	end
end

return Signal
