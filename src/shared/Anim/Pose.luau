--[[
	Pose: keyframed clips, two-bone leg IK and blending for the procedural animator.

	Authoring format (degrees and studs, in the parent part's frame - see Rig.luau):
		RightHip = { rx, ry, rz, px, py, pz }      any trailing values may be left out
		RFoot / LFoot = { x, y, z, pitch }         IK target: the ankle's offset from where it is standing
		                                           still, in the HumanoidRootPart's frame (-z = forward,
		                                           y = up), plus the foot's pitch (+ = toes up)
	A clip is a list of keys { time, pose, ease? }. Joints that appear in any key are the clip's
	channels; a channel missing from one key is at rest (0) in that key. Joints that are in no key at
	all are left to the layer underneath (so an arm-only clip doesn't touch the legs).

	Each layer is resolved to CFrames (IK solved) and layers are blended with CFrame:Lerp.
]]

local Rig = require(script.Parent.Rig)

type RigInfo = Rig.RigInfo

local Pose = {}

export type Values = { number }
export type Pose = { [string]: Values }
export type EaseName = "Linear" | "In" | "Out" | "InOut" | "OutBack" | "OutExpo" | "InExpo" | "Hold" | "Snap"
export type Key = { T: number, Pose: Pose, Ease: EaseName }
export type Clip = {
	Name: string,
	Length: number,
	Loop: boolean,
	Keys: { Key },
	Channels: { string }, -- resolved joint names this clip drives
	Raw: { string }, -- authored channel names (incl. RFoot/LFoot)
	FadeIn: number,
	FadeOut: number,
}
export type Resolved = { [string]: CFrame }

local RAD = math.pi / 180
local ZERO: Values = { 0, 0, 0, 0, 0, 0 }

local LEG = {
	RFoot = { Side = "R", Hip = "RightHip", Knee = "RightKnee", Ankle = "RightAnkle" },
	LFoot = { Side = "L", Hip = "LeftHip", Knee = "LeftKnee", Ankle = "LeftAnkle" },
}
Pose.LEG = LEG

--------------------------------------------------------------------------------
-- Easing
--------------------------------------------------------------------------------
local EASE: { [string]: (number) -> number } = {
	Linear = function(a)
		return a
	end,
	In = function(a)
		return a * a
	end,
	Out = function(a)
		return 1 - (1 - a) * (1 - a)
	end,
	InOut = function(a)
		return 0.5 - math.cos(a * math.pi) / 2
	end,
	OutBack = function(a)
		local c = 1.9
		local x = a - 1
		return 1 + (c + 1) * x * x * x + c * x * x
	end,
	OutExpo = function(a)
		return if a >= 1 then 1 else 1 - 2 ^ (-10 * a)
	end,
	InExpo = function(a)
		return if a <= 0 then 0 else 2 ^ (10 * a - 10)
	end,
	Hold = function(a)
		return if a >= 1 then 1 else 0
	end,
	Snap = function(a)
		local x = 1 - a
		return 1 - x * x * x
	end,
}
Pose.Ease = EASE

--------------------------------------------------------------------------------
-- Clips
--------------------------------------------------------------------------------
export type ClipOptions = { Loop: boolean?, FadeIn: number?, FadeOut: number? }

-- Pose.Clip("Name", { Loop = true }, { { 0, poseA }, { 0.2, poseB, "Out" }, ... })
function Pose.Clip(name: string, options: ClipOptions, keys: { { any } }): Clip
	local list: { Key } = {}
	local raw: { [string]: boolean } = {}
	for _, k in keys do
		local pose = k[2] :: Pose
		table.insert(list, { T = k[1] :: number, Pose = pose, Ease = (k[3] or "InOut") :: EaseName })
		for channel in pose do
			raw[channel] = true
		end
	end
	table.sort(list, function(a, b)
		return a.T < b.T
	end)
	local channels: { string } = {}
	local rawList: { string } = {}
	for channel in raw do
		table.insert(rawList, channel)
		local leg = LEG[channel]
		if leg then
			table.insert(channels, leg.Hip)
			table.insert(channels, leg.Knee)
			table.insert(channels, leg.Ankle)
		else
			table.insert(channels, channel)
		end
	end
	if raw.RFoot or raw.LFoot then
		-- IK depends on where the hips are
		if not raw.Root then
			table.insert(rawList, "Root")
			table.insert(channels, "Root")
		end
	end
	return {
		Name = name,
		Length = if #list > 0 then list[#list].T else 0,
		Loop = options.Loop == true,
		Keys = list,
		Channels = channels,
		Raw = rawList,
		FadeIn = options.FadeIn or 0.07,
		FadeOut = options.FadeOut or 0.15,
	}
end

local function lerpValues(a: Values, b: Values, alpha: number): Values
	local out = table.create(6, 0)
	for i = 1, 6 do
		local va = a[i] or 0
		out[i] = va + ((b[i] or 0) - va) * alpha
	end
	return out
end
Pose.LerpValues = lerpValues

-- Samples a clip at time t (seconds). Returns the authored channels only.
function Pose.Sample(clip: Clip, t: number): Pose
	local keys = clip.Keys
	local out: Pose = {}
	if #keys == 0 then
		return out
	end
	if clip.Loop and clip.Length > 0 then
		t = t % clip.Length
	else
		t = math.clamp(t, 0, clip.Length)
	end
	local a, b = keys[1], keys[1]
	for i = 1, #keys do
		if keys[i].T <= t then
			a = keys[i]
			b = keys[i + 1] or keys[i]
		end
	end
	local alpha = 0
	if b ~= a and b.T > a.T then
		alpha = EASE[b.Ease]((t - a.T) / (b.T - a.T))
	end
	for _, channel in clip.Raw do
		out[channel] = lerpValues(a.Pose[channel] or ZERO, b.Pose[channel] or ZERO, alpha)
	end
	return out
end

--------------------------------------------------------------------------------
-- Resolving to CFrames
--------------------------------------------------------------------------------
function Pose.ToCFrame(v: Values, scale: number?): CFrame
	local s = scale or 1
	return CFrame.new((v[4] or 0) * s, (v[5] or 0) * s, (v[6] or 0) * s)
		* CFrame.Angles((v[1] or 0) * RAD, (v[2] or 0) * RAD, (v[3] or 0) * RAD)
end

-- Where a joint puts its child part, in the parent's frame, for a pose rotation `l`.
local function childOffset(joint: Rig.JointInfo, l: CFrame): CFrame
	return CFrame.new(joint.C0.Position) * l * joint.Q0 * joint.C1:Inverse()
end

local function solveLeg(rig: RigInfo, out: Resolved, target: Values, legName: string)
	local leg = LEG[legName]
	local side = leg.Side
	local hipJ = rig.Joints[leg.Hip]
	local rootJ = rig.Joints.Root
	if not hipJ or not rootJ then
		return
	end
	local rootLocal = out.Root or CFrame.identity
	local lowerTorso = childOffset(rootJ, rootLocal) -- LowerTorso in root (HRP) space

	local scale = rig.Scale
	local rest = if side == "R" then rig.RestAnkle.R else rig.RestAnkle.L
	local goal = rest + Vector3.new((target[1] or 0) * scale, (target[2] or 0) * scale, (target[3] or 0) * scale)
	local local_ = lowerTorso:PointToObjectSpace(goal)
	local hip = if side == "R" then rig.Hip.R else rig.Hip.L
	local a = if side == "R" then rig.Thigh.R else rig.Thigh.L
	local b = if side == "R" then rig.Shin.R else rig.Shin.L

	local v = local_ - hip
	local d = math.clamp(v.Magnitude, math.abs(a - b) + 0.02, (a + b) * 0.9995)
	local dir = if v.Magnitude > 1e-4 then v.Unit else Vector3.new(0, -1, 0)

	local theta = math.asin(math.clamp(-dir.Z, -1, 1))
	local phi = math.atan2(dir.X, -dir.Y)
	local alpha = math.acos(math.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1))
	local kneeInterior = math.acos(math.clamp((a * a + b * b - d * d) / (2 * a * b), -1, 1))
	local bend = math.pi - kneeInterior

	local hipRot = CFrame.Angles(0, 0, phi) * CFrame.Angles(theta + alpha, 0, 0)
	local kneeRot = CFrame.Angles(-bend, 0, 0)
	-- Keep the foot level with the ground (root frame), then add the requested pitch
	local chain = (lowerTorso - lowerTorso.Position) * hipRot * kneeRot
	local ankleRot = chain:Inverse() * CFrame.Angles((target[4] or 0) * RAD, 0, 0)

	out[leg.Hip] = hipRot
	out[leg.Knee] = kneeRot
	out[leg.Ankle] = ankleRot
end

-- Turns a sampled pose into joint CFrames (pose rotations in the parent's frame), solving IK.
function Pose.Resolve(rig: RigInfo, pose: Pose, into: Resolved?): Resolved
	local out: Resolved = into or {}
	local scale = rig.Scale
	local root = pose.Root
	if root then
		out.Root = Pose.ToCFrame(root, scale)
	end
	for channel, v in pose do
		if channel ~= "Root" and not LEG[channel] then
			out[channel] = Pose.ToCFrame(v, scale)
		end
	end
	if pose.RFoot then
		solveLeg(rig, out, pose.RFoot, "RFoot")
	end
	if pose.LFoot then
		solveLeg(rig, out, pose.LFoot, "LFoot")
	end
	return out
end

-- Blends `over` onto `base` (in place) for the given channels.
function Pose.Blend(base: Resolved, over: Resolved, channels: { string }, weight: number)
	if weight <= 0 then
		return
	end
	for _, channel in channels do
		local o = over[channel]
		if o then
			local b = base[channel]
			if weight >= 1 or not b then
				base[channel] = o
			else
				base[channel] = b:Lerp(o, weight)
			end
		end
	end
end

-- Additive offsets (flinches, head look): base[c] = base[c] * add[c]
function Pose.Add(base: Resolved, add: Resolved)
	for channel, cf in add do
		base[channel] = (base[channel] or CFrame.identity) * cf
	end
end

--------------------------------------------------------------------------------
-- Small authoring helpers
--------------------------------------------------------------------------------
-- One clip key (for building key lists in loops).
function Pose.Key(t: number, pose: Pose, ease: EaseName?): { any }
	return { t, pose, ease }
end

-- Mirrors a pose left <-> right (for alternating kicks / punches).
local MIRROR_NAMES: { [string]: string } = {
	RightShoulder = "LeftShoulder",
	RightElbow = "LeftElbow",
	RightWrist = "LeftWrist",
	RightHip = "LeftHip",
	RightKnee = "LeftKnee",
	RightAnkle = "LeftAnkle",
	RFoot = "LFoot",
}
for k, v in table.clone(MIRROR_NAMES) do
	MIRROR_NAMES[v] = k
end

function Pose.Mirror(pose: Pose): Pose
	local out: Pose = {}
	for channel, v in pose do
		local name = MIRROR_NAMES[channel] or channel
		if channel == "RFoot" or channel == "LFoot" then
			out[name] = { -(v[1] or 0), v[2] or 0, v[3] or 0, v[4] or 0 }
		else
			-- Mirror across the X=0 plane: keep pitch, negate yaw and roll, negate x offset
			out[name] = { v[1] or 0, -(v[2] or 0), -(v[3] or 0), -(v[4] or 0), v[5] or 0, v[6] or 0 }
		end
	end
	return out
end

function Pose.MirrorClip(clip: Clip, name: string): Clip
	local keys: { { any } } = {}
	for _, k in clip.Keys do
		local entry: { any } = { k.T, Pose.Mirror(k.Pose), k.Ease }
		table.insert(keys, entry)
	end
	return Pose.Clip(name, { Loop = clip.Loop, FadeIn = clip.FadeIn, FadeOut = clip.FadeOut }, keys)
end

-- Merges poses left to right (later wins) - for building keys from shared pieces.
function Pose.Merge(...: Pose): Pose
	local out: Pose = {}
	for i = 1, select("#", ...) do
		local p = select(i, ...)
		for k, v in p do
			out[k] = v
		end
	end
	return out
end

return Pose
