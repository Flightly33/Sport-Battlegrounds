--[[
	Locomotion: the base layer every character stands, walks, runs, jumps and falls with.

	Walking and running are procedural gaits: each foot follows a path (planted while in stance, lifted
	and swung forward otherwise) and the leg IK in Pose.luau bends the knees to reach it. The stride is
	derived from the actual ground speed, so feet don't slide (up to MaxStride). Feet follow the real
	direction of travel, so strafing and backpedalling work with shift-lock.

	A Style (see Styles.luau) supplies the idle pose, two gait parameter sets (walk / run) and optional
	hooks for props (dribbling, a bat on the shoulder...).
]]

local Pose = require(script.Parent.Pose)

type Pose = Pose.Pose
type Values = Pose.Values

local Locomotion = {}

export type Gait = {
	Freq: number, -- gait cycles per second (two steps per cycle)
	Stance: number, -- fraction of the cycle each foot is planted (< 0.5 = flight phase, i.e. running)
	MaxStride: number, -- max half-stride (studs from the rest position)
	Lift: number, -- swing foot height
	HeelKick: number, -- extra heel lift early in the swing (sprinting)
	KneeDrive: number, -- 0..1: how early the swing foot comes forward (high = knees lead)
	ToeOff: number, -- push-off foot pitch in degrees (negative = toes down)
	Width: number, -- extra distance between the feet
	Bob: number, -- root bounce
	Crouch: number, -- root lowered while moving
	Lean: number, -- forward lean (degrees) into the direction of travel
	HipSway: number, -- hips turning with the legs (degrees)
	Twist: number, -- shoulders counter-rotating (degrees)
	ArmSwing: number,
	ArmOut: number,
	Elbow: number,
	ElbowSwing: number,
	Head: number, -- head pitch compensation for the lean (0..1)
}

export type State = {
	Time: number, -- seconds, always increasing
	Phase: number, -- gait phase 0..1 (advanced by Locomotion.Advance)
	Speed: number, -- horizontal speed (studs/s)
	MoveDir: Vector3, -- local direction of travel (unit, relative to the root: -Z = forward)
	Move: number, -- 0..1 smoothed "is moving"
	RunBlend: number, -- 0..1 smoothed walk -> run
	Grounded: boolean,
	VerticalSpeed: number,
	Air: number, -- 0..1 smoothed in-air weight
	Land: number, -- 1 right after landing, decays to 0
	Distance: number, -- studs travelled (ball rolling)
	Awakened: boolean,
	Custom: { [string]: number }, -- per-style scratch values (dribble phase...)
}

export type Style = {
	Name: string,
	Idle: (state: State) -> Pose,
	Walk: Gait,
	Run: Gait,
	WalkSpeed: number,
	RunSpeed: number,
	-- Called after the gait pose is built: adjust arms for props, set the Prop channel.
	Props: ((pose: Pose, state: State, gaitPhase: number, moveWeight: number) -> ())?,
	-- Upper body override while moving (e.g. a ball tucked under the arm); weight 0..1 by move.
	Carry: Pose?,
}

local TAU = math.pi * 2

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function gaitLerp(a: Gait, b: Gait, t: number): Gait
	local out = {} :: any
	for k, v in a :: any do
		out[k] = lerp(v, (b :: any)[k], t)
	end
	return out :: Gait
end

function Locomotion.NewState(): State
	return {
		Time = 0,
		Phase = 0,
		Speed = 0,
		MoveDir = Vector3.new(0, 0, -1),
		Move = 0,
		RunBlend = 0,
		Grounded = true,
		VerticalSpeed = 0,
		Air = 0,
		Land = 0,
		Distance = 0,
		Awakened = false,
		Custom = {},
	}
end

-- Current gait parameters for the state's speed.
function Locomotion.GaitFor(style: Style, state: State): Gait
	return gaitLerp(style.Walk, style.Run, state.RunBlend)
end

-- Advances smoothing and the gait phase. velocity is local to the root (studs/s).
function Locomotion.Advance(style: Style, state: State, dt: number, localVelocity: Vector3, grounded: boolean)
	state.Time += dt
	local flat = Vector3.new(localVelocity.X, 0, localVelocity.Z)
	local speed = flat.Magnitude
	state.Speed = speed
	if speed > 0.5 then
		local dir = flat.Unit
		-- Smooth the direction so feet don't snap when strafing
		state.MoveDir = state.MoveDir:Lerp(dir, math.min(1, dt * 12))
		if state.MoveDir.Magnitude > 1e-3 then
			state.MoveDir = state.MoveDir.Unit
		else
			state.MoveDir = dir
		end
	end
	local moving = if grounded and speed > 1.5 then 1 else 0
	state.Move = lerp(state.Move, moving, math.min(1, dt * (if moving == 1 then 10 else 7)))
	local runTarget = math.clamp((speed - style.WalkSpeed - 1) / math.max(1, style.RunSpeed - style.WalkSpeed - 2), 0, 1)
	state.RunBlend = lerp(state.RunBlend, runTarget, math.min(1, dt * 6))

	local wasGrounded = state.Grounded
	state.Grounded = grounded
	state.VerticalSpeed = localVelocity.Y
	state.Air = lerp(state.Air, if grounded then 0 else 1, math.min(1, dt * (if grounded then 14 else 9)))
	if grounded and not wasGrounded and localVelocity.Y < -18 then
		state.Land = 1
	end
	state.Land = math.max(0, state.Land - dt * 4)

	local gait = Locomotion.GaitFor(style, state)
	if speed > 0.5 then
		-- Pick the cycle rate so the planted foot moves at ground speed, unless that makes the stride
		-- longer than MaxStride; then speed the cadence up instead (and as a last resort, slide).
		local freq = gait.Freq
		local stride = speed * gait.Stance / (2 * freq)
		if stride > gait.MaxStride then
			freq = math.min(freq * 1.35, speed * gait.Stance / (2 * gait.MaxStride))
		end
		state.Phase = (state.Phase + freq * dt) % 1
		state.Distance += speed * dt
	end
end

-- One foot's path. p = this foot's phase (0..1). Returns progress along travel (u, + = ahead), height,
-- foot pitch.
local function footPath(g: Gait, p: number, stride: number): (number, number, number)
	local st = g.Stance
	if p < st then
		local s = p / st
		local u = stride - 2 * stride * s
		local lift = if s > 0.7 then (s - 0.7) / 0.3 * 0.12 else 0
		local pitch = lerp(6, g.ToeOff, s * s)
		return u, lift, pitch
	end
	local s = (p - st) / (1 - st)
	-- Knee drive: the foot comes forward early in the swing
	local power = 1 + g.KneeDrive * 2.2
	local prog = 1 - (1 - s) ^ power
	local u = -stride + 2 * stride * prog
	local arc = math.sin(math.pi * s)
	local y = g.Lift * arc ^ 0.85 + g.HeelKick * math.sin(math.pi * math.min(1, s * 1.7)) * (1 - s)
	local pitch = lerp(g.ToeOff * 1.3, 8, math.min(1, s * 1.3))
	return u, y, pitch
end

local function addValues(pose: Pose, channel: string, v: Values)
	local cur = pose[channel]
	if not cur then
		pose[channel] = v
		return
	end
	local out = table.create(6, 0)
	for i = 1, 6 do
		out[i] = (cur[i] or 0) + (v[i] or 0)
	end
	pose[channel] = out
end
Locomotion.AddValues = addValues

local function blendInto(base: Pose, over: Pose, w: number)
	if w <= 0 then
		return
	end
	for channel, v in over do
		local cur = base[channel]
		if cur then
			base[channel] = Pose.LerpValues(cur, v, w)
		else
			base[channel] = Pose.LerpValues({ 0, 0, 0, 0, 0, 0 }, v, w)
		end
	end
end
Locomotion.BlendInto = blendInto

-- The full gait pose (not blended with idle) for the current phase.
function Locomotion.GaitPose(style: Style, state: State): (Pose, Gait)
	local g = Locomotion.GaitFor(style, state)
	local p = state.Phase
	local speed = state.Speed
	local stride = math.min(g.MaxStride, speed * g.Stance / (2 * math.max(g.Freq, 0.1)))
	stride = math.max(stride, 0.35)
	local dir = state.MoveDir
	local dx, dz = dir.X, dir.Z

	local pose: Pose = {}
	local function foot(phase: number, side: number): Values
		local u, y, pitch = footPath(g, phase % 1, stride)
		-- u is along the travel direction; travel direction (dx, dz) with -z forward
		local x = dx * u + side * g.Width
		local z = dz * u
		-- Keep the feet apart when strafing (legs crossing looks broken)
		x += side * math.abs(dx) * 0.25
		return { x, y, z, pitch }
	end
	pose.RFoot = foot(p, 1)
	pose.LFoot = foot(p + 0.5, -1)

	local c = math.cos(TAU * p)
	local bobWave = -math.cos(TAU * 2 * (p - g.Stance / 2))
	local forward = -dz
	local lateral = dx
	pose.Root = {
		-g.Lean * forward,
		g.HipSway * c,
		-g.Lean * 0.6 * lateral,
		0,
		-g.Crouch + g.Bob * bobWave,
		0,
	}
	pose.Waist = { -g.Lean * 0.35 * math.abs(forward), -(g.HipSway + g.Twist) * c, 0 }
	pose.Neck = { g.Lean * g.Head * math.abs(forward) * 1.1, g.Twist * 0.5 * c, 0 }

	local swing = g.ArmSwing * c
	pose.RightShoulder = { -swing - g.Lean * 0.2, 0, g.ArmOut }
	pose.LeftShoulder = { swing - g.Lean * 0.2, 0, -g.ArmOut }
	pose.RightElbow = { g.Elbow + g.ElbowSwing * math.max(0, -c), 0, 0 }
	pose.LeftElbow = { g.Elbow + g.ElbowSwing * math.max(0, c), 0, 0 }
	pose.RightWrist = { 0, 0, 0 }
	pose.LeftWrist = { 0, 0, 0 }
	return pose, g
end

local JUMP: Pose = {
	Root = { 4, 0, 0, 0, 0.1, 0 },
	RFoot = { 0.1, 0.9, -0.5, -10 },
	LFoot = { -0.1, 0.25, 0.35, -30 },
	Waist = { -6, 0, 0 },
	RightShoulder = { 40, 0, 25 },
	LeftShoulder = { 25, 0, -30 },
	RightElbow = { 40 },
	LeftElbow = { 35 },
	Neck = { 8 },
}

local FALL: Pose = {
	Root = { 6, 0, 0, 0, 0, 0 },
	RFoot = { 0.15, 0.45, -0.35, -15 },
	LFoot = { -0.15, 0.6, 0.2, -25 },
	Waist = { 4, 0, 0 },
	RightShoulder = { 30, 0, 70 },
	LeftShoulder = { 20, 0, -75 },
	RightElbow = { 25 },
	LeftElbow = { 25 },
	Neck = { -6 },
}

local LAND: Pose = {
	Root = { -14, 0, 0, 0, -0.75, 0 },
	RFoot = { 0.15, 0, -0.15, 0 },
	LFoot = { -0.15, 0, 0.2, 0 },
	Waist = { -10, 0, 0 },
	RightShoulder = { 20, 0, 35 },
	LeftShoulder = { 20, 0, -35 },
	RightElbow = { 30 },
	LeftElbow = { 30 },
	Neck = { 14 },
}

-- The base pose for this frame: idle <-> gait by movement, plus air and landing.
function Locomotion.Evaluate(style: Style, state: State): Pose
	local pose = style.Idle(state)
	local move = state.Move
	local gaitPhase = state.Phase
	if move > 0.01 then
		local gait = Locomotion.GaitPose(style, state)
		if style.Carry then
			blendInto(gait, style.Carry, 1)
		end
		blendInto(pose, gait, move)
	end
	if style.Props then
		style.Props(pose, state, gaitPhase, move)
	end
	if state.Air > 0.01 then
		local air = if state.VerticalSpeed > 4 then JUMP else FALL
		blendInto(pose, air, state.Air)
	end
	if state.Land > 0.01 then
		blendInto(pose, LAND, state.Land * (1 - state.Air))
	end
	return pose
end

return Locomotion
