--[[
	Runs the game's ModuleScripts under Lune (outside Roblox) for tests and offline previews.

	Roblox-style requires (`require(script.Parent.Pose)`, `ReplicatedStorage:WaitForChild("Shared")`)
	are resolved to files through the same mapping as default.project.json. Roblox datatypes come from
	@lune/roblox. Services are NOT emulated here; only pure modules (math, data, instance building)
	can be loaded.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Loader = {}

local ROOT = process.cwd
if string.sub(ROOT, -1) ~= "/" then
	ROOT ..= "/"
end
Loader.Root = ROOT

local MOUNTS = {
	{ { "ReplicatedStorage", "Shared" }, "src/shared" },
	{ { "ServerScriptService", "Server" }, "src/server" },
	{ { "StarterPlayer", "StarterPlayerScripts", "Client" }, "src/client" },
}

-- Roblox globals handed to every loaded module
local GLOBALS: { [string]: any } = {}
for _, name in { "CFrame", "Vector3", "Vector2", "Color3", "BrickColor", "UDim", "UDim2", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "NumberRange", "Rect", "Ray", "Enum", "Instance", "Font", "PhysicalProperties", "Region3", "Faces", "Axes" } do
	GLOBALS[name] = (roblox :: any)[name]
end
Loader.Globals = GLOBALS

-- Lune has no Random datatype: a small deterministic stand-in (xorshift)
local RandomShim = {}
RandomShim.__index = RandomShim
function RandomShim.new(seed: number?)
	local s = math.floor(seed or os.clock() * 1e6) % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	return setmetatable({ state = s }, RandomShim)
end
function RandomShim:_next(): number
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function RandomShim:NextNumber(min: number?, max: number?): number
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * self:_next()
end
function RandomShim:NextInteger(min: number, max: number): number
	return math.floor(min + (max - min + 1) * self:_next())
end
GLOBALS.Random = RandomShim

local Proxy = {}

local function makeProxy(path: { string })
	return setmetatable({ __path = path }, Proxy)
end

local function child(self, name: string)
	local path = table.clone(rawget(self, "__path"))
	table.insert(path, name)
	return makeProxy(path)
end

Proxy.__index = function(self, key)
	local path = rawget(self, "__path")
	if key == "Parent" then
		local p = table.clone(path)
		table.remove(p)
		return makeProxy(p)
	elseif key == "Name" then
		return path[#path]
	elseif key == "WaitForChild" or key == "FindFirstChild" then
		return function(_, name)
			return child(self, name)
		end
	elseif key == "GetService" then
		return function(_, name)
			return makeProxy({ name })
		end
	end
	return child(self, key)
end
Proxy.__tostring = function(self)
	return table.concat(rawget(self, "__path"), ".")
end

local function toFile(path: { string }): string?
	for _, mount in MOUNTS do
		local prefix, dir = mount[1], mount[2]
		local ok = #path >= #prefix
		for i = 1, #prefix do
			if path[i] ~= prefix[i] then
				ok = false
				break
			end
		end
		if ok then
			local rest = {}
			for i = #prefix + 1, #path do
				table.insert(rest, path[i])
			end
			local base = ROOT .. dir .. (if #rest > 0 then "/" .. table.concat(rest, "/") else "")
			for _, candidate in { base .. ".luau", base .. "/init.luau", base .. ".lua", base .. "/init.lua" } do
				if fs.isFile(candidate) then
					return candidate
				end
			end
		end
	end
	return nil
end

local cache: { [string]: any } = {}

Loader.Game = makeProxy({})
Loader.Extra = {} :: { [string]: any } -- extra globals for loaded modules (mocks)

local function load(file: string, scriptPath: { string }): any
	if cache[file] ~= nil then
		return cache[file]
	end
	local source = fs.readFile(file)
	local env = {
		script = makeProxy(scriptPath),
		game = Loader.Game,
		require = nil :: any,
	}
	env.require = function(target)
		if type(target) == "table" and rawget(target, "__path") then
			return Loader.RequirePath(rawget(target, "__path"))
		end
		return require(target)
	end
	for k, v in GLOBALS do
		(env :: any)[k] = v
	end
	for k, v in Loader.Extra do
		(env :: any)[k] = v
	end
	local fn = luau.load(source, { debugName = string.sub(file, #ROOT + 1), environment = env })
	local result = fn()
	cache[file] = result
	return result
end

function Loader.RequirePath(path: { string }): any
	local file = toFile(path)
	if not file then
		error("Loader: no file for " .. table.concat(path, "."))
	end
	-- A folder module's script is the folder itself
	return load(file, path)
end

-- Loader.Require("ReplicatedStorage.Shared.Anim.Pose")
function Loader.Require(dotted: string): any
	return Loader.RequirePath(string.split(dotted, "."))
end

return Loader
