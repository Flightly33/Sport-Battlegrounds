--[[
	MoveRunner: runs move scripts (Client/Moves/*.luau) for every fighter.

	The same script runs in two modes:
	  owner     on the attacking player's client, the instant the key is pressed: it plays the
	            animation and VFX, moves the character, runs hitboxes and projectiles, and reports what
	            they touch to the server (HitRequest)
	  observer  on everyone else's client when MoveStarted arrives: animation and VFX only (the
	            character's movement arrives through normal physics replication)
	Impact effects play when the server confirms a hit (HitConfirmed), on every client.

	A move script is a function(ctx). ctx:Wait() returns false once the move was interrupted, so
	scripts read like timelines:
		ctx:Play(Clips.Soccer.LightKick)
		if not ctx:Wait(0.15) then return end
		ctx:Projectile({ ... })
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Pose = require(Shared.Anim.Pose)
local Props = require(Shared.Props)
local Remotes = require(Shared.Remotes)

local Animator = require(script.Parent.Animator)
local FX = require(script.Parent.FX)

type Move = Characters.Move
type Palette = Characters.Palette

local MoveRunner = {}

local hitRequest = Remotes.Event("HitRequest")

export type ProjectileSpec = {
	Hit: string?,
	Origin: Vector3,
	Direction: Vector3,
	Speed: number,
	Range: number,
	Radius: number,
	Gravity: number?,
	Visual: (() -> Instance)?,
	Spin: Vector3?, -- radians/s around the visual's axes
	Pierce: boolean?,
	Homing: number?, -- degrees/s towards the closest fighter in front (owner)
	OnStep: ((position: Vector3, direction: Vector3, dt: number, age: number) -> ())?,
	OnImpact: ((position: Vector3, victim: Model?) -> ())?,
	-- Boomerang: after impact or max range, fly back to this part (hitting `ReturnHit` on the way)
	ReturnTo: BasePart?,
	ReturnHit: string?,
	IgnoreWalls: boolean?,
}

export type Projectile = {
	Spec: ProjectileSpec,
	Position: Vector3,
	Direction: Vector3,
	Velocity: Vector3,
	Travelled: number,
	Age: number,
	Done: boolean,
	Returning: boolean,
	Visual: Instance?,
	HitSet: { [Model]: boolean },
	Ctx: Ctx,
	Stop: (self: Projectile, position: Vector3?, victim: Model?) -> (),
}

export type Ctx = {
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	IsOwner: boolean,
	Token: number,
	Move: Move,
	ClassId: string,
	Palette: Palette,
	Aim: Vector3,
	Variant: string,
	Started: number,
	Cancelled: boolean,
	Finished: boolean,
	Data: { [string]: any },
	HitLog: { [string]: { [Model]: number } },
	Tracks: { Animator.Track },
	Cleanup: { () -> () },
	Projectiles: { Projectile },
	Counter: (() -> ())?,
	Alive: (self: Ctx) -> boolean,
	Wait: (self: Ctx, seconds: number) -> boolean,
	Play: (self: Ctx, clip: Pose.Clip, options: Animator.PlayOptions?) -> Animator.Track?,
	Velocity: (self: Ctx, velocity: Vector3, duration: number) -> LinearVelocity?,
	Forward: (self: Ctx, speed: number, duration: number, up: number?) -> LinearVelocity?,
	Teleport: (self: Ctx, cf: CFrame) -> (),
	Face: (self: Ctx, direction: Vector3?) -> (),
	Hitbox: (self: Ctx, hitName: string, cf: CFrame, size: Vector3) -> { Model },
	Sphere: (self: Ctx, hitName: string, center: Vector3, radius: number) -> { Model },
	Query: (self: Ctx, center: Vector3, radius: number) -> { Model },
	QueryBox: (self: Ctx, cf: CFrame, size: Vector3) -> { Model },
	Report: (self: Ctx, hitName: string, targets: { Model }, position: Vector3) -> { Model },
	Projectile: (self: Ctx, spec: ProjectileSpec) -> Projectile,
	OnCleanup: (self: Ctx, fn: () -> ()) -> (),
	Keep: (self: Ctx, instance: Instance) -> (),
	HideProp: (self: Ctx, hidden: boolean) -> (),
	PropPart: (self: Ctx) -> BasePart?,
	Limb: (self: Ctx, name: string) -> BasePart?,
	Nearest: (self: Ctx, range: number, cone: number?) -> Model?,
	Ahead: (self: Ctx, distance: number, height: number?) -> Vector3,
	Ground: (self: Ctx, position: Vector3) -> Vector3,
}

export type MoveScript = {
	Run: (ctx: Ctx) -> (),
	-- Extra effects when the server confirms a hit of this move (on every client)
	OnHit: ((hit: HitInfo, palette: Palette) -> ())?,
}

export type HitInfo = {
	Attacker: Model,
	Victim: Model,
	Move: string,
	Hit: string,
	Token: number,
	Position: Vector3,
	Damage: number,
	Blocked: boolean,
	GuardBroken: boolean,
	Countered: boolean,
	Killed: boolean,
	Variant: string,
}

local scripts: { [string]: MoveScript } = {}
local active: { [Model]: { [number]: Ctx } } = {}
local projectiles: { Projectile } = {}

function MoveRunner.Register(list: { [string]: MoveScript })
	for id, s in list do
		scripts[id] = s
	end
end

function MoveRunner.Script(id: string): MoveScript?
	return scripts[id]
end

--------------------------------------------------------------------------------
-- Targets
--------------------------------------------------------------------------------
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function fighterFolders(): { Instance }
	local list: { Instance } = {}
	for _, name in { "Fighters", "Dummies" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	return list
end

local function fighterOf(part: Instance): Model?
	local model = part:FindFirstAncestorOfClass("Model")
	while model and not CollectionService:HasTag(model, "Fighter") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return model
end
MoveRunner.FighterOf = fighterOf

local function alive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function collectTargets(parts: { BasePart }, self: Model): { Model }
	local seen: { [Model]: boolean } = {}
	local out: { Model } = {}
	for _, p in parts do
		local model = fighterOf(p)
		if model and model ~= self and not seen[model] and alive(model) then
			seen[model] = true
			table.insert(out, model)
		end
	end
	return out
end

local envParams = RaycastParams.new()
envParams.FilterType = Enum.RaycastFilterType.Exclude
local fighterParams = RaycastParams.new()
fighterParams.FilterType = Enum.RaycastFilterType.Include

local function refreshParams(self: Model)
	local exclude = fighterFolders()
	table.insert(exclude, FX.Folder())
	table.insert(exclude, self)
	local walls = workspace:FindFirstChild("Stadium")
	local arenaWalls = walls and walls:FindFirstChild("ArenaWalls")
	if arenaWalls then
		-- Projectiles fly through the invisible walls (they stop at the real ones)
		table.insert(exclude, arenaWalls)
	end
	envParams.FilterDescendantsInstances = exclude
	fighterParams.FilterDescendantsInstances = fighterFolders()
end

local hitboxDebug = RunService:IsStudio() and Config.Debug.ShowHitboxes

--------------------------------------------------------------------------------
-- Context
--------------------------------------------------------------------------------
local function newCtx(character: Model, move: Move, token: number, aim: Vector3, variant: string, owner: boolean): Ctx?
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return nil
	end
	local classId = (character:GetAttribute("Class") :: string?) or Characters.Default
	local awakened = character:GetAttribute("Awakened") == true or move.Slot == "Awaken"
	local ctx = {
		Character = character,
		Root = root,
		Humanoid = humanoid,
		IsOwner = owner,
		Token = token,
		Move = move,
		ClassId = classId,
		Palette = Characters.Palette(classId, awakened),
		Aim = aim,
		Variant = variant,
		Started = os.clock(),
		Cancelled = false,
		Finished = false,
		Data = {},
		HitLog = {},
		Tracks = {},
		Cleanup = {},
		Projectiles = {},
		Counter = nil,
	} :: any

	function ctx.Alive(self: Ctx): boolean
		return not self.Cancelled and self.Character.Parent ~= nil and self.Humanoid.Health > 0
	end

	function ctx.Wait(self: Ctx, seconds: number): boolean
		if seconds > 0 then
			task.wait(seconds)
		end
		return self:Alive()
	end

	function ctx.Play(self: Ctx, clip: Pose.Clip, options: Animator.PlayOptions?): Animator.Track?
		local track = Animator.Play(self.Character, clip, options)
		if track then
			table.insert(self.Tracks, track)
		end
		return track
	end

	function ctx.Velocity(self: Ctx, velocity: Vector3, duration: number): LinearVelocity?
		if not self.IsOwner then
			return nil
		end
		local attachment = self.Root:FindFirstChild("RootAttachment") :: Attachment?
		if not attachment then
			return nil
		end
		-- Only one move velocity at a time
		for _, old in self.Root:GetChildren() do
			if old.Name == "SB_MoveVelocity" then
				old:Destroy()
			end
		end
		local lv = Instance.new("LinearVelocity")
		lv.Name = "SB_MoveVelocity"
		lv.Attachment0 = attachment
		lv.MaxForce = 1e7
		lv.VectorVelocity = velocity
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.Parent = self.Root
		self:Keep(lv)
		task.delay(duration, function()
			lv:Destroy()
		end)
		return lv
	end

	function ctx.Forward(self: Ctx, speed: number, duration: number, up: number?): LinearVelocity?
		local flat = Vector3.new(self.Aim.X, 0, self.Aim.Z)
		flat = if flat.Magnitude > 1e-3 then flat.Unit else self.Root.CFrame.LookVector
		return self:Velocity(flat * speed + Vector3.new(0, up or 0, 0), duration)
	end

	function ctx.Teleport(self: Ctx, cf: CFrame)
		if not self.IsOwner then
			return
		end
		self.Root.CFrame = cf
		self.Root.AssemblyLinearVelocity = Vector3.zero
	end

	function ctx.Face(self: Ctx, direction: Vector3?)
		if not self.IsOwner then
			return
		end
		local dir = direction or self.Aim
		local flat = Vector3.new(dir.X, 0, dir.Z)
		if flat.Magnitude < 1e-3 then
			return
		end
		local pos = self.Root.Position
		self.Root.CFrame = CFrame.lookAt(pos, pos + flat.Unit)
	end

	function ctx.Report(self: Ctx, hitName: string, targets: { Model }, position: Vector3): { Model }
		if not self.IsOwner or #targets == 0 then
			return {}
		end
		local def = self.Move.Hits[hitName]
		if not def then
			warn("[MoveRunner] unknown hit", self.Move.Id, hitName)
			return {}
		end
		local log = self.HitLog[hitName]
		if not log then
			log = {}
			self.HitLog[hitName] = log
		end
		local fresh: { Model } = {}
		for _, model in targets do
			local count = log[model] or 0
			if count < (def.Repeat or 1) then
				log[model] = count + 1
				table.insert(fresh, model)
			end
		end
		if #fresh > 0 then
			hitRequest:FireServer(self.Token, hitName, fresh, position)
		end
		return fresh
	end

	function ctx.Hitbox(self: Ctx, hitName: string, cf: CFrame, size: Vector3): { Model }
		if not self.IsOwner then
			return {}
		end
		overlap.FilterDescendantsInstances = fighterFolders()
		local parts = workspace:GetPartBoundsInBox(cf, size, overlap)
		if hitboxDebug then
			local box = FX.Part({ Size = size, CFrame = cf, Color = Color3.new(1, 0, 0), Transparency = 0.7, Life = 0.3 })
			box.Material = Enum.Material.ForceField
		end
		return self:Report(hitName, collectTargets(parts, self.Character), cf.Position)
	end

	function ctx.Sphere(self: Ctx, hitName: string, center: Vector3, radius: number): { Model }
		if not self.IsOwner then
			return {}
		end
		overlap.FilterDescendantsInstances = fighterFolders()
		local parts = workspace:GetPartBoundsInRadius(center, radius, overlap)
		if hitboxDebug then
			local ball = FX.Part({ Size = Vector3.one * radius * 2, CFrame = CFrame.new(center), Color = Color3.new(1, 0, 0), Transparency = 0.7, Shape = Enum.PartType.Ball, Life = 0.3 })
			ball.Material = Enum.Material.ForceField
		end
		return self:Report(hitName, collectTargets(parts, self.Character), center)
	end

	-- Fighters inside a sphere, without reporting a hit (owner only).
	function ctx.Query(self: Ctx, center: Vector3, radius: number): { Model }
		if not self.IsOwner then
			return {}
		end
		overlap.FilterDescendantsInstances = fighterFolders()
		return collectTargets(workspace:GetPartBoundsInRadius(center, radius, overlap), self.Character)
	end

	function ctx.QueryBox(self: Ctx, cf: CFrame, size: Vector3): { Model }
		if not self.IsOwner then
			return {}
		end
		overlap.FilterDescendantsInstances = fighterFolders()
		return collectTargets(workspace:GetPartBoundsInBox(cf, size, overlap), self.Character)
	end

	function ctx.Projectile(self: Ctx, spec: ProjectileSpec): Projectile
		return MoveRunner.SpawnProjectile(self, spec)
	end

	function ctx.OnCleanup(self: Ctx, fn: () -> ())
		table.insert(self.Cleanup, fn)
	end

	function ctx.Keep(self: Ctx, instance: Instance)
		table.insert(self.Cleanup, function()
			instance:Destroy()
		end)
	end

	function ctx.HideProp(self: Ctx, hidden: boolean)
		for _, p in Props.Visible(self.Character) do
			p.LocalTransparencyModifier = if hidden then 1 else 0
		end
		if hidden then
			self:OnCleanup(function()
				for _, p in Props.Visible(self.Character) do
					p.LocalTransparencyModifier = 0
				end
			end)
		end
	end

	function ctx.PropPart(self: Ctx): BasePart?
		local folder = self.Character:FindFirstChild("SB_Props")
		local handle = folder and folder:FindFirstChild(Props.HANDLE)
		return if handle and handle:IsA("BasePart") then handle else nil
	end

	function ctx.Limb(self: Ctx, name: string): BasePart?
		local p = self.Character:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end

	-- Closest living fighter within range, optionally inside a cone (degrees) around the aim.
	function ctx.Nearest(self: Ctx, range: number, cone: number?): Model?
		local best: Model? = nil
		local bestDistance = range
		local origin = self.Root.Position
		local cosLimit = if cone then math.cos(math.rad(cone)) else -2
		for _, model in CollectionService:GetTagged("Fighter") do
			if model ~= self.Character and model:IsA("Model") and alive(model) then
				local r = model:FindFirstChild("HumanoidRootPart")
				if r and r:IsA("BasePart") then
					local offset = r.Position - origin
					local distance = offset.Magnitude
					if distance < bestDistance and (distance < 1e-3 or offset.Unit:Dot(self.Aim) >= cosLimit) then
						best, bestDistance = model, distance
					end
				end
			end
		end
		return best
	end

	function ctx.Ahead(self: Ctx, distance: number, height: number?): Vector3
		local flat = Vector3.new(self.Aim.X, 0, self.Aim.Z)
		flat = if flat.Magnitude > 1e-3 then flat.Unit else self.Root.CFrame.LookVector
		return self.Root.Position + flat * distance + Vector3.new(0, height or 0, 0)
	end

	function ctx.Ground(_self: Ctx, position: Vector3): Vector3
		return (FX.GroundBelow(position))
	end

	return ctx :: Ctx
end

local function finish(ctx: Ctx)
	if ctx.Finished then
		return
	end
	ctx.Finished = true
	for _, track in ctx.Tracks do
		track:Stop()
	end
	for _, fn in ctx.Cleanup do
		task.spawn(fn)
	end
	local list = active[ctx.Character]
	if list then
		list[ctx.Token] = nil
	end
end

function MoveRunner.Cancel(character: Model, token: number)
	local list = active[character]
	local ctx = list and list[token]
	if ctx then
		ctx.Cancelled = true
		for _, track in ctx.Tracks do
			track:Stop(0.08)
		end
		finish(ctx)
	end
end

function MoveRunner.CancelAll(character: Model, includeArmored: boolean?)
	local list = active[character]
	if not list then
		return
	end
	for token, ctx in list do
		if includeArmored or not ctx.Move.HyperArmor then
			MoveRunner.Cancel(character, token)
		end
	end
end

function MoveRunner.Active(character: Model): { [number]: Ctx }
	return active[character] or {}
end

-- Starts a move script (owner or observer). Returns the context.
function MoveRunner.Start(character: Model, moveId: string, token: number, aim: Vector3, variant: string, owner: boolean, elapsed: number?): Ctx?
	local move = Characters.Move(moveId)
	local s = scripts[moveId]
	if not move or not s then
		warn("[MoveRunner] no script for", moveId)
		return nil
	end
	local ctx = newCtx(character, move, token, aim, variant, owner)
	if not ctx then
		return nil
	end
	-- Observers can skip the very start of a move if the message arrived late
	if elapsed and elapsed > 0 then
		ctx.Started -= elapsed
	end
	local list = active[character]
	if not list then
		list = {}
		active[character] = list
	end
	list[token] = ctx
	task.spawn(function()
		local ok, err = pcall(function()
			s.Run(ctx)
		end)
		if not ok then
			warn("[MoveRunner]", moveId, err)
		end
		-- Projectiles outlive the script; finish when they're done too
		while #ctx.Projectiles > 0 and not ctx.Cancelled do
			local any = false
			for _, p in ctx.Projectiles do
				if not p.Done then
					any = true
				end
			end
			if not any then
				break
			end
			task.wait(0.1)
		end
		finish(ctx)
	end)
	return ctx
end

--------------------------------------------------------------------------------
-- Projectiles
--------------------------------------------------------------------------------
function MoveRunner.SpawnProjectile(ctx: Ctx, spec: ProjectileSpec): Projectile
	local dir = if spec.Direction.Magnitude > 1e-3 then spec.Direction.Unit else Vector3.new(0, 0, -1)
	local visual: Instance? = nil
	if spec.Visual then
		visual = spec.Visual()
	end
	local projectile = {
		Spec = spec,
		Position = spec.Origin,
		Direction = dir,
		Velocity = dir * spec.Speed,
		Travelled = 0,
		Age = 0,
		Done = false,
		Returning = false,
		Visual = visual,
		HitSet = {},
		Ctx = ctx,
	} :: any
	function projectile.Stop(self: Projectile, position: Vector3?, victim: Model?)
		if self.Done then
			return
		end
		if position then
			self.Position = position
		end
		if self.Spec.ReturnTo and not self.Returning then
			self.Returning = true
			self.Travelled = 0
			self.HitSet = {}
			if self.Spec.OnImpact then
				task.spawn(self.Spec.OnImpact, self.Position, victim)
			end
			return
		end
		self.Done = true
		if self.Visual then
			self.Visual:Destroy()
			self.Visual = nil
		end
		if self.Spec.OnImpact and not self.Returning then
			task.spawn(self.Spec.OnImpact, self.Position, victim)
		end
	end
	if visual then
		visual.Parent = FX.Folder()
	end
	table.insert(projectiles, projectile)
	table.insert(ctx.Projectiles, projectile)
	return projectile :: Projectile
end

local function placeVisual(p: Projectile)
	local visual = p.Visual
	if not visual then
		return
	end
	local spin = p.Spec.Spin
	local rot = if spin then CFrame.Angles(spin.X * p.Age, spin.Y * p.Age, spin.Z * p.Age) else CFrame.identity
	local cf = CFrame.lookAt(p.Position, p.Position + p.Direction) * rot
	if visual:IsA("Model") then
		visual:PivotTo(cf)
	elseif visual:IsA("BasePart") then
		visual.CFrame = cf
	end
end

local function stepProjectile(p: Projectile, dt: number)
	local spec = p.Spec
	local ctx = p.Ctx
	p.Age += dt
	if p.Returning then
		local target = spec.ReturnTo
		if not target or not target.Parent then
			p.Done = true
		else
			local to = target.Position - p.Position
			if to.Magnitude < 2.5 then
				p.Done = true
			else
				p.Direction = to.Unit
				p.Velocity = p.Direction * spec.Speed * 1.15
			end
		end
		if p.Done then
			if p.Visual then
				p.Visual:Destroy()
				p.Visual = nil
			end
			return
		end
	elseif spec.Homing and ctx.IsOwner then
		local targetModel = ctx:Nearest(60, 50)
		local r = targetModel and targetModel:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			local want = (r.Position - p.Position).Unit
			local maxTurn = math.rad(spec.Homing) * dt
			local angle = math.acos(math.clamp(p.Direction:Dot(want), -1, 1))
			if angle > 1e-3 then
				local t = math.min(1, maxTurn / angle)
				p.Direction = p.Direction:Lerp(want, t).Unit
				p.Velocity = p.Direction * p.Velocity.Magnitude
			end
		end
	end
	if spec.Gravity and not p.Returning then
		p.Velocity += Vector3.new(0, -spec.Gravity * dt, 0)
		p.Direction = p.Velocity.Unit
	end
	local delta = p.Velocity * dt
	local from = p.Position

	refreshParams(ctx.Character)
	-- Fighters (owner only)
	local hitName = if p.Returning then spec.ReturnHit else spec.Hit
	if ctx.IsOwner and hitName then
		local result = workspace:Spherecast(from, spec.Radius, delta, fighterParams)
		if result then
			local model = fighterOf(result.Instance)
			if model and model ~= ctx.Character and not p.HitSet[model] and alive(model) then
				p.HitSet[model] = true
				ctx:Report(hitName, { model }, result.Position)
				if not spec.Pierce then
					p:Stop(result.Position, model)
					return
				end
			end
		end
	end
	-- Walls / ground
	if not spec.IgnoreWalls and not p.Returning then
		local wall = workspace:Raycast(from, delta, envParams)
		if wall then
			p:Stop(wall.Position, nil)
			return
		end
	end
	p.Position = from + delta
	p.Travelled += delta.Magnitude
	placeVisual(p)
	if spec.OnStep then
		spec.OnStep(p.Position, p.Direction, dt, p.Age)
	end
	if not p.Returning and p.Travelled >= spec.Range then
		p:Stop(nil, nil)
	end
end

-- Server confirmed a projectile hit: observers stop their copy at the impact point.
function MoveRunner.OnHitConfirmed(hit: HitInfo)
	local list = active[hit.Attacker]
	local ctx = list and list[hit.Token]
	if not ctx then
		return
	end
	if hit.Countered then
		return
	end
	if not ctx.IsOwner then
		for _, p in ctx.Projectiles do
			if not p.Done and not p.Spec.Pierce and (p.Spec.Hit == hit.Hit or p.Spec.ReturnHit == hit.Hit) then
				p:Stop(hit.Position, hit.Victim)
				break
			end
		end
	end
end

-- Goal Line Stand: the server says our counter stance caught someone.
function MoveRunner.OnCountered(character: Model, token: number, attacker: Model)
	local list = active[character]
	local ctx = list and list[token]
	if ctx and ctx.Counter then
		ctx.Data.CounterTarget = attacker
		task.spawn(ctx.Counter)
	end
end

-- The running context of a move (for OnHit handlers that change what the move does next).
function MoveRunner.Find(character: Model, token: number): Ctx?
	local list = active[character]
	return list and list[token]
end

function MoveRunner.Init()
	RunService.Heartbeat:Connect(function(dt)
		local i = 1
		while i <= #projectiles do
			local p = projectiles[i]
			if p.Done or (p.Ctx.Cancelled and not p.Ctx.Move.Hits[p.Spec.Hit or ""]) then
				table.remove(projectiles, i)
			else
				local ok, err = pcall(function()
					stepProjectile(p, dt)
				end)
				if not ok then
					warn("[MoveRunner] projectile", err)
					p.Done = true
				end
				i += 1
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		if p.Character then
			active[p.Character] = nil
		end
	end)
end

return MoveRunner
