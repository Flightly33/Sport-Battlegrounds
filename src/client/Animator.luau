--[[
	Animator: the procedural animator, run by every client for every fighter near its camera.

	Each frame (RunService.PreSimulation, i.e. after Roblox's own animation step) it builds a pose from
	these layers and writes it to the Motor6Ds:
		1. locomotion (idle / walk / run / jump / fall) in the character's style - Shared/Anim/Styles
		2. status: block, hit-stun stagger (from the attributes CombatService replicates)
		3. action tracks started by moves (Animator.Play)
		4. knockdown / tumbling
		5. additive: hit flinches, leaning into turns
	Hit-stop freezes the action clock for a few frames, which is most of what makes hits feel heavy.

	Joint transforms aren't replicated, so every client animates everyone; moves start on all clients
	at (almost) the same time through MoveStarted.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rig = require(Shared.Anim.Rig)
local Pose = require(Shared.Anim.Pose)
local Locomotion = require(Shared.Anim.Locomotion)
local Styles = require(Shared.Anim.Styles)
local Clips = require(Shared.Anim.Clips)

type Clip = Pose.Clip
type Resolved = Pose.Resolved

local Animator = {}

export type Track = {
	Clip: Clip,
	Time: number,
	Speed: number,
	Weight: number,
	Target: number, -- weight we're fading towards
	FadeSpeed: number,
	Stopped: boolean,
	Looped: boolean,
	Hold: boolean, -- stay on the last frame instead of ending
	Stop: (self: Track, fade: number?) -> (),
	SetSpeed: (self: Track, speed: number) -> (),
}

type Flinch = { Dir: Vector3, Strength: number, Time: number }

type Entry = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Rig: Rig.RigInfo?,
	Style: Locomotion.Style,
	StyleName: string,
	State: Locomotion.State,
	Tracks: { Track },
	StatusWeights: { [string]: number },
	HitStopUntil: number,
	Flinches: { Flinch },
	Spin: number,
	LastYaw: number,
	Lean: number,
	Frame: number,
	Dead: boolean,
}

local entries: { [Model]: Entry } = {}
local CULL_DISTANCE = 320
local LOW_RATE_DISTANCE = 140

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function styleFor(classId: string?): (Locomotion.Style, string)
	local name = if classId and (Styles :: any)[classId] then classId else "Dummy"
	return (Styles :: any)[name] :: Locomotion.Style, name
end

local function newTrack(clip: Clip, speed: number, fadeIn: number, hold: boolean): Track
	local track = {
		Clip = clip,
		Time = 0,
		Speed = speed,
		Weight = if fadeIn <= 0 then 1 else 0,
		Target = 1,
		FadeSpeed = if fadeIn <= 0 then math.huge else 1 / fadeIn,
		Stopped = false,
		Looped = clip.Loop,
		Hold = hold,
	} :: any
	function track.Stop(self: Track, fade: number?)
		local f = fade or self.Clip.FadeOut
		self.Target = 0
		self.FadeSpeed = if f <= 0 then math.huge else 1 / f
		self.Stopped = true
	end
	function track.SetSpeed(self: Track, s: number)
		self.Speed = s
	end
	return track :: Track
end

local function register(model: Instance)
	if not model:IsA("Model") or entries[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
	local root = model:FindFirstChild("HumanoidRootPart") or model:WaitForChild("HumanoidRootPart", 5)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return
	end
	local style, styleName = styleFor(model:GetAttribute("Class") :: string?)
	local entry: Entry = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Rig = nil,
		Style = style,
		StyleName = styleName,
		State = Locomotion.NewState(),
		Tracks = {},
		StatusWeights = {},
		HitStopUntil = 0,
		Flinches = {},
		Spin = 0,
		LastYaw = 0,
		Lean = 0,
		Frame = math.random(0, 3),
		Dead = false,
	}
	entries[model] = entry
	local function refreshRig()
		entry.Rig = Rig.FromCharacter(model)
	end
	refreshRig()
	-- Props arrive (or change with the class) after the body
	model.DescendantAdded:Connect(function(d)
		if d:IsA("Motor6D") then
			task.defer(refreshRig)
		end
	end)
	model.DescendantRemoving:Connect(function(d)
		if d:IsA("Motor6D") then
			task.defer(refreshRig)
		end
	end)
	model:GetAttributeChangedSignal("Class"):Connect(function()
		entry.Style, entry.StyleName = styleFor(model:GetAttribute("Class") :: string?)
		entry.State.Custom = {}
	end)
	humanoid.Died:Connect(function()
		entry.Dead = true
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			entries[model] = nil
		end
	end)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
export type PlayOptions = { Speed: number?, FadeIn: number?, Hold: boolean? }

function Animator.Play(model: Model, clip: Clip, options: PlayOptions?): Track?
	local entry = entries[model]
	local opts: PlayOptions = options or {}
	local track = newTrack(clip, opts.Speed or 1, opts.FadeIn or clip.FadeIn, opts.Hold == true)
	if not entry then
		return track
	end
	table.insert(entry.Tracks, track)
	return track
end

function Animator.StopAll(model: Model, fade: number?)
	local entry = entries[model]
	if entry then
		for _, track in entry.Tracks do
			track:Stop(fade)
		end
	end
end

-- Freeze the action clock (hit-stop) for `duration` seconds.
function Animator.HitStop(model: Model, duration: number)
	local entry = entries[model]
	if entry then
		entry.HitStopUntil = math.max(entry.HitStopUntil, os.clock() + duration)
	end
end

-- A recoil in the direction the hit travels (world space).
function Animator.Flinch(model: Model, direction: Vector3, strength: number)
	local entry = entries[model]
	if entry then
		table.insert(entry.Flinches, { Dir = direction, Strength = strength, Time = 0 })
	end
end

function Animator.IsRegistered(model: Model): boolean
	return entries[model] ~= nil
end

--------------------------------------------------------------------------------
-- Per-frame
--------------------------------------------------------------------------------
local function approach(current: number, target: number, rate: number): number
	if current < target then
		return math.min(target, current + rate)
	end
	return math.max(target, current - rate)
end

local function statusLayer(entry: Entry, name: string, active: boolean, dt: number, fade: number): number
	local w = entry.StatusWeights[name] or 0
	w = approach(w, if active then 1 else 0, dt / fade)
	entry.StatusWeights[name] = w
	return w
end

local function blendClip(rig: Rig.RigInfo, out: Resolved, clip: Clip, t: number, weight: number)
	if weight <= 0.001 then
		return
	end
	local resolved = Pose.Resolve(rig, Pose.Sample(clip, t))
	Pose.Blend(out, resolved, clip.Channels, weight)
end

local function blockClip(entry: Entry): Clip
	local byClass = (Clips :: any)[entry.StyleName]
	if byClass and byClass.Block then
		return byClass.Block
	end
	return Clips.Common.Block
end

local function update(entry: Entry, dt: number, now: number, camPos: Vector3)
	local rig = entry.Rig
	if not rig then
		return
	end
	local model = entry.Model
	local root = entry.Root
	local distance = (root.Position - camPos).Magnitude
	if distance > CULL_DISTANCE then
		return
	end
	entry.Frame += 1
	if distance > LOW_RATE_DISTANCE and entry.Frame % 2 == 1 then
		return
	end
	local step = if distance > LOW_RATE_DISTANCE then dt * 2 else dt
	local frozen = os.clock() < entry.HitStopUntil
	local clockDt = if frozen then 0 else step

	-- 1. Locomotion
	local cf = root.CFrame
	local velocity = root.AssemblyLinearVelocity
	local localVelocity = cf:VectorToObjectSpace(velocity)
	local humanoid = entry.Humanoid
	-- Humanoid states replicate for every character (FloorMaterial doesn't)
	local humanoidState = humanoid:GetState()
	local grounded = humanoidState ~= Enum.HumanoidStateType.Freefall
		and humanoidState ~= Enum.HumanoidStateType.Jumping
		and humanoidState ~= Enum.HumanoidStateType.Flying
	local state = entry.State
	state.Awakened = model:GetAttribute("Awakened") == true
	Locomotion.Advance(entry.Style, state, clockDt, localVelocity, grounded)
	local out = Pose.Resolve(rig, Locomotion.Evaluate(entry.Style, state))

	-- 2. Status: block, stagger
	local stunUntil = (model:GetAttribute("StunUntil") :: number?) or 0
	local knockUntil = (model:GetAttribute("KnockdownUntil") :: number?) or 0
	local knocked = knockUntil > now or entry.Dead
	local stunned = stunUntil > now and not knocked
	local blocking = model:GetAttribute("Blocking") == true and not stunned and not knocked
	local blockW = statusLayer(entry, "Block", blocking, step, 0.08)
	blendClip(rig, out, blockClip(entry), state.Time, blockW)
	local stunW = statusLayer(entry, "Stun", stunned, step, 0.06)
	blendClip(rig, out, Clips.Common.Stagger, state.Time, stunW)

	-- 3. Action tracks
	local i = 1
	while i <= #entry.Tracks do
		local track = entry.Tracks[i]
		track.Time += clockDt * track.Speed
		local clip = track.Clip
		if not track.Looped and not track.Hold and not track.Stopped and track.Time >= clip.Length then
			track:Stop()
		end
		if track.FadeSpeed == math.huge then
			track.Weight = track.Target
		else
			track.Weight = approach(track.Weight, track.Target, step * track.FadeSpeed)
		end
		if track.Stopped and track.Weight <= 0 then
			table.remove(entry.Tracks, i)
		else
			blendClip(rig, out, clip, track.Time, track.Weight)
			i += 1
		end
	end

	-- 4. Knockdown: tumble while flying, lie flat once landed
	local knockW = statusLayer(entry, "Knock", knocked, step, if knocked then 0.08 else 0.25)
	if knockW > 0.001 then
		if not grounded and knocked then
			entry.Spin += step * 9
		else
			entry.Spin = approach(entry.Spin % (math.pi * 2), 0, step * 8)
		end
		blendClip(rig, out, Clips.Common.Knockdown, state.Time, knockW)
		if entry.Spin ~= 0 then
			out.Root = (out.Root or CFrame.identity) * CFrame.Angles(entry.Spin * knockW, 0, 0)
		end
	end

	-- 5. Additive: flinches and leaning into turns
	local additive: Resolved = {}
	local fi = 1
	while fi <= #entry.Flinches do
		local f = entry.Flinches[fi]
		f.Time += step
		if f.Time > 0.45 then
			table.remove(entry.Flinches, fi)
		else
			local localDir = cf:VectorToObjectSpace(f.Dir)
			local env = math.exp(-f.Time * 9) * math.sin(math.min(f.Time * 30, math.pi / 2)) * f.Strength
			-- Pushed backwards = lean back (+X); pushed sideways = roll
			local pitch = -localDir.Z * env * 0.5
			local roll = -localDir.X * env * 0.4
			additive.Waist = (additive.Waist or CFrame.identity) * CFrame.Angles(pitch, 0, roll)
			additive.Neck = (additive.Neck or CFrame.identity) * CFrame.Angles(pitch * 0.8, 0, roll * 0.5)
			fi += 1
		end
	end
	local yaw = math.atan2(-cf.LookVector.X, -cf.LookVector.Z)
	local dyaw = (yaw - entry.LastYaw + math.pi) % (math.pi * 2) - math.pi
	entry.LastYaw = yaw
	local targetLean = math.clamp(dyaw / math.max(step, 1e-3) * 0.02, -0.25, 0.25) * state.Move
	entry.Lean += (targetLean - entry.Lean) * math.min(1, step * 8)
	additive.Root = (additive.Root or CFrame.identity) * CFrame.Angles(0, 0, -entry.Lean)
	Pose.Add(out, additive)

	-- Apply
	for name, l in out do
		local joint = rig.Joints[name]
		local motor = joint and joint.Motor
		if motor and joint then
			motor.Transform = Rig.ToTransform(joint, l)
		end
	end
end

function Animator.Init()
	for _, model in CollectionService:GetTagged("Fighter") do
		task.spawn(register, model)
	end
	CollectionService:GetInstanceAddedSignal("Fighter"):Connect(function(model)
		task.spawn(register, model)
	end)
	RunService.PreSimulation:Connect(function(dt)
		local camera = workspace.CurrentCamera
		local camPos = if camera then camera.CFrame.Position else Vector3.zero
		local now = serverNow()
		for _, entry in entries do
			local ok, err = pcall(function()
				update(entry, dt, now, camPos)
			end)
			if not ok then
				warn("[Animator]", entry.Model.Name, err)
				entry.Rig = nil
				task.delay(1, function()
					entry.Rig = Rig.FromCharacter(entry.Model)
				end)
			end
		end
	end)
end

return Animator
