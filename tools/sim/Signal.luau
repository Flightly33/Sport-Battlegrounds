--[[ RBXScriptSignal stand-in for the simulator. ]]
local task = require("@lune/task")

local Signal = {}
Signal.__index = Signal

-- Set by the world: receives (message, traceback) for errors in handlers
Signal.OnError = function(err: any)
	print("[sim] error:", err)
end

local function guarded(fn, ...)
	local ok, err = xpcall(fn, function(e)
		local okTrace, trace = pcall(debug.traceback, tostring(e), 2)
		return if okTrace then trace else tostring(e)
	end, ...)
	if not ok then
		Signal.OnError(err)
	end
end
Signal.Guarded = guarded

export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }

function Signal.new(name: string?)
	return setmetatable({ _handlers = {}, _name = name or "Signal" }, Signal)
end

function Signal:Connect(fn)
	assert(type(fn) == "function", "Connect expects a function")
	local connection = { Connected = true, _fn = fn }
	function connection.Disconnect(c)
		c.Connected = false
	end
	table.insert(self._handlers, connection)
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

-- Fires every handler in its own thread (errors are reported, not swallowed).
function Signal:Fire(...)
	local handlers = table.clone(self._handlers)
	local alive = {}
	for _, c in self._handlers do
		if c.Connected then
			table.insert(alive, c)
		end
	end
	self._handlers = alive
	for _, c in handlers do
		if c.Connected then
			task.spawn(guarded, c._fn, ...)
		end
	end
end

-- Synchronous fire (frame events): runs handlers in order, errors propagate to the caller.
function Signal:FireSync(...)
	for _, c in table.clone(self._handlers) do
		if c.Connected then
			guarded(c._fn, ...)
		end
	end
end

function Signal:HasHandlers(): boolean
	for _, c in self._handlers do
		if c.Connected then
			return true
		end
	end
	return false
end

return Signal
