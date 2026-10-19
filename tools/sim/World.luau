--[[
	A small Roblox runtime for Lune: runs the game's real server and client scripts against simulated
	instances, so runtime errors show up without opening Studio.

	- The place is mirrored from Rojo's sourcemap (scripts point at their files).
	- Server and client share one world (no replication delay except for remotes, which are delivered
	  a frame later). Each side has its own module cache, RunService flags and Players.LocalPlayer.
	- Physics is minimal: LinearVelocity moves characters, gravity pulls them to the floor (y = 0).
	- Spatial queries treat parts as boxes around their centre.

	Not simulated: rendering, sound playback, humanoid walking, collisions between parts.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local Sim = require("./Instance")
local Clock = require("./Clock")
local Signal = require("./Signal")

local CFrame, Vector3, Vector2 = roblox.CFrame, roblox.Vector3, roblox.Vector2

local World = {}
World.__index = World

local SERVICES = {
	"Workspace",
	"Players",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterPlayer",
	"StarterGui",
	"Lighting",
	"SoundService",
	"RunService",
	"TweenService",
	"Debris",
	"CollectionService",
	"UserInputService",
	"PhysicsService",
	"HttpService",
	"TextService",
	"ContextActionService",
	"MaterialService",
	"AssetService",
	"ContentProvider",
}

local RIG = {
	-- name, part0, part1, c0, c1, part size
	{ "Root", "HumanoidRootPart", "LowerTorso", CFrame.new(0, -1, 0), CFrame.new(0, -0.2, 0), Vector3.new(2, 0.4, 1) },
	{ "Waist", "LowerTorso", "UpperTorso", CFrame.new(0, 0.2, 0), CFrame.new(0, -0.8, 0), Vector3.new(2, 1.6, 1) },
	{ "Neck", "UpperTorso", "Head", CFrame.new(0, 0.8, 0), CFrame.new(0, -0.5, 0), Vector3.new(1.2, 1.2, 1.2) },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", CFrame.new(1, 0.56, 0), CFrame.new(-0.5, 0.42, 0), Vector3.new(1, 1.2, 1) },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", CFrame.new(0, -0.42, 0), CFrame.new(0, 0.35, 0), Vector3.new(1, 1.05, 1) },
	{ "RightWrist", "RightLowerArm", "RightHand", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.12, 0), Vector3.new(1, 0.3, 1) },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", CFrame.new(-1, 0.56, 0), CFrame.new(0.5, 0.42, 0), Vector3.new(1, 1.2, 1) },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", CFrame.new(0, -0.42, 0), CFrame.new(0, 0.35, 0), Vector3.new(1, 1.05, 1) },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.12, 0), Vector3.new(1, 0.3, 1) },
	{ "RightHip", "LowerTorso", "RightUpperLeg", CFrame.new(0.5, -0.2, 0), CFrame.new(0, 0.42, 0), Vector3.new(1, 1.2, 1) },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", CFrame.new(0, -0.42, 0), CFrame.new(0, 0.42, 0), Vector3.new(1, 1.15, 1) },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.09, 0), Vector3.new(1, 0.3, 1) },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", CFrame.new(-0.5, -0.2, 0), CFrame.new(0, 0.42, 0), Vector3.new(1, 1.2, 1) },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", CFrame.new(0, -0.42, 0), CFrame.new(0, 0.42, 0), Vector3.new(1, 1.15, 1) },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.09, 0), Vector3.new(1, 0.3, 1) },
}

function World.new(root: string)
	local self = setmetatable({}, World)
	self.Root = root
	self.Errors = {} :: { string }
	self.Warnings = {} :: { string }
	self.Log = {} :: { string }
	self.Latency = 0.03
	self.Time = 0
	self.Contexts = {}
	self.ClientPlayer = nil
	self.Parts = {} :: { [any]: boolean }
	self.Velocities = {} :: { [any]: boolean }
	self.Welds = {} :: { [any]: boolean }
	self.Tags = {} :: { [string]: { [any]: boolean } }
	self.TagAdded = {} :: { [string]: any }
	self.TagRemoved = {} :: { [string]: any }
	self.Vertical = {} :: { [any]: number }

	-- Same random numbers every run, so results repeat
	math.randomseed(1)

	Signal.OnError = function(err)
		table.insert(self.Errors, tostring(err))
		print("\n[sim] ERROR: " .. tostring(err))
	end

	-- DataModel + services
	local game = Sim.Raw("DataModel")
	Sim.States[game].Name = "Game"
	self.Game = game
	self.Services = {}
	for _, name in SERVICES do
		local s = Sim.Raw(name)
		Sim.States[s].Name = name
		s.Parent = game
		self.Services[name] = s
	end
	local ws = self.Services.Workspace
	local terrain = Sim.Raw("Terrain")
	Sim.States[terrain].Name = "Terrain"
	terrain.Parent = ws
	local camera = Sim.Raw("Camera")
	Sim.States[camera].Name = "Camera"
	camera.Parent = ws
	camera.CFrame = CFrame.new(0, 10, 30)
	ws.CurrentCamera = camera
	self.Camera = camera
	local uis = self.Services.UserInputService
	Sim.States[uis].Props.TouchEnabled = false
	Sim.States[uis].Props.KeyboardEnabled = true
	Sim.States[uis].Props.MouseEnabled = true
	for _, n in { "StarterPlayerScripts", "StarterCharacterScripts" } do
		local f = Sim.Raw(n)
		Sim.States[f].Name = n
		f.Parent = self.Services.StarterPlayer
	end
	self.Ground = Sim.Raw("Part")
	Sim.States[self.Ground].Name = "SimGround"
	self.Ground.Color = roblox.Color3.fromRGB(60, 150, 70)

	self:InstallHooks()
	self:BuildFromSourcemap()
	return self
end

--------------------------------------------------------------------------------
-- Hooks: tags, remotes, physics bookkeeping, service methods
--------------------------------------------------------------------------------
function World:InstallHooks()
	local world = self
	local M = Sim.Methods

	Sim.OnParented = function(inst, _old, new)
		local st = Sim.States[inst]
		local inWorkspace = new ~= nil and (new == world.Services.Workspace or (Sim.States[new] and inst:IsDescendantOf(world.Services.Workspace)))
		local function mark(x)
			local cls = Sim.States[x].ClassName
			if Sim.ClassIsA(cls, "BasePart") then
				world.Parts[x] = if inWorkspace then true else nil
			elseif cls == "LinearVelocity" then
				world.Velocities[x] = if inWorkspace then true else nil
			elseif cls == "WeldConstraint" then
				world.Welds[x] = if inWorkspace then true else nil
			end
		end
		mark(inst)
		for _, d in inst:GetDescendants() do
			mark(d)
		end
		local _ = st
	end
	Sim.OnDestroyed = function(inst)
		world.Parts[inst] = nil
		world.Velocities[inst] = nil
		world.Welds[inst] = nil
		for tag, set in world.Tags do
			if set[inst] then
				set[inst] = nil
				if world.TagRemoved[tag] then
					world.TagRemoved[tag]:Fire(inst)
				end
			end
		end
	end

	Sim.Tags = {
		Add = function(inst, tag)
			local set = world.Tags[tag]
			if not set then
				set = {}
				world.Tags[tag] = set
			end
			if not set[inst] then
				set[inst] = true
				if world.TagAdded[tag] then
					world.TagAdded[tag]:Fire(inst)
				end
			end
		end,
		Has = function(inst, tag)
			local set = world.Tags[tag]
			return set ~= nil and set[inst] == true
		end,
		Of = function(inst)
			local out = {}
			for tag, set in world.Tags do
				if set[inst] then
					table.insert(out, tag)
				end
			end
			return out
		end,
	}

	Sim.Remote = {
		FireServer = function(remote, ...)
			local args = table.pack(...)
			local player = world.ClientPlayer
			Clock.Delay(world.Latency, function()
				Sim.Signal(remote, "OnServerEvent"):Fire(player, table.unpack(args, 1, args.n))
			end)
		end,
		FireClient = function(remote, player, ...)
			if not Sim.IsInstance(player) or Sim.States[player].ClassName ~= "Player" then
				error("FireClient: player argument must be a Player", 3)
			end
			if player == world.ClientPlayer then
				local args = table.pack(...)
				Clock.Delay(world.Latency, function()
					Sim.Signal(remote, "OnClientEvent"):Fire(table.unpack(args, 1, args.n))
				end)
			end
		end,
		FireAllClients = function(remote, ...)
			if world.ClientPlayer then
				local args = table.pack(...)
				Clock.Delay(world.Latency, function()
					Sim.Signal(remote, "OnClientEvent"):Fire(table.unpack(args, 1, args.n))
				end)
			end
		end,
	}

	-- Humanoid health / death
	Sim.Setters.Humanoid = {
		Health = function(h, value)
			local st = Sim.States[h]
			local max = st.Props.MaxHealth or 100
			local old = st.Props.Health or max
			local new = math.clamp(value, 0, max)
			if new ~= old then
				Clock.Defer(function()
					Sim.Fire(h, "HealthChanged", new)
				end)
			end
			if old > 0 and new <= 0 then
				if World.TraceDeaths then
					print("[sim] humanoid died:", h:GetFullName(), debug.traceback("", 2))
				end
				Clock.Defer(function()
					Sim.Fire(h, "Died")
				end)
			end
			return new
		end,
	}
	Sim.Getters.Humanoid = {
		MoveDirection = function(_h)
			return Vector3.zero
		end,
		FloorMaterial = function(_h)
			return roblox.Enum.Material.Plastic
		end,
		RootPart = function(h)
			local parent = Sim.States[h].Parent
			return parent and parent:FindFirstChild("HumanoidRootPart")
		end,
	}
	Sim.Setters.Player = {
		Character = function(player, character)
			if character then
				Clock.Defer(function()
					Sim.Fire(player, "CharacterAdded", character)
				end)
			end
			return character
		end,
	}

	M.DataModel = {
		GetService = function(_g, name)
			local s = world.Services[name]
			if not s then
				error("[sim] service not simulated: " .. tostring(name), 2)
			end
			return s
		end,
	}
	M.TweenService = {
		Create = function(_ts, inst, info, props)
			local tween = Sim.Raw("Tween")
			local st = Sim.States[tween]
			st.Extra.Target = inst
			st.Extra.Info = info
			st.Extra.Props = props
			-- Validate the properties now, like Roblox does
			for k, v in props do
				local _ = inst[k]
				local __ = v
			end
			return tween
		end,
	}
	M.Tween = {
		Play = function(tween)
			local st = Sim.States[tween]
			local time = (st.Extra.Info and st.Extra.Info.Time) or 1
			Clock.Delay(time, function()
				local target = st.Extra.Target
				if not Sim.States[target].Destroyed then
					for k, v in st.Extra.Props do
						target[k] = v
					end
				end
				Sim.Fire(tween, "Completed", roblox.Enum.PlaybackState.Completed)
			end)
		end,
		Cancel = function() end,
		Pause = function() end,
	}
	M.Debris = {
		AddItem = function(_d, inst, life)
			Clock.Delay(life or 10, function()
				if not Sim.States[inst].Destroyed then
					inst:Destroy()
				end
			end)
		end,
	}
	M.CollectionService = {
		AddTag = function(_c, inst, tag)
			Sim.Tags.Add(inst, tag)
		end,
		RemoveTag = function(_c, inst, tag)
			local set = world.Tags[tag]
			if set and set[inst] then
				set[inst] = nil
				if world.TagRemoved[tag] then
					world.TagRemoved[tag]:Fire(inst)
				end
			end
		end,
		HasTag = function(_c, inst, tag)
			return Sim.Tags.Has(inst, tag)
		end,
		GetTags = function(_c, inst)
			return Sim.Tags.Of(inst)
		end,
		GetTagged = function(_c, tag)
			local out = {}
			for _, inst in Sim.Ordered(world.Tags[tag] or {}) do
				table.insert(out, inst)
			end
			return out
		end,
		GetInstanceAddedSignal = function(_c, tag)
			world.TagAdded[tag] = world.TagAdded[tag] or Signal.new("TagAdded")
			return world.TagAdded[tag]
		end,
		GetInstanceRemovedSignal = function(_c, tag)
			world.TagRemoved[tag] = world.TagRemoved[tag] or Signal.new("TagRemoved")
			return world.TagRemoved[tag]
		end,
	}
	-- Audio search: a few fake results per keyword (ids derived from the keyword) so the parsing,
	-- publishing and client fallback paths all run. Odd ids "fail to load" on the client.
	M.AssetService = {
		SearchAudioAsync = function(_a, params)
			local keyword = params.SearchKeyword
			local base = 1000
			for i = 1, #keyword do
				base = (base * 31 + string.byte(keyword, i)) % 1000000
			end
			local items = {}
			for i = 1, 3 do
				table.insert(items, { Id = base * 10 + i, Title = keyword .. " #" .. i, IsEndorsed = i == 2 })
			end
			return {
				GetCurrentPage = function()
					return items
				end,
				IsFinished = true,
			}
		end,
	}
	M.ContentProvider = {
		PreloadAsync = function(_c, list, callback)
			for _, inst in list do
				local id = inst.SoundId
				local n = tonumber(string.match(id, "%d+")) or 0
				local ok = n % 2 == 0
				if ok then
					Sim.States[inst].Props.IsLoaded = true
				end
				if callback then
					callback(id, if ok then roblox.Enum.AssetFetchStatus.Success else roblox.Enum.AssetFetchStatus.Failure)
				end
			end
		end,
	}
	M.StarterGui = {
		SetCoreGuiEnabled = function() end,
		SetCore = function() end,
	}
	M.UserInputService = {
		IsKeyDown = function()
			return false
		end,
		GetMouseLocation = function()
			return Vector2.new(640, 360)
		end,
	}
	M.RunService = {
		IsStudio = function()
			return true
		end,
		IsRunning = function()
			return true
		end,
		BindToRenderStep = function(rs, _name, _priority, fn)
			Sim.Signal(rs, "RenderStepped"):Connect(fn)
		end,
		UnbindFromRenderStep = function() end,
		IsServer = function()
			error("[sim] RunService:IsServer called without a context")
		end,
	}
	M.Players = {
		GetPlayers = function(players)
			local out = {}
			for _, c in players:GetChildren() do
				if c.ClassName == "Player" then
					table.insert(out, c)
				end
			end
			return out
		end,
		GetPlayerFromCharacter = function(players, character)
			for _, p in players:GetChildren() do
				if p.ClassName == "Player" and Sim.States[p].Props.Character == character then
					return p
				end
			end
			return nil
		end,
		GetHumanoidDescriptionFromUserId = function()
			error("HTTP is not available in the simulator")
		end,
		CreateHumanoidModelFromDescription = function(_players, _description, _rigType)
			return world:BuildRig()
		end,
	}
	M.Workspace = {
		GetServerTimeNow = function()
			return Clock.Now + 1000
		end,
		BulkMoveTo = function(_ws, parts, cframes)
			for i, p in parts do
				p.CFrame = cframes[i]
			end
		end,
		Raycast = function(_ws, origin, direction, _params)
			return world:Raycast(origin, direction)
		end,
		Spherecast = function(_ws, origin, radius, direction, params)
			return world:Spherecast(origin, radius, direction, params)
		end,
		GetPartBoundsInBox = function(_ws, cf, size, params)
			return world:QueryBox(cf, size, params)
		end,
		GetPartBoundsInRadius = function(_ws, position, radius, params)
			return world:QueryRadius(position, radius, params)
		end,
	}
end

--------------------------------------------------------------------------------
-- The place: scripts from the sourcemap
--------------------------------------------------------------------------------
function World:BuildFromSourcemap()
	local map = serde.decode("json", fs.readFile(self.Root .. "sourcemap.json"))
	self.Sources = self.Sources or {}
	local function build(node, parent)
		if node.name == "Stadium" and parent == self.Services.Workspace then
			return -- the baked map; the server builds it if missing
		end
		local inst
		local existing = parent:FindFirstChild(node.name)
		if existing and existing.ClassName == node.className then
			inst = existing
		else
			inst = Sim.Raw(node.className)
			Sim.States[inst].Name = node.name
			inst.Parent = parent
		end
		for _, path in node.filePaths or {} do
			if string.match(path, "%.luau$") or string.match(path, "%.lua$") then
				Sim.States[inst].Extra.File = path
				-- Read now: fs.readFile is async in Lune, and a script yielding to Lune's I/O loop in
				-- the middle of a require would make runs depend on real timing
				self.Sources[path] = fs.readFile(self.Root .. path)
			end
		end
		for _, child in node.children or {} do
			build(child, inst)
		end
	end
	for _, child in map.children or {} do
		local service = self.Services[child.name]
		if service then
			for _, c in child.children or {} do
				build(c, service)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Characters
--------------------------------------------------------------------------------
function World:BuildRig(): any
	local model = Sim.Raw("Model")
	Sim.States[model].Name = "Character"
	local parts = {}
	local root = Sim.Raw("Part")
	Sim.States[root].Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.CFrame = CFrame.new(0, 3, 0)
	root.Parent = model
	parts.HumanoidRootPart = root
	local attachment = Sim.Raw("Attachment")
	Sim.States[attachment].Name = "RootAttachment"
	attachment.Parent = root
	for _, j in RIG do
		local name, p0, p1, c0, c1, size = j[1], j[2], j[3], j[4], j[5], j[6]
		local part = Sim.Raw("MeshPart")
		Sim.States[part].Name = p1
		part.Size = size
		part.CFrame = parts[p0].CFrame * c0 * c1:Inverse()
		part.Parent = model
		parts[p1] = part
		local motor = Sim.Raw("Motor6D")
		Sim.States[motor].Name = name
		motor.Part0 = parts[p0]
		motor.Part1 = part
		motor.C0 = c0
		motor.C1 = c1
		motor.Parent = part
	end
	local humanoid = Sim.Raw("Humanoid")
	Sim.States[humanoid].Name = "Humanoid"
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

--------------------------------------------------------------------------------
-- Spatial queries
--------------------------------------------------------------------------------
local function passes(world, part, params): boolean
	if not params then
		return true
	end
	local list = params.FilterDescendantsInstances or {}
	local inList = false
	for _, x in list do
		if part == x or part:IsDescendantOf(x) then
			inList = true
			break
		end
	end
	local include = params.FilterType == roblox.Enum.RaycastFilterType.Include
	local _ = world
	return if include then inList else not inList
end

function World:Raycast(origin, direction)
	if direction.Y >= 0 or origin.Y <= 0 then
		return nil
	end
	local t = -origin.Y / direction.Y
	if t > 1 then
		return nil
	end
	return {
		Instance = self.Ground,
		Position = origin + direction * t,
		Normal = Vector3.yAxis,
		Material = roblox.Enum.Material.Grass,
		Distance = (direction * t).Magnitude,
	}
end

function World:Spherecast(origin, radius, direction, params)
	local best, bestT = nil, math.huge
	local length = direction.Magnitude
	if length < 1e-6 then
		return nil
	end
	local dir = direction / length
	for part in self.Parts do
		if passes(self, part, params) and part.CanQuery ~= false then
			local center = part.Position
			local t = math.clamp((center - origin):Dot(dir), 0, length)
			local closest = origin + dir * t
			local reach = radius + math.max(part.Size.X, part.Size.Y, part.Size.Z) * 0.5
			if (center - closest).Magnitude <= reach and (t < bestT or (t == bestT and best and Sim.Seq(part) < Sim.Seq(best))) then
				best, bestT = part, t
			end
		end
	end
	if best then
		return { Instance = best, Position = origin + dir * bestT, Normal = -dir, Distance = bestT, Material = roblox.Enum.Material.Plastic }
	end
	return nil
end

function World:QueryBox(cf, size, params)
	local out = {}
	for part in self.Parts do
		if passes(self, part, params) and part.CanQuery ~= false then
			local p = cf:PointToObjectSpace(part.Position)
			local s = part.Size
			if math.abs(p.X) <= size.X / 2 + s.X / 2 and math.abs(p.Y) <= size.Y / 2 + s.Y / 2 and math.abs(p.Z) <= size.Z / 2 + s.Z / 2 then
				table.insert(out, part)
			end
		end
	end
	return Sim.SortList(out)
end

function World:QueryRadius(position, radius, params)
	local out = {}
	for part in self.Parts do
		if passes(self, part, params) and part.CanQuery ~= false then
			local s = part.Size
			if (part.Position - position).Magnitude <= radius + math.max(s.X, s.Y, s.Z) / 2 then
				table.insert(out, part)
			end
		end
	end
	return Sim.SortList(out)
end

--------------------------------------------------------------------------------
-- Contexts (server / client) and script loading
--------------------------------------------------------------------------------
local TweenInfoShim = {}
TweenInfoShim.__index = TweenInfoShim
function TweenInfoShim.new(time, style, direction, repeatCount, reverses, delay)
	return setmetatable({ Time = time or 1, EasingStyle = style, EasingDirection = direction, RepeatCount = repeatCount or 0, Reverses = reverses or false, DelayTime = delay or 0 }, TweenInfoShim)
end

local function paramsShim()
	return {
		new = function()
			return { FilterType = roblox.Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {}, CollisionGroup = "Default", RespectCanCollide = false, MaxParts = 0 }
		end,
	}
end

function World:Context(name: string, isServer: boolean, localPlayer: any?)
	local world = self
	local ctx = { Name = name, Cache = {}, Loading = {} }
	local proxies = {}
	local function proxy(real, overrides)
		local p = setmetatable({}, {
			__index = function(_, key)
				local o = overrides[key]
				if o ~= nil then
					return o
				end
				local v = real[key]
				if type(v) == "function" then
					return function(_self, ...)
						return v(real, ...)
					end
				end
				return v
			end,
			__newindex = function(_, key, value)
				real[key] = value
			end,
		})
		proxies[p] = real
		return p
	end
	local runService = proxy(self.Services.RunService, {
		IsServer = function()
			return isServer
		end,
		IsClient = function()
			return not isServer
		end,
	})
	local players = proxy(self.Services.Players, { LocalPlayer = localPlayer or false })
	if not localPlayer then
		getmetatable(players).__index = (function(old)
			return function(t, key)
				if key == "LocalPlayer" then
					return nil
				end
				return old(t, key)
			end
		end)(getmetatable(players).__index)
	end
	local gameProxy = proxy(self.Game, {
		GetService = function(_, serviceName)
			if serviceName == "RunService" then
				return runService
			elseif serviceName == "Players" then
				return players
			end
			return world.Game:GetService(serviceName)
		end,
	})
	local function simTypeof(x)
		if Sim.IsInstance(x) or proxies[x] then
			return "Instance"
		elseif getmetatable(x) == Signal then
			return "RBXScriptSignal"
		elseif getmetatable(x) == TweenInfoShim then
			return "TweenInfo"
		end
		return typeof(x)
	end
	local function wrap(fn)
		return function(...)
			return Signal.Guarded(fn, ...)
		end
	end
	local taskShim = {
		spawn = function(f, ...)
			if type(f) == "thread" then
				return task.spawn(f, ...)
			end
			return task.spawn(wrap(f), ...)
		end,
		defer = function(f, ...)
			if type(f) == "thread" then
				Clock.Defer(f, ...)
				return f
			end
			local thread = coroutine.create(wrap(f))
			Clock.Defer(thread, ...)
			return thread
		end,
		delay = function(t, f, ...)
			if type(f) == "thread" then
				return Clock.Delay(t or 0, f, ...)
			end
			return Clock.Delay(t or 0, wrap(f), ...)
		end,
		wait = function(t)
			return Clock.Wait(t or 1 / 60)
		end,
		cancel = function(handle)
			if type(handle) == "thread" then
				task.cancel(handle)
			else
				Clock.Cancel(handle)
			end
		end,
	}
	-- Scripts see virtual time
	local osShim = table.clone(os)
	osShim.clock = function()
		return Clock.Now
	end
	local env = {
		game = gameProxy,
		workspace = self.Services.Workspace,
		task = taskShim,
		os = osShim,
		typeof = simTypeof,
		Instance = {
			new = function(className, parent)
				return Sim.New(className, parent)
			end,
		},
		TweenInfo = TweenInfoShim,
		RaycastParams = paramsShim(),
		OverlapParams = paramsShim(),
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring((select(i, ...))))
			end
			local message = table.concat(parts, " ")
			table.insert(world.Warnings, "[" .. name .. "] " .. message)
			print("[" .. name .. "] WARN " .. message)
		end,
		print = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				table.insert(parts, tostring((select(i, ...))))
			end
			table.insert(world.Log, "[" .. name .. "] " .. table.concat(parts, " "))
		end,
	}
	for _, k in { "CFrame", "Vector3", "Vector2", "Color3", "BrickColor", "UDim", "UDim2", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "NumberRange", "Rect", "Ray", "Enum", "Font", "PhysicalProperties", "Region3", "Faces", "Axes" } do
		env[k] = (roblox :: any)[k]
	end
	-- Deterministic Random
	local RandomShim = {}
	RandomShim.__index = RandomShim
	local unseeded = 0
	function RandomShim.new(seed)
		-- Unseeded generators get 1, 2, 3... so runs repeat
		if seed == nil then
			unseeded += 1
		end
		local s = math.floor(seed or unseeded * 7919) % 2147483647
		if s <= 0 then
			s += 2147483646
		end
		return setmetatable({ state = s }, RandomShim)
	end
	function RandomShim:_next()
		self.state = (self.state * 48271) % 2147483647
		return self.state / 2147483647
	end
	function RandomShim:NextNumber(min, max)
		local lo, hi = min or 0, max or 1
		return lo + (hi - lo) * self:_next()
	end
	function RandomShim:NextInteger(min, max)
		return math.floor(min + (max - min + 1) * self:_next())
	end
	env.Random = RandomShim

	local function sourceOf(scriptInstance): string
		local file = Sim.States[scriptInstance].Extra.File
		if not file then
			error("[sim] no source for " .. scriptInstance:GetFullName())
		end
		return file
	end
	local requireModule
	local function environmentFor(scriptInstance)
		-- Lune's luau.load reads globals raw (no __index), so every script gets a flat copy
		local e = table.clone(env)
		e.script = scriptInstance
		e.require = requireModule
		return e
	end
	requireModule = function(target)
		if not Sim.IsInstance(target) or target.ClassName ~= "ModuleScript" then
			error("[sim] require expects a ModuleScript, got " .. simTypeof(target), 2)
		end
		local cached = ctx.Cache[target]
		if cached ~= nil then
			return cached.value
		end
		if ctx.Loading[target] then
			local loader = ctx.Loading[target]
			local where = if type(loader) == "thread" then debug.traceback(loader) else tostring(loader)
			error("Requested module was required recursively: " .. target:GetFullName() .. "\n(the first load is suspended at: " .. where .. ")", 2)
		end
		ctx.Loading[target] = coroutine.running()
		local file = sourceOf(target)
		local fn = luau.load(world.Sources[file], { debugName = file, environment = environmentFor(target) })
		local value = fn()
		ctx.Loading[target] = nil
		ctx.Cache[target] = { value = value }
		return value
	end
	-- Runs a Script / LocalScript in this context.
	ctx.Run = function(scriptInstance)
		local file = sourceOf(scriptInstance)
		local fn = luau.load(world.Sources[file], { debugName = file, environment = environmentFor(scriptInstance) })
		task.spawn(function()
			Signal.Guarded(fn)
		end)
	end
	-- Requires a ModuleScript in this context (shares the cache with the game's own requires).
	ctx.Require = requireModule
	ctx.Env = env
	self.Contexts[name] = ctx
	return ctx
end

--------------------------------------------------------------------------------
-- Players
--------------------------------------------------------------------------------
function World:AddPlayer(name: string, userId: number, withClient: boolean): any
	local player = Sim.Raw("Player")
	Sim.States[player].Name = name
	player.DisplayName = name
	player.UserId = userId
	local gui = Sim.Raw("PlayerGui")
	Sim.States[gui].Name = "PlayerGui"
	gui.Parent = player
	local scripts = Sim.Raw("PlayerScripts")
	Sim.States[scripts].Name = "PlayerScripts"
	scripts.Parent = player
	if withClient then
		self.ClientPlayer = player
	end
	player.Parent = self.Services.Players
	Sim.Fire(self.Services.Players, "PlayerAdded", player)
	return player
end

--------------------------------------------------------------------------------
-- Frame loop
--------------------------------------------------------------------------------
local GRAVITY = 196.2

local function assemblyOf(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end

function World:Physics(dt: number)
	local driven: { [any]: any } = {}
	for _, lv in Sim.Ordered(self.Velocities) do
		local st = Sim.States[lv]
		if not st.Destroyed and lv.Enabled ~= false then
			local a = lv.Attachment0
			local part = a and a.Parent
			if part and Sim.IsInstance(part) and part:IsA("BasePart") then
				local model = assemblyOf(part)
				driven[model or part] = lv.VectorVelocity
			end
		end
	end
	-- Characters: velocity constraints, else gravity onto the floor
	for _, folderName in { "Fighters", "Dummies" } do
		local folder = self.Services.Workspace:FindFirstChild(folderName)
		if folder then
			for _, model in folder:GetChildren() do
				local root = model:FindFirstChild("HumanoidRootPart")
				if root then
					local v = driven[model]
					local cf = root.CFrame
					local vy = self.Vertical[model] or 0
					if v then
						vy = v.Y
						local moved = cf + v * dt
						if moved.Position.Y < 3 then
							moved = moved + Vector3.new(0, 3 - moved.Position.Y, 0)
						end
						model:PivotTo(moved)
						root.AssemblyLinearVelocity = v
					else
						vy -= GRAVITY * dt
						local y = cf.Position.Y + vy * dt
						if y <= 3 then
							y = 3
							vy = 0
						end
						model:PivotTo(cf + Vector3.new(0, y - cf.Position.Y, 0))
						root.AssemblyLinearVelocity = Vector3.new(0, vy, 0)
					end
					self.Vertical[model] = vy
				end
			end
		end
	end
	-- Welded dummies follow their grabber
	for _, weld in Sim.Ordered(self.Welds) do
		local p0, p1 = weld.Part0, weld.Part1
		if p0 and p1 and weld.Name == "SB_Grab" and not Sim.States[weld].Destroyed then
			local model = assemblyOf(p1)
			if model then
				model:PivotTo(p0.CFrame * CFrame.new(0, 0, -3.2) * CFrame.Angles(0, math.pi, 0))
			end
		end
	end
end

function World:Step(dt: number)
	self.Time += dt
	local rs = self.Services.RunService
	Sim.Signal(rs, "RenderStepped"):FireSync(dt)
	Sim.Signal(rs, "PreAnimation"):FireSync(dt)
	Sim.Signal(rs, "PreSimulation"):FireSync(dt)
	Sim.Signal(rs, "Stepped"):FireSync(self.Time, dt)
	self:Physics(dt)
	Sim.Signal(rs, "PostSimulation"):FireSync(dt)
	Sim.Signal(rs, "Heartbeat"):FireSync(dt)
end

World.FrameTime = 1 / 60

-- Runs the world for `seconds` of virtual time in fixed 60 Hz frames: timers due in a frame wake,
-- deferred threads run, then the frame steps (render, animation, physics, heartbeat).
function World:Run(seconds: number)
	local stop = Clock.Now + seconds - 1e-9
	while Clock.Now < stop do
		Clock.Advance(World.FrameTime)
		Clock.Flush()
		self:Step(World.FrameTime)
		Clock.Flush()
		if World.Digest then
			self.Frame = (self.Frame or 0) + 1
			local parts = { string.format("[digest] %d t=%.4f", self.Frame, Clock.Now) }
			for _, folderName in { "Fighters", "Dummies" } do
				local folder = self.Services.Workspace:FindFirstChild(folderName)
				if folder then
					for _, model in folder:GetChildren() do
						local root = model:FindFirstChild("HumanoidRootPart")
						local h = model:FindFirstChildOfClass("Humanoid")
						if root then
							local p = root.Position
							table.insert(parts, string.format("%s(%.3f,%.3f,%.3f|%s)", model.Name, p.X, p.Y, p.Z, tostring(h and h.Health)))
						end
					end
				end
			end
			print(table.concat(parts, " "))
		end
	end
end

-- Current virtual time (what scripts see as os.clock()).
function World:Now(): number
	return Clock.Now
end

return World
