--[[
	Baseball clips. The bat hangs off the right hand (rest = sticking out forward from the fist); the
	Prop channel turns it in the hand. Prop { -90 } lines the bat up with the forearm, which is what the
	swings use. Pitches are thrown left-handed so the bat never leaves the right hand.
	Hit timings used by Client/Moves/Baseball.luau are noted per clip.
]]

local Pose = require(script.Parent.Parent.Pose)

local Clip = Pose.Clip
local Mirror = Pose.MirrorClip

local Baseball = {}

local STANCE = {
	Root = { -6, 0, 0, 0, -0.35, 0 },
	RFoot = { 0.4, 0, 0.2, 0 },
	LFoot = { -0.4, 0, -0.2, 0 },
}
local BAT_LINE = { -90, 0, 0 }

local function stance(extra: Pose.Pose): Pose.Pose
	return Pose.Merge(STANCE, extra)
end

-- Two-handed swing pieces: arms reach forward together, the body turn does the swinging
local function swing(waistYaw: number, rootYaw: number, armPitch: number, batTilt: number): Pose.Pose
	return stance({
		Root = { -6, rootYaw, 0, 0, -0.35, 0 },
		Waist = { -4, waistYaw, 0 },
		Neck = { 0, -waistYaw * 0.6, 0 },
		RightShoulder = { armPitch, 0, -12 },
		RightElbow = { 10 },
		LeftShoulder = { armPitch, 0, 30 },
		LeftElbow = { 25 },
		Prop = { -90, batTilt, 0 },
	})
end

-- M1 #1: level swing, right to left. Hit at 0.13.
Baseball.Level = Clip("Baseball.Level", { FadeIn = 0.04, FadeOut = 0.12, Marks = { Contact = 0.13 } }, {
	{ 0, swing(-60, -20, 85, 30) },
	{ 0.13, swing(25, 10, 82, 0), "Snap" },
	{ 0.2, swing(60, 18, 80, -25) },
	{ 0.32, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40 }, Prop = { -40, 0, 0 } }) },
})

-- M1 #2: overhead chop. Hit at 0.13.
Baseball.Chop = Clip("Baseball.Chop", { FadeIn = 0.04, FadeOut = 0.12, Marks = { Contact = 0.13 } }, {
	{ 0, stance({ Root = { 6, 0, 0, 0, -0.25, 0 }, Waist = { 8 }, RightShoulder = { 165, 0, -10 }, RightElbow = { 20 }, LeftShoulder = { 160, 0, 25 }, LeftElbow = { 30 }, Prop = BAT_LINE }) },
	{ 0.13, stance({ Root = { -20, 0, 0, 0, -0.45, -0.2 }, Waist = { -16 }, Neck = { 14 }, RightShoulder = { 55, 0, -12 }, RightElbow = { 6 }, LeftShoulder = { 55, 0, 25 }, LeftElbow = { 15 }, Prop = BAT_LINE }), "Snap" },
	{ 0.2, stance({ Root = { -20, 0, 0, 0, -0.45, -0.2 }, Waist = { -14 }, Neck = { 12 }, RightShoulder = { 50, 0, -12 }, RightElbow = { 10 }, LeftShoulder = { 50, 0, 25 }, LeftElbow = { 18 }, Prop = BAT_LINE }) },
	{ 0.32, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40 }, Prop = { -40, 0, 0 } }) },
})

-- M1 #3: one-handed backhand, left to right. Hit at 0.13.
Baseball.Backhand = Clip("Baseball.Backhand", { FadeIn = 0.04, FadeOut = 0.12, Marks = { Contact = 0.13 } }, {
	{ 0, stance({ Root = { -6, 20, 0, 0, -0.35, 0 }, Waist = { -4, 50 }, RightShoulder = { 80, 0, -40 }, RightElbow = { 40 }, LeftShoulder = { 10, 0, -30 }, Prop = { -90, -40, 0 } }) },
	{ 0.13, stance({ Root = { -6, -20, 0, 0, -0.35, -0.1 }, Waist = { -4, -40 }, Neck = { 0, 26 }, RightShoulder = { 85, 0, 45 }, RightElbow = { 4 }, LeftShoulder = { 10, 0, -40 }, Prop = { -90, 20, 0 } }), "Snap" },
	{ 0.2, stance({ Root = { -6, -22, 0, 0, -0.35, -0.1 }, Waist = { -4, -42 }, Neck = { 0, 26 }, RightShoulder = { 80, 0, 55 }, RightElbow = { 8 }, LeftShoulder = { 10, 0, -40 }, Prop = { -90, 30, 0 } }) },
	{ 0.32, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40 }, Prop = { -40, 0, 0 } }) },
})

-- M1 #4: full power swing with a step (knockback). Hit at 0.22.
Baseball.PowerSwing = Clip("Baseball.PowerSwing", { FadeIn = 0.04, FadeOut = 0.15, Marks = { Contact = 0.22 } }, {
	{ 0, Pose.Merge(swing(-80, -30, 100, 40), { LFoot = { -0.3, 0.4, 0, 0 } }) },
	{ 0.12, Pose.Merge(swing(-85, -32, 105, 45), { LFoot = { -0.4, 0, -0.6, 0 } }) },
	{ 0.22, Pose.Merge(swing(30, 14, 85, 0), { LFoot = { -0.4, 0, -0.6, 0 } }), "Snap" },
	{ 0.34, Pose.Merge(swing(95, 24, 120, -40), { LFoot = { -0.4, 0, -0.6, 0 } }) },
	{ 0.46, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40 }, Prop = { -40, 0, 0 } }) },
})

-- M1 Uppercut: low-to-high golf swing. Hit at 0.16.
Baseball.Golf = Clip("Baseball.Golf", { FadeIn = 0.04, FadeOut = 0.15, Marks = { Contact = 0.16 } }, {
	{ 0, stance({ Root = { -20, -20, 0, 0, -0.7, 0 }, Waist = { -14, -30 }, RightShoulder = { -10, 0, -10 }, RightElbow = { 10 }, LeftShoulder = { -10, 0, 25 }, LeftElbow = { 20 }, Prop = BAT_LINE }) },
	{ 0.16, stance({ Root = { 12, 10, 0, 0, 0.1, 0 }, Waist = { 10, 20 }, Neck = { -18 }, RightShoulder = { 165, 0, -10 }, RightElbow = { 8 }, LeftShoulder = { 160, 0, 25 }, LeftElbow = { 15 }, Prop = BAT_LINE }), "Snap" },
	{ 0.26, stance({ Root = { 10, 10, 0, 0, 0.05, 0 }, Waist = { 8, 20 }, Neck = { -15 }, RightShoulder = { 160, 0, -10 }, RightElbow = { 10 }, LeftShoulder = { 155, 0, 25 }, LeftElbow = { 18 }, Prop = BAT_LINE }) },
	{ 0.42, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40 }, Prop = { -40, 0, 0 } }) },
})

-- M1 Downslam: jumping overhead smash. Hit at 0.22.
Baseball.Smash = Clip("Baseball.Smash", { FadeIn = 0.04, FadeOut = 0.15, Marks = { Contact = 0.22 } }, {
	{ 0, { Root = { 14, 0, 0, 0, 0, 0 }, RightHip = { 40 }, RightKnee = { -70 }, LeftHip = { 20 }, LeftKnee = { -50 }, Waist = { 10 }, RightShoulder = { 175, 0, -10 }, RightElbow = { 30 }, LeftShoulder = { 170, 0, 25 }, LeftElbow = { 30 }, Prop = BAT_LINE } },
	{ 0.22, { Root = { -32, 0, 0, 0, -0.2, 0 }, RightHip = { 40 }, RightKnee = { -60 }, LeftHip = { 30 }, LeftKnee = { -50 }, Waist = { -20 }, Neck = { 20 }, RightShoulder = { 45, 0, -12 }, RightElbow = { 5 }, LeftShoulder = { 45, 0, 25 }, LeftElbow = { 10 }, Prop = BAT_LINE }, "Snap" },
	{ 0.42, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40 }, Prop = { -40, 0, 0 } }) },
})

-- Pitch (authored right-handed, then mirrored to the left arm). Release at 0.28.
local PITCH_R = Clip("Baseball.PitchR", { FadeIn = 0.04, FadeOut = 0.15, Marks = { Release = 0.28 } }, {
	{ 0, { Root = { 0, -30, 0, 0, -0.2, 0 }, RFoot = { 0.2, 0, 0.2, 0 }, LeftHip = { 80 }, LeftKnee = { -100 }, Waist = { 0, -20 }, RightShoulder = { -30, 0, 30 }, RightElbow = { 30 }, LeftShoulder = { 40, 0, -30 }, LeftElbow = { 80 } } },
	{ 0.2, { Root = { 4, -40, 0, 0, -0.45, 0.2 }, RFoot = { 0.3, 0, 0.5, 0 }, LFoot = { -0.3, 0, -1.2, 0 }, Waist = { 4, -24 }, Neck = { -4, 36 }, RightShoulder = { 100, 0, 85 }, RightElbow = { 100 }, LeftShoulder = { 70, 0, -30 }, LeftElbow = { 30 } }, "Out" },
	{ 0.28, { Root = { -22, 30, 0, 0, -0.5, -0.2 }, RFoot = { 0.3, 0.2, 0.8, -30 }, LFoot = { -0.3, 0, -1.2, 0 }, Waist = { -12, 24 }, Neck = { 10, -20 }, RightShoulder = { 110, 0, -5 }, RightElbow = { 8 }, RightWrist = { -40 }, LeftShoulder = { -10, 0, -40 }, LeftElbow = { 70 } }, "Snap" },
	{ 0.4, { Root = { -30, 36, 0, 0, -0.55, -0.2 }, RFoot = { 0.3, 0.3, 0.9, -40 }, LFoot = { -0.3, 0, -1.2, 0 }, Waist = { -16, 28 }, Neck = { 14, -24 }, RightShoulder = { 30, 0, -40 }, RightElbow = { 20 }, LeftShoulder = { -20, 0, -40 }, LeftElbow = { 70 } } },
	{ 0.5, { Root = { -6, 0, 0, 0, -0.3, 0 }, RFoot = { 0.3, 0, 0.1, 0 }, LFoot = { -0.3, 0, -0.2, 0 }, RightShoulder = { 20, 0, 10 }, RightElbow = { 30 }, LeftShoulder = { 20, 0, -10 }, LeftElbow = { 30 } } },
})
Baseball.Pitch = Mirror(PITCH_R, "Baseball.Pitch")

-- 2: Stolen Base - slide in feet first (0.12 .. 0.45), trip at 0.3.
local SLIDE = {
	Root = { 66, 0, 0, 0, -1.45, 0.4 },
	Waist = { -20 },
	Neck = { -30 },
	RightHip = { 30 },
	RightKnee = { -10 },
	RightAnkle = { 10 },
	LeftHip = { 20 },
	LeftKnee = { -95 },
	RightShoulder = { 120, 0, 40 },
	RightElbow = { 30 },
	LeftShoulder = { -30, 0, -50 },
	LeftElbow = { 10 },
	Prop = { -60, 0, 0 },
}
Baseball.Slide = Clip("Baseball.Slide", { FadeIn = 0.04, FadeOut = 0.2, Marks = { Slide = 0.08 } }, {
	{ 0, stance({ Root = { -24, 0, 0, 0, -0.6, 0 }, Waist = { -10 } }) },
	{ 0.12, SLIDE, "Out" },
	{ 0.45, Pose.Merge(SLIDE, { Root = { 60, 0, 0, 0, -1.4, 0.4 } }) },
	{ 0.62, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, Prop = { -40, 0, 0 } }) },
})

-- 3: Line Drive - toss with the left hand (0.1), power swing at 0.4.
Baseball.LineDrive = Clip("Baseball.LineDrive", { FadeIn = 0.04, FadeOut = 0.15, Marks = { Toss = 0.1, Contact = 0.4 } }, {
	{ 0, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 60 }, Prop = { -40, 0, 0 } }) },
	{ 0.1, stance({ Neck = { 20 }, RightShoulder = { 60, 0, 30 }, RightElbow = { 90 }, LeftShoulder = { 120, 0, -10 }, LeftElbow = { 10 }, Prop = { -60, 0, 0 } }), "Out" },
	{ 0.3, Pose.Merge(swing(-85, -32, 105, 45), { LFoot = { -0.4, 0, -0.6, 0 }, Neck = { 10, 40, 0 } }) },
	{ 0.4, Pose.Merge(swing(30, 14, 85, 0), { LFoot = { -0.4, 0, -0.6, 0 } }), "Snap" },
	{ 0.55, Pose.Merge(swing(95, 24, 120, -40), { LFoot = { -0.4, 0, -0.6, 0 } }) },
	{ 0.75, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40 }, Prop = { -40, 0, 0 } }) },
})

-- 4: Home Run - long wind-up with a leg kick, contact at 0.62, big follow-through.
Baseball.HomeRun = Clip("Baseball.HomeRun", { FadeIn = 0.05, FadeOut = 0.2, Marks = { Contact = 0.62 } }, {
	{ 0, Pose.Merge(swing(-60, -20, 110, 40), {}) },
	{ 0.45, Pose.Merge(swing(-95, -38, 125, 55), { RFoot = { 0.4, 0, 0.3, 0 }, LFoot = { -0.3, 1.1, -0.35, -35 } }) },
	{ 0.55, Pose.Merge(swing(-95, -38, 120, 55), { RFoot = { 0.4, 0, 0.3, 0 }, LFoot = { -0.45, 0, -0.9, 0 } }) },
	{ 0.62, Pose.Merge(swing(35, 16, 85, -5), { RFoot = { 0.4, 0.15, 0.4, -30 }, LFoot = { -0.45, 0, -0.9, 0 } }), "Snap" },
	{ 0.8, Pose.Merge(swing(110, 28, 145, -50), { RFoot = { 0.4, 0.25, 0.4, -40 }, LFoot = { -0.45, 0, -0.9, 0 } }) },
	{ 1.0, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40 }, Prop = { -40, 0, 0 } }) },
})

-- Awakened 1: Rapid Fire - six quick left-handed throws (0.1 .. 0.7).
do
	local keys: { { any } } = { { 0, stance({ LeftShoulder = { 60, 0, -60 }, LeftElbow = { 100 }, RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, Prop = { -40, 0, 0 } }) } }
	for i = 0, 5 do
		local t = 0.1 + i * 0.12
		table.insert(keys, Pose.Key( t - 0.06, stance({ Root = { -4, 20, 0, 0, -0.4, 0 }, Waist = { 0, 20 }, LeftShoulder = { 95, 0, -80 }, LeftElbow = { 100 }, RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, Prop = { -40, 0, 0 } }) ))
		table.insert(keys, Pose.Key( t, stance({ Root = { -14, -18, 0, 0, -0.45, -0.1 }, Waist = { -8, -22 }, LeftShoulder = { 105, 0, 4 }, LeftElbow = { 6 }, LeftWrist = { -40 }, RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, Prop = { -40, 0, 0 } }), "Snap" ))
	end
	table.insert(keys, Pose.Key( 0.85, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, Prop = { -40, 0, 0 } }) ))
	Baseball.RapidFire = Clip("Baseball.RapidFire", { FadeIn = 0.04, FadeOut = 0.15, Marks = { Throw1 = 0.1, Throw2 = 0.22, Throw3 = 0.34, Throw4 = 0.46, Throw5 = 0.58, Throw6 = 0.7 } }, keys)
end

-- Awakened 2: Tornado Swing - three spins with the bat out (1.2 s), launch at 1.2.
Baseball.Tornado = Clip("Baseball.Tornado", { FadeIn = 0.05, FadeOut = 0.2, Marks = { Launch = 1.2 } }, {
	{ 0, stance({ Root = { -6, 30, 0, 0, -0.4, 0 }, RightShoulder = { 85, 0, 70 }, RightElbow = { 4 }, LeftShoulder = { 80, 0, -70 }, LeftElbow = { 4 }, Prop = BAT_LINE }) },
	{ 0.4, stance({ Root = { -6, -330, 0, 0, -0.4, 0 }, RightShoulder = { 85, 0, 70 }, RightElbow = { 4 }, LeftShoulder = { 80, 0, -70 }, LeftElbow = { 4 }, Prop = BAT_LINE }), "In" },
	{ 0.8, stance({ Root = { -6, -690, 0, 0, -0.4, 0 }, RightShoulder = { 85, 0, 70 }, RightElbow = { 4 }, LeftShoulder = { 80, 0, -70 }, LeftElbow = { 4 }, Prop = BAT_LINE }), "Linear" },
	{ 1.2, stance({ Root = { 6, -1080, 0, 0, -0.1, 0 }, Waist = { 8 }, RightShoulder = { 140, 0, 30 }, RightElbow = { 4 }, LeftShoulder = { 140, 0, -10 }, LeftElbow = { 10 }, Prop = BAT_LINE }), "Linear" },
	{ 1.3, stance({ Root = { -6, -1080, 0, 0, -0.35, 0 }, RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, Prop = { -40, 0, 0 } }) },
})

-- Awakened 3: Inside-the-Park - four swings from four sides (0.2, 0.4, 0.6, 0.8).
Baseball.InsideThePark = Clip("Baseball.InsideThePark", { FadeIn = 0.03, FadeOut = 0.15, Marks = { Dash1 = 0.14, Swing1 = 0.2, Dash2 = 0.34, Swing2 = 0.4, Dash3 = 0.54, Swing3 = 0.6, Dash4 = 0.74, Swing4 = 0.8 } }, {
	{ 0, swing(-60, -20, 85, 30) },
	{ 0.2, swing(40, 12, 82, -10), "Snap" },
	{ 0.3, stance({ Root = { -6, 20, 0, 0, -0.35, 0 }, Waist = { -4, 50 }, RightShoulder = { 80, 0, -40 }, RightElbow = { 40 }, LeftShoulder = { 10, 0, -30 }, Prop = { -90, -40, 0 } }) },
	{ 0.4, stance({ Root = { -6, -20, 0, 0, -0.35, -0.1 }, Waist = { -4, -40 }, RightShoulder = { 85, 0, 45 }, RightElbow = { 4 }, LeftShoulder = { 10, 0, -40 }, Prop = { -90, 20, 0 } }), "Snap" },
	{ 0.5, swing(-60, -20, 85, 30) },
	{ 0.6, swing(40, 12, 82, -10), "Snap" },
	{ 0.7, stance({ Root = { 6, 0, 0, 0, -0.25, 0 }, Waist = { 8 }, RightShoulder = { 165, 0, -10 }, RightElbow = { 20 }, LeftShoulder = { 160, 0, 25 }, LeftElbow = { 30 }, Prop = BAT_LINE }) },
	{ 0.8, stance({ Root = { -20, 0, 0, 0, -0.45, -0.2 }, Waist = { -16 }, RightShoulder = { 55, 0, -12 }, RightElbow = { 6 }, LeftShoulder = { 55, 0, 25 }, LeftElbow = { 15 }, Prop = BAT_LINE }), "Snap" },
	{ 1.0, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40 }, Prop = { -40, 0, 0 } }) },
})

-- Called shot: the bat points at the sky, the other hand on the hip
local CALLED_SHOT = {
	Root = { 2, 0, 0, 0, -0.05, 0 },
	RFoot = { 0.2, 0, 0, 0 },
	LFoot = { -0.2, 0, 0.1, 0 },
	Waist = { 6, 10 },
	Neck = { 26, -6, 0 },
	RightShoulder = { 160, 0, 14 },
	RightElbow = { 0 },
	RightWrist = { 0 },
	Prop = BAT_LINE,
	LeftShoulder = { -14, -30, -42 },
	LeftElbow = { 95 },
	LeftWrist = { 0, 0, 20 },
}

-- Awakened 4: Walk-Off Homer - call the shot (0 .. 0.6), wind up, colossal swing at 0.95.
Baseball.WalkOff = Clip("Baseball.WalkOff", { FadeIn = 0.06, FadeOut = 0.25, Marks = { Call = 0.3, Contact = 0.95 } }, {
	{ 0, CALLED_SHOT },
	{ 0.6, CALLED_SHOT },
	{ 0.85, Pose.Merge(swing(-100, -40, 125, 55), { RFoot = { 0.45, 0, 0.3, 0 }, LFoot = { -0.45, 0, -0.9, 0 } }), "Out" },
	{ 0.95, Pose.Merge(swing(35, 16, 85, -5), { RFoot = { 0.45, 0.15, 0.4, -30 }, LFoot = { -0.45, 0, -0.9, 0 } }), "Snap" },
	{ 1.25, Pose.Merge(swing(115, 30, 150, -55), { RFoot = { 0.45, 0.25, 0.4, -40 }, LFoot = { -0.45, 0, -0.9, 0 }, Neck = { 30, -60, 0 } }) },
	{ 1.7, Pose.Merge(swing(112, 28, 148, -55), { RFoot = { 0.45, 0.25, 0.4, -40 }, LFoot = { -0.45, 0, -0.9, 0 }, Neck = { 30, -60, 0 } }) },
	{ 2.0, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, LeftShoulder = { 30, 0, -10 }, LeftElbow = { 40 }, Prop = { -40, 0, 0 } }) },
})

-- Awakening: called shot, spin the bat (2.2 s).
Baseball.Awaken = Clip("Baseball.Awaken", { FadeIn = 0.1, FadeOut = 0.3, Marks = { Call = 0.5, Burst = 1.2 } }, {
	{ 0, stance({ RightShoulder = { 40, 0, 10 }, RightElbow = { 60 }, Prop = { -40, 0, 0 } }) },
	{ 0.5, Pose.Merge(CALLED_SHOT, { Prop = { -90, 0, 0 } }), "OutBack" },
	{ 1.2, Pose.Merge(CALLED_SHOT, { Prop = { -90, 720, 0 } }) },
	{ 2.2, Pose.Merge(CALLED_SHOT, { Prop = { -90, 720, 0 } }) },
})

-- Idle fidget: takes the bat off the shoulder, twirls it twice and rests it back (1.5 s).
Baseball.BatTwirl = Clip("Baseball.BatTwirl", { FadeIn = 0.15, FadeOut = 0.25 }, {
	{ 0, { RightShoulder = { 72, 0, 16 }, RightElbow = { 108 }, RightWrist = { 0 }, Prop = { -48, 0, -12 } } },
	{ 0.3, { RightShoulder = { 40, 0, 30 }, RightElbow = { 70 }, RightWrist = { 0 }, Prop = { -90, 0, 0 } }, "InOut" },
	{ 0.75, { RightShoulder = { 42, 0, 32 }, RightElbow = { 70 }, RightWrist = { 0 }, Prop = { -90, 360, 0 } }, "Linear" },
	{ 1.1, { RightShoulder = { 42, 0, 32 }, RightElbow = { 70 }, RightWrist = { 0 }, Prop = { -90, 720, 0 } }, "Out" },
	{ 1.5, { RightShoulder = { 72, 0, 16 }, RightElbow = { 108 }, RightWrist = { 0 }, Prop = { -48, 720, -12 } }, "InOut" },
})
Baseball.Fidgets = { Baseball.BatTwirl }

return Baseball
