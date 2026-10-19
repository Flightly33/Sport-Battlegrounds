--[[
	Motion: moves the local character for dashes, lunges, leaps and slides.

	A move asks for a push - a velocity, or a direction and a distance - plus a duration and a speed
	curve. Motion drives the HumanoidRootPart with a LinearVelocity on its own attachment
	(Rig.MOTION_ATTACHMENT) and updates it every frame:
		- the curve gives dashes a snappy start and a soft stop instead of starting and ending dead
		- pushes slide along walls in their way and never carry anyone out of the arena (the barrier in
		  Shared/Stadium/Layout, minus a margin)
		- pushes without a vertical speed drive the horizontal plane only (gravity untouched); ones with a
	  vertical speed drive the full velocity
	Only a character's owner moves it (MoveRunner's ctx:Push / Velocity / Forward / Dash / Teleport).
	A script may Destroy() the LinearVelocity Push returns to end the push early (e.g. on reaching its
	target). Tuning lives in Config.Motion and Config.Dash.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rig = require(Shared.Anim.Rig)
local Layout = require(Shared.Stadium.Layout)

local Motion = {}

export type ProfileName = "Constant" | "Dash" | "Lunge"

export type PushSpec = {
	Velocity: Vector3?, -- world velocity at full speed...
	Direction: Vector3?, -- ...or a direction (flattened) and
	Distance: number?, -- how far to travel along it, in studs
	Duration: number,
	Profile: ProfileName?, -- speed curve, default "Constant"
	Vertical: boolean?, -- drive the vertical speed too (default: when a Velocity is given)
	Bounded: boolean?, -- stay inside the arena (default true)
	Collide: boolean?, -- slide along walls in the way (default true)
	Carry: number?, -- share of the final speed kept when the push ends (default 0)
}

type Active = {
	Root: BasePart,
	Constraint: LinearVelocity,
	Base: Vector3,
	Duration: number,
	Started: number,
	Profile: (number) -> number,
	Vertical: boolean,
	Bounded: boolean,
	Collide: boolean,
	Carry: number,
	Last: Vector3,
	From: Vector3, -- where the push started
	Expected: number?, -- studs it should cover (distance pushes)
	Blocked: boolean, -- a wall or the arena edge cut it short
}

local function smoothstep(a: number): number
	return a * a * (3 - 2 * a)
end

-- Speed curves over the push (t = 0..1), as a share of the peak speed.
Motion.Profiles = {
	Constant = function(_t: number): number
		return 1
	end,
	-- Snap off the mark, hold, then settle (shaped by Config.Dash)
	Dash = function(t: number): number
		local c = Config.Dash
		if t < c.EaseIn then
			local a = t / c.EaseIn
			return c.StartSpeed + (1 - c.StartSpeed) * (1 - (1 - a) ^ 3)
		end
		local outStart = 1 - c.EaseOut
		if t > outStart then
			return 1 - (1 - c.EndSpeed) * smoothstep((t - outStart) / c.EaseOut)
		end
		return 1
	end,
	-- A burst that bleeds off: steps into strikes, lunges
	Lunge = function(t: number): number
		return 1 - 0.8 * t * t
	end,
} :: { [string]: (number) -> number }

-- Average of a curve over the push, so a distance can be turned into a peak speed.
local function meanOf(curve: (number) -> number): number
	local sum = 0
	for i = 0, 63 do
		sum += curve((i + 0.5) / 64)
	end
	return sum / 64
end

local active: { [LinearVelocity]: Active } = {}
local connection: RBXScriptConnection? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function refreshFilter()
	local ignore: { Instance } = {}
	for _, name in { "Fighters", "Dummies", "FX", "Crowd" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
end

-- Removes the part of `h` that runs into a wall within the next couple of frames (slides along it).
local function alongWalls(position: Vector3, h: Vector3, dt: number): Vector3
	local speed = h.Magnitude
	if speed < 1e-3 then
		return h
	end
	local dir = h / speed
	local reach = speed * math.max(dt, 1 / 60) * 2 + Config.Motion.BodyRadius
	local side = dir:Cross(Vector3.yAxis) * 0.8
	for _, offset in { Vector3.zero, side, -side, Vector3.new(0, -1.6, 0) } do
		local hit = workspace:Raycast(position + offset, dir * reach, rayParams)
		if hit and math.abs(hit.Normal.Y) < 0.7 then
			local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
			local into = h:Dot(n)
			if into < 0 then
				h -= n * into
			end
		end
	end
	return h
end

-- Removes the outward part of `h` near the arena wall.
local function insideArena(position: Vector3, h: Vector3, dt: number): Vector3
	local ahead = position + h * math.max(dt, 1 / 60) * 2
	if Layout.InsideDistance(ahead) >= Config.Motion.WallMargin then
		return h
	end
	local n = Layout.WallNormal(ahead)
	local out = h:Dot(n)
	if out > 0 then
		h -= n * out
	end
	return h
end

local function step(a: Active, dt: number)
	local t = math.clamp((os.clock() - a.Started) / a.Duration, 0, 1)
	local v = a.Base * a.Profile(t)
	local h = Vector3.new(v.X, 0, v.Z)
	local position = a.Root.Position
	local wanted = h
	if a.Collide then
		h = alongWalls(position, h, dt)
	end
	if a.Bounded then
		h = insideArena(position, h, dt)
	end
	if (wanted - h).Magnitude > 1 then
		a.Blocked = true
	end
	local out = Vector3.new(h.X, if a.Vertical then v.Y else 0, h.Z)
	if a.Vertical then
		a.Constraint.VectorVelocity = out
	else
		a.Constraint.PlaneVelocity = Vector2.new(out.X, out.Z)
	end
	-- Also set the velocity directly: the constraint holds it against the Humanoid, and this makes sure
	-- the push moves the body from its first frame even where the constraint takes hold late
	local current = a.Root.AssemblyLinearVelocity
	a.Root.AssemblyLinearVelocity = Vector3.new(out.X, if a.Vertical then out.Y else current.Y, out.Z)
	a.Last = out
end

local function finish(a: Active, natural: boolean)
	active[a.Constraint] = nil
	if natural and a.Expected and not a.Blocked and a.Root.Parent then
		local moved = ((a.Root.Position - a.From) * Vector3.new(1, 0, 1)).Magnitude
		if moved < a.Expected * 0.4 then
			warn(string.format("[Motion] a push covered %.1f of %.1f studs - something is holding the character back", moved, a.Expected))
		end
	end
	if natural and a.Carry > 0 and a.Root.Parent then
		local keep = a.Last * a.Carry
		a.Root.AssemblyLinearVelocity = Vector3.new(keep.X, a.Root.AssemblyLinearVelocity.Y, keep.Z)
	end
	a.Constraint:Destroy()
end

local function update(dt: number)
	if next(active) == nil then
		return
	end
	refreshFilter()
	local now = os.clock()
	for lv, a in active do
		if lv.Parent == nil or a.Root.Parent == nil then
			active[lv] = nil -- ended by its move (or the character is gone)
		elseif now - a.Started >= a.Duration then
			finish(a, true)
		else
			step(a, dt)
		end
	end
end

-- Starts a push on `root` (replacing any push already running on it). Returns its LinearVelocity.
function Motion.Push(root: BasePart, spec: PushSpec): LinearVelocity
	if not connection then
		connection = RunService.PreSimulation:Connect(update)
	end
	for _, a in active do
		if a.Root == root then
			finish(a, false)
		end
	end
	local profile = Motion.Profiles[spec.Profile or "Constant"] or Motion.Profiles.Constant
	local base: Vector3
	if spec.Velocity then
		base = spec.Velocity
	else
		local dir = spec.Direction or root.CFrame.LookVector
		local flat = Vector3.new(dir.X, 0, dir.Z)
		flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero
		local peak = (spec.Distance or 0) / math.max(spec.Duration * meanOf(profile), 1e-3)
		base = flat * peak
	end
	local vertical = if spec.Vertical ~= nil then spec.Vertical else spec.Velocity ~= nil
	local lv = Instance.new("LinearVelocity")
	lv.Name = "SB_MoveVelocity"
	lv.Attachment0 = Rig.MotionAttachment(root)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	-- Pushes without a vertical speed drive only the horizontal plane, leaving gravity alone; ones
	-- with one drive the full velocity. One big force limit, so the Humanoid can't hold it back.
	lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	lv.MaxForce = Config.Motion.Force
	if vertical then
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	else
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
	end
	local a: Active = {
		Root = root,
		Constraint = lv,
		Base = base,
		Duration = math.max(spec.Duration, 1 / 60),
		Started = os.clock(),
		Profile = profile,
		Vertical = vertical,
		Bounded = spec.Bounded ~= false,
		Collide = spec.Collide ~= false,
		Carry = spec.Carry or 0,
		Last = Vector3.zero,
		From = root.Position,
		Expected = if spec.Velocity then nil else spec.Distance,
		Blocked = false,
	}
	refreshFilter()
	step(a, 1 / 60)
	lv.Parent = root
	active[lv] = a
	return lv
end

-- Ends any push on `root`.
function Motion.Stop(root: BasePart)
	for _, a in active do
		if a.Root == root then
			finish(a, false)
		end
	end
end

-- Puts `root` at `cf` right away, kept inside the arena.
function Motion.Teleport(root: BasePart, cf: CFrame)
	local position = cf.Position
	local inside = Layout.InsideDistance(position)
	local margin = Config.Motion.WallMargin
	if inside < margin then
		position -= Layout.WallNormal(position) * (margin - inside)
	end
	root.CFrame = (cf - cf.Position) + position
	root.AssemblyLinearVelocity = Vector3.zero
end

return Motion
