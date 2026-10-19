--[[
	Clips every fighter uses: block, hit stun, knockdown, dashes, evasive, ankle-broken kneel.
	Conventions are in Pose.luau / Rig.luau (+X swings a limb forward, -X on a knee bends it, ...).
]]

local Pose = require(script.Parent.Parent.Pose)

local Clip = Pose.Clip

local Common = {}

Common.Block = Clip("Block", { Loop = true, FadeIn = 0.06 }, {
	{ 0, {
		Root = { -6, 0, 0, 0, -0.4, 0 },
		RFoot = { 0.32, 0, 0.35, 0 },
		LFoot = { -0.32, 0, -0.35, 0 },
		Waist = { -8, 0, 0 },
		Neck = { -12, 0, 0 },
		RightShoulder = { 78, -8, -24 },
		RightElbow = { 112 },
		RightWrist = { 0, 0, 10 },
		LeftShoulder = { 70, 8, 24 },
		LeftElbow = { 118 },
		LeftWrist = { 0, 0, -10 },
	} },
	{ 0.6, {
		Root = { -6, 0, 0, 0, -0.44, 0 },
		RFoot = { 0.32, 0, 0.35, 0 },
		LFoot = { -0.32, 0, -0.35, 0 },
		Waist = { -9, 0, 0 },
		Neck = { -12, 0, 0 },
		RightShoulder = { 80, -8, -24 },
		RightElbow = { 112 },
		RightWrist = { 0, 0, 10 },
		LeftShoulder = { 72, 8, 24 },
		LeftElbow = { 118 },
		LeftWrist = { 0, 0, -10 },
	} },
	{ 1.2, {
		Root = { -6, 0, 0, 0, -0.4, 0 },
		RFoot = { 0.32, 0, 0.35, 0 },
		LFoot = { -0.32, 0, -0.35, 0 },
		Waist = { -8, 0, 0 },
		Neck = { -12, 0, 0 },
		RightShoulder = { 78, -8, -24 },
		RightElbow = { 112 },
		RightWrist = { 0, 0, 10 },
		LeftShoulder = { 70, 8, 24 },
		LeftElbow = { 118 },
		LeftWrist = { 0, 0, -10 },
	} },
})

local STAGGER_A = {
	Root = { 10, 0, 0, 0, -0.3, 0.15 },
	RFoot = { 0.28, 0, 0.15, 0 },
	LFoot = { -0.28, 0, -0.1, 0 },
	Waist = { 14, 0, 3 },
	Neck = { 22, 0, -6 },
	RightShoulder = { -14, 0, 24 },
	RightElbow = { 22 },
	LeftShoulder = { -8, 0, -28 },
	LeftElbow = { 18 },
}
local STAGGER_B = Pose.Merge(STAGGER_A, {
	Waist = { 9, 0, -3 },
	Neck = { 14, 0, 5 },
	RightShoulder = { -8, 0, 30 },
	LeftShoulder = { -14, 0, -22 },
})
Common.Stagger = Clip("Stagger", { Loop = true, FadeIn = 0.04 }, {
	{ 0, STAGGER_A },
	{ 0.35, STAGGER_B },
	{ 0.7, STAGGER_A },
})

-- Lying on the back (the HumanoidRootPart stays upright; the body is rotated around the hips)
Common.Knockdown = Clip("Knockdown", { Loop = true, FadeIn = 0.08 }, {
	{ 0, {
		Root = { 88, 0, 0, 0, -1.55, 0.6 },
		Waist = { 4, 0, 0 },
		Neck = { -10, 25, 0 },
		RightShoulder = { 20, 0, 70 },
		RightElbow = { 40 },
		LeftShoulder = { 60, 0, -55 },
		LeftElbow = { 70 },
		RightHip = { 12, 0, 10 },
		RightKnee = { -30 },
		RightAnkle = { 10 },
		LeftHip = { 30, 0, -6 },
		LeftKnee = { -70 },
		LeftAnkle = { 20 },
	} },
	{ 1.5, {
		Root = { 88, 0, 0, 0, -1.55, 0.6 },
		Waist = { 6, 0, 0 },
		Neck = { -8, 20, 0 },
		RightShoulder = { 20, 0, 72 },
		RightElbow = { 40 },
		LeftShoulder = { 60, 0, -55 },
		LeftElbow = { 72 },
		RightHip = { 12, 0, 10 },
		RightKnee = { -32 },
		RightAnkle = { 10 },
		LeftHip = { 30, 0, -6 },
		LeftKnee = { -70 },
		LeftAnkle = { 20 },
	} },
	{ 3, {
		Root = { 88, 0, 0, 0, -1.55, 0.6 },
		Waist = { 4, 0, 0 },
		Neck = { -10, 25, 0 },
		RightShoulder = { 20, 0, 70 },
		RightElbow = { 40 },
		LeftShoulder = { 60, 0, -55 },
		LeftElbow = { 70 },
		RightHip = { 12, 0, 10 },
		RightKnee = { -30 },
		RightAnkle = { 10 },
		LeftHip = { 30, 0, -6 },
		LeftKnee = { -70 },
		LeftAnkle = { 20 },
	} },
})

-- Ankle broken: dropped to one knee
Common.Kneel = Clip("Kneel", { FadeIn = 0.05, FadeOut = 0.25 }, {
	{ 0, {
		Root = { -4, 0, 6, 0, -0.2, 0 },
		RFoot = { 0.3, 0, 0, 0 },
		LFoot = { -0.3, 0, 0, 0 },
		Waist = { -10, 0, 0 },
		Neck = { -10 },
	} },
	{ 0.12, {
		Root = { -8, 10, 12, 0.3, -1.3, 0 },
		RFoot = { 0.35, 0.15, 1.15, -75 },
		LFoot = { -0.3, 0, -0.55, 0 },
		Waist = { -18, 0, -6 },
		Neck = { -22, 0, 8 },
		RightShoulder = { -10, 0, 25 },
		LeftShoulder = { 30, 0, -10 },
		LeftElbow = { 30 },
	}, "Out" },
	{ 1.3, {
		Root = { -8, 10, 12, 0.3, -1.3, 0 },
		RFoot = { 0.35, 0.15, 1.15, -75 },
		LFoot = { -0.3, 0, -0.55, 0 },
		Waist = { -16, 0, -6 },
		Neck = { -18, 0, 8 },
		RightShoulder = { -10, 0, 25 },
		LeftShoulder = { 30, 0, -10 },
		LeftElbow = { 30 },
	} },
})

local function dash(name: string, lean: { number }, rFoot: { number }, lFoot: { number }, arms: { number }): Pose.Clip
	local pose = {
		Root = lean,
		RFoot = rFoot,
		LFoot = lFoot,
		Waist = { lean[1] * 0.4, 0, lean[3] * 0.4 },
		RightShoulder = { arms[1], 0, arms[2] },
		LeftShoulder = { arms[1], 0, -arms[2] },
		RightElbow = { 20 },
		LeftElbow = { 20 },
		Neck = { -lean[1] * 0.6, 0, -lean[3] * 0.5 },
	}
	return Clip(name, { FadeIn = 0.03, FadeOut = 0.12 }, {
		{ 0, pose },
		{ 0.24, pose },
	})
end

Common.DashFront = dash("DashFront", { -30, 0, 0, 0, -0.35, 0 }, { 0.1, 0.55, 0.9, -40 }, { -0.1, 0.15, -0.5, 0 }, { -55, 12 })
Common.DashBack = dash("DashBack", { 18, 0, 0, 0, -0.3, 0 }, { 0.2, 0.3, -0.7, 20 }, { -0.2, 0.05, 0.4, 0 }, { 30, 30 })
Common.DashLeft = dash("DashLeft", { -6, 0, 22, 0, -0.3, 0 }, { 0.6, 0.35, 0, 0 }, { -0.1, 0.05, 0, 0 }, { 10, 45 })
Common.DashRight = dash("DashRight", { -6, 0, -22, 0, -0.3, 0 }, { 0.1, 0.05, 0, 0 }, { -0.6, 0.35, 0, 0 }, { 10, 45 })

-- Evasive: a quick backflip out of the combo
Common.Evasive = Clip("Evasive", { FadeIn = 0.02, FadeOut = 0.1 }, {
	{ 0, { Root = { 0, 0, 0, 0, -0.5, 0 }, RFoot = { 0.2, 0, 0, 0 }, LFoot = { -0.2, 0, 0, 0 }, RightShoulder = { 60, 0, 40 }, LeftShoulder = { 60, 0, -40 } } },
	{ 0.12, { Root = { 120, 0, 0, 0, 0.6, 0 }, RightHip = { 100 }, RightKnee = { -120 }, LeftHip = { 100 }, LeftKnee = { -120 }, RightShoulder = { 150, 0, 20 }, LeftShoulder = { 150, 0, -20 } }, "Linear" },
	{ 0.26, { Root = { 300, 0, 0, 0, 0.4, 0 }, RightHip = { 90 }, RightKnee = { -110 }, LeftHip = { 90 }, LeftKnee = { -110 }, RightShoulder = { 90, 0, 60 }, LeftShoulder = { 90, 0, -60 } }, "Linear" },
	{ 0.36, { Root = { 360, 0, 0, 0, -0.3, 0 }, RightHip = { 30 }, RightKnee = { -50 }, LeftHip = { 30 }, LeftKnee = { -50 }, RightShoulder = { 20, 0, 50 }, LeftShoulder = { 20, 0, -50 } }, "Out" },
})

-- Held in a grab
Common.Grabbed = Clip("Grabbed", { Loop = true, FadeIn = 0.05 }, {
	{ 0, { Root = { 15, 0, 0, 0, 0.2, 0 }, Waist = { 15 }, Neck = { 25 }, RightShoulder = { 60, 0, 60 }, LeftShoulder = { 40, 0, -70 }, RightHip = { 30 }, RightKnee = { -50 }, LeftHip = { -10 }, LeftKnee = { -30 } } },
	{ 0.2, { Root = { 15, 0, 0, 0, 0.2, 0 }, Waist = { 18 }, Neck = { 20 }, RightShoulder = { 40, 0, 75 }, LeftShoulder = { 60, 0, -55 }, RightHip = { -10 }, RightKnee = { -30 }, LeftHip = { 30 }, LeftKnee = { -50 } } },
	{ 0.4, { Root = { 15, 0, 0, 0, 0.2, 0 }, Waist = { 15 }, Neck = { 25 }, RightShoulder = { 60, 0, 60 }, LeftShoulder = { 40, 0, -70 }, RightHip = { 30 }, RightKnee = { -50 }, LeftHip = { -10 }, LeftKnee = { -30 } } },
})

-- Generic power-up (used if a class has no awakening clip)
Common.PowerUp = Clip("PowerUp", { FadeIn = 0.1, FadeOut = 0.3 }, {
	{ 0, { Root = { -10, 0, 0, 0, -0.6, 0 }, RFoot = { 0.4, 0, 0, 0 }, LFoot = { -0.4, 0, 0, 0 }, Waist = { -20 }, Neck = { -20 }, RightShoulder = { 30, 0, 20 }, LeftShoulder = { 30, 0, -20 }, RightElbow = { 110 }, LeftElbow = { 110 } } },
	{ 0.8, { Root = { -14, 0, 0, 0, -0.7, 0 }, RFoot = { 0.4, 0, 0, 0 }, LFoot = { -0.4, 0, 0, 0 }, Waist = { -26 }, Neck = { -24 }, RightShoulder = { 20, 0, 30 }, LeftShoulder = { 20, 0, -30 }, RightElbow = { 125 }, LeftElbow = { 125 } } },
	{ 1.1, { Root = { 12, 0, 0, 0, -0.2, 0 }, RFoot = { 0.5, 0, 0, 0 }, LFoot = { -0.5, 0, 0, 0 }, Waist = { 18 }, Neck = { 30 }, RightShoulder = { 30, 0, 95 }, LeftShoulder = { 30, 0, -95 }, RightElbow = { 10 }, LeftElbow = { 10 } }, "OutBack" },
	{ 2.2, { Root = { 10, 0, 0, 0, -0.2, 0 }, RFoot = { 0.5, 0, 0, 0 }, LFoot = { -0.5, 0, 0, 0 }, Waist = { 14 }, Neck = { 22 }, RightShoulder = { 30, 0, 90 }, LeftShoulder = { 30, 0, -90 }, RightElbow = { 15 }, LeftElbow = { 15 } } },
})

return Common
