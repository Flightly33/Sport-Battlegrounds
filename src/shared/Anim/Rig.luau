--[[
	Rig: the R15 joints the procedural animator drives, read from a live character (or from a spec table
	in the offline previewer).

	Pose rotations are authored in the PARENT part's frame (X = pitch, +X swings a hanging limb forward;
	Y = twist, +Y turns left; Z = roll, +Z swings a right limb outwards). Some avatar packages rotate their
	rig attachments, so every Transform is conjugated by the joint's C0 rotation:
		Part1 = Part0 * C0 * (Q0^-1 * R * Q0) * C1^-1  ==  Part0 * P0 * R * (rest)
	which makes the same pose look the same on every body.

	Current Roblox avatars are jointed with AnimationConstraints (an AnimationConstraint's C0 / C1 are
	its two attachments); older rigs and the props use Motor6Ds. Both are read the same way and both
	take their pose through .Transform.
]]

local Rig = {}

-- Name of the attachment on the HumanoidRootPart that dashes, lunges and knockback push on. Ours,
-- so movement never depends on which attachments an avatar happens to come with.
Rig.MOTION_ATTACHMENT = "SB_Motion"

export type JointInfo = {
	Name: string,
	Part0: string,
	Part1: string,
	C0: CFrame,
	C1: CFrame,
	Q0: CFrame,
	Q0Inv: CFrame,
	Motor: Motor6D?, -- whichever drives the joint: a Motor6D...
	Constraint: AnimationConstraint?, -- ...or an AnimationConstraint
}

export type RigInfo = {
	Joints: { [string]: JointInfo },
	Order: { string },
	Thigh: { R: number, L: number },
	Shin: { R: number, L: number },
	Hip: { R: Vector3, L: Vector3 }, -- hip pivot in LowerTorso space
	RestAnkle: { R: Vector3, L: Vector3 }, -- ankle pivot in HumanoidRootPart space with no pose
	AnkleToSole: number,
	Scale: number, -- ~1 for a default-height avatar; poses' translations are multiplied by it
}

-- Joint name -> { Part1 name, Motor6D name }. Order matters: parents before children (for FK).
Rig.JOINTS = {
	{ "Root", "LowerTorso", "Root" },
	{ "Waist", "UpperTorso", "Waist" },
	{ "Neck", "Head", "Neck" },
	{ "RightShoulder", "RightUpperArm", "RightShoulder" },
	{ "RightElbow", "RightLowerArm", "RightElbow" },
	{ "RightWrist", "RightHand", "RightWrist" },
	{ "LeftShoulder", "LeftUpperArm", "LeftShoulder" },
	{ "LeftElbow", "LeftLowerArm", "LeftElbow" },
	{ "LeftWrist", "LeftHand", "LeftWrist" },
	{ "RightHip", "RightUpperLeg", "RightHip" },
	{ "RightKnee", "RightLowerLeg", "RightKnee" },
	{ "RightAnkle", "RightFoot", "RightAnkle" },
	{ "LeftHip", "LeftUpperLeg", "LeftHip" },
	{ "LeftKnee", "LeftLowerLeg", "LeftKnee" },
	{ "LeftAnkle", "LeftFoot", "LeftAnkle" },
	-- Props (balls, bats) hang off a Motor6D called SB_Prop inside the prop's handle.
	{ "Prop", "SB_PropHandle", "SB_Prop" },
}

local function rotationOf(cf: CFrame): CFrame
	return cf - cf.Position
end

local function makeJoint(name: string, part0: string, part1: string, c0: CFrame, c1: CFrame, motor: Motor6D?, constraint: AnimationConstraint?): JointInfo
	local q0 = rotationOf(c0)
	return {
		Name = name,
		Part0 = part0,
		Part1 = part1,
		C0 = c0,
		C1 = c1,
		Q0 = q0,
		Q0Inv = q0:Inverse(),
		Motor = motor,
		Constraint = constraint,
	}
end

local function isJoint(x: Instance): boolean
	return x:IsA("AnimationConstraint") or x:IsA("Motor6D")
end
Rig.IsJoint = isJoint

-- Part0, Part1, C0, C1 of either kind of joint.
local function jointFrames(joint: Instance): (BasePart?, BasePart?, CFrame, CFrame)
	if joint:IsA("Motor6D") then
		return joint.Part0, joint.Part1, joint.C0, joint.C1
	elseif joint:IsA("AnimationConstraint") then
		local a0, a1 = joint.Attachment0, joint.Attachment1
		if a0 and a1 then
			local p0, p1 = a0.Parent, a1.Parent
			if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
				return p0, p1, a0.CFrame, a1.CFrame
			end
		end
	end
	return nil, nil, CFrame.identity, CFrame.identity
end

-- The joint that drives `part1`: normally inside it and named after the joint; failing that, any
-- joint in the character whose Part1 it is (AnimationConstraints first, as Roblox recommends).
local function findJoint(character: Instance, part1: BasePart, name: string): Instance?
	local direct = part1:FindFirstChild(name)
	if direct and isJoint(direct) then
		local _, p1 = jointFrames(direct)
		if p1 == part1 then
			return direct
		end
	end
	local fallback: Instance? = nil
	for _, d in character:GetDescendants() do
		if isJoint(d) then
			local _, p1 = jointFrames(d)
			if p1 == part1 then
				if d:IsA("AnimationConstraint") then
					return d
				end
				fallback = fallback or d
			end
		end
	end
	return fallback
end

-- Leg lengths, hip pivots and rest ankle positions, computed from the joints.
local function finish(joints: { [string]: JointInfo }, order: { string }): RigInfo?
	local root, rHip, rKnee, rAnkle = joints.Root, joints.RightHip, joints.RightKnee, joints.RightAnkle
	local lHip, lKnee, lAnkle = joints.LeftHip, joints.LeftKnee, joints.LeftAnkle
	if not (root and rHip and rKnee and rAnkle and lHip and lKnee and lAnkle) then
		return nil
	end
	local thighR = (rKnee.C0.Position - rHip.C1.Position).Magnitude
	local shinR = (rAnkle.C0.Position - rKnee.C1.Position).Magnitude
	local thighL = (lKnee.C0.Position - lHip.C1.Position).Magnitude
	local shinL = (lAnkle.C0.Position - lKnee.C1.Position).Magnitude

	-- Rest FK in root space (HumanoidRootPart frame)
	local lowerTorso = root.C0 * root.C1:Inverse()
	local function restAnkle(hip: JointInfo, knee: JointInfo, ankle: JointInfo): Vector3
		local upper = lowerTorso * hip.C0 * hip.C1:Inverse()
		local lower = upper * knee.C0 * knee.C1:Inverse()
		return (lower * ankle.C0).Position
	end
	local ankleR = restAnkle(rHip, rKnee, rAnkle)
	local ankleL = restAnkle(lHip, lKnee, lAnkle)
	local legLength = thighR + shinR
	return {
		Joints = joints,
		Order = order,
		Thigh = { R = thighR, L = thighL },
		Shin = { R = shinR, L = shinL },
		Hip = { R = rHip.C0.Position, L = lHip.C0.Position },
		RestAnkle = { R = ankleR, L = ankleL },
		AnkleToSole = 0.25, -- refined by FromCharacter
		Scale = legLength / 1.9,
	}
end

-- Live character (client). Returns nil until the character has all of its joints.
function Rig.FromCharacter(character: Model): RigInfo?
	local joints: { [string]: JointInfo } = {}
	local order: { string } = {}
	for _, def in Rig.JOINTS do
		local name, part1Name, motorName = def[1], def[2], def[3]
		local part1 = character:FindFirstChild(part1Name, name == "Prop")
		if part1 and part1:IsA("BasePart") then
			local joint = findJoint(character, part1, motorName)
			if joint then
				local part0, _, c0, c1 = jointFrames(joint)
				if part0 then
					local motor = if joint:IsA("Motor6D") then joint else nil
					local constraint = if joint:IsA("AnimationConstraint") then joint else nil
					joints[name] = makeJoint(name, part0.Name, part1.Name, c0, c1, motor, constraint)
					table.insert(order, name)
				end
			end
		end
	end
	local rig = finish(joints, order)
	if rig then
		local foot = character:FindFirstChild("RightFoot")
		local ankle = joints.RightAnkle
		if foot and foot:IsA("BasePart") and ankle then
			-- Ankle pivot height above the sole of the foot
			rig.AnkleToSole = math.max(0.05, foot.Size.Y / 2 + ankle.C1.Position.Y)
		end
	end
	return rig
end

export type JointSpec = { Part0: string, Part1: string, C0: CFrame, C1: CFrame }

-- Offline previewer: build from a plain table of joints (same names as Rig.JOINTS).
function Rig.FromSpec(spec: { [string]: JointSpec }): RigInfo?
	local joints: { [string]: JointInfo } = {}
	local order: { string } = {}
	for _, def in Rig.JOINTS do
		local s = spec[def[1]]
		if s then
			joints[def[1]] = makeJoint(def[1], s.Part0, s.Part1, s.C0, s.C1, nil)
			table.insert(order, def[1])
		end
	end
	return finish(joints, order)
end

-- Turns a pose rotation/offset (in the parent's frame) into the Motor6D.Transform for that joint.
function Rig.ToTransform(joint: JointInfo, local_: CFrame): CFrame
	return joint.Q0Inv * local_ * joint.Q0
end

-- Writes a joint's Transform, whichever kind of joint it is.
function Rig.SetTransform(joint: JointInfo, transform: CFrame)
	local constraint = joint.Constraint
	if constraint then
		constraint.Transform = transform
		return
	end
	local motor = joint.Motor
	if motor then
		motor.Transform = transform
	end
end

-- The attachment movement pushes on (created if the avatar doesn't have it yet).
function Rig.MotionAttachment(root: BasePart): Attachment
	local existing = root:FindFirstChild(Rig.MOTION_ATTACHMENT)
	if existing and existing:IsA("Attachment") then
		return existing
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = Rig.MOTION_ATTACHMENT
	attachment.Parent = root
	return attachment
end

-- Server, on spawn: joints follow the animator exactly (kinematic) and the root gets its motion
-- attachment before the character replicates, so every client sees the same one.
function Rig.Prepare(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("AnimationConstraint") then
			d.IsKinematic = true
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		Rig.MotionAttachment(root)
	end
end

-- Forward kinematics (previewer and debug): world CFrame of every part given the root's CFrame.
function Rig.SolveWorld(rig: RigInfo, transforms: { [string]: CFrame }, rootCFrame: CFrame): { [string]: CFrame }
	local parts: { [string]: CFrame } = { HumanoidRootPart = rootCFrame }
	for _, name in rig.Order do
		local joint = rig.Joints[name]
		local parent = parts[joint.Part0]
		if parent then
			local t = transforms[name] or CFrame.identity
			parts[joint.Part1] = parent * joint.C0 * t * joint.C1:Inverse()
		end
	end
	return parts
end

return Rig
