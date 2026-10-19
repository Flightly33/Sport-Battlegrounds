--[[
	Virtual time for the simulator. Scripts' os.clock, workspace:GetServerTimeNow, task.wait/delay/defer
	and the sim's own timers (remote latency, tweens, Debris...) all run on this clock, which only moves
	when the world steps. Nothing waits on Lune's real-time scheduler, so a run is fully repeatable: a
	slow machine makes it take longer, never changes what happens in it.
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

local deferred: { { Run: any, Args: any } } = {}

-- task.defer: runs `fn` (a function or thread) at the next flush, after the current work.
function Clock.Defer(fn: any, ...: any)
	table.insert(deferred, { Run = fn, Args = table.pack(...) })
end

-- Runs deferred work until none is left (work deferred while flushing runs in the same flush,
-- like Roblox's resumption cycle).
function Clock.Flush()
	local rounds = 0
	while #deferred > 0 do
		rounds += 1
		if rounds > 1000 then
			error("[sim] task.defer loop: work keeps deferring more work")
		end
		local batch = deferred
		deferred = {}
		for _, item in batch do
			task.spawn(item.Run, table.unpack(item.Args, 1, item.Args.n))
		end
	end
end

return Clock
