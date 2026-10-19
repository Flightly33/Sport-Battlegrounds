--[[
	Kit: building blocks shared by the move scripts - the M1 chain, melee hitboxes, ball visuals,
	limb trails, the anime contact / climax beats and the awakening template.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Pose = require(Shared.Anim.Pose)
local Props = require(Shared.Props)

local Animator = require(script.Parent.Parent.Animator)
local CameraFX = require(script.Parent.Parent.CameraFX)
local FX = require(script.Parent.Parent.FX)
local MoveRunner = require(script.Parent.Parent.MoveRunner)
local Sound = require(script.Parent.Parent.Sound)

type Ctx = MoveRunner.Ctx
type Palette = Characters.Palette

local Kit = {}

-- Box hitbox `distance` studs in front of the root (centre height `height`).
function Kit.Front(ctx: Ctx, hitName: string, distance: number, size: Vector3, height: number?): { Model }
	local cf = CFrame.lookAt(ctx.Root.Position, ctx.Root.Position + Vector3.new(ctx.Aim.X, 0, ctx.Aim.Z))
	if (Vector3.new(ctx.Aim.X, 0, ctx.Aim.Z)).Magnitude < 1e-3 then
		cf = ctx.Root.CFrame
	end
	return ctx:Hitbox(hitName, cf * CFrame.new(0, height or 0, -distance), size)
end

-- The flat facing frame at the root (X right, -Z forward along the aim).
function Kit.Frame(ctx: Ctx): CFrame
	local flat = Vector3.new(ctx.Aim.X, 0, ctx.Aim.Z)
	if flat.Magnitude < 1e-3 then
		flat = ctx.Root.CFrame.LookVector
	end
	return CFrame.lookAt(ctx.Root.Position, ctx.Root.Position + flat.Unit)
end

-- A loose ball for projectiles (anchored, so it can be moved freely).
function Kit.Ball(classId: string, scale: number?, skin: unknown?): () -> Instance
	return function(): Instance
		local model = Props.BuildBall(classId, true, skin)
		if scale and scale ~= 1 then
			model:ScaleTo(scale)
		end
		return model
	end
end

-- Ball visual with a glowing shell and a light around it.
function Kit.GlowBall(classId: string, color: Color3, glowSize: number, scale: number?, skin: unknown?): () -> Instance
	return function(): Instance
		local model = Props.BuildBall(classId, true, skin)
		if scale and scale ~= 1 then
			model:ScaleTo(scale)
		end
		local core = model.PrimaryPart :: BasePart
		local glow = Instance.new("Part")
		glow.Name = "Glow"
		glow.Shape = Enum.PartType.Ball
		glow.Size = Vector3.one * glowSize
		glow.Material = Enum.Material.Neon
		glow.Color = color
		glow.Transparency = 0.55
		glow.Anchored = true
		glow.CanCollide = false
		glow.CanQuery = false
		glow.CanTouch = false
		glow.CastShadow = false
		glow.CFrame = core.CFrame
		glow.Parent = model
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 3
		light.Range = 16
		light.Parent = core
		return model
	end
end

-- An energy orb (no ball inside).
function Kit.Orb(color: Color3, core: Color3, size: number): () -> Instance
	return function(): Instance
		local model = Instance.new("Model")
		local inner = Instance.new("Part")
		inner.Shape = Enum.PartType.Ball
		inner.Size = Vector3.one * size * 0.5
		inner.Material = Enum.Material.Neon
		inner.Color = core
		inner.Anchored = true
		inner.CanCollide = false
		inner.CanQuery = false
		inner.CanTouch = false
		inner.CastShadow = false
		inner.Parent = model
		local outer = inner:Clone()
		outer.Size = Vector3.one * size
		outer.Color = color
		outer.Transparency = 0.45
		outer.Parent = model
		model.PrimaryPart = inner
		return model
	end
end

-- Where the attached prop is right now (or a fallback in front of the feet).
function Kit.PropPosition(ctx: Ctx, fallback: Vector3?): Vector3
	local handle = ctx:PropPart()
	if handle then
		return handle.Position
	end
	return fallback or (ctx.Root.CFrame * Vector3.new(0.5, -2.4, -1.2))
end

-- A trail on a limb for `duration` seconds.
function Kit.LimbTrail(ctx: Ctx, limb: string, color: Color3, width: number, duration: number, lifetime: number?)
	local part = ctx:Limb(limb)
	if not part then
		return
	end
	local trail = FX.Trail(part, color, width, lifetime or 0.16, ctx.Palette.Core)
	ctx:OnCleanup(function()
		trail:Destroy()
	end)
	task.delay(duration, function()
		trail.Enabled = false
		task.wait(0.3)
		trail:Destroy()
	end)
end

-- The contact frame: a white-hot flash where foot / fist / bat meets its target, a hair of hit-pause
-- on the user (the pose "sticks" for a beat) and a camera kick for its owner. strength ~1 for pokes,
-- 2 for heavy strikes, 3 for ultimates.
function Kit.Contact(ctx: Ctx, at: Vector3, strength: number)
	FX.Flash(at, ctx.Palette.Core, 2 + 1.6 * strength, 0.1)
	FX.ImpactLines(at, ctx.Palette.Core, math.floor(4 + 3 * strength), 2 + 1.5 * strength, 0.14)
	Animator.HitStop(ctx.Character, 0.02 + 0.02 * strength)
	if ctx.IsOwner then
		CameraFX.Shake(0.1 * strength)
	end
end

-- An ultimate's big moment: a beat of slow motion, the manga impact frame and an FOV punch.
function Kit.Climax(ctx: Ctx, at: Vector3, slow: number?, duration: number?)
	Animator.SlowMo(slow or 0.3, duration or 0.2)
	FX.Flash(at, ctx.Palette.Core, 14, 0.2)
	if ctx.IsOwner then
		CameraFX.ImpactFrame({ ctx.Character }, 0.12, ctx.Palette.Accent)
		CameraFX.FOVPunch(12, 0.3)
	end
end

-- A puff of turf where a foot plants.
function Kit.Dust(ctx: Ctx, limb: string, size: number?)
	local part = ctx:Limb(limb)
	local at = if part then part.Position else ctx.Root.Position - Vector3.new(0, 2.6, 0)
	FX.Smoke(at, Color3.fromRGB(205, 200, 188), 5, size or 0.9, 0.5, 1.5)
end

-- Spawns afterimages every `interval` for `duration`.
function Kit.Afterimages(ctx: Ctx, color: Color3, duration: number, interval: number, fade: number?)
	task.spawn(function()
		local stop = os.clock() + duration
		while os.clock() < stop and ctx:Alive() do
			FX.Afterimage(ctx.Character, color, fade or 0.25)
			task.wait(interval)
		end
	end)
end

--------------------------------------------------------------------------------
-- M1 chain
--------------------------------------------------------------------------------
-- Each clip carries a Contact mark: the frame the strike lands.
export type M1Entry = { Clip: Pose.Clip, Mirror: Pose.Clip?, Limb: string?, MirrorLimb: string? }
export type M1Set = {
	Hits: { M1Entry }, -- 4 entries
	Uppercut: M1Entry,
	Downslam: M1Entry,
	Size: Vector3?,
	Reach: number?,
	-- Swing effect at the moment of the hit (both modes)
	Swing: ((ctx: Ctx, step: number, mirrored: boolean, position: Vector3) -> ())?,
	Sounds: { string }?, -- a sound per combo hit (1-4) on the contact frame; the enders use the 4th
}

-- Runs one click of the chain; ctx.Variant is "<step><leg>" ("1L", "4R", "UL", "DR").
function Kit.M1(ctx: Ctx, set: M1Set)
	local stepChar = string.sub(ctx.Variant, 1, 1)
	local mirrored = string.sub(ctx.Variant, 2, 2) == "L"
	local step = tonumber(stepChar) or 4
	local entry: M1Entry
	local hitName: string
	if stepChar == "U" then
		entry, hitName = set.Uppercut, "Uppercut"
	elseif stepChar == "D" then
		entry, hitName = set.Downslam, "Downslam"
	else
		entry, hitName = set.Hits[math.clamp(step, 1, 4)], "Hit" .. math.clamp(step, 1, 4)
	end
	local clip = if mirrored and entry.Mirror then entry.Mirror else entry.Clip
	ctx:Face()
	local track = ctx:Play(clip)
	local finisher = hitName ~= "Hit1" and hitName ~= "Hit2" and hitName ~= "Hit3"
	-- Step into the strike: a short lunge, longer for the finisher
	ctx:Forward(if finisher then 26 else 14, 0.1, if hitName == "Downslam" then -40 else nil)
	local limb = if mirrored and entry.MirrorLimb then entry.MirrorLimb else entry.Limb
	if limb then
		Kit.LimbTrail(ctx, limb, ctx.Palette.Primary, if finisher then 0.8 else 0.6, (clip.Marks.Contact or 0.15) + 0.12)
	end
	Sound.Play(if finisher then "HeavyWhoosh" else "Whoosh", ctx.Root.Position, if finisher then 0.9 else 1)
	if not ctx:Until(track, "Contact") then
		return
	end
	local reach = set.Reach or 3.4
	local size = set.Size or Vector3.new(5.5, 6, 6)
	local frame = Kit.Frame(ctx)
	local at = (frame * CFrame.new(0, 0, -reach)).Position
	Kit.Contact(ctx, at, if finisher then 1.6 else 0.7)
	if set.Sounds then
		local name = set.Sounds[math.clamp(step, 1, #set.Sounds)]
		if hitName == "Uppercut" or hitName == "Downslam" then
			name = set.Sounds[#set.Sounds]
		end
		Sound.Play(name, at)
	end
	if set.Swing then
		set.Swing(ctx, step, mirrored, at)
	end
	if hitName == "Uppercut" then
		Kit.Front(ctx, hitName, reach, size + Vector3.new(0, 3, 0), 1)
	elseif hitName == "Downslam" then
		Kit.Front(ctx, hitName, reach - 0.5, size + Vector3.new(1, 3, 1), -1.5)
	else
		Kit.Front(ctx, hitName, reach, size)
	end
	ctx:Until(track, "End")
end

--------------------------------------------------------------------------------
-- Awakening template
--------------------------------------------------------------------------------
-- Plays the class's transformation clip with a cinematic camera for its owner, calls `burst` at the
-- clip's Burst mark (the climax), and blows nearby enemies back.
function Kit.Awaken(ctx: Ctx, clip: Pose.Clip, buildUp: (ctx: Ctx) -> (), burst: (ctx: Ctx, at: Vector3) -> (), intro: { string }?)
	local track = ctx:Play(clip)
	if ctx.IsOwner then
		CameraFX.Orbit(ctx.Root, 2.1, -35, 65, 13, 2.5, 55)
	end
	-- The class's own intro sounds, or the shared one
	if intro then
		for _, name in intro do
			Sound.Play(name, ctx.Root.Position)
		end
	else
		Sound.Play("Awaken", ctx.Root.Position, 0.9)
	end
	task.spawn(buildUp, ctx)
	if not ctx:Until(track, "Burst") then
		return
	end
	local at = ctx.Root.Position
	burst(ctx, at)
	ctx:Sphere("Burst", at, 16)
	Kit.Climax(ctx, at, 0.4, 0.15)
	if ctx.IsOwner then
		CameraFX.Shake(0.8)
	end
	ctx:Until(track, "End")
end

-- Rough "is this fighter in the air" check (used by Posterize / airborne bonuses).
function Kit.Airborne(model: Model): boolean
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local ground = FX.GroundBelow(root.Position)
	return root.Position.Y - ground.Y > 4.2
end

-- Victims hit by a move this frame, other than `except`.
function Kit.Without(list: { Model }, except: Model?): { Model }
	local out: { Model } = {}
	for _, m in list do
		if m ~= except then
			table.insert(out, m)
		end
	end
	return out
end

return Kit
