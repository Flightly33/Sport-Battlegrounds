--[[
	Soccer clips. Each clip's Marks name the frames Client/Moves/Soccer.luau hangs gameplay off
	(Plant = the standing foot lands, Contact = the strike lands / the ball leaves the foot).
	Kicks are authored with the right leg; the left-leg versions are mirrored (M1 picks a leg at random).
]]

local Pose = require(script.Parent.Parent.Pose)

local Clip = Pose.Clip
local Mirror = Pose.MirrorClip

local Soccer = {}

local PLANT = { -0.12, 0, 0.12, 0 } -- left foot planted (IK)
local REST_ARMS = {
	RightShoulder = { -6, 0, 10 },
	LeftShoulder = { -6, 0, -10 },
	RightElbow = { 15 },
	LeftElbow = { 15 },
}

-- M1 #1/#3: front snap kick to the body. Hit at 0.13.
Soccer.KickA = Clip("Soccer.KickA", { FadeIn = 0.04, FadeOut = 0.12, Marks = { Contact = 0.13 } }, {
	{ 0, Pose.Merge(REST_ARMS, { Root = { 2, 6, 0, 0, -0.08, 0 }, LFoot = PLANT, RightHip = { 20 }, RightKnee = { -40 } }) },
	{ 0.07, { Root = { 6, 10, 0, 0, -0.12, 0 }, LFoot = PLANT, Waist = { 4, -10, 0 }, RightHip = { 62 }, RightKnee = { -112 }, RightAnkle = { -20 }, RightShoulder = { -15, 0, 30 }, LeftShoulder = { 25, 0, -40 }, LeftElbow = { 40 } }, "Out" },
	{ 0.13, { Root = { 16, -10, 0, 0, -0.05, 0.1 }, LFoot = PLANT, Waist = { 6, -16, 0 }, Neck = { -10 }, RightHip = { 88, 0, 4 }, RightKnee = { -4 }, RightAnkle = { -36 }, RightShoulder = { -32, 0, 38 }, LeftShoulder = { 38, 0, -55 }, LeftElbow = { 30 } }, "Snap" },
	{ 0.2, { Root = { 15, -10, 0, 0, -0.05, 0.1 }, LFoot = PLANT, Waist = { 6, -14, 0 }, Neck = { -8 }, RightHip = { 84, 0, 4 }, RightKnee = { -10 }, RightAnkle = { -30 }, RightShoulder = { -30, 0, 36 }, LeftShoulder = { 36, 0, -52 }, LeftElbow = { 30 } } },
	{ 0.32, Pose.Merge(REST_ARMS, { Root = { 2, 0, 0, 0, -0.08, 0 }, LFoot = PLANT, RightHip = { 18 }, RightKnee = { -45 }, RightAnkle = { 0 } }) },
})

-- M1 #2: roundhouse body kick. Hit at 0.14.
Soccer.KickB = Clip("Soccer.KickB", { FadeIn = 0.04, FadeOut = 0.12, Marks = { Contact = 0.14 } }, {
	{ 0, Pose.Merge(REST_ARMS, { Root = { 0, 8, 0, 0, -0.1, 0 }, LeftHip = { 4 }, LeftKnee = { -14 }, RightHip = { 20, 0, 20 }, RightKnee = { -50 } }) },
	{ 0.07, { Root = { 2, 18, 0, 0, -0.12, 0 }, LeftHip = { 4 }, LeftKnee = { -16 }, Waist = { 0, -6 }, RightHip = { 48, 0, 42 }, RightKnee = { -105 }, RightAnkle = { -15 }, RightShoulder = { -10, 0, 40 }, LeftShoulder = { 30, 0, -45 } }, "Out" },
	{ 0.14, { Root = { 10, 48, 4, 0, -0.04, 0 }, LeftHip = { 2 }, LeftKnee = { -10 }, LeftAnkle = { -15 }, Waist = { 0, -22, 0 }, Neck = { -6, -26, 0 }, RightHip = { 72, 0, 58 }, RightKnee = { -5 }, RightAnkle = { -32 }, RightShoulder = { -25, 0, 55 }, LeftShoulder = { 22, 0, -62 }, LeftElbow = { 50 } }, "Snap" },
	{ 0.21, { Root = { 9, 46, 4, 0, -0.04, 0 }, LeftHip = { 2 }, LeftKnee = { -10 }, LeftAnkle = { -15 }, Waist = { 0, -20, 0 }, Neck = { -6, -24, 0 }, RightHip = { 66, 0, 56 }, RightKnee = { -18 }, RightAnkle = { -28 }, RightShoulder = { -25, 0, 52 }, LeftShoulder = { 22, 0, -60 }, LeftElbow = { 50 } } },
	{ 0.34, Pose.Merge(REST_ARMS, { Root = { 0, 4, 0, 0, -0.08, 0 }, LeftHip = { 2 }, LeftKnee = { -10 }, RightHip = { 15, 0, 15 }, RightKnee = { -40 } }) },
})

-- M1 #4: spinning hook kick (knockback). Hit at 0.24.
Soccer.KickFinisher = Clip("Soccer.KickFinisher", { FadeIn = 0.04, FadeOut = 0.14, Marks = { Contact = 0.24 } }, {
	{ 0, Pose.Merge(REST_ARMS, { Root = { -4, 18, 0, 0, -0.35, 0 }, LeftHip = { 10 }, LeftKnee = { -35 }, RightHip = { 10 }, RightKnee = { -35 } }) },
	{ 0.12, { Root = { 4, -130, 0, 0, -0.1, 0 }, LeftHip = { 4 }, LeftKnee = { -12 }, LeftAnkle = { -20 }, Waist = { 0, 10 }, RightHip = { 42, 0, 48 }, RightKnee = { -70 }, RightShoulder = { 10, 0, 70 }, LeftShoulder = { 10, 0, -70 } }, "In" },
	{ 0.24, { Root = { 14, -300, 6, 0, 0.1, 0 }, LeftHip = { 2 }, LeftKnee = { -6 }, LeftAnkle = { -30 }, Waist = { 4, 18 }, Neck = { -10, 30, 0 }, RightHip = { 82, 0, 72 }, RightKnee = { -4 }, RightAnkle = { -35 }, RightShoulder = { -10, 0, 80 }, LeftShoulder = { 20, 0, -80 } }, "Linear" },
	{ 0.34, { Root = { 6, -352, 0, 0, -0.05, 0 }, LeftHip = { 4 }, LeftKnee = { -14 }, Waist = { 2, 6 }, RightHip = { 30, 0, 30 }, RightKnee = { -40 }, RightShoulder = { 0, 0, 50 }, LeftShoulder = { 10, 0, -50 } }, "Out" },
	{ 0.44, Pose.Merge(REST_ARMS, { Root = { 0, -360, 0, 0, -0.1, 0 }, LeftHip = { 4 }, LeftKnee = { -14 }, RightHip = { 6 }, RightKnee = { -20 } }) },
})

-- M1 Uppercut variant: rising upward kick. Hit at 0.18.
Soccer.UpKick = Clip("Soccer.UpKick", { FadeIn = 0.04, FadeOut = 0.15, Marks = { Contact = 0.18 } }, {
	{ 0, Pose.Merge(REST_ARMS, { Root = { -8, 0, 0, 0, -0.45, 0 }, LFoot = PLANT, RightHip = { -30 }, RightKnee = { -60 } }) },
	{ 0.1, { Root = { 6, 0, 0, 0, -0.2, 0 }, LFoot = PLANT, RightHip = { 40 }, RightKnee = { -90 }, RightShoulder = { -30, 0, 30 }, LeftShoulder = { 50, 0, -30 } }, "In" },
	{ 0.18, { Root = { 30, 0, 0, 0, 0.3, 0.3 }, LFoot = { -0.12, 0.2, 0.12, -30 }, Waist = { 10 }, Neck = { -18 }, RightHip = { 150 }, RightKnee = { -3 }, RightAnkle = { -30 }, RightShoulder = { -50, 0, 40 }, LeftShoulder = { 70, 0, -40 } }, "Snap" },
	{ 0.28, { Root = { 26, 0, 0, 0, 0.25, 0.3 }, LFoot = { -0.12, 0.2, 0.12, -30 }, Waist = { 10 }, Neck = { -15 }, RightHip = { 145 }, RightKnee = { -8 }, RightAnkle = { -30 }, RightShoulder = { -48, 0, 40 }, LeftShoulder = { 68, 0, -40 } } },
	{ 0.42, Pose.Merge(REST_ARMS, { Root = { 0, 0, 0, 0, -0.1, 0 }, LFoot = PLANT, RightHip = { 20 }, RightKnee = { -40 } }) },
})

-- M1 Downslam variant: axe kick. Hit at 0.24.
Soccer.AxeKick = Clip("Soccer.AxeKick", { FadeIn = 0.04, FadeOut = 0.15, Marks = { Contact = 0.24 } }, {
	{ 0, Pose.Merge(REST_ARMS, { Root = { 6, 0, 0, 0, 0, 0 }, LeftHip = { 10 }, LeftKnee = { -30 }, RightHip = { 30 }, RightKnee = { -40 } }) },
	{ 0.14, { Root = { 18, 0, 0, 0, 0.2, 0 }, LeftHip = { 6 }, LeftKnee = { -20 }, Waist = { 8 }, RightHip = { 160 }, RightKnee = { -4 }, RightAnkle = { 10 }, RightShoulder = { 30, 0, 60 }, LeftShoulder = { 30, 0, -60 } }, "Out" },
	{ 0.24, { Root = { -16, 0, 0, 0, -0.1, 0 }, LeftHip = { 20 }, LeftKnee = { -40 }, Waist = { -14 }, Neck = { 10 }, RightHip = { 30 }, RightKnee = { -4 }, RightAnkle = { -10 }, RightShoulder = { -20, 0, 40 }, LeftShoulder = { -20, 0, -40 } }, "In" },
	{ 0.42, Pose.Merge(REST_ARMS, { Root = { -4, 0, 0, 0, -0.2, 0 }, LeftHip = { 15 }, LeftKnee = { -35 }, RightHip = { 20 }, RightKnee = { -30 } }) },
})

Soccer.KickAL = Mirror(Soccer.KickA, "Soccer.KickAL")
Soccer.KickBL = Mirror(Soccer.KickB, "Soccer.KickBL")
Soccer.KickFinisherL = Mirror(Soccer.KickFinisher, "Soccer.KickFinisherL")
Soccer.UpKickL = Mirror(Soccer.UpKick, "Soccer.UpKickL")
Soccer.AxeKickL = Mirror(Soccer.AxeKick, "Soccer.AxeKickL")

-- 1: Light Kick - step in and plant the left foot beside the ball (Plant), cock the leg back and hold
-- it for a beat, snap it through the ball (Contact: the ball leaves the foot), follow through high
-- up on the toes, settle.
Soccer.LightKick = Clip("Soccer.LightKick", { FadeIn = 0.04, FadeOut = 0.14, Marks = { Plant = 0.12, Contact = 0.2 } }, {
	{ 0, Pose.Merge(REST_ARMS, { Root = { 0, 4, 0, 0, -0.1, 0 }, LFoot = { -0.15, 0, 0.3, 0 }, RightHip = { 4 }, RightKnee = { -20 } }) },
	-- step: the plant foot travels forward, the kicking leg starts to cock
	{ 0.07, { Root = { -4, 10, 0, 0, -0.16, 0 }, LFoot = { -0.15, 0.35, 0.05, 15 }, Waist = { -3, -6 }, RightHip = { -14 }, RightKnee = { -55 }, RightAnkle = { -10 }, RightShoulder = { 8, 0, 28 }, LeftShoulder = { 22, 0, -34 } }, "Out" },
	-- plant: the left foot lands beside the ball, hips drop, the leg is fully cocked
	{ 0.12, { Root = { -8, 18, 0, 0, -0.28, 0 }, LFoot = { -0.18, 0, -0.25, 0 }, Waist = { -5, -12 }, Neck = { 4, -10 }, RightHip = { -44 }, RightKnee = { -108 }, RightAnkle = { -25 }, RightShoulder = { 16, 0, 46 }, LeftShoulder = { 34, 0, -52 }, LeftElbow = { 25 } }, "Out" },
	-- a breath of hold before the strike (anticipation)
	{ 0.155, { Root = { -9, 20, 0, 0, -0.3, 0 }, LFoot = { -0.18, 0, -0.25, 0 }, Waist = { -6, -13 }, Neck = { 5, -11 }, RightHip = { -48 }, RightKnee = { -112 }, RightAnkle = { -26 }, RightShoulder = { 18, 0, 48 }, LeftShoulder = { 36, 0, -54 }, LeftElbow = { 26 } }, "InOut" },
	-- contact: the straight leg snaps through the ball, the foot right at the ball on the ground
	{ 0.2, { Root = { 7, -10, 0, 0, -0.16, 0.05 }, LFoot = { -0.18, 0, -0.25, 0 }, Waist = { 4, -14 }, Neck = { -10 }, RightHip = { 40, 0, 4 }, RightKnee = { -6 }, RightAnkle = { -40 }, RightShoulder = { -26, 0, 38 }, LeftShoulder = { 42, 0, -50 }, LeftElbow = { 20 } }, "Snap" },
	-- follow-through: the leg keeps rising, up on the toes of the plant foot
	{ 0.31, { Root = { 16, -16, 0, 0, 0.02, 0.12 }, LFoot = { -0.18, 0.12, -0.25, -22 }, Waist = { 7, -16 }, Neck = { -10 }, RightHip = { 98, 0, 6 }, RightKnee = { -10 }, RightAnkle = { -35 }, RightShoulder = { -36, 0, 40 }, LeftShoulder = { 50, 0, -48 }, LeftElbow = { 18 } }, "OutBack" },
	-- settle back into the stance
	{ 0.5, Pose.Merge(REST_ARMS, { Root = { 0, 0, 0, 0, -0.08, 0 }, LFoot = { -0.15, 0, -0.1, 0 }, RightHip = { 10 }, RightKnee = { -30 } }) },
})

-- 2: Lightning Shot - big wind-up, strike at 0.6.
Soccer.LightningShot = Clip("Soccer.LightningShot", { FadeIn = 0.06, FadeOut = 0.2, Marks = { Plant = 0.12, Contact = 0.6 } }, {
	{ 0, Pose.Merge(REST_ARMS, { Root = { 0, 10, 0, 0, -0.15, 0 }, LFoot = { -0.15, 0, -0.2, 0 }, RightHip = { -10 }, RightKnee = { -30 } }) },
	{ 0.12, { Root = { -10, 26, 0, 0, -0.45, 0 }, LFoot = { -0.18, 0, -0.45, 0 }, Waist = { -4, -8 }, Neck = { 6, -18 }, RightHip = { -40 }, RightKnee = { -95 }, RightAnkle = { -20 }, RightShoulder = { 20, 0, 70 }, LeftShoulder = { 40, 0, -72 }, LeftElbow = { 20 } }, "Out" },
	{ 0.52, { Root = { -14, 32, 0, 0, -0.55, 0 }, LFoot = { -0.18, 0, -0.5, 0 }, Waist = { -6, -10 }, Neck = { 8, -24 }, RightHip = { -58 }, RightKnee = { -112 }, RightAnkle = { -25 }, RightShoulder = { 25, 0, 78 }, LeftShoulder = { 45, 0, -80 }, LeftElbow = { 25 } } },
	{ 0.6, { Root = { 18, -20, 0, 0, -0.1, 0.2 }, LFoot = { -0.18, 0, -0.5, 0 }, Waist = { 10, -16 }, Neck = { -16 }, RightHip = { 96, 0, 5 }, RightKnee = { -4 }, RightAnkle = { -42 }, RightShoulder = { -40, 0, 42 }, LeftShoulder = { 62, 0, -62 }, LeftElbow = { 20 } }, "Snap" },
	{ 0.76, { Root = { 28, -26, 0, 0, 0.2, 0.3 }, LFoot = { -0.18, 0.15, -0.5, -25 }, Waist = { 12, -18 }, Neck = { -18 }, RightHip = { 126 }, RightKnee = { -6 }, RightAnkle = { -38 }, RightShoulder = { -48, 0, 45 }, LeftShoulder = { 70, 0, -60 }, LeftElbow = { 20 } }, "Out" },
	{ 0.95, Pose.Merge(REST_ARMS, { Root = { 0, 0, 0, 0, -0.1, 0 }, LFoot = { -0.15, 0, -0.2, 0 }, RightHip = { 18 }, RightKnee = { -45 } }) },
})

-- 3: Lightning Dribble Dash - sprint dribble for up to 0.42 s...
local DASH_A = {
	Root = { -26, 0, 0, 0, -0.25, 0 },
	RFoot = { 0.1, 0.9, -0.7, -25 },
	LFoot = { -0.1, 0.45, 0.85, -45 },
	Waist = { -6, 8 },
	Neck = { 20 },
	RightShoulder = { -50, 0, 12 },
	LeftShoulder = { 55, 0, -12 },
	RightElbow = { 85 },
	LeftElbow = { 85 },
}
local DASH_B = {
	Root = { -26, 0, 0, 0, -0.25, 0 },
	RFoot = { 0.1, 0.45, 0.85, -45 },
	LFoot = { -0.1, 0.9, -0.7, -25 },
	Waist = { -6, -8 },
	Neck = { 20 },
	RightShoulder = { 55, 0, 12 },
	LeftShoulder = { -50, 0, -12 },
	RightElbow = { 85 },
	LeftElbow = { 85 },
}
local function dribbled(pose: Pose.Pose, roll: number): Pose.Pose
	return Pose.Merge(pose, { Prop = { roll, 0, 0, -0.3, 0, -0.9 } })
end
Soccer.DribbleDash = Clip("Soccer.DribbleDash", { FadeIn = 0.04, FadeOut = 0.08 }, {
	{ 0, dribbled(DASH_A, 0) },
	{ 0.1, dribbled(DASH_B, -180), "Linear" },
	{ 0.2, dribbled(DASH_A, -360), "Linear" },
	{ 0.3, dribbled(DASH_B, -540), "Linear" },
	{ 0.42, dribbled(DASH_A, -720), "Linear" },
})

-- ...then the flick into the chin (hit at 0.05), played the moment the dash reaches someone.
Soccer.Flick = Clip("Soccer.Flick", { FadeIn = 0.03, FadeOut = 0.2, Marks = { Contact = 0.05 } }, {
	{ 0, { Root = { 8, 0, 0, 0, -0.1, 0 }, LFoot = { -0.12, 0, 0.1, 0 }, Waist = { 4 }, Neck = { 0 }, RightHip = { 70 }, RightKnee = { -110 }, RightAnkle = { -30 }, RightShoulder = { -20, 0, 35 }, LeftShoulder = { 30, 0, -40 }, Prop = { -760, 0, 0, -0.3, 0.6, -1.6 } } },
	{ 0.05, { Root = { 18, 0, 0, 0, 0.1, 0.1 }, LFoot = { -0.12, 0.1, 0.1, -20 }, Waist = { 8 }, Neck = { -14 }, RightHip = { 115 }, RightKnee = { -10 }, RightAnkle = { -30 }, RightShoulder = { -35, 0, 40 }, LeftShoulder = { 55, 0, -40 }, Prop = { -900, 0, 0, -0.3, 4.2, -2.6 } }, "Snap" },
	{ 0.18, { Root = { 12, 0, 0, 0, 0, 0.1 }, LFoot = { -0.12, 0, 0.1, 0 }, Waist = { 6 }, Neck = { -20 }, RightHip = { 60 }, RightKnee = { -50 }, RightShoulder = { -20, 0, 30 }, LeftShoulder = { 40, 0, -30 }, Prop = { -1000, 0, 0, -0.3, 3.0, -1.4 } } },
	{ 0.33, Pose.Merge(REST_ARMS, { Root = { 0, 0, 0, 0, -0.1, 0 }, LFoot = { -0.12, 0, 0.1, 0 }, RightHip = { 15 }, RightKnee = { -30 }, Prop = { -1080, 0, 0, 0, 0, 0 } }) },
})

-- 4: Thunder Bicycle Kick - jump, turn and lie back in the air, scissor the legs; strike at 0.45.
Soccer.BicycleKick = Clip("Soccer.BicycleKick", { FadeIn = 0.05, FadeOut = 0.2, Marks = { Jump = 0.12, Contact = 0.45 } }, {
	{ 0, Pose.Merge(REST_ARMS, { Root = { -12, 0, 0, 0, -0.65, 0 }, RFoot = { 0.25, 0, 0, 0 }, LFoot = { -0.25, 0, 0, 0 }, Waist = { -10 } }) },
	{ 0.14, { Root = { 20, 60, 0, 0, 0.4, 0 }, Waist = { 0 }, Neck = { -10 }, RightHip = { 10 }, RightKnee = { -30 }, LeftHip = { 80 }, LeftKnee = { -60 }, RightShoulder = { 60, 0, 60 }, LeftShoulder = { 60, 0, -60 } }, "Out" },
	{ 0.32, { Root = { 95, 150, 0, 0, 1.2, 0 }, Neck = { -20 }, RightHip = { 40 }, RightKnee = { -60 }, LeftHip = { 150 }, LeftKnee = { -5 }, RightShoulder = { 30, 0, 85 }, LeftShoulder = { 30, 0, -85 } } },
	{ 0.45, { Root = { 120, 180, 0, 0, 1.4, 0 }, Neck = { -25 }, RightHip = { 160 }, RightKnee = { -3 }, RightAnkle = { -40 }, LeftHip = { 20 }, LeftKnee = { -50 }, RightShoulder = { 20, 0, 90 }, LeftShoulder = { 20, 0, -90 } }, "Snap" },
	{ 0.62, { Root = { 60, 260, 0, 0, 0.6, 0 }, Neck = { -10 }, RightHip = { 90 }, RightKnee = { -40 }, LeftHip = { 40 }, LeftKnee = { -60 }, RightShoulder = { 40, 0, 70 }, LeftShoulder = { 40, 0, -70 } } },
	{ 0.8, { Root = { -10, 360, 0, 0, -0.7, 0 }, RFoot = { 0.3, 0, 0.1, 0 }, LFoot = { -0.3, 0, -0.1, 0 }, Waist = { -12 }, Neck = { 12 }, RightShoulder = { 10, 0, 50 }, LeftShoulder = { 10, 0, -50 } }, "In" },
	{ 1.0, Pose.Merge(REST_ARMS, { Root = { 0, 360, 0, 0, -0.15, 0 }, RFoot = { 0.15, 0, 0, 0 }, LFoot = { -0.15, 0, 0, 0 } }) },
})

-- Awakened 1: Railgun - ball floats up, charge, strike at 0.38.
Soccer.Railgun = Clip("Soccer.Railgun", { FadeIn = 0.05, FadeOut = 0.2, Marks = { Contact = 0.38 } }, {
	{ 0, Pose.Merge(REST_ARMS, { Root = { -6, 20, 0, 0, -0.3, 0 }, LFoot = { -0.2, 0, -0.4, 0 }, RightHip = { -20 }, RightKnee = { -50 }, Prop = { 0, 0, 0, 0, 1.4, -0.4 } }) },
	{ 0.3, { Root = { -14, 34, 0, 0, -0.55, 0 }, LFoot = { -0.2, 0, -0.5, 0 }, Waist = { -6, -12 }, Neck = { 6, -26 }, RightHip = { -60 }, RightKnee = { -110 }, RightShoulder = { 20, 0, 80 }, LeftShoulder = { 90, 0, -10 }, LeftElbow = { 0 }, Prop = { 0, 0, 0, 0, 1.6, -0.6 } } },
	{ 0.38, { Root = { 16, -20, 0, 0, -0.1, 0.2 }, LFoot = { -0.2, 0, -0.5, 0 }, Waist = { 10, -16 }, Neck = { -14 }, RightHip = { 98, 0, 4 }, RightKnee = { -4 }, RightAnkle = { -42 }, RightShoulder = { -40, 0, 45 }, LeftShoulder = { 60, 0, -60 }, Prop = { 0, 0, 0, 0, 1.6, -0.6 } }, "Snap" },
	{ 0.7, Pose.Merge(REST_ARMS, { Root = { 0, 0, 0, 0, -0.1, 0 }, LFoot = { -0.15, 0, -0.2, 0 }, RightHip = { 15 }, RightKnee = { -35 } }) },
})

-- Awakened 2: Thunderclap Volley - five snap kicks at 0.1, 0.25, 0.4, 0.55, 0.7.
do
	local keys: { { any } } = { { 0, Pose.Merge(REST_ARMS, { Root = { 0, 0, 0, 0, 0.2, 0 }, RightHip = { 10 }, LeftHip = { 10 }, RightKnee = { -30 }, LeftKnee = { -30 } }) } }
	for i = 0, 4 do
		local right = i % 2 == 0
		local t = 0.1 + i * 0.15
		local kick = if right
			then { Root = { 10, -14, 0, 0, 0.3, 0 }, RightHip = { 88 }, RightKnee = { -4 }, RightAnkle = { -40 }, LeftHip = { -10 }, LeftKnee = { -50 }, RightShoulder = { -30, 0, 40 }, LeftShoulder = { 40, 0, -50 } }
			else { Root = { 10, 14, 0, 0, 0.3, 0 }, LeftHip = { 88 }, LeftKnee = { -4 }, LeftAnkle = { -40 }, RightHip = { -10 }, RightKnee = { -50 }, LeftShoulder = { -30, 0, -40 }, RightShoulder = { 40, 0, 50 } }
		table.insert(keys, Pose.Key( t - 0.05, { Root = { 4, 0, 0, 0, 0.2, 0 }, RightHip = { 20 }, LeftHip = { 20 }, RightKnee = { -70 }, LeftKnee = { -70 }, RightShoulder = { 10, 0, 40 }, LeftShoulder = { 10, 0, -40 } } ))
		table.insert(keys, Pose.Key( t, kick, "Snap" ))
	end
	table.insert(keys, Pose.Key( 0.9, Pose.Merge(REST_ARMS, { Root = { 0, 0, 0, 0, -0.1, 0 }, RightHip = { 5 }, LeftHip = { 5 }, RightKnee = { -15 }, LeftKnee = { -15 } }) ))
	Soccer.Volley = Clip("Soccer.Volley", { FadeIn = 0.04, FadeOut = 0.15, Marks = { Kick1 = 0.1, Kick2 = 0.25, Kick3 = 0.4, Kick4 = 0.55, Kick5 = 0.7 } }, keys)
end

-- Awakened 3: Flash Step - reappear crouched, spinning roundhouse at 0.22.
Soccer.FlashStep = Clip("Soccer.FlashStep", { FadeIn = 0.02, FadeOut = 0.15, Marks = { Contact = 0.21 } }, {
	{ 0, { Root = { -10, 40, 0, 0, -0.8, 0 }, LeftHip = { 40 }, LeftKnee = { -90 }, RightHip = { 30 }, RightKnee = { -100 }, RightShoulder = { 20, 0, 50 }, LeftShoulder = { 20, 0, -50 }, Neck = { 10 } } },
	{ 0.1, { Root = { 4, -120, 0, 0, -0.1, 0 }, LeftHip = { 4 }, LeftKnee = { -12 }, RightHip = { 45, 0, 50 }, RightKnee = { -70 }, RightShoulder = { 10, 0, 70 }, LeftShoulder = { 10, 0, -70 } }, "In" },
	{ 0.22, { Root = { 14, -300, 6, 0, 0.1, 0 }, LeftHip = { 2 }, LeftKnee = { -6 }, LeftAnkle = { -30 }, Waist = { 4, 18 }, Neck = { -10, 30, 0 }, RightHip = { 84, 0, 72 }, RightKnee = { -4 }, RightAnkle = { -35 }, RightShoulder = { -10, 0, 80 }, LeftShoulder = { 20, 0, -80 } }, "Linear" },
	{ 0.4, { Root = { 4, -355, 0, 0, -0.05, 0 }, LeftHip = { 4 }, LeftKnee = { -14 }, RightHip = { 25, 0, 25 }, RightKnee = { -40 }, RightShoulder = { 0, 0, 40 }, LeftShoulder = { 10, 0, -40 } }, "Out" },
	{ 0.65, Pose.Merge(REST_ARMS, { Root = { 0, -360, 0, 0, -0.1, 0 }, LeftHip = { 4 }, LeftKnee = { -14 }, RightHip = { 6 }, RightKnee = { -20 } }) },
})

-- Awakened 4: Storm of the Century - kick the ball skyward (0.3), point at the sky, bring the bolt down (1.95).
local POINT_SKY = {
	Root = { 4, 0, 0, 0, -0.05, 0 },
	RFoot = { 0.2, 0, 0, 0 },
	LFoot = { -0.2, 0, 0.1, 0 },
	Waist = { 8, 0, 0 },
	Neck = { 32, 0, 0 },
	RightShoulder = { 172, 0, 8 },
	RightElbow = { 4 },
	RightWrist = { 0 },
	LeftShoulder = { -16, -12, -9 },
	LeftElbow = { 30 },
	LeftWrist = { -6, 0, 8 },
}
Soccer.Storm = Clip("Soccer.Storm", { FadeIn = 0.06, FadeOut = 0.25, Marks = { Kick = 0.3, Rain = 0.6, Bolt = 1.95 } }, {
	{ 0, Pose.Merge(REST_ARMS, { Root = { -10, 0, 0, 0, -0.4, 0 }, LFoot = { -0.15, 0, -0.2, 0 }, RightHip = { -30 }, RightKnee = { -80 } }) },
	{ 0.3, { Root = { 26, 0, 0, 0, 0.2, 0.2 }, LFoot = { -0.15, 0.1, -0.2, -20 }, Waist = { 12 }, Neck = { -30 }, RightHip = { 150 }, RightKnee = { -4 }, RightAnkle = { -30 }, RightShoulder = { -40, 0, 40 }, LeftShoulder = { 60, 0, -40 } }, "Snap" },
	{ 0.6, POINT_SKY, "Out" },
	{ 1.85, Pose.Merge(POINT_SKY, { Neck = { 28, 0, 0 } }) },
	{ 1.98, Pose.Merge(POINT_SKY, { Root = { -6, 0, 0, 0, -0.3, 0 }, Waist = { -10 }, Neck = { 0 }, RightShoulder = { 92, 0, 6 } }), "Snap" },
	{ 2.3, Pose.Merge(POINT_SKY, { Root = { -4, 0, 0, 0, -0.25, 0 }, Waist = { -8 }, Neck = { 0 }, RightShoulder = { 88, 0, 6 } }) },
})

-- Awakening: hands in pockets, the ball rises, arms spread, lightning (2.2 s).
Soccer.Awaken = Clip("Soccer.Awaken", { FadeIn = 0.1, FadeOut = 0.3, Marks = { Burst = 1.2 } }, {
	{ 0, { Root = { 2, 0, 0, 0, -0.05, 0 }, RFoot = { 0.15, 0, 0, 0 }, LFoot = { -0.15, 0, 0, 0 }, Neck = { -24 }, RightShoulder = { -16, 12, 9 }, RightElbow = { 30 }, LeftShoulder = { -16, -12, -9 }, LeftElbow = { 30 }, Prop = { 0, 0, 0, 0, 0, 0 } } },
	{ 0.6, { Root = { 2, 0, 0, 0, -0.05, 0 }, RFoot = { 0.15, 0, 0, 0 }, LFoot = { -0.15, 0, 0, 0 }, Neck = { -20 }, RightShoulder = { -16, 12, 9 }, RightElbow = { 30 }, LeftShoulder = { -16, -12, -9 }, LeftElbow = { 30 }, Prop = { -200, 0, 0, -0.5, 3.5, 0.6 } } },
	{ 1.2, { Root = { 10, 0, 0, 0, 0.1, 0 }, RFoot = { 0.4, 0.05, 0, -15 }, LFoot = { -0.4, 0.05, 0, -15 }, Waist = { 14 }, Neck = { 34 }, RightShoulder = { 40, 0, 85 }, RightElbow = { 10 }, LeftShoulder = { 40, 0, -85 }, LeftElbow = { 10 }, Prop = { -500, 0, 0, -0.5, 6.5, 0.6 } }, "OutBack" },
	{ 2.2, { Root = { 8, 0, 0, 0, 0.05, 0 }, RFoot = { 0.4, 0, 0, 0 }, LFoot = { -0.4, 0, 0, 0 }, Waist = { 10 }, Neck = { 26 }, RightShoulder = { 36, 0, 80 }, RightElbow = { 12 }, LeftShoulder = { 36, 0, -80 }, LeftElbow = { 12 }, Prop = { -900, 0, 0, -0.5, 6.2, 0.6 } } },
})

-- Idle fidget: flicks the ball up off the foot, two touches and a knee, then traps it again (1.7 s).
-- Only the right leg and the ball are animated, so the hands stay in the pockets.
Soccer.Juggle = Clip("Soccer.Juggle", { FadeIn = 0.15, FadeOut = 0.25 }, {
	{ 0, { RightHip = { 45 }, RightKnee = { -75 }, RightAnkle = { -10 }, Prop = { 0, 0, 0, 0, 0, 0.05 } } },
	{ 0.22, { RightHip = { 20 }, RightKnee = { -60 }, RightAnkle = { -25 }, Prop = { -60, 0, 0, -0.1, 0.4, 0.3 } }, "In" },
	{ 0.32, { RightHip = { 55 }, RightKnee = { -25 }, RightAnkle = { -20 }, Prop = { -160, 0, 0, -0.1, 1.9, -0.1 } }, "Snap" },
	{ 0.55, { RightHip = { 30 }, RightKnee = { -30 }, RightAnkle = { -10 }, Prop = { -300, 0, 0, -0.1, 3.4, -0.2 } }, "Out" },
	{ 0.78, { RightHip = { 42 }, RightKnee = { -20 }, RightAnkle = { -15 }, Prop = { -420, 0, 0, -0.1, 1.2, -0.3 } }, "In" },
	{ 1.0, { RightHip = { 35 }, RightKnee = { -30 }, RightAnkle = { -10 }, Prop = { -560, 0, 0, -0.1, 3.0, -0.3 } }, "Out" },
	{ 1.2, { RightHip = { 85 }, RightKnee = { -95 }, RightAnkle = { -10 }, Prop = { -660, 0, 0, -0.1, 2.4, -0.6 } }, "In" },
	{ 1.38, { RightHip = { 50 }, RightKnee = { -80 }, RightAnkle = { -10 }, Prop = { -760, 0, 0, -0.1, 3.4, -0.4 } }, "Out" },
	{ 1.7, { RightHip = { 45 }, RightKnee = { -75 }, RightAnkle = { -10 }, Prop = { -900, 0, 0, 0, 0, 0.05 } }, "In" },
})
Soccer.Fidgets = { Soccer.Juggle }

return Soccer
