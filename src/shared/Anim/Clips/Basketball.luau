--[[
	Basketball clips. The ball hangs off the root (Prop channel = offset from where it rests on the floor
	by the right foot), so clips that hold the ball move it to the hands with Prop offsets.
	Hit timings used by Client/Moves/Basketball.luau are noted per clip.
]]

local Pose = require(script.Parent.Parent.Pose)

local Clip = Pose.Clip

local Basketball = {}

-- Ball positions (Prop offsets from its rest spot)
local BALL_CHEST = { 0, 0, 0, -1.4, 2.8, -0.85 }
local BALL_RIGHT_HIP = { 0, 0, 0, -0.35, 1.8, -0.2 }
local BALL_OVERHEAD = { 0, 0, 0, -0.8, 5.9, -0.3 }

local STANCE = {
	Root = { -8, 0, 0, 0, -0.35, 0 },
	RFoot = { 0.32, 0, -0.2, 0 },
	LFoot = { -0.32, 0, 0.25, 0 },
}

local function stance(extra: Pose.Pose): Pose.Pose
	return Pose.Merge(STANCE, extra)
end

-- M1 #1: jab with the ball in the right hand. Hit at 0.12.
Basketball.Jab = Clip("Basketball.Jab", { FadeIn = 0.04, FadeOut = 0.12 }, {
	{ 0, stance({ Waist = { -4, 20 }, RightShoulder = { 40, 0, 15 }, RightElbow = { 100 }, LeftShoulder = { 40, 0, -20 }, LeftElbow = { 90 }, Prop = { 0, 0, 0, -0.6, 2.6, -0.4 } }) },
	{ 0.12, stance({ Root = { -12, -10, 0, 0, -0.35, -0.2 }, Waist = { -6, -28 }, Neck = { 6, 20 }, RightShoulder = { 88, 0, -4 }, RightElbow = { 2 }, LeftShoulder = { 30, 0, -25 }, LeftElbow = { 100 }, Prop = { -90, 0, 0, -0.75, 3.2, -2.1 } }), "Snap" },
	{ 0.18, stance({ Root = { -12, -10, 0, 0, -0.35, -0.2 }, Waist = { -6, -26 }, Neck = { 6, 18 }, RightShoulder = { 86, 0, -4 }, RightElbow = { 8 }, LeftShoulder = { 30, 0, -25 }, LeftElbow = { 100 }, Prop = { -90, 0, 0, -0.75, 3.15, -2.0 } }) },
	{ 0.3, stance({ Waist = { -4, 10 }, RightShoulder = { 35, 0, 18 }, RightElbow = { 80 }, LeftShoulder = { 35, 0, -22 }, LeftElbow = { 80 }, Prop = BALL_RIGHT_HIP }) },
})

-- M1 #2: left elbow. Hit at 0.12.
Basketball.Elbow = Clip("Basketball.Elbow", { FadeIn = 0.04, FadeOut = 0.12 }, {
	{ 0, stance({ Waist = { -4, -25 }, LeftShoulder = { 60, 0, -50 }, LeftElbow = { 125 }, RightShoulder = { 20, 0, 20 }, RightElbow = { 60 }, Prop = BALL_RIGHT_HIP }) },
	{ 0.12, stance({ Root = { -10, 20, 0, 0, -0.35, -0.15 }, Waist = { -6, 38 }, Neck = { 4, -30 }, LeftShoulder = { 92, 0, -8 }, LeftElbow = { 135 }, RightShoulder = { 10, 0, 25 }, RightElbow = { 50 }, Prop = BALL_RIGHT_HIP }), "Snap" },
	{ 0.18, stance({ Root = { -10, 20, 0, 0, -0.35, -0.15 }, Waist = { -6, 36 }, Neck = { 4, -28 }, LeftShoulder = { 90, 0, -10 }, LeftElbow = { 132 }, RightShoulder = { 10, 0, 25 }, RightElbow = { 50 }, Prop = BALL_RIGHT_HIP }) },
	{ 0.3, stance({ Waist = { -4, 5 }, LeftShoulder = { 30, 0, -25 }, LeftElbow = { 70 }, RightShoulder = { 20, 0, 20 }, RightElbow = { 60 }, Prop = BALL_RIGHT_HIP }) },
})

-- M1 #3: two-handed ball slam from overhead. Hit at 0.14.
Basketball.Slam = Clip("Basketball.Slam", { FadeIn = 0.04, FadeOut = 0.12 }, {
	{ 0, stance({ Root = { 6, 0, 0, 0, -0.2, 0 }, Waist = { 8 }, RightShoulder = { 160, 0, 10 }, RightElbow = { 40 }, LeftShoulder = { 160, 0, -10 }, LeftElbow = { 40 }, Prop = BALL_OVERHEAD }) },
	{ 0.14, stance({ Root = { -22, 0, 0, 0, -0.5, -0.2 }, Waist = { -18 }, Neck = { 18 }, RightShoulder = { 55, 0, -12 }, RightElbow = { 10 }, LeftShoulder = { 55, 0, 12 }, LeftElbow = { 10 }, Prop = { -180, 0, 0, -1.4, 1.6, -2.4 } }), "Snap" },
	{ 0.2, stance({ Root = { -22, 0, 0, 0, -0.5, -0.2 }, Waist = { -16 }, Neck = { 16 }, RightShoulder = { 52, 0, -12 }, RightElbow = { 14 }, LeftShoulder = { 52, 0, 12 }, LeftElbow = { 14 }, Prop = { -180, 0, 0, -1.4, 1.5, -2.3 } }) },
	{ 0.32, stance({ Waist = { -4 }, RightShoulder = { 35, 0, 18 }, RightElbow = { 70 }, LeftShoulder = { 35, 0, -18 }, LeftElbow = { 70 }, Prop = BALL_CHEST }) },
})

-- M1 #4: point-blank two-hand chest pass (knockback). Hit at 0.2.
Basketball.ChestPassHit = Clip("Basketball.ChestPassHit", { FadeIn = 0.04, FadeOut = 0.15 }, {
	{ 0, stance({ Waist = { -4 }, RightShoulder = { 30, 0, -10 }, RightElbow = { 120 }, LeftShoulder = { 30, 0, 10 }, LeftElbow = { 120 }, Prop = BALL_CHEST }) },
	{ 0.12, stance({ Root = { -4, 0, 0, 0, -0.45, 0.2 }, Waist = { 0 }, RightShoulder = { 25, 0, -8 }, RightElbow = { 135 }, LeftShoulder = { 25, 0, 8 }, LeftElbow = { 135 }, Prop = { 0, 0, 0, -1.4, 2.6, -0.5 } }) },
	{ 0.2, stance({ Root = { -16, 0, 0, 0, -0.35, -0.5 }, Waist = { -8 }, Neck = { 10 }, RightShoulder = { 86, 0, -10 }, RightElbow = { 2 }, LeftShoulder = { 86, 0, 10 }, LeftElbow = { 2 }, Prop = { -90, 0, 0, -1.4, 2.9, -2.6 } }), "Snap" },
	{ 0.42, stance({ Waist = { -4 }, RightShoulder = { 35, 0, 15 }, RightElbow = { 70 }, LeftShoulder = { 35, 0, -15 }, LeftElbow = { 70 }, Prop = BALL_RIGHT_HIP }) },
})

-- M1 Uppercut variant: rising ball uppercut. Hit at 0.16.
Basketball.Uppercut = Clip("Basketball.Uppercut", { FadeIn = 0.04, FadeOut = 0.15 }, {
	{ 0, stance({ Root = { -14, 0, 0, 0, -0.75, 0 }, Waist = { -10, 20 }, RightShoulder = { -20, 0, 20 }, RightElbow = { 60 }, Prop = { 0, 0, 0, -0.4, 0.9, -0.4 } }) },
	{ 0.16, stance({ Root = { 16, 0, 0, 0, 0.2, 0 }, Waist = { 12, -20 }, Neck = { -15 }, RightShoulder = { 165, 0, 0 }, RightElbow = { 20 }, LeftShoulder = { -20, 0, -30 }, Prop = { -200, 0, 0, -0.9, 6.2, -1.2 } }), "Snap" },
	{ 0.26, stance({ Root = { 14, 0, 0, 0, 0.15, 0 }, Waist = { 10, -18 }, Neck = { -12 }, RightShoulder = { 160, 0, 0 }, RightElbow = { 25 }, LeftShoulder = { -20, 0, -30 }, Prop = { -220, 0, 0, -0.9, 6.0, -1.1 } }) },
	{ 0.42, stance({ RightShoulder = { 30, 0, 18 }, RightElbow = { 70 }, Prop = BALL_RIGHT_HIP }) },
})

-- M1 Downslam variant: mid-air dunk slam. Hit at 0.2.
Basketball.Downslam = Clip("Basketball.Downslam", { FadeIn = 0.04, FadeOut = 0.15 }, {
	{ 0, { Root = { 10, 0, 0, 0, 0, 0 }, RightHip = { 60 }, RightKnee = { -90 }, LeftHip = { 10 }, LeftKnee = { -40 }, RightShoulder = { 170, 0, 10 }, RightElbow = { 30 }, LeftShoulder = { 120, 0, -20 }, Prop = BALL_OVERHEAD } },
	{ 0.2, { Root = { -30, 0, 0, 0, -0.2, 0 }, RightHip = { 40 }, RightKnee = { -60 }, LeftHip = { 30 }, LeftKnee = { -50 }, Waist = { -20 }, Neck = { 20 }, RightShoulder = { 30, 0, 0 }, RightElbow = { 5 }, LeftShoulder = { 30, 0, -20 }, Prop = { -270, 0, 0, -0.8, 0.6, -2.2 } }, "Snap" },
	{ 0.42, stance({ Prop = BALL_RIGHT_HIP }) },
})

-- 1: Ankle Breaker - crossover left, explode, left-hand ball jab at 0.35.
Basketball.AnkleBreaker = Clip("Basketball.AnkleBreaker", { FadeIn = 0.03, FadeOut = 0.15 }, {
	{ 0, stance({ Root = { -12, -10, -8, 0.5, -0.5, 0 }, Waist = { -6, 10 }, RightShoulder = { 20, 0, 30 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -40 }, LeftElbow = { 70 }, Prop = { 0, 0, 0, -0.3, 0.3, -0.5 } }) },
	{ 0.12, stance({ Root = { -14, 12, 10, -0.6, -0.6, 0 }, Waist = { -8, -12 }, Neck = { 10, 8 }, RightShoulder = { 20, 0, 40 }, RightElbow = { 40 }, LeftShoulder = { 20, 0, -30 }, LeftElbow = { 60 }, Prop = { -360, 0, 0, -2.9, 0.25, -0.6 } }), "Out" },
	{ 0.24, stance({ Root = { -16, 6, 6, -0.3, -0.55, -0.4 }, Waist = { -8, -20 }, Neck = { 12, 10 }, LeftShoulder = { 40, 0, -20 }, LeftElbow = { 90 }, RightShoulder = { 30, 0, 30 }, RightElbow = { 60 }, Prop = { -360, 0, 0, -2.2, 2.6, -0.7 } }) },
	{ 0.35, stance({ Root = { -14, -18, 0, -0.2, -0.4, -0.6 }, Waist = { -6, 30 }, Neck = { 6, -24 }, LeftShoulder = { 90, 0, 4 }, LeftElbow = { 2 }, RightShoulder = { 20, 0, 30 }, RightElbow = { 80 }, Prop = { -450, 0, 0, -2.2, 3.1, -2.1 } }), "Snap" },
	{ 0.55, stance({ Waist = { -4, 5 }, LeftShoulder = { 30, 0, -25 }, LeftElbow = { 80 }, RightShoulder = { 25, 0, 20 }, RightElbow = { 60 }, Prop = BALL_RIGHT_HIP }) },
})

-- 2: Chest Pass - ball leaves at 0.15.
Basketball.ChestPass = Clip("Basketball.ChestPass", { FadeIn = 0.03, FadeOut = 0.15 }, {
	{ 0, stance({ Waist = { -4 }, RightShoulder = { 30, 0, -10 }, RightElbow = { 120 }, LeftShoulder = { 30, 0, 10 }, LeftElbow = { 120 }, Prop = BALL_CHEST }) },
	{ 0.08, stance({ Root = { -4, 0, 0, 0, -0.45, 0.2 }, RightShoulder = { 25, 0, -8 }, RightElbow = { 138 }, LeftShoulder = { 25, 0, 8 }, LeftElbow = { 138 }, Prop = { 0, 0, 0, -1.4, 2.6, -0.45 } }) },
	{ 0.15, stance({ Root = { -14, 0, 0, 0, -0.35, -0.4 }, Waist = { -6 }, RightShoulder = { 84, 0, -8 }, RightElbow = { 2 }, RightWrist = { 30 }, LeftShoulder = { 84, 0, 8 }, LeftElbow = { 2 }, LeftWrist = { 30 } }), "Snap" },
	{ 0.42, stance({ RightShoulder = { 35, 0, 15 }, RightElbow = { 70 }, LeftShoulder = { 35, 0, -15 }, LeftElbow = { 70 } }) },
})

-- 3: Alley-Oop - crouch, explode upward, launch at 0.25.
Basketball.AlleyOop = Clip("Basketball.AlleyOop", { FadeIn = 0.03, FadeOut = 0.18 }, {
	{ 0, stance({ Root = { -24, 0, 0, 0, -0.9, 0 }, Waist = { -14 }, RightShoulder = { 0, 0, -20 }, RightElbow = { 30 }, LeftShoulder = { 0, 0, 20 }, LeftElbow = { 30 }, Prop = { 0, 0, 0, -1.4, 0.9, -1.2 } }) },
	{ 0.12, stance({ Root = { -26, 0, 0, 0, -1.0, 0 }, Waist = { -16 }, RightShoulder = { -10, 0, -20 }, RightElbow = { 30 }, LeftShoulder = { -10, 0, 20 }, LeftElbow = { 30 }, Prop = { 0, 0, 0, -1.4, 0.7, -1.1 } }) },
	{ 0.25, stance({ Root = { 10, 0, 0, 0, 0.3, 0 }, Waist = { 12 }, Neck = { -24 }, RightShoulder = { 172, 0, -6 }, RightElbow = { 5 }, LeftShoulder = { 172, 0, 6 }, LeftElbow = { 5 }, Prop = { -180, 0, 0, -1.4, 8.0, -2.0 } }), "Snap" },
	{ 0.4, stance({ Root = { 8, 0, 0, 0, 0.2, 0 }, Waist = { 10 }, Neck = { -26 }, RightShoulder = { 165, 0, -6 }, RightElbow = { 10 }, LeftShoulder = { 165, 0, 6 }, LeftElbow = { 10 }, Prop = { -260, 0, 0, -1.4, 10.0, -2.2 } }) },
	{ 0.6, stance({ RightShoulder = { 40, 0, 15 }, RightElbow = { 60 }, LeftShoulder = { 40, 0, -15 }, LeftElbow = { 60 }, Prop = BALL_RIGHT_HIP }) },
})

-- 4: Slam Dunk - leap at 0.14, airborne with the ball overhead, slam at 0.62.
Basketball.SlamDunk = Clip("Basketball.SlamDunk", { FadeIn = 0.04, FadeOut = 0.2 }, {
	{ 0, stance({ Root = { -20, 0, 0, 0, -0.8, 0 }, Waist = { -12 }, RightShoulder = { 30, 0, -10 }, RightElbow = { 110 }, LeftShoulder = { 30, 0, 10 }, LeftElbow = { 110 }, Prop = BALL_CHEST }) },
	{ 0.14, { Root = { 6, 0, 0, 0, 0.2, 0 }, RightHip = { 95 }, RightKnee = { -110 }, LeftHip = { -10 }, LeftKnee = { -30 }, Waist = { 6 }, Neck = { -10 }, RightShoulder = { 120, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 110, 0, -10 }, LeftElbow = { 50 }, Prop = { -90, 0, 0, -0.9, 5.0, -0.8 } }, "Out" },
	{ 0.48, { Root = { 12, 0, 0, 0, 0.3, 0 }, RightHip = { 100 }, RightKnee = { -115 }, LeftHip = { 20 }, LeftKnee = { -60 }, Waist = { 14 }, Neck = { -18 }, RightShoulder = { 178, 0, 10 }, RightElbow = { 30 }, LeftShoulder = { 90, 0, -20 }, LeftElbow = { 10 }, Prop = { -120, 0, 0, -0.6, 6.4, 0.3 } } },
	{ 0.62, { Root = { -28, 0, 0, 0, -0.2, 0 }, RightHip = { 60 }, RightKnee = { -80 }, LeftHip = { 30 }, LeftKnee = { -60 }, Waist = { -22 }, Neck = { 22 }, RightShoulder = { 40, 0, 4 }, RightElbow = { 4 }, LeftShoulder = { 50, 0, -30 }, LeftElbow = { 20 }, Prop = { -330, 0, 0, -0.8, 1.0, -2.4 } }, "Snap" },
	{ 0.8, stance({ Root = { -24, 0, 0, 0, -1.0, 0 }, Waist = { -14 }, Neck = { 16 }, RightShoulder = { 30, 0, 30 }, RightElbow = { 30 }, LeftShoulder = { 30, 0, -30 }, LeftElbow = { 30 }, Prop = { -360, 0, 0, -0.4, 0.4, -1.4 } }), "In" },
	{ 1.05, stance({ RightShoulder = { 30, 0, 18 }, RightElbow = { 60 }, Prop = BALL_RIGHT_HIP }) },
})

-- Awakened 1: Heat Check - three jump shots, released at 0.15, 0.35, 0.55.
do
	local keys: { { any } } = {}
	for i = 0, 2 do
		local t = i * 0.2
		table.insert(keys, Pose.Key( t, stance({ Root = { 0, 0, 0, 0, -0.1, 0 }, RightShoulder = { 150, 0, 10 }, RightElbow = { 95 }, RightWrist = { 30 }, LeftShoulder = { 140, 0, -15 }, LeftElbow = { 90 }, Prop = { 0, 0, 0, -1.0, 5.3, -0.5 } }) ))
		table.insert(keys, Pose.Key( t + 0.15, stance({ Root = { 4, 0, 0, 0, 0.4, 0 }, Neck = { -12 }, RightShoulder = { 160, 0, 5 }, RightElbow = { 8 }, RightWrist = { -60 }, LeftShoulder = { 130, 0, -15 }, LeftElbow = { 40 } }), "Snap" ))
	end
	table.insert(keys, Pose.Key( 0.8, stance({ RightShoulder = { 35, 0, 18 }, RightElbow = { 60 }, Prop = BALL_RIGHT_HIP }) ))
	Basketball.HeatCheck = Clip("Basketball.HeatCheck", { FadeIn = 0.04, FadeOut = 0.18 }, keys)
end

-- Awakened 2: Fast Break - blazing dribble sprint (0.6).
local SPRINT_A = {
	Root = { -28, 0, 0, 0, -0.25, 0 },
	RFoot = { 0.1, 0.9, -0.7, -25 },
	LFoot = { -0.1, 0.45, 0.85, -45 },
	Neck = { 22 },
	RightShoulder = { 40, 0, 20 },
	RightElbow = { 50 },
	LeftShoulder = { 50, 0, -12 },
	LeftElbow = { 85 },
	Prop = { 0, 0, 0, -0.6, 0.3, -1.6 },
}
local SPRINT_B = Pose.Merge(SPRINT_A, {
	RFoot = { 0.1, 0.45, 0.85, -45 },
	LFoot = { -0.1, 0.9, -0.7, -25 },
	LeftShoulder = { -50, 0, -12 },
	Prop = { -360, 0, 0, -0.6, 1.6, -1.6 },
})
Basketball.FastBreak = Clip("Basketball.FastBreak", { FadeIn = 0.03, FadeOut = 0.15 }, {
	{ 0, SPRINT_A },
	{ 0.12, SPRINT_B, "Linear" },
	{ 0.24, SPRINT_A, "Linear" },
	{ 0.36, SPRINT_B, "Linear" },
	{ 0.48, SPRINT_A, "Linear" },
	{ 0.6, stance({ Prop = BALL_RIGHT_HIP }) },
})

-- Awakened 3: Crossover Combo - five alternating strikes (0.1 .. 0.58), two-hand blast at 0.8.
do
	local keys: { { any } } = { { 0, stance({ Prop = BALL_CHEST }) } }
	for i = 0, 4 do
		local t = 0.1 + i * 0.12
		local right = i % 2 == 0
		local strike = if right
			then stance({ Root = { -12, -12, 0, 0.2, -0.4, -0.2 }, Waist = { -6, -26 }, RightShoulder = { 88, 0, -4 }, RightElbow = { 2 }, LeftShoulder = { 30, 0, -25 }, LeftElbow = { 100 }, Prop = { -90, 0, 0, -0.75, 3.2, -2.1 } })
			else stance({ Root = { -12, 12, 0, -0.2, -0.4, -0.2 }, Waist = { -6, 26 }, LeftShoulder = { 88, 0, 4 }, LeftElbow = { 2 }, RightShoulder = { 30, 0, 25 }, RightElbow = { 100 }, Prop = { -90, 0, 0, -2.05, 3.2, -2.1 } })
		table.insert(keys, Pose.Key( t - 0.05, stance({ Root = { -10, 0, 0, 0, -0.45, 0 }, RightShoulder = { 40, 0, 10 }, RightElbow = { 100 }, LeftShoulder = { 40, 0, -10 }, LeftElbow = { 100 }, Prop = BALL_CHEST }) ))
		table.insert(keys, Pose.Key( t, strike, "Snap" ))
	end
	table.insert(keys, Pose.Key( 0.7, stance({ Root = { -4, 0, 0, 0, -0.5, 0.2 }, RightShoulder = { 25, 0, -8 }, RightElbow = { 138 }, LeftShoulder = { 25, 0, 8 }, LeftElbow = { 138 }, Prop = { 0, 0, 0, -1.4, 2.6, -0.45 } }) ))
	table.insert(keys, Pose.Key( 0.8, stance({ Root = { -18, 0, 0, 0, -0.35, -0.6 }, Waist = { -8 }, RightShoulder = { 86, 0, -10 }, RightElbow = { 2 }, LeftShoulder = { 86, 0, 10 }, LeftElbow = { 2 }, Prop = { -90, 0, 0, -1.4, 2.9, -2.8 } }), "Snap" ))
	table.insert(keys, Pose.Key( 1.0, stance({ RightShoulder = { 35, 0, 15 }, RightElbow = { 70 }, LeftShoulder = { 35, 0, -15 }, LeftElbow = { 70 }, Prop = BALL_RIGHT_HIP }) ))
	Basketball.CrossoverCombo = Clip("Basketball.CrossoverCombo", { FadeIn = 0.03, FadeOut = 0.15 }, keys)
end

-- Awakened 4: Supernova Dunk - crouch, soar with the sun overhead, slam at 1.5, land 1.6.
Basketball.Supernova = Clip("Basketball.Supernova", { FadeIn = 0.05, FadeOut = 0.3 }, {
	{ 0, stance({ Root = { -24, 0, 0, 0, -1.0, 0 }, Waist = { -14 }, RightShoulder = { 20, 0, -10 }, RightElbow = { 110 }, LeftShoulder = { 20, 0, 10 }, LeftElbow = { 110 }, Prop = BALL_CHEST }) },
	{ 0.25, { Root = { 8, 0, 0, 0, 0.3, 0 }, RightHip = { 100 }, RightKnee = { -120 }, LeftHip = { 80 }, LeftKnee = { -120 }, Neck = { -20 }, RightShoulder = { 175, 0, -8 }, RightElbow = { 20 }, LeftShoulder = { 175, 0, 8 }, LeftElbow = { 20 }, Prop = { -180, 0, 0, -1.4, 6.6, -0.6 } }, "Out" },
	{ 1.35, { Root = { 14, 0, 0, 0, 0.4, 0 }, RightHip = { 105 }, RightKnee = { -125 }, LeftHip = { 85 }, LeftKnee = { -125 }, Waist = { 14 }, Neck = { -24 }, RightShoulder = { 178, 0, -6 }, RightElbow = { 30 }, LeftShoulder = { 178, 0, 6 }, LeftElbow = { 30 }, Prop = { -900, 0, 0, -1.4, 7.0, 0.2 } } },
	{ 1.5, { Root = { -34, 0, 0, 0, -0.2, 0 }, RightHip = { 60 }, RightKnee = { -80 }, LeftHip = { 40 }, LeftKnee = { -70 }, Waist = { -24 }, Neck = { 24 }, RightShoulder = { 45, 0, -6 }, RightElbow = { 4 }, LeftShoulder = { 45, 0, 6 }, LeftElbow = { 4 }, Prop = { -1080, 0, 0, -1.4, 0.8, -2.6 } }, "Snap" },
	{ 1.62, stance({ Root = { -30, 0, 0, 0, -1.2, 0 }, Waist = { -18 }, Neck = { 20 }, RightShoulder = { 20, 0, 40 }, RightElbow = { 20 }, LeftShoulder = { 20, 0, -40 }, LeftElbow = { 20 }, Prop = { -1080, 0, 0, -1.4, 0.4, -2.0 } }), "In" },
	{ 2.1, stance({ RightShoulder = { 30, 0, 18 }, RightElbow = { 60 }, Prop = BALL_RIGHT_HIP }) },
})

-- Awakening: spins the ball on a finger, then flames erupt (2.2 s).
Basketball.Awaken = Clip("Basketball.Awaken", { FadeIn = 0.1, FadeOut = 0.3 }, {
	{ 0, { Root = { 0, 0, 0, 0, -0.05, 0 }, RFoot = { 0.2, 0, 0, 0 }, LFoot = { -0.2, 0, 0, 0 }, Neck = { 10 }, RightShoulder = { 140, 0, 10 }, RightElbow = { 70 }, LeftShoulder = { 5, 0, -10 }, LeftElbow = { 20 }, Prop = { 0, 0, 0, -1.0, 6.0, -0.6 } } },
	{ 1.0, { Root = { 0, 0, 0, 0, -0.05, 0 }, RFoot = { 0.2, 0, 0, 0 }, LFoot = { -0.2, 0, 0, 0 }, Neck = { 14 }, RightShoulder = { 142, 0, 10 }, RightElbow = { 72 }, LeftShoulder = { 5, 0, -10 }, LeftElbow = { 20 }, Prop = { 0, 1440, 0, -1.0, 6.0, -0.6 } } },
	{ 1.25, { Root = { 10, 0, 0, 0, -0.3, 0 }, RFoot = { 0.45, 0, 0, 0 }, LFoot = { -0.45, 0, 0, 0 }, Waist = { 14 }, Neck = { 30 }, RightShoulder = { 30, 0, 90 }, RightElbow = { 30 }, LeftShoulder = { 30, 0, -90 }, LeftElbow = { 30 }, Prop = { 0, 1800, 0, -1.4, 7.5, -0.6 } }, "OutBack" },
	{ 2.2, { Root = { 8, 0, 0, 0, -0.3, 0 }, RFoot = { 0.45, 0, 0, 0 }, LFoot = { -0.45, 0, 0, 0 }, Waist = { 10 }, Neck = { 22 }, RightShoulder = { 28, 0, 85 }, RightElbow = { 30 }, LeftShoulder = { 28, 0, -85 }, LeftElbow = { 30 }, Prop = { 0, 2600, 0, -1.4, 7.2, -0.6 } } },
})

-- Idle fidget: between-the-legs crossover and back (1.2 s).
Basketball.BetweenLegs = Clip("Basketball.BetweenLegs", { FadeIn = 0.12, FadeOut = 0.2 }, {
	{ 0, stance({ RightShoulder = { 20, 0, 22 }, RightElbow = { 55 }, LeftShoulder = { 20, 0, -22 }, LeftElbow = { 60 }, Prop = { 0, 0, 0, 0, 1.6, 0 } }) },
	{ 0.2, stance({ Root = { -14, 0, 0, 0, -0.55, 0 }, RightShoulder = { 0, 0, 10 }, RightElbow = { 30 }, LeftShoulder = { 0, 0, -10 }, LeftElbow = { 30 }, Prop = { -180, 0, 0, -1.3, 0.15, 0.05 } }), "In" },
	{ 0.42, stance({ Root = { -12, -6, 0, 0, -0.5, 0 }, RightShoulder = { 10, 0, 15 }, RightElbow = { 40 }, LeftShoulder = { 10, 0, -20 }, LeftElbow = { 55 }, Prop = { -360, 0, 0, -2.75, 1.5, -0.2 } }), "Out" },
	{ 0.62, stance({ Root = { -14, 0, 0, 0, -0.55, 0 }, RightShoulder = { 0, 0, 10 }, RightElbow = { 30 }, LeftShoulder = { 0, 0, -10 }, LeftElbow = { 30 }, Prop = { -540, 0, 0, -1.3, 0.15, 0.05 } }), "In" },
	{ 0.85, stance({ RightShoulder = { 20, 0, 22 }, RightElbow = { 55 }, LeftShoulder = { 20, 0, -22 }, LeftElbow = { 60 }, Prop = { -720, 0, 0, 0, 1.7, -0.1 } }), "Out" },
	{ 1.2, stance({ RightShoulder = { 20, 0, 22 }, RightElbow = { 55 }, LeftShoulder = { 22, 0, -24 }, LeftElbow = { 70 }, Prop = { -720, 0, 0, 0, 0.9, 0 } }) },
})
Basketball.Fidgets = { Basketball.BetweenLegs }

return Basketball
