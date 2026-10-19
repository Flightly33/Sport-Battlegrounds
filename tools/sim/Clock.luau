--[[
	Virtual time for the simulator. Scripts' os.clock, workspace:GetServerTimeNow, task.wait/delay and
	the sim's own timers (remote latency, tweens, Debris...) all run on this clock, which only moves
	when the world steps. A slow machine makes the run take longer, never changes what happens in it.
]]
local task = require("@lune/task")

local Clock = {}
Clock.Now = 0

export type Entry = { At: number, Seq: number, Run: any, Args: any, Cancelled: boolean }

local queue: { Entry } = {}
local seq = 0

local function push(at: number, run: any, args: any): Entry
	seq += 1
	local entry = { At = at, Seq = seq, Run = run, Args = args, Cancelled = false }
	table.insert(queue, entry)
	return entry
end

-- Yields the running thread for `t` virtual seconds; returns the time actually waited.
function Clock.Wait(t: number?): number
	local start = Clock.Now
	push(Clock.Now + math.max(t or 0, 0), coroutine.running(), nil)
	coroutine.yield()
	return Clock.Now - start
end

-- Runs `fn` (a function or thread) after `t` virtual seconds. Returns a handle for Clock.Cancel.
function Clock.Delay(t: number, fn: any, ...: any): Entry
	return push(Clock.Now + math.max(t, 0), fn, table.pack(...))
end

function Clock.Cancel(entry: any)
	if type(entry) == "table" and entry.Seq then
		entry.Cancelled = true
	end
end

-- Moves time forward by dt, resuming everything that comes due, in time order. Like a Roblox
-- frame, anything scheduled while advancing (task.wait() in a loop) waits for the next advance.
function Clock.Advance(dt: number)
	local target = Clock.Now + dt
	local due: { Entry } = {}
	local rest: { Entry } = {}
	for _, entry in queue do
		table.insert(if entry.At <= target then due else rest, entry)
	end
	queue = rest
	table.sort(due, function(a, b)
		if a.At ~= b.At then
			return a.At < b.At
		end
		return a.Seq < b.Seq
	end)
	for _, entry in due do
		Clock.Now = math.max(Clock.Now, entry.At)
		if not entry.Cancelled then
			if entry.Args then
				task.spawn(entry.Run, table.unpack(entry.Args, 1, entry.Args.n))
			else
				task.spawn(entry.Run)
			end
		end
	end
	Clock.Now = target
end

-- Lets Lune run deferred threads (task.defer) before the caller continues.
function Clock.Flush()
	task.wait(0)
end

return Clock
