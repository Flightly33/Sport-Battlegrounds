--[[
	Static consistency checks between move data (Shared/Characters) and move scripts (Client/Moves):
	  - every move has a script, every script has a move
	  - every hit name a script reports exists in that move's Hits
	  - the Soccer numbers match the design (Light Kick 4 s, Lightning Shot 10 s and 1/3 of max health)
	  - sanity of every move's numbers
	lune run tests/consistency.luau
]]
local fs = require("@lune/fs")
local process = require("@lune/process")
local Loader = require("../tools/lune/loader")

local Characters = Loader.Require("ReplicatedStorage.Shared.Characters")
local Config = Loader.Require("ReplicatedStorage.Shared.Config")

local failures = 0
local function check(ok: boolean, message: string)
	if not ok then
		failures += 1
		print("FAIL  " .. message)
	end
end

-- Move data sanity
local count = 0
for id, move in Characters.Moves do
	count += 1
	check(move.Id == id, id .. ": id mismatch")
	check(move.Busy > 0, id .. ": Busy must be > 0")
	check(move.Cooldown >= 0, id .. ": negative cooldown")
	for name, hit in move.Hits do
		check(hit.Damage >= 0 and hit.Damage <= 40, id .. "." .. name .. ": damage out of range")
		check(hit.Stun >= 0 and hit.Stun <= 4, id .. "." .. name .. ": stun out of range")
		check(hit.Range > 0, id .. "." .. name .. ": range must be > 0")
		check(move.MaxTime > 0, id .. ": has hits but MaxTime is 0")
	end
end
print(string.format("%d moves", count))

-- The Soccer spec
local soccer = Characters.Get("Soccer")
check(soccer.Moves[1].Name == "Light Kick" and soccer.Moves[1].Cooldown == 4, "Soccer Light Kick should have a 4 s cooldown")
check(soccer.Moves[2].Cooldown == 10, "Soccer Lightning Shot should have a 10 s cooldown")
check(math.abs(soccer.Moves[2].Hits.Ball.Damage - Config.Player.MaxHealth / 3) < 1e-6, "Lightning Shot should deal a third of max health")
check(soccer.Moves[3].Name == "Lightning Dribble Dash", "Soccer move 3 should be the Lightning Dribble Dash")

-- Scripts vs data
local KIT_HITS = { Kit_M1 = { "Hit1", "Hit2", "Hit3", "Hit4", "Uppercut", "Downslam" }, Kit_Awaken = { "Burst" } }
local scripted: { [string]: boolean } = {}
for _, class in { "Common", "Soccer", "Basketball", "Football", "Baseball" } do
	local source = fs.readFile("src/client/Moves/" .. class .. ".luau")
	-- function bodies
	local bodies: { [string]: string } = {}
	local order = {}
	for name in string.gmatch(source, "\nlocal function ([%w_]+)%(") do
		table.insert(order, name)
	end
	for i, name in order do
		local start = string.find(source, "\nlocal function " .. name .. "%(")
		local nextName = order[i + 1]
		local finish = if nextName then string.find(source, "\nlocal function " .. nextName .. "%(") else string.find(source, "\nlocal scripts")
		bodies[name] = string.sub(source, start or 1, (finish or #source) - 1)
	end
	local function hitsOf(name: string, seen: { [string]: boolean }): { string }
		local out = {}
		local body = bodies[name]
		if not body or seen[name] then
			return out
		end
		seen[name] = true
		for _, pattern in { ':Hitbox%("([%w_]+)"', ':Sphere%("([%w_]+)"', ':Report%("([%w_]+)"', 'Kit%.Front%(ctx, "([%w_]+)"', 'Hit = "([%w_]+)"', 'ReturnHit = "([%w_]+)"' } do
			for hit in string.gmatch(body, pattern) do
				table.insert(out, hit)
			end
		end
		-- hit names passed to this file's own helpers, e.g. throwBall(ctx, "Ball", ...)
		for helper in pairs(bodies) do
			for hit in string.gmatch(body, "[^%w_.]" .. helper .. '%(ctx, "([%w_]+)"') do
				table.insert(out, hit)
			end
		end
		if string.find(body, "Kit%.M1%(") then
			for _, h in KIT_HITS.Kit_M1 do
				table.insert(out, h)
			end
		end
		if string.find(body, "Kit%.Awaken%(") then
			for _, h in KIT_HITS.Kit_Awaken do
				table.insert(out, h)
			end
		end
		-- helpers called from this function
		for other in pairs(bodies) do
			if other ~= name and string.find(body, "[^%w_]" .. other .. "%(") then
				for _, h in hitsOf(other, seen) do
					table.insert(out, h)
				end
			end
		end
		return out
	end
	for moveId, fnName in string.gmatch(source, "\n\t([%w_]+) = { Run = ([%w_]+)") do
		scripted[moveId] = true
		local move = Characters.Move(moveId)
		check(move ~= nil, class .. ": script for unknown move " .. moveId)
		if move then
			local reported = hitsOf(fnName, {})
			local unique = {}
			for _, h in reported do
				unique[h] = true
			end
			for h in unique do
				-- Literals passed to helpers can be non-hit strings (sound names etc.); only flag ones that look like hits
				if move.Hits[h] == nil and string.match(h, "^%u") and not string.match(h, "^Sound") then
					local known = false
					for _, otherMove in Characters.Moves do
						if otherMove.Hits[h] then
							known = true
						end
					end
					if known or #reported > 0 then
						check(move.Hits[h] ~= nil, string.format("%s (%s): reports hit '%s' that the move doesn't define", moveId, fnName, h))
					end
				end
			end
			for h in move.Hits do
				check(unique[h] == true, string.format("%s: hit '%s' is defined but no script reports it", moveId, h))
			end
		end
	end
end
for id in Characters.Moves do
	check(scripted[id] == true, "no client script for move " .. id)
end

if failures > 0 then
	print(string.format("%d check(s) failed", failures))
	process.exit(1)
end
print("consistency: all checks passed")
