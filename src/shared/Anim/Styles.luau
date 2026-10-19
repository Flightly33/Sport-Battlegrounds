--[[
	Locomotion styles, one per character: idle pose, walk and run gaits, and the prop hooks that
	dribble the ball / carry the bat.

	Soccer      hands in his pockets with a foot resting on the ball; light, springy walk; a fast,
	            athletic sprint (forward lean, high knees, pumping arms) with the ball at his feet
	Basketball  low stance, dribbling with the right hand, left arm guarding
	Football    heavy wide stance, ball tucked under the right arm; powerful forward-leaning run
	Baseball    bat resting on the right shoulder, left hand on the hip
]]

local Locomotion = require(script.Parent.Locomotion)
local Pose = require(script.Parent.Pose)

type Pose = Pose.Pose
type State = Locomotion.State
type Style = Locomotion.Style
type Gait = Locomotion.Gait

local TAU = math.pi * 2
local DEG = 180 / math.pi

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function breathe(state: State, rate: number, amount: number): number
	return math.sin(state.Time * rate) * amount
end

local function dtOf(state: State): number
	local last = state.Custom.LastTime or state.Time
	state.Custom.LastTime = state.Time
	return math.clamp(state.Time - last, 0, 0.1)
end

local Styles: { [string]: Style } = {}

--------------------------------------------------------------------------------
-- Soccer
--------------------------------------------------------------------------------
local SOCCER_WALK: Gait = {
	Freq = 1.8,
	Stance = 0.5,
	MaxStride = 1.8,
	Lift = 0.5,
	HeelKick = 0.15,
	KneeDrive = 0.3,
	ToeOff = -24,
	Width = 0,
	Bob = 0.14,
	Crouch = 0.04,
	Lean = 4,
	HipSway = 7,
	Twist = 5,
	ArmSwing = 24,
	ArmOut = 7,
	Elbow = 16,
	ElbowSwing = 14,
	Head = 0.5,
}

local SOCCER_RUN: Gait = {
	Freq = 2.35,
	Stance = 0.33,
	MaxStride = 2.3,
	Lift = 0.95,
	HeelKick = 0.95,
	KneeDrive = 0.7,
	ToeOff = -38,
	Width = 0,
	Bob = 0.24,
	Crouch = 0.14,
	Lean = 15,
	HipSway = 10,
	Twist = 7,
	ArmSwing = 60,
	ArmOut = 9,
	Elbow = 88,
	ElbowSwing = 16,
	Head = 0.75,
}

Styles.Soccer = {
	Name = "Soccer",
	WalkSpeed = 16,
	RunSpeed = 28,
	Walk = SOCCER_WALK,
	Run = SOCCER_RUN,
	Idle = function(state: State): Pose
		local b = breathe(state, 1.7, 1.2)
		local look = math.sin(state.Time * 0.37) * 14 + math.sin(state.Time * 0.91) * 4
		return {
			-- Weight on the left leg, right foot resting on top of the ball
			Root = { 1, 0, -3, -0.1, -0.06, 0 },
			RFoot = { 0.05, 1.08, -0.82, -6 },
			LFoot = { -0.05, 0, 0.12, 0 },
			Waist = { 5 + b, -6, 3 },
			Neck = { -3 - b * 0.5, look, 4 },
			-- Hands in the front pockets: elbows out, forearms forward and in
			RightShoulder = { -16 + b * 0.3, 12, 9 },
			RightElbow = { 30, 0, 0 },
			RightWrist = { -6, 0, -8 },
			LeftShoulder = { -16 + b * 0.3, -12, -9 },
			LeftElbow = { 30, 0, 0 },
			LeftWrist = { -6, 0, 8 },
		}
	end,
	Props = function(pose: Pose, state: State, phase: number, move: number)
		-- Ball (rest = on the ground in front of the right foot). Idle: under the raised right foot.
		-- Moving: dribbled ahead along the direction of travel, touched forward once per stride.
		local touch = 1 - phase -- jumps to 1 when the right foot comes through, then the runner catches up
		local eased = touch * touch * (3 - 2 * touch)
		local ahead = lerp(1.25, 2.1, state.RunBlend) + eased * lerp(0.45, 0.9, state.RunBlend)
		local dir = state.MoveDir
		local dribbleX = dir.X * ahead + 0.25 * (1 - math.abs(dir.X)) - 0.5
		local dribbleZ = dir.Z * ahead + 1.0
		local bounce = math.abs(math.sin(math.pi * phase * 2)) * 0.12 * state.RunBlend
		local roll = -state.Distance / 0.55 * DEG
		local x = lerp(0, dribbleX, move)
		local z = lerp(0.05, dribbleZ, move)
		pose.Prop = { roll * move, math.atan2(-dir.X, -dir.Z) * DEG * move, 0, x, bounce * move, z }
	end,
}

--------------------------------------------------------------------------------
-- Basketball
--------------------------------------------------------------------------------
local BASKETBALL_WALK: Gait = table.clone(SOCCER_WALK)
BASKETBALL_WALK.Crouch = 0.3
BASKETBALL_WALK.Lean = 9
BASKETBALL_WALK.Width = 0.12
BASKETBALL_WALK.Bob = 0.1
BASKETBALL_WALK.Freq = 1.85

local BASKETBALL_RUN: Gait = table.clone(SOCCER_RUN)
BASKETBALL_RUN.Lean = 13
BASKETBALL_RUN.Crouch = 0.22
BASKETBALL_RUN.HeelKick = 0.7

local DRIBBLE_HEIGHT = 1.9

Styles.Basketball = {
	Name = "Basketball",
	WalkSpeed = 16,
	RunSpeed = 27,
	Walk = BASKETBALL_WALK,
	Run = BASKETBALL_RUN,
	Idle = function(state: State): Pose
		local b = breathe(state, 2.2, 1)
		local sway = math.sin(state.Time * 1.1) * 0.06
		return {
			Root = { -10, 8, 0, sway, -0.42 + b * 0.01, 0 },
			RFoot = { 0.32, 0, -0.25, 0 },
			LFoot = { -0.32, 0, 0.3, 0 },
			Waist = { -8 + b, 6, 0 },
			Neck = { 16, -10, 0 },
			LeftShoulder = { 22, 0, -24 },
			LeftElbow = { 70, 0, 0 },
			LeftWrist = { 0, 0, 10 },
			RightShoulder = { 20, 0, 18 },
			RightElbow = { 55, 0, 0 },
		}
	end,
	Props = function(pose: Pose, state: State, phase: number, move: number)
		local dt = dtOf(state)
		-- Dribble: one bounce per step while moving, ~2 per second standing
		local rate = lerp(2.1, 0, move)
		local d = state.Custom.Dribble or 0
		if move > 0.5 then
			d = (phase * 2) % 1
		else
			d = (d + rate * dt) % 1
		end
		state.Custom.Dribble = d
		local y = math.abs(math.sin(math.pi * d)) * DRIBBLE_HEIGHT -- 0 at the floor, max in the hand
		local handPush = math.cos(TAU * (d - 0.5)) -- 1 when the ball is in the hand
		local dir = state.MoveDir
		local ahead = lerp(0, lerp(0.6, 1.2, state.RunBlend), move)
		pose.Prop = { -d * 360, 0, 0, dir.X * ahead, y, dir.Z * ahead }
		-- Right hand meets the ball at the top and pushes it down
		pose.RightShoulder = { lerp(16, 34, move) + handPush * 10, 0, 22 }
		pose.RightElbow = { 62 - handPush * 22, 0, 0 }
		pose.RightWrist = { -10 - handPush * 30, 0, 0 }
	end,
}

--------------------------------------------------------------------------------
-- Football
--------------------------------------------------------------------------------
local FOOTBALL_WALK: Gait = table.clone(SOCCER_WALK)
FOOTBALL_WALK.Freq = 1.6
FOOTBALL_WALK.Width = 0.2
FOOTBALL_WALK.Bob = 0.09
FOOTBALL_WALK.HipSway = 11
FOOTBALL_WALK.Twist = 8
FOOTBALL_WALK.Crouch = 0.12
FOOTBALL_WALK.Lean = 6
FOOTBALL_WALK.ArmOut = 16

local FOOTBALL_RUN: Gait = table.clone(SOCCER_RUN)
FOOTBALL_RUN.Freq = 2.15
FOOTBALL_RUN.Lean = 18
FOOTBALL_RUN.Width = 0.15
FOOTBALL_RUN.Crouch = 0.2
FOOTBALL_RUN.ArmOut = 14
FOOTBALL_RUN.Bob = 0.2

-- Ball tucked against the chest under the right arm
local TUCK: Pose = {
	RightShoulder = { 2, 28, 4 },
	RightElbow = { 88, 0, 0 },
	RightWrist = { 0, 0, -10 },
}

Styles.Football = {
	Name = "Football",
	WalkSpeed = 16,
	RunSpeed = 26,
	Walk = FOOTBALL_WALK,
	Run = FOOTBALL_RUN,
	Carry = TUCK,
	Idle = function(state: State): Pose
		local b = breathe(state, 1.3, 1.6)
		return {
			Root = { -4, 0, 0, 0, -0.22, 0 },
			RFoot = { 0.38, 0, -0.1, 0 },
			LFoot = { -0.38, 0, 0.12, 0 },
			Waist = { -4 + b, 0, 0 },
			Neck = { 2 - b * 0.4, math.sin(state.Time * 0.5) * 8, 0 },
			RightShoulder = TUCK.RightShoulder,
			RightElbow = TUCK.RightElbow,
			RightWrist = TUCK.RightWrist,
			LeftShoulder = { 8, 0, -18 - b * 0.5 },
			LeftElbow = { 20, 0, 0 },
			LeftWrist = { 0, 0, 0 },
		}
	end,
}

--------------------------------------------------------------------------------
-- Baseball
--------------------------------------------------------------------------------
local BASEBALL_WALK: Gait = table.clone(SOCCER_WALK)
BASEBALL_WALK.Freq = 1.7
BASEBALL_WALK.Bob = 0.1
BASEBALL_WALK.HipSway = 8

local BASEBALL_RUN: Gait = table.clone(SOCCER_RUN)
BASEBALL_RUN.Freq = 2.3
BASEBALL_RUN.Lean = 13

-- Bat resting on the right shoulder
local SHOULDER_BAT: Pose = {
	RightShoulder = { 72, 0, 16 },
	RightElbow = { 108, 0, 0 },
	RightWrist = { 0, 0, 0 },
	Prop = { -48, 0, -12 },
}

Styles.Baseball = {
	Name = "Baseball",
	WalkSpeed = 16,
	RunSpeed = 27,
	Walk = BASEBALL_WALK,
	Run = BASEBALL_RUN,
	Idle = function(state: State): Pose
		local b = breathe(state, 1.6, 1.1)
		local chew = math.sin(state.Time * 6) * 0.6
		return {
			Root = { 0, 0, 2, 0.08, -0.04, 0 },
			RFoot = { 0.12, 0, -0.05, 0 },
			LFoot = { -0.1, 0, 0.15, 0 },
			Waist = { 3 + b, 8, 0 },
			Neck = { -2 + chew, -10 + math.sin(state.Time * 0.42) * 10, -3 },
			RightShoulder = SHOULDER_BAT.RightShoulder,
			RightElbow = SHOULDER_BAT.RightElbow,
			RightWrist = SHOULDER_BAT.RightWrist,
			Prop = SHOULDER_BAT.Prop,
			-- Left hand on the hip
			LeftShoulder = { -14, -30, -42 },
			LeftElbow = { 95, 0, 0 },
			LeftWrist = { 0, 0, 20 },
		}
	end,
	Props = function(pose: Pose, state: State, phase: number, move: number)
		-- Walking: keep the bat on the shoulder. Running: carry it low in the pumping right hand.
		local run = state.RunBlend * move
		if run > 0.01 then
			local c = math.cos(TAU * phase)
			Locomotion.BlendInto(pose, {
				RightShoulder = { -50 * c - 3, 0, 9 },
				RightElbow = { 85, 0, 0 },
				RightWrist = { 0, 0, 0 },
				Prop = { 20, 0, 0 },
			}, run)
		end
		if move > 0.01 and run < 1 then
			Locomotion.BlendInto(pose, SHOULDER_BAT, move * (1 - run))
		end
	end,
}

--------------------------------------------------------------------------------
-- Training dummy: plain stance, no props
--------------------------------------------------------------------------------
Styles.Dummy = {
	Name = "Dummy",
	WalkSpeed = 16,
	RunSpeed = 27,
	Walk = SOCCER_WALK,
	Run = SOCCER_RUN,
	Idle = function(state: State): Pose
		local b = breathe(state, 1.5, 1)
		return {
			Root = { 0, 0, 0, 0, -0.03, 0 },
			RFoot = { 0.1, 0, 0, 0 },
			LFoot = { -0.1, 0, 0, 0 },
			Waist = { b, 0, 0 },
			RightShoulder = { 2, 0, 6 },
			LeftShoulder = { 2, 0, -6 },
			RightElbow = { 8 },
			LeftElbow = { 8 },
		}
	end,
}

return Styles
