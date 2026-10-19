--[[
	Instance stand-in for the simulator.

	Property writes are validated against Lune's Roblox reflection database (unknown or read-only
	properties error like they would in Roblox). Reads fall back to the database's default values.
	Methods and events are implemented as needed by the game; touching anything unknown errors with a
	"[sim]" prefix so simulator gaps are easy to tell from real bugs.
]]
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local Signal = require("./Signal")
local Clock = require("./Clock")

local CFrame, Vector3, Vector2 = roblox.CFrame, roblox.Vector3, roblox.Vector2
local db = roblox.getReflectionDatabase()

local Sim = {}

type State = {
	ClassName: string,
	Name: string,
	Parent: any,
	Children: { any },
	Props: { [string]: any },
	Attributes: { [string]: any },
	Signals: { [string]: any },
	AttributeSignals: { [string]: any },
	PropSignals: { [string]: any },
	Locked: boolean,
	Destroyed: boolean,
	Extra: { [string]: any },
}

local states: { [any]: State } = setmetatable({}, { __mode = "k" }) :: any
Sim.States = states

local InstanceMT = {}

function Sim.IsInstance(x: any): boolean
	return type(x) == "table" and states[x] ~= nil
end

--------------------------------------------------------------------------------
-- Reflection helpers
--------------------------------------------------------------------------------
local classCache: { [string]: any } = {}
local function class(name: string)
	local c = classCache[name]
	if c == nil then
		c = db:GetClass(name) or false
		classCache[name] = c
	end
	return c or nil
end

local isACache: { [string]: boolean } = {}
local function isAUncached(className: string, target: string): boolean
	local c = class(className)
	while c do
		if c.Name == target then
			return true
		end
		c = c.Superclass and class(c.Superclass)
	end
	return className == target
end
local function isA(className: string, target: string): boolean
	local key = className .. ">" .. target
	local hit = isACache[key]
	if hit == nil then
		hit = isAUncached(className, target)
		isACache[key] = hit
	end
	return hit
end
Sim.ClassIsA = isA

local propCache: { [string]: { [string]: any } } = {}
local function propertyInfo(className: string, prop: string)
	local cache = propCache[className]
	if not cache then
		cache = {}
		propCache[className] = cache
	end
	local hit = cache[prop]
	if hit == nil then
		local c = class(className)
		hit = false
		while c do
			local p = c.Properties[prop]
			if p then
				hit = p
				break
			end
			c = c.Superclass and class(c.Superclass)
		end
		cache[prop] = hit
	end
	return hit or nil
end

local defaultCache: { [string]: any } = {}
local NONE = {}
local function defaultValueUncached(className: string, prop: string): any
	local c = class(className)
	while c do
		local d = c.DefaultProperties
		if d and d[prop] ~= nil then
			return d[prop]
		end
		c = c.Superclass and class(c.Superclass)
	end
	return nil
end
local function defaultValue(className: string, prop: string): any
	local key = className .. "." .. prop
	local hit = defaultCache[key]
	if hit == nil then
		hit = defaultValueUncached(className, prop)
		if hit == nil then
			hit = NONE
		end
		defaultCache[key] = hit
	end
	return if hit == NONE then nil else hit
end

-- Runtime defaults the database doesn't carry
local EXTRA_DEFAULTS: { [string]: { [string]: any } } = {
	Humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, HipHeight = 2 },
	BasePart = { AssemblyLinearVelocity = Vector3.zero, LocalTransparencyModifier = 0 },
}

--------------------------------------------------------------------------------
-- Construction
--------------------------------------------------------------------------------
local function newState(className: string): State
	return {
		ClassName = className,
		Name = className,
		Parent = nil,
		Children = {},
		Props = {},
		Attributes = {},
		Signals = {},
		AttributeSignals = {},
		PropSignals = {},
		Locked = false,
		Destroyed = false,
		Extra = {},
	}
end

function Sim.Raw(className: string): any
	local inst = setmetatable({}, InstanceMT)
	states[inst] = newState(className)
	return inst
end

Sim.OnCreated = function(_inst: any) end

function Sim.New(className: string, parent: any?): any
	local c = class(className)
	if not c then
		error(string.format("Unable to create an Instance of type \"%s\"", className), 2)
	end
	for _, tag in c.Tags do
		if tag == "NotCreatable" or tag == "Service" then
			error(string.format("Unable to create an Instance of type \"%s\"", className), 2)
		end
	end
	local inst = Sim.Raw(className)
	Sim.OnCreated(inst)
	if parent then
		inst.Parent = parent
	end
	return inst
end

--------------------------------------------------------------------------------
-- Signals
--------------------------------------------------------------------------------
local function signal(inst: any, name: string)
	local st = states[inst]
	local s = st.Signals[name]
	if not s then
		s = Signal.new(name)
		st.Signals[name] = s
	end
	return s
end
Sim.Signal = signal

local function fireIfAny(inst: any, name: string, ...: any)
	local s = states[inst].Signals[name]
	if s then
		s:Fire(...)
	end
end
Sim.Fire = fireIfAny

local EVENTS: { [string]: { string } } = {
	Instance = { "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "Destroying", "Changed", "AttributeChanged" },
	Humanoid = { "Died", "HealthChanged", "StateChanged", "Running", "Jumping" },
	Player = { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded" },
	Players = { "PlayerAdded", "PlayerRemoving" },
	RemoteEvent = { "OnServerEvent", "OnClientEvent" },
	UnreliableRemoteEvent = { "OnServerEvent", "OnClientEvent" },
	Sound = { "Ended", "Played" },
	GuiButton = { "Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up" },
	GuiObject = { "InputBegan", "InputEnded", "InputChanged", "MouseEnter", "MouseLeave" },
	BasePart = { "Touched", "TouchEnded" },
	Tween = { "Completed" },
	RunService = { "Heartbeat", "RenderStepped", "Stepped", "PreSimulation", "PostSimulation", "PreAnimation", "PreRender" },
	UserInputService = { "InputBegan", "InputEnded", "InputChanged", "TouchStarted", "LastInputTypeChanged" },
	Workspace = {},
	Trail = {},
}

local eventCache: { [string]: boolean } = {}
local function hasEventUncached(className: string, name: string): boolean
	for cls, list in EVENTS do
		if isA(className, cls) then
			for _, e in list do
				if e == name then
					return true
				end
			end
		end
	end
	return false
end
local function hasEvent(className: string, name: string): boolean
	local key = className .. "." .. name
	local hit = eventCache[key]
	if hit == nil then
		hit = hasEventUncached(className, name)
		eventCache[key] = hit
	end
	return hit
end

--------------------------------------------------------------------------------
-- Tree
--------------------------------------------------------------------------------
local function isDescendantOf(inst: any, ancestor: any): boolean
	local p = states[inst].Parent
	while p do
		if p == ancestor then
			return true
		end
		p = states[p].Parent
	end
	return false
end

local function forEachDescendant(inst: any, fn: (any) -> ())
	for _, c in table.clone(states[inst].Children) do
		fn(c)
		forEachDescendant(c, fn)
	end
end

local function setParent(inst: any, parent: any)
	local st = states[inst]
	if st.Locked then
		error(string.format("The Parent property of %s is locked, current parent: NULL, new parent %s", st.Name, if parent then states[parent].Name else "NULL"), 3)
	end
	if parent ~= nil and not Sim.IsInstance(parent) then
		error("Parent must be an Instance", 3)
	end
	if parent == inst or (parent and isDescendantOf(parent, inst)) then
		error("Attempt to set parent of " .. st.Name .. " to itself or a descendant", 3)
	end
	local old = st.Parent
	if old == parent then
		return
	end
	if old then
		local list = states[old].Children
		local i = table.find(list, inst)
		if i then
			table.remove(list, i)
		end
		fireIfAny(old, "ChildRemoved", inst)
		local a = old
		while a do
			fireIfAny(a, "DescendantRemoving", inst)
			a = states[a].Parent
		end
	end
	st.Parent = parent
	if parent then
		table.insert(states[parent].Children, inst)
	end
	fireIfAny(inst, "AncestryChanged", inst, parent)
	forEachDescendant(inst, function(d)
		fireIfAny(d, "AncestryChanged", inst, parent)
	end)
	if parent then
		fireIfAny(parent, "ChildAdded", inst)
		local a = parent
		while a do
			fireIfAny(a, "DescendantAdded", inst)
			forEachDescendant(inst, function(d)
				fireIfAny(a, "DescendantAdded", d)
			end)
			a = states[a].Parent
		end
	end
	Sim.OnParented(inst, old, parent)
end
Sim.OnParented = function(_inst: any, _old: any, _new: any) end

local function findChild(inst: any, name: string, recursive: boolean?): any
	for _, c in states[inst].Children do
		if states[c].Name == name then
			return c
		end
	end
	if recursive then
		for _, c in states[inst].Children do
			local found = findChild(c, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Geometry helpers (CFrame / Position / attachments / models)
--------------------------------------------------------------------------------
local function partCFrame(inst: any): any
	return states[inst].Props.CFrame or CFrame.identity
end

local function attachmentWorld(inst: any): any
	local st = states[inst]
	local parent = st.Parent
	local localCF = st.Props.CFrame or CFrame.new(st.Props.Position or Vector3.zero)
	if parent and isA(states[parent].ClassName, "BasePart") and states[parent].ClassName ~= "Terrain" then
		return partCFrame(parent) * localCF
	end
	return localCF
end

local function modelParts(model: any): { any }
	local out = {}
	forEachDescendant(model, function(d)
		if isA(states[d].ClassName, "BasePart") then
			table.insert(out, d)
		end
	end)
	return out
end
Sim.ModelParts = modelParts

local function modelPivot(model: any): any
	local primary = states[model].Props.PrimaryPart
	if primary then
		return partCFrame(primary)
	end
	local parts = modelParts(model)
	if #parts > 0 then
		return partCFrame(parts[1])
	end
	return CFrame.identity
end

--------------------------------------------------------------------------------
-- Methods
--------------------------------------------------------------------------------
local Methods: { [string]: { [string]: (...any) -> ...any } } = {}

Methods.Instance = {
	IsA = function(self, name)
		return isA(states[self].ClassName, name)
	end,
	FindFirstChild = function(self, name, recursive)
		return findChild(self, name, recursive)
	end,
	FindFirstChildOfClass = function(self, className)
		for _, c in states[self].Children do
			if states[c].ClassName == className then
				return c
			end
		end
		return nil
	end,
	FindFirstChildWhichIsA = function(self, className, recursive)
		for _, c in states[self].Children do
			if isA(states[c].ClassName, className) then
				return c
			end
		end
		if recursive then
			for _, c in states[self].Children do
				local f = (c :: any):FindFirstChildWhichIsA(className, true)
				if f then
					return f
				end
			end
		end
		return nil
	end,
	FindFirstAncestor = function(self, name)
		local p = states[self].Parent
		while p do
			if states[p].Name == name then
				return p
			end
			p = states[p].Parent
		end
		return nil
	end,
	FindFirstAncestorOfClass = function(self, className)
		local p = states[self].Parent
		while p do
			if states[p].ClassName == className then
				return p
			end
			p = states[p].Parent
		end
		return nil
	end,
	FindFirstAncestorWhichIsA = function(self, className)
		local p = states[self].Parent
		while p do
			if isA(states[p].ClassName, className) then
				return p
			end
			p = states[p].Parent
		end
		return nil
	end,
	WaitForChild = function(self, name, timeout)
		local found = findChild(self, name)
		local deadline = Clock.Now + (timeout or 5)
		while not found do
			if Clock.Now > deadline then
				if timeout then
					return nil
				end
				error(string.format("[sim] infinite yield: %s:WaitForChild(\"%s\")", (self :: any):GetFullName(), name), 2)
			end
			Clock.Wait(0.03)
			found = findChild(self, name)
		end
		return found
	end,
	GetChildren = function(self)
		return table.clone(states[self].Children)
	end,
	GetDescendants = function(self)
		local out = {}
		forEachDescendant(self, function(d)
			table.insert(out, d)
		end)
		return out
	end,
	IsDescendantOf = function(self, ancestor)
		return isDescendantOf(self, ancestor)
	end,
	IsAncestorOf = function(self, descendant)
		return isDescendantOf(descendant, self)
	end,
	GetFullName = function(self)
		local names = {}
		local x = self
		while x and states[x].ClassName ~= "DataModel" do
			table.insert(names, 1, states[x].Name)
			x = states[x].Parent
		end
		return table.concat(names, ".")
	end,
	Destroy = function(self)
		local st = states[self]
		if st.Destroyed then
			return
		end
		fireIfAny(self, "Destroying")
		for _, c in table.clone(st.Children) do
			(c :: any):Destroy()
		end
		if st.Parent then
			setParent(self, nil)
		end
		st.Locked = true
		st.Destroyed = true
		Sim.OnDestroyed(self)
	end,
	ClearAllChildren = function(self)
		for _, c in table.clone(states[self].Children) do
			(c :: any):Destroy()
		end
	end,
	Clone = function(self)
		local st = states[self]
		local copy = Sim.Raw(st.ClassName)
		local cst = states[copy]
		cst.Name = st.Name
		cst.Props = table.clone(st.Props)
		cst.Attributes = table.clone(st.Attributes)
		Sim.OnCreated(copy)
		for _, c in st.Children do
			local cc = (c :: any):Clone()
			cc.Parent = copy
		end
		return copy
	end,
	GetAttribute = function(self, name)
		return states[self].Attributes[name]
	end,
	SetAttribute = function(self, name, value)
		local st = states[self]
		if st.Attributes[name] == value then
			return
		end
		st.Attributes[name] = value
		local s = st.AttributeSignals[name]
		if s then
			s:Fire()
		end
		fireIfAny(self, "AttributeChanged", name)
	end,
	GetAttributes = function(self)
		return table.clone(states[self].Attributes)
	end,
	GetAttributeChangedSignal = function(self, name)
		local st = states[self]
		local s = st.AttributeSignals[name]
		if not s then
			s = Signal.new("Attribute:" .. name)
			st.AttributeSignals[name] = s
		end
		return s
	end,
	GetPropertyChangedSignal = function(self, name)
		local st = states[self]
		local s = st.PropSignals[name]
		if not s then
			s = Signal.new("Property:" .. name)
			st.PropSignals[name] = s
		end
		return s
	end,
	AddTag = function(self, tag)
		Sim.Tags.Add(self, tag)
	end,
	HasTag = function(self, tag)
		return Sim.Tags.Has(self, tag)
	end,
	GetTags = function(self)
		return Sim.Tags.Of(self)
	end,
}

Methods.PVInstance = {
	GetPivot = function(self)
		if isA(states[self].ClassName, "BasePart") then
			return partCFrame(self)
		end
		return modelPivot(self)
	end,
	PivotTo = function(self, cf)
		if isA(states[self].ClassName, "BasePart") then
			self.CFrame = cf
			return
		end
		local pivot = modelPivot(self)
		local delta = cf * pivot:Inverse()
		for _, p in modelParts(self) do
			states[p].Props.CFrame = delta * partCFrame(p)
		end
	end,
}

Methods.Model = {
	ScaleTo = function(_self, _scale) end,
	GetScale = function(_self)
		return 1
	end,
	GetExtentsSize = function(_self)
		return Vector3.new(4, 5, 2)
	end,
}

Methods.BasePart = {
	GetMass = function(self)
		local size = self.Size
		return size.X * size.Y * size.Z * 0.7
	end,
	SetNetworkOwner = function() end,
	ApplyImpulse = function() end,
	GetRootPart = function(self)
		return self
	end,
}

Methods.Humanoid = {
	GetState = function(_self)
		return roblox.Enum.HumanoidStateType.Running
	end,
	ChangeState = function() end,
	SetStateEnabled = function() end,
	TakeDamage = function(self, amount)
		self.Health = self.Health - amount
	end,
	MoveTo = function() end,
	Move = function() end,
	ApplyDescription = function() end,
	GetAppliedDescription = function()
		return Sim.New("HumanoidDescription")
	end,
	LoadAnimation = function()
		error("[sim] LoadAnimation is not used by this game")
	end,
}

Methods.ParticleEmitter = { Emit = function() end, Clear = function() end }
Methods.Sound = {
	Play = function(self)
		Clock.Delay(0.05, function()
			if not states[self].Destroyed then
				fireIfAny(self, "Ended", "")
			end
		end)
	end,
	Stop = function() end,
	Pause = function() end,
	Resume = function() end,
}
Methods.Player = {
	LoadCharacter = function()
		error("[sim] LoadCharacter is not used (CharacterAutoLoads = false)")
	end,
	Kick = function() end,
	GetMouse = function()
		return { Hit = CFrame.identity }
	end,
}
Methods.GuiObject = {
	TweenPosition = function() end,
	TweenSize = function() end,
}
Methods.RemoteEvent = {
	FireServer = function(self, ...)
		Sim.Remote.FireServer(self, ...)
	end,
	FireClient = function(self, player, ...)
		Sim.Remote.FireClient(self, player, ...)
	end,
	FireAllClients = function(self, ...)
		Sim.Remote.FireAllClients(self, ...)
	end,
}
Methods.Camera = {
	WorldToViewportPoint = function(_self, p)
		return Vector3.new(640, 360, 10), true
	end,
	ScreenPointToRay = function()
		return roblox.Ray.new(Vector3.zero, Vector3.new(0, 0, -1))
	end,
}

local methodCache: { [string]: any } = {}
local function findMethodUncached(className: string, name: string)
	for cls, list in Methods do
		if isA(className, cls) and list[name] then
			return list[name]
		end
	end
	return nil
end
local function findMethod(className: string, name: string)
	local key = className .. "." .. name
	local hit = methodCache[key]
	if hit == nil then
		hit = findMethodUncached(className, name) or false
		methodCache[key] = hit
	end
	return hit or nil
end
Sim.Methods = Methods

--------------------------------------------------------------------------------
-- Metatable
--------------------------------------------------------------------------------
InstanceMT.__index = function(self, key)
	local st = states[self]
	if key == "Name" then
		return st.Name
	elseif key == "ClassName" then
		return st.ClassName
	elseif key == "Parent" then
		return st.Parent
	end
	local cls = st.ClassName
	-- Computed properties
	if key == "Position" and isA(cls, "BasePart") then
		return partCFrame(self).Position
	elseif key == "Orientation" and isA(cls, "BasePart") then
		return Vector3.zero
	elseif (key == "WorldPosition" or key == "WorldCFrame") and cls == "Attachment" then
		local w = attachmentWorld(self)
		return if key == "WorldPosition" then w.Position else w
	elseif key == "AbsoluteSize" and (isA(cls, "GuiBase2d")) then
		return Vector2.new(1280, 720)
	elseif key == "AbsolutePosition" and isA(cls, "GuiBase2d") then
		return Vector2.zero
	end
	local custom = Sim.FindAccessor(Sim.Getters, cls, key)
	if custom then
		return custom(self)
	end
	local stored = st.Props[key]
	if stored ~= nil then
		return stored
	end
	local info = propertyInfo(cls, key)
	if info then
		for ec, defaults in EXTRA_DEFAULTS do
			if isA(cls, ec) and defaults[key] ~= nil then
				return defaults[key]
			end
		end
		return defaultValue(cls, key)
	end
	local method = findMethod(cls, key)
	if method then
		return method
	end
	if hasEvent(cls, key) then
		return signal(self, key)
	end
	local child = findChild(self, key)
	if child then
		return child
	end
	error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), cls, st.Name), 2)
end

InstanceMT.__newindex = function(self, key, value)
	local st = states[self]
	local cls = st.ClassName
	if key == "Parent" then
		setParent(self, value)
		return
	elseif key == "Name" then
		if st.Name ~= value then
			st.Name = tostring(value)
			fireIfAny(self, "Changed", "Name")
		end
		return
	end
	if key == "Position" and isA(cls, "BasePart") then
		local cf = partCFrame(self)
		st.Props.CFrame = (cf - cf.Position) + value
		return
	elseif key == "WorldPosition" and cls == "Attachment" then
		local parent = st.Parent
		if parent and isA(states[parent].ClassName, "BasePart") and states[parent].ClassName ~= "Terrain" then
			st.Props.Position = partCFrame(parent):PointToObjectSpace(value)
		else
			st.Props.Position = value
		end
		st.Props.CFrame = CFrame.new(st.Props.Position)
		return
	end
	local info = propertyInfo(cls, key)
	if not info then
		error(string.format("%s is not a valid member of %s \"%s\"", tostring(key), cls, st.Name), 2)
	end
	if info.Scriptability == "Read" or info.Scriptability == "None" then
		error(string.format("Unable to assign property %s. Property is read only", tostring(key)), 2)
	end
	if key == "Position" and cls == "Attachment" then
		st.Props.CFrame = CFrame.new(value)
	end
	local setter = Sim.FindAccessor(Sim.Setters, cls, key)
	if setter then
		value = setter(self, value)
	end
	local old = st.Props[key]
	st.Props[key] = value
	if old ~= value then
		local s = st.PropSignals[key]
		if s then
			s:Fire()
		end
		fireIfAny(self, "Changed", key)
	end
end

InstanceMT.__tostring = function(self)
	return states[self].Name
end

Sim.Getters = {} :: { [string]: { [string]: (any) -> any } }
Sim.Setters = {} :: { [string]: { [string]: (any, any) -> any } }

-- Getter / setter lookup through the class hierarchy (memoised)
local accessorCache: { [any]: { [string]: any } } = {}
function Sim.FindAccessor(map: { [string]: { [string]: any } }, className: string, key: string): any
	local cache = accessorCache[map]
	if not cache then
		cache = {}
		accessorCache[map] = cache
	end
	local id = className .. "." .. key
	local hit = cache[id]
	if hit == nil then
		hit = false
		for cls, list in map do
			if list[key] and isA(className, cls) then
				hit = list[key]
				break
			end
		end
		cache[id] = hit
	end
	return hit or nil
end
Sim.OnDestroyed = function(_inst: any) end
Sim.Tags = {
	Add = function(_inst: any, _tag: string) end,
	Has = function(_inst: any, _tag: string)
		return false
	end,
	Of = function(_inst: any)
		return {}
	end,
}
Sim.Remote = {
	FireServer = function(...) end,
	FireClient = function(...) end,
	FireAllClients = function(...) end,
}

return Sim
