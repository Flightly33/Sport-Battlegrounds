--[[
	Football clips. The ball is held in the right hand (the prop hangs off RightHand), so it follows
	the right arm. Hit timings used by Client/Moves/Football.luau are noted per clip.
]]

local Pose = require(script.Parent.Parent.Pose)

local Clip = Pose.Clip
local Mirror = Pose.MirrorClip

local Football = {}

local STANCE = {
	Root = { -6, 0, 0, 0, -0.3, 0 },
	RFoot = { 0.38, 0, 0.1, 0 },
	LFoot = { -0.38, 0, -0.15, 0 },
}
local TUCK = { RightShoulder = { 2, 28, 4 }, RightElbow = { 88 }, RightWrist = { 0, 0, -10 } }

local function stance(extra: Pose.Pose): Pose.Pose
	return Pose.Merge(STANCE, TUCK, extra)
end

-- M1 #1: left forearm shiver. Hit at 0.13. (#2 is the mirror, with the ball arm.)
Football.Shiver = Clip("Football.Shiver", { FadeIn = 0.04, FadeOut = 0.12 }, {
	{ 0, stance({ Waist = { -4, 30 }, LeftShoulder = { 60, 0, -60 }, LeftElbow = { 110 } }) },
	{ 0.13, stance({ Root = { -12, -14, 0, 0, -0.35, -0.25 }, Waist = { -8, -34 }, Neck = { 6, 26 }, LeftShoulder = { 82, 0, -6 }, LeftElbow = { 92 }, LeftWrist = { 0, 0, 20 } }), "Snap" },
	{ 0.2, stance({ Root = { -12, -14, 0, 0, -0.35, -0.25 }, Waist = { -8, -32 }, Neck = { 6, 24 }, LeftShoulder = { 80, 0, -8 }, LeftElbow = { 95 } }) },
	{ 0.32, stance({ Waist = { -4, 5 }, LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})
Football.ShiverR = Mirror(Football.Shiver, "Football.ShiverR")

-- M1 #3: two-hand shove. Hit at 0.13.
Football.Shove = Clip("Football.Shove", { FadeIn = 0.04, FadeOut = 0.12 }, {
	{ 0, Pose.Merge(STANCE, { Root = { -4, 0, 0, 0, -0.4, 0.2 }, RightShoulder = { 40, 0, -10 }, RightElbow = { 120 }, LeftShoulder = { 40, 0, 10 }, LeftElbow = { 120 } }) },
	{ 0.13, Pose.Merge(STANCE, { Root = { -18, 0, 0, 0, -0.35, -0.5 }, Waist = { -8 }, Neck = { 12 }, RightShoulder = { 82, 0, -12 }, RightElbow = { 4 }, RightWrist = { 50 }, LeftShoulder = { 82, 0, 12 }, LeftElbow = { 4 }, LeftWrist = { 50 } }), "Snap" },
	{ 0.2, Pose.Merge(STANCE, { Root = { -18, 0, 0, 0, -0.35, -0.5 }, Waist = { -8 }, Neck = { 12 }, RightShoulder = { 80, 0, -12 }, RightElbow = { 8 }, LeftShoulder = { 80, 0, 12 }, LeftElbow = { 8 } }) },
	{ 0.32, stance({ LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})

-- M1 #4: shoulder charge (knockback). Hit at 0.2.
Football.ShoulderCharge = Clip("Football.ShoulderCharge", { FadeIn = 0.04, FadeOut = 0.15 }, {
	{ 0, stance({ Root = { -10, -20, 0, 0, -0.5, 0.3 }, Waist = { -6, -20 }, LeftShoulder = { 10, 0, -30 }, LeftElbow = { 60 } }) },
	{ 0.2, stance({ Root = { -28, 38, 0, 0, -0.45, -0.7 }, RFoot = { 0.38, 0.1, 0.7, -30 }, LFoot = { -0.38, 0, -0.6, 0 }, Waist = { -10, 14 }, Neck = { 20, -40 }, LeftShoulder = { 20, 0, -12 }, LeftElbow = { 100 } }), "Snap" },
	{ 0.28, stance({ Root = { -26, 36, 0, 0, -0.45, -0.7 }, RFoot = { 0.38, 0.1, 0.7, -30 }, LFoot = { -0.38, 0, -0.6, 0 }, Waist = { -10, 12 }, Neck = { 18, -36 }, LeftShoulder = { 20, 0, -12 }, LeftElbow = { 100 } }) },
	{ 0.44, stance({ LeftShoulder = { 15, 0, -20 }, LeftElbow = { 40 } }) },
})

-- M1 Uppercut: rising left forearm. Hit at 0.16.
Football.Uppercut = Clip("Football.Uppercut", { FadeIn = 0.04, FadeOut = 0.15 }, {
	{ 0, stance({ Root = { -14, 0, 0, 0, -0.8, 0 }, Waist = { -10, -20 }, LeftShoulder = { -20, 0, -20 }, LeftElbow = { 90 } }) },
	{ 0.16, stance({ Root = { 14, 0, 0, 0, 0.2, 0 }, Waist = { 10, 20 }, Neck = { -15 }, LeftShoulder = { 160, 0, -5 }, LeftElbow = { 70 } }), "Snap" },
	{ 0.26, stance({ Root = { 12, 0, 0, 0, 0.15, 0 }, Waist = { 8, 18 }, Neck = { -12 }, LeftShoulder = { 155, 0, -5 }, LeftElbow = { 75 } }) },
	{ 0.42, stance({ LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})

-- M1 Downslam: double axe-handle smash. Hit at 0.22.
Football.Hammer = Clip("Football.Hammer", { FadeIn = 0.04, FadeOut = 0.15 }, {
	{ 0, { Root = { 12, 0, 0, 0, 0, 0 }, RightHip = { 30 }, RightKnee = { -60 }, LeftHip = { 20 }, LeftKnee = { -50 }, Waist = { 10 }, RightShoulder = { 175, 0, -12 }, RightElbow = { 30 }, LeftShoulder = { 175, 0, 12 }, LeftElbow = { 30 } } },
	{ 0.22, { Root = { -30, 0, 0, 0, -0.2, 0 }, RightHip = { 40 }, RightKnee = { -60 }, LeftHip = { 30 }, LeftKnee = { -50 }, Waist = { -22 }, Neck = { 22 }, RightShoulder = { 50, 0, -14 }, RightElbow = { 5 }, LeftShoulder = { 50, 0, 14 }, LeftElbow = { 5 } }, "Snap" },
	{ 0.42, stance({ LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})

-- 1: Stiff Arm - lunge with the left arm locked straight. Hit at 0.22.
Football.StiffArm = Clip("Football.StiffArm", { FadeIn = 0.04, FadeOut = 0.15 }, {
	{ 0, stance({ Root = { -8, -16, 0, 0, -0.45, 0.2 }, Waist = { -4, -20 }, LeftShoulder = { 30, 0, -40 }, LeftElbow = { 100 } }) },
	{ 0.22, stance({ Root = { -16, 18, 0, 0, -0.4, -0.6 }, RFoot = { 0.38, 0.05, 0.6, -20 }, LFoot = { -0.38, 0, -0.6, 0 }, Waist = { -8, 20 }, Neck = { 10, -14 }, LeftShoulder = { 90, 0, 4 }, LeftElbow = { 0 }, LeftWrist = { 70 } }), "Snap" },
	{ 0.32, stance({ Root = { -15, 18, 0, 0, -0.4, -0.6 }, RFoot = { 0.38, 0.05, 0.6, -20 }, LFoot = { -0.38, 0, -0.6, 0 }, Waist = { -8, 18 }, Neck = { 10, -12 }, LeftShoulder = { 88, 0, 4 }, LeftElbow = { 4 }, LeftWrist = { 70 } }) },
	{ 0.5, stance({ LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})

-- 2: Hail Mary - quarterback throw, release at 0.3.
Football.HailMary = Clip("Football.HailMary", { FadeIn = 0.05, FadeOut = 0.18 }, {
	{ 0, Pose.Merge(STANCE, { Root = { -4, -30, 0, 0, -0.3, 0 }, Waist = { 0, -20 }, RightShoulder = { 60, 0, 50 }, RightElbow = { 110 }, LeftShoulder = { 60, 0, -10 }, LeftElbow = { 40 } }) },
	{ 0.22, Pose.Merge(STANCE, { Root = { 4, -38, 0, 0, -0.25, 0.2 }, LFoot = { -0.38, 0, -0.7, 0 }, Waist = { 4, -26 }, Neck = { -4, 40 }, RightShoulder = { 92, 0, 82 }, RightElbow = { 110 }, RightWrist = { 20 }, LeftShoulder = { 88, 0, -4 }, LeftElbow = { 6 } }), "Out" },
	{ 0.3, Pose.Merge(STANCE, { Root = { -12, 28, 0, 0, -0.3, -0.2 }, LFoot = { -0.38, 0, -0.7, 0 }, Waist = { -6, 24 }, Neck = { 6, -20 }, RightShoulder = { 125, 0, 15 }, RightElbow = { 12 }, RightWrist = { -30 }, LeftShoulder = { 20, 0, -30 }, LeftElbow = { 60 } }), "Snap" },
	{ 0.42, Pose.Merge(STANCE, { Root = { -18, 34, 0, 0, -0.35, -0.2 }, LFoot = { -0.38, 0, -0.7, 0 }, Waist = { -10, 28 }, Neck = { 8, -24 }, RightShoulder = { 40, 0, -30 }, RightElbow = { 20 }, LeftShoulder = { 0, 0, -30 }, LeftElbow = { 60 } }) },
	{ 0.55, stance({ LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})

-- 3: Blitz Tackle - low charge (looped by the move until it connects), grab, spear at 1.0.
local CHARGE_A = {
	Root = { -36, 0, 0, 0, -0.45, 0 },
	RFoot = { 0.2, 0.8, -0.7, -25 },
	LFoot = { -0.2, 0.35, 0.8, -40 },
	Neck = { 30 },
	RightShoulder = { 60, 0, 25 },
	RightElbow = { 70 },
	LeftShoulder = { 60, 0, -25 },
	LeftElbow = { 70 },
}
local CHARGE_B = Pose.Merge(CHARGE_A, { RFoot = { 0.2, 0.35, 0.8, -40 }, LFoot = { -0.2, 0.8, -0.7, -25 } })
Football.Charge = Clip("Football.Charge", { Loop = true, FadeIn = 0.06 }, {
	{ 0, CHARGE_A },
	{ 0.11, CHARGE_B, "Linear" },
	{ 0.22, CHARGE_A, "Linear" },
})
Football.Spear = Clip("Football.Spear", { FadeIn = 0.04, FadeOut = 0.2 }, {
	{ 0, { Root = { -30, 0, 0, 0, -0.3, 0 }, RFoot = { 0.25, 0.3, 0.6, -30 }, LFoot = { -0.25, 0, -0.5, 0 }, Neck = { 25 }, RightShoulder = { 85, 0, -20 }, RightElbow = { 95 }, LeftShoulder = { 85, 0, 20 }, LeftElbow = { 95 } } },
	{ 0.25, { Root = { -40, 0, 0, 0, -0.2, -0.4 }, RFoot = { 0.25, 0.4, 0.9, -40 }, LFoot = { -0.25, 0.2, -0.3, -10 }, Neck = { 30 }, RightShoulder = { 85, 0, -22 }, RightElbow = { 100 }, LeftShoulder = { 85, 0, 22 }, LeftElbow = { 100 } } },
	{ 0.32, { Root = { -70, 0, 0, 0, -1.2, -0.8 }, RFoot = { 0.25, 0.6, 1.4, -60 }, LFoot = { -0.25, 0.1, 0.4, -40 }, Neck = { 40 }, RightShoulder = { 120, 0, -10 }, RightElbow = { 40 }, LeftShoulder = { 120, 0, 10 }, LeftElbow = { 40 } }, "Snap" },
	{ 0.5, { Root = { -55, 0, 0, 0, -1.0, -0.6 }, RFoot = { 0.25, 0.3, 1.0, -40 }, LFoot = { -0.25, 0, 0.2, -20 }, Neck = { 30 }, RightShoulder = { 90, 0, -10 }, RightElbow = { 40 }, LeftShoulder = { 90, 0, 10 }, LeftElbow = { 40 } } },
	{ 0.75, stance({ LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})

-- 4: Touchdown Spike - leap with the ball raised, spike at 0.45.
Football.Spike = Clip("Football.Spike", { FadeIn = 0.04, FadeOut = 0.2 }, {
	{ 0, stance({ Root = { -14, 0, 0, 0, -0.8, 0 }, Waist = { -10 } }) },
	{ 0.18, { Root = { 10, 0, 0, 0, 0.3, 0 }, RightHip = { 30 }, RightKnee = { -70 }, LeftHip = { 70 }, LeftKnee = { -100 }, Waist = { 10 }, Neck = { -20 }, RightShoulder = { 176, 0, 6 }, RightElbow = { 8 }, LeftShoulder = { 120, 0, -40 }, LeftElbow = { 20 } }, "Out" },
	{ 0.38, { Root = { 14, 0, 0, 0, 0.4, 0 }, RightHip = { 30 }, RightKnee = { -70 }, LeftHip = { 70 }, LeftKnee = { -100 }, Waist = { 14 }, Neck = { -24 }, RightShoulder = { 178, 0, 6 }, RightElbow = { 10 }, LeftShoulder = { 120, 0, -40 }, LeftElbow = { 20 } } },
	{ 0.45, stance({ Root = { -36, 0, 0, 0, -1.0, -0.2 }, Waist = { -24 }, Neck = { 26 }, RightShoulder = { 30, 0, 4 }, RightElbow = { 4 }, LeftShoulder = { 20, 0, -50 }, LeftElbow = { 30 } }), "Snap" },
	{ 0.7, stance({ Root = { -30, 0, 0, 0, -0.9, -0.2 }, Waist = { -20 }, Neck = { 20 }, RightShoulder = { 25, 0, 4 }, RightElbow = { 10 }, LeftShoulder = { 20, 0, -50 }, LeftElbow = { 30 } }) },
	{ 0.95, stance({ LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})

-- Awakened 1: Pancake Block - explosive two-hand thrust at 0.2.
Football.Pancake = Clip("Football.Pancake", { FadeIn = 0.04, FadeOut = 0.18 }, {
	{ 0, Pose.Merge(STANCE, { Root = { -4, 0, 0, 0, -0.55, 0.3 }, Waist = { 4 }, RightShoulder = { 30, 0, -10 }, RightElbow = { 135 }, LeftShoulder = { 30, 0, 10 }, LeftElbow = { 135 } }) },
	{ 0.12, Pose.Merge(STANCE, { Root = { -2, 0, 0, 0, -0.65, 0.4 }, Waist = { 6 }, RightShoulder = { 20, 0, -10 }, RightElbow = { 145 }, LeftShoulder = { 20, 0, 10 }, LeftElbow = { 145 } }) },
	{ 0.2, Pose.Merge(STANCE, { Root = { -22, 0, 0, 0, -0.35, -0.8 }, RFoot = { 0.38, 0.05, 0.7, -25 }, LFoot = { -0.38, 0, -0.6, 0 }, Waist = { -10 }, Neck = { 14 }, RightShoulder = { 85, 0, -15 }, RightElbow = { 2 }, RightWrist = { 60 }, LeftShoulder = { 85, 0, 15 }, LeftElbow = { 2 }, LeftWrist = { 60 } }), "Snap" },
	{ 0.35, Pose.Merge(STANCE, { Root = { -20, 0, 0, 0, -0.35, -0.8 }, RFoot = { 0.38, 0.05, 0.7, -25 }, LFoot = { -0.38, 0, -0.6, 0 }, Waist = { -10 }, Neck = { 12 }, RightShoulder = { 83, 0, -15 }, RightElbow = { 6 }, LeftShoulder = { 83, 0, 15 }, LeftElbow = { 6 } }) },
	{ 0.55, stance({ LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})

-- Awakened 2: Spiral Cannon - big throw, release at 0.38.
Football.Cannon = Clip("Football.Cannon", { FadeIn = 0.05, FadeOut = 0.2 }, {
	{ 0, Pose.Merge(STANCE, { Root = { 0, -40, 0, 0, -0.4, 0.2 }, Waist = { 2, -30 }, RightShoulder = { 70, 0, 70 }, RightElbow = { 120 }, LeftShoulder = { 70, 0, -10 }, LeftElbow = { 30 } }) },
	{ 0.3, Pose.Merge(STANCE, { Root = { 8, -50, 0, 0, -0.45, 0.4 }, LFoot = { -0.38, 0, -0.9, 0 }, Waist = { 6, -34 }, Neck = { -6, 45 }, RightShoulder = { 100, 0, 90 }, RightElbow = { 120 }, LeftShoulder = { 90, 0, -2 }, LeftElbow = { 4 } }), "Out" },
	{ 0.38, Pose.Merge(STANCE, { Root = { -16, 34, 0, 0, -0.35, -0.3 }, LFoot = { -0.38, 0, -0.9, 0 }, Waist = { -10, 30 }, Neck = { 8, -24 }, RightShoulder = { 115, 0, 10 }, RightElbow = { 8 }, LeftShoulder = { 10, 0, -30 }, LeftElbow = { 60 } }), "Snap" },
	{ 0.5, Pose.Merge(STANCE, { Root = { -22, 40, 0, 0, -0.4, -0.3 }, LFoot = { -0.38, 0, -0.9, 0 }, Waist = { -12, 32 }, Neck = { 10, -26 }, RightShoulder = { 30, 0, -40 }, RightElbow = { 20 }, LeftShoulder = { 0, 0, -30 }, LeftElbow = { 60 } }) },
	{ 0.7, stance({ LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})

-- Awakened 3: Goal Line Stand - braced counter stance (held by the move).
Football.Brace = Clip("Football.Brace", { Loop = true, FadeIn = 0.05 }, {
	{ 0, { Root = { -14, 0, 0, 0, -0.75, 0 }, RFoot = { 0.55, 0, 0.3, 0 }, LFoot = { -0.55, 0, -0.3, 0 }, Waist = { -10 }, Neck = { 18 }, RightShoulder = { 55, 0, 30 }, RightElbow = { 90 }, LeftShoulder = { 55, 0, -30 }, LeftElbow = { 90 } } },
	{ 0.3, { Root = { -15, 0, 0, 0, -0.78, 0 }, RFoot = { 0.55, 0, 0.3, 0 }, LFoot = { -0.55, 0, -0.3, 0 }, Waist = { -11 }, Neck = { 18 }, RightShoulder = { 57, 0, 30 }, RightElbow = { 92 }, LeftShoulder = { 57, 0, -30 }, LeftElbow = { 92 } } },
	{ 0.6, { Root = { -14, 0, 0, 0, -0.75, 0 }, RFoot = { 0.55, 0, 0.3, 0 }, LFoot = { -0.55, 0, -0.3, 0 }, Waist = { -10 }, Neck = { 18 }, RightShoulder = { 55, 0, 30 }, RightElbow = { 90 }, LeftShoulder = { 55, 0, -30 }, LeftElbow = { 90 } } },
})

-- Awakened 4: Meteor Sack - grab and lift overhead (0.4 .. 1.6), piledrive at 1.7.
Football.MeteorSack = Clip("Football.MeteorSack", { FadeIn = 0.04, FadeOut = 0.25 }, {
	{ 0, CHARGE_A },
	{ 0.12, CHARGE_B, "Linear" },
	{ 0.24, CHARGE_A, "Linear" },
	{ 0.36, { Root = { -10, 0, 0, 0, -0.6, 0 }, RFoot = { 0.4, 0, 0.2, 0 }, LFoot = { -0.4, 0, -0.2, 0 }, Neck = { 10 }, RightShoulder = { 90, 0, -20 }, RightElbow = { 90 }, LeftShoulder = { 90, 0, 20 }, LeftElbow = { 90 } } },
	{ 0.55, { Root = { 6, 0, 0, 0, 0.2, 0 }, RightHip = { 30 }, RightKnee = { -60 }, LeftHip = { 20 }, LeftKnee = { -60 }, Neck = { -20 }, RightShoulder = { 170, 0, -8 }, RightElbow = { 30 }, LeftShoulder = { 170, 0, 8 }, LeftElbow = { 30 } }, "Out" },
	{ 1.55, { Root = { 10, 0, 0, 0, 0.3, 0 }, RightHip = { 40 }, RightKnee = { -70 }, LeftHip = { 30 }, LeftKnee = { -70 }, Neck = { -24 }, RightShoulder = { 172, 0, -8 }, RightElbow = { 30 }, LeftShoulder = { 172, 0, 8 }, LeftElbow = { 30 } } },
	{ 1.7, { Root = { -40, 0, 0, 0, -1.1, -0.4 }, RFoot = { 0.5, 0, 0.6, 0 }, LFoot = { -0.5, 0, -0.4, 0 }, Waist = { -24 }, Neck = { 30 }, RightShoulder = { 60, 0, -10 }, RightElbow = { 20 }, LeftShoulder = { 60, 0, 10 }, LeftElbow = { 20 } }, "Snap" },
	{ 2.0, { Root = { -34, 0, 0, 0, -1.0, -0.4 }, RFoot = { 0.5, 0, 0.6, 0 }, LFoot = { -0.5, 0, -0.4, 0 }, Waist = { -20 }, Neck = { 24 }, RightShoulder = { 55, 0, -10 }, RightElbow = { 25 }, LeftShoulder = { 55, 0, 10 }, LeftElbow = { 25 } } },
	{ 2.4, stance({ LeftShoulder = { 20, 0, -20 }, LeftElbow = { 40 } }) },
})

-- Awakening: fists together, then a double-biceps roar (2.2 s).
Football.Awaken = Clip("Football.Awaken", { FadeIn = 0.1, FadeOut = 0.3 }, {
	{ 0, Pose.Merge(STANCE, { Waist = { -6 }, Neck = { -10 }, RightShoulder = { 30, 0, 20 }, RightElbow = { 40 }, LeftShoulder = { 30, 0, -20 }, LeftElbow = { 40 } }) },
	{ 0.5, Pose.Merge(STANCE, { Root = { -10, 0, 0, 0, -0.6, 0 }, Waist = { -14 }, Neck = { -18 }, RightShoulder = { 75, 30, -10 }, RightElbow = { 95 }, LeftShoulder = { 75, -30, 10 }, LeftElbow = { 95 } }), "In" },
	{ 0.7, Pose.Merge(STANCE, { Root = { -12, 0, 0, 0, -0.7, 0 }, Waist = { -16 }, Neck = { -20 }, RightShoulder = { 80, 30, -14 }, RightElbow = { 100 }, LeftShoulder = { 80, -30, 14 }, LeftElbow = { 100 } }) },
	{ 1.05, { Root = { 10, 0, 0, 0, -0.35, 0 }, RFoot = { 0.6, 0, 0, 0 }, LFoot = { -0.6, 0, 0, 0 }, Waist = { 14 }, Neck = { 30 }, RightShoulder = { 0, 0, 92 }, RightElbow = { 125 }, LeftShoulder = { 0, 0, -92 }, LeftElbow = { 125 } }, "OutBack" },
	{ 2.2, { Root = { 8, 0, 0, 0, -0.35, 0 }, RFoot = { 0.6, 0, 0, 0 }, LFoot = { -0.6, 0, 0, 0 }, Waist = { 10 }, Neck = { 24 }, RightShoulder = { 0, 0, 90 }, RightElbow = { 128 }, LeftShoulder = { 0, 0, -90 }, LeftElbow = { 128 } } },
})

-- Idle fidget: rolls the shoulders and cracks the neck (1.6 s).
Football.ShoulderRoll = Clip("Football.ShoulderRoll", { FadeIn = 0.15, FadeOut = 0.25 }, {
	{ 0, { Waist = { -4, 0, 0 }, Neck = { 2, 0, 0 }, LeftShoulder = { 8, 0, -18 }, LeftElbow = { 20 } } },
	{ 0.35, { Waist = { 2, 12, 4 }, Neck = { -6, 0, 18 }, LeftShoulder = { -14, 0, -26 }, LeftElbow = { 30 } }, "InOut" },
	{ 0.6, { Waist = { -2, 12, 4 }, Neck = { 0, 0, 24 }, LeftShoulder = { 14, 0, -12 }, LeftElbow = { 25 } }, "InOut" },
	{ 0.9, { Waist = { 0, -10, -4 }, Neck = { 0, 0, -22 }, LeftShoulder = { 4, 0, -20 }, LeftElbow = { 20 } }, "InOut" },
	{ 1.05, { Waist = { 0, -10, -4 }, Neck = { 0, 0, -26 }, LeftShoulder = { 4, 0, -20 }, LeftElbow = { 20 } }, "Snap" },
	{ 1.6, { Waist = { -4, 0, 0 }, Neck = { 2, 0, 0 }, LeftShoulder = { 8, 0, -18 }, LeftElbow = { 20 } }, "InOut" },
})
Football.Fidgets = { Football.ShoulderRoll }

return Football
