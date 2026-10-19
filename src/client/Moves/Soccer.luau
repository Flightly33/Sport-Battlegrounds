--[[
	Soccer move scripts. Electric blue lightning, white wind, the ball.

	M1   body kicks, the leg picked at random each kick (Controller rolls it; cosmetic only)
	1    Light Kick          snap shot, small damage, 4 s
	2    Lightning Shot      the leg and the ball light up with blue lightning, the ball flies wrapped
	                         in wind and explodes on impact in a smoky, fiery lightning explosion -
	                         a third of max health, 10 s
	3    Dribble Dash        crackling dribble dash, flick into the chin of the first enemy reached
	4    Bicycle Kick        leap and volley a lightning bolt into the ground
	Awakening  Storm Striker: Railgun, Thunderclap Volley, Flash Step, Storm of the Century
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clips = require(Shared.Anim.Clips)
local Characters = require(Shared.Characters)

local CameraFX = require(script.Parent.Parent.CameraFX)
local FX = require(script.Parent.Parent.FX)
local MoveRunner = require(script.Parent.Parent.MoveRunner)
local Sound = require(script.Parent.Parent.Sound)
local Kit = require(script.Parent.Kit)

type Ctx = MoveRunner.Ctx
type Palette = Characters.Palette
type MoveScript = MoveRunner.MoveScript

local C = Clips.Soccer

-- The "fiery" half of the Lightning Shot explosion
local FIRE: Palette = {
	Core = Color3.fromRGB(255, 244, 210),
	Primary = Color3.fromRGB(255, 120, 30),
	Secondary = Color3.fromRGB(255, 62, 24),
	Dark = Color3.fromRGB(40, 32, 34),
	Accent = Color3.fromRGB(255, 196, 70),
	Light = Color3.fromRGB(255, 150, 80),
}

local function ballWithTrail(scale: number, glow: Color3?, trailColor: Color3, trailCore: Color3, skin: string?): () -> Instance
	return function(): Instance
		local build: () -> Instance = if glow then Kit.GlowBall("Soccer", glow, 2.6 * scale, scale, skin) else Kit.Ball("Soccer", scale, skin)
		local model = build() :: Model
		local core = model.PrimaryPart
		if core then
			FX.Trail(core, trailColor, 1.0 * scale, 0.2, trailCore)
		end
		return model
	end
end

local function shake(position: Vector3, amount: number, range: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local d = (camera.CFrame.Position - position).Magnitude
	if d < range then
		CameraFX.Shake(amount * (1 - d / range))
	end
end

-- Dark storm cloud gathering above a point.
local function stormCloud(position: Vector3, palette: Palette, duration: number, radius: number)
	local disc = FX.Part({
		Size = Vector3.new(4, radius * 0.6, radius * 0.6),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		Color = palette.Dark,
		Material = Enum.Material.SmoothPlastic,
		Shape = Enum.PartType.Cylinder,
		Transparency = 1,
		Life = duration + 1.2,
	})
	FX.Tween(disc, 0.6, { Size = Vector3.new(6, radius * 2, radius * 2), Transparency = 0.25 })
	task.delay(duration, function()
		FX.Tween(disc, 1, { Transparency = 1, Size = Vector3.new(2, radius * 2.4, radius * 2.4) })
	end)
	FX.Smoke(position, palette.Dark:Lerp(Color3.fromRGB(60, 60, 80), 0.4), 40, radius * 0.35, duration + 0.8, -1)
	task.spawn(function()
		local stop = os.clock() + duration
		while os.clock() < stop do
			local a = position + Vector3.new((math.random() - 0.5) * radius * 1.6, (math.random() - 0.5) * 3, (math.random() - 0.5) * radius * 1.6)
			local b = a + Vector3.new((math.random() - 0.5) * 18, (math.random() - 0.5) * 4, (math.random() - 0.5) * 18)
			FX.Lightning(a, b, palette.Primary, { Thickness = 0.35, Duration = 0.15, Flickers = 1, Core = palette.Core })
			FX.Light(a, palette.Light, 6, 60, 0.15)
			task.wait(0.12 + math.random() * 0.15)
		end
	end)
end

--------------------------------------------------------------------------------
-- M1
--------------------------------------------------------------------------------
local M1: Kit.M1Set = {
	Hits = {
		{ Clip = C.KickA, Mirror = C.KickAL, Limb = "RightFoot", MirrorLimb = "LeftFoot" },
		{ Clip = C.KickB, Mirror = C.KickBL, Limb = "RightFoot", MirrorLimb = "LeftFoot" },
		{ Clip = C.KickA, Mirror = C.KickAL, Limb = "RightFoot", MirrorLimb = "LeftFoot" },
		{ Clip = C.KickFinisher, Mirror = C.KickFinisherL, Limb = "RightFoot", MirrorLimb = "LeftFoot" },
	},
	Sounds = { "Soccer_M1_1", "Soccer_M1_2", "Soccer_M1_3", "Soccer_M1_4" },
	Uppercut = { Clip = C.UpKick, Mirror = C.UpKickL, Limb = "RightFoot", MirrorLimb = "LeftFoot" },
	Downslam = { Clip = C.AxeKick, Mirror = C.AxeKickL, Limb = "RightFoot", MirrorLimb = "LeftFoot" },
	Swing = function(ctx: Ctx, step: number, mirrored: boolean, position: Vector3)
		local P = ctx.Palette
		local frame = Kit.Frame(ctx)
		local big = step >= 4 or string.sub(ctx.Variant, 1, 1) == "U" or string.sub(ctx.Variant, 1, 1) == "D"
		local plane = if step == 2 or step == 4 then CFrame.Angles(0, 0, if mirrored then -0.25 else 0.25) else CFrame.Angles(0, 0, math.pi / 2)
		FX.Slash(frame * CFrame.new(0, -0.6, -1.2) * plane, P.Primary, {
			Radius = if big then 4.6 else 3.2,
			Arc = if big then 170 else 120,
			Width = if big then 1.3 else 0.85,
			Duration = 0.18,
			Reverse = mirrored,
			Core = P.Core,
		})
		FX.Sparks(position, P.Accent, if big then 10 else 4, 18, 0.3)
		if big then
			FX.Lightning(position + Vector3.new(0, 1, 0), position + frame.LookVector * 4 + Vector3.new(0, -1, 0), P.Primary, { Thickness = 0.25, Duration = 0.14, Flickers = 1, Core = P.Core })
		end
	end,
}

local function m1(ctx: Ctx)
	Kit.M1(ctx, M1)
end

local function m1Hit(hit: MoveRunner.HitInfo, palette: Palette)
	-- Static crackle on whoever got kicked
	local p = hit.Position
	for _ = 1, 2 do
		local a = p + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3
		FX.Lightning(a, a + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 4, palette.Primary, { Thickness = 0.15, Detail = 2, Duration = 0.1, Flickers = 1, Branches = 0 })
	end
end

--------------------------------------------------------------------------------
-- 1: Light Kick
--------------------------------------------------------------------------------
local function lightKick(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local kick = ctx:Play(C.LightKick)
	if not ctx:Until(kick, "Plant") then
		return
	end
	-- The plant foot lands: a short step into the ball
	ctx:Forward(16, 0.1)
	Kit.Dust(ctx, "LeftFoot", 0.7)
	Kit.LimbTrail(ctx, "RightFoot", P.Accent, 0.55, 0.22)
	if not ctx:Until(kick, "Contact") then
		return
	end
	local origin = Kit.PropPosition(ctx) + Vector3.new(0, 0.4, 0)
	local dir = ctx.Aim
	Kit.Contact(ctx, origin, 1)
	FX.Ring(CFrame.lookAt(origin, origin + dir) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 0.5, 3, 0.18, 0.3, 12)
	FX.Sparks(origin, P.Accent, 6, 20, 0.35)
	Sound.Play("Soccer_LightKick", origin)
	ctx:HideProp(true)
	ctx:Projectile({
		Hit = "Ball",
		Origin = origin,
		Direction = dir,
		Speed = 140,
		Range = 75,
		Radius = 1.6,
		Visual = ballWithTrail(1, nil, P.Primary, P.Core, Kit.BallSkin(ctx)),
		Spin = Vector3.new(-25, 0, 0),
		OnStep = function(position: Vector3)
			if math.random() < 0.3 then
				FX.Sparks(position, P.Accent, 2, 6, 0.3)
			end
		end,
		OnImpact = function(position: Vector3, victim: Model?)
			FX.Flash(position, P.Core, 4, 0.15)
			FX.Sparks(position, P.Primary, 12, 30, 0.5)
			FX.Ring(CFrame.new(position), P.Primary, 0.5, 4, 0.2, 0.3, 12)
			if not victim then
				Sound.Play("Bounce", position) -- landing on someone has its own sound (HitSound)
			end
		end,
	})
	ctx:Until(kick, "End")
end

--------------------------------------------------------------------------------
-- 2: Lightning Shot
--------------------------------------------------------------------------------
local function lightningExplosion(ctx: Ctx, position: Vector3, victim: Model?)
	local P = ctx.Palette
	-- Blue lightning blast...
	FX.Flash(position, P.Core, 15, 0.18)
	FX.Shell(position, P.Primary, 2, 12, 0.35, Enum.Material.Neon)
	FX.Shell(position, P.Secondary, 3, 17, 0.55)
	-- ...inside a fiery, smoky explosion
	FX.Explosion(position, FIRE, 11, { Lightning = false, Fire = true, Smoke = true, Crater = true, Debris = true })
	FX.Smoke(position, Color3.fromRGB(45, 45, 52), 24, 4.5, 2.8, 9)
	for _ = 1, 9 do
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.9 - 0.1, math.random() - 0.5).Unit
		FX.Lightning(position, position + dir * (9 + math.random() * 9), P.Primary, { Thickness = 0.45, Duration = 0.35, Flickers = 3, Core = P.Core })
	end
	local ground = FX.GroundBelow(position)
	FX.Shockwave(CFrame.new(Vector3.new(position.X, ground.Y + 0.25, position.Z)), P.Primary, 22, 0.6, P.Core)
	-- Lingering static
	task.spawn(function()
		for _ = 1, 6 do
			task.wait(0.1)
			local a = position + Vector3.new(math.random() - 0.5, math.random(), math.random() - 0.5) * 8
			FX.Lightning(a, a + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 8, P.Primary, { Thickness = 0.2, Duration = 0.12, Flickers = 1, Branches = 0 })
		end
	end)
	Sound.Play("Explosion", position)
	Sound.Play("Thunder", position, 1.2)
	shake(position, 1.0, 140)
	if ctx.IsOwner then
		ctx:Report("Blast", Kit.Without(ctx:Query(position, 13), victim), position)
	end
end

local function lightningShot(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local shot = ctx:Play(C.LightningShot)
	-- Charge: blue lightning lights up the leg and crackles around the ball
	local foot = ctx:Limb("RightFoot")
	local shin = ctx:Limb("RightLowerLeg")
	local ball = ctx:PropPart()
	if foot then
		FX.Crackle(foot, P.Primary, 0.62, 1.4, 22)
		FX.Charge(foot, P.Accent, 0.5, 6)
	end
	if shin then
		FX.Crackle(shin, P.Accent, 0.62, 1.1, 12)
	end
	if ball then
		FX.Crackle(ball, P.Primary, 0.62, 1.7, 16)
	end
	Kit.LimbTrail(ctx, "RightFoot", P.Primary, 1, 0.85, 0.22)
	Kit.LimbTrail(ctx, "RightLowerLeg", P.Accent, 0.8, 0.85, 0.18)
	Sound.Play("Zap", ctx.Root.Position, 0.8)
	task.spawn(function()
		for _ = 1, 4 do
			task.wait(0.12)
			if not ctx:Alive() then
				return
			end
			local feet = ctx.Root.Position - Vector3.new(0, 2.8, 0)
			local a = math.random() * math.pi * 2
			FX.Lightning(feet, feet + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6), P.Primary, { Thickness = 0.22, Duration = 0.14, Flickers = 1, Branches = 0, Core = P.Core })
		end
	end)
	if ctx.IsOwner then
		CameraFX.Shake(0.2)
		CameraFX.FOVPunch(-5, 0.5)
	end
	if not ctx:Until(shot, "Plant") then
		return
	end
	Kit.Dust(ctx, "LeftFoot", 1.1)
	if not ctx:Until(shot, "Contact") then
		return
	end
	local origin = Kit.PropPosition(ctx) + Vector3.new(0, 0.5, 0)
	local dir = ctx.Aim
	Kit.Contact(ctx, origin, 2.4)
	FX.Flash(origin, P.Core, 7, 0.15)
	FX.Shockwave(CFrame.lookAt(origin, origin + dir) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 7, 0.35, P.Core)
	for _ = 1, 4 do
		local d = (dir + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6).Unit
		FX.Lightning(origin, origin + d * 7, P.Primary, { Thickness = 0.3, Duration = 0.18, Flickers = 1, Core = P.Core })
	end
	Sound.Play("Kick", origin, 0.7)
	Sound.Play("Soccer_LightningShot", origin)
	if ctx.IsOwner then
		CameraFX.Shake(0.4)
		CameraFX.FOVPunch(9, 0.12)
	end
	ctx:HideProp(true)
	local wind = 0
	ctx:Projectile({
		Hit = "Ball",
		Origin = origin,
		Direction = dir,
		Speed = 110,
		Range = 125,
		Radius = 2.3,
		Visual = ballWithTrail(1.3, P.Primary, Color3.new(1, 1, 1), P.Core, Kit.BallSkin(ctx)),
		Spin = Vector3.new(-30, 0, 0),
		OnStep = function(position: Vector3, direction: Vector3, dt: number)
			wind += dt
			if wind > 0.05 then
				wind = 0
				-- Wind spiralling around the ball's path
				FX.Spiral(CFrame.lookAt(position, position - direction), Color3.fromRGB(235, 245, 255), 1.5, 8, 0.28, 2)
			end
			if math.random() < 0.55 then
				local d = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 5
				FX.Lightning(position, position + d, P.Primary, { Thickness = 0.16, Detail = 2, Duration = 0.08, Flickers = 1, Branches = 0, Core = P.Core })
			end
		end,
		OnImpact = function(position: Vector3, victim: Model?)
			lightningExplosion(ctx, position, victim)
		end,
	})
	ctx:Until(shot, "End")
end

--------------------------------------------------------------------------------
-- 3: Lightning Dribble Dash
--------------------------------------------------------------------------------
local function flickEffects(ctx: Ctx, at: Vector3)
	local P = ctx.Palette
	local ground = FX.GroundBelow(at)
	FX.Lightning(ground, ground + Vector3.new(0, 16, 0), P.Primary, { Thickness = 0.6, Duration = 0.3, Flickers = 2, Branches = 2, Core = P.Core })
	FX.Ring(CFrame.new(ground + Vector3.new(0, 0.2, 0)), P.Primary, 1, 7, 0.3, 0.6)
	FX.Emit(at, { Color = P.Accent, Count = 18, Speed = NumberRange.new(30, 55), Spread = Vector2.new(25, 25), Size = FX.Seq(0.5, 0), Lifetime = NumberRange.new(0.25, 0.5) })
	Sound.Play("Soccer_DashKick", at)
	Sound.Play("Soccer_DashLightning", at)
end

local function dribbleDash(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local dashTrack = ctx:Play(C.DribbleDash)
	local ball = ctx:PropPart()
	if ball then
		FX.Crackle(ball, P.Primary, 0.45, 1.3, 18)
		local trail = FX.Trail(ball, P.Primary, 0.9, 0.25, P.Core)
		ctx:OnCleanup(function()
			trail:Destroy()
		end)
	end
	Kit.Afterimages(ctx, P.Primary, 0.42, 0.07, 0.22)
	if ctx.IsOwner then
		CameraFX.SpeedLines(0.45, P.Accent)
	end
	Sound.Play("Soccer_DashRun", ctx.Root.Position)
	local frame = Kit.Frame(ctx)
	local velocity = ctx:Velocity(frame.LookVector * 62, 0.42)
	local last = ctx.Root.Position
	local start = os.clock()
	local target: Model? = nil
	while os.clock() - start < 0.42 and ctx:Alive() do
		local now = ctx.Root.Position
		FX.Lightning(last - Vector3.new(0, 2.7, 0), now - Vector3.new(0, 2.7, 0), P.Primary, { Thickness = 0.28, Detail = 2, Duration = 0.3, Flickers = 1, Branches = 0, Core = P.Core })
		last = now
		if ctx.IsOwner then
			local found = ctx:QueryBox(ctx.Root.CFrame * CFrame.new(0, 0, -3), Vector3.new(6.5, 6, 6))
			if #found > 0 then
				target = found[1]
				break
			end
		elseif ctx.Data.Flicked then
			break
		end
		task.wait()
	end
	if not ctx:Alive() then
		return
	end
	if velocity then
		velocity:Destroy()
		ctx.Root.AssemblyLinearVelocity = Vector3.new(0, ctx.Root.AssemblyLinearVelocity.Y, 0)
	end
	if dashTrack then
		dashTrack:Stop(0.04)
	end
	local flick = ctx:Play(C.Flick)
	if not ctx:Until(flick, "Contact") then
		return
	end
	local at = ctx.Root.Position + ctx.Root.CFrame.LookVector * 2.5
	Kit.Contact(ctx, at, 1.5)
	flickEffects(ctx, at)
	if ctx.IsOwner then
		if target then
			local r = target:FindFirstChild("HumanoidRootPart")
			ctx:Report("Flick", { target }, if r and r:IsA("BasePart") then r.Position else at)
		else
			Kit.Front(ctx, "Flick", 3, Vector3.new(6, 7, 6))
		end
	end
	ctx:Until(flick, "End")
end

local function dribbleHit(hit: MoveRunner.HitInfo, palette: Palette)
	local ctx = MoveRunner.Find(hit.Attacker, hit.Token)
	if ctx and not ctx.IsOwner then
		ctx.Data.Flicked = true
	end
	FX.Emit(hit.Position, { Color = palette.Core, Count = 12, Speed = NumberRange.new(30, 60), Spread = Vector2.new(15, 15), Size = FX.Seq(0.6, 0), Lifetime = NumberRange.new(0.2, 0.4) })
	FX.Lightning(hit.Position, hit.Position + Vector3.new(0, 12, 0), palette.Primary, { Thickness = 0.4, Duration = 0.25, Flickers = 2, Core = palette.Core })
end

--------------------------------------------------------------------------------
-- 4: Thunder Bicycle Kick
--------------------------------------------------------------------------------
local function bicycleKick(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local kick = ctx:Play(C.BicycleKick)
	local frame = Kit.Frame(ctx)
	Sound.Play("Soccer_BicycleLeap", ctx.Root.Position)
	if not ctx:Until(kick, "Jump") then
		return
	end
	ctx:Velocity(frame.LookVector * 16 + Vector3.new(0, 58, 0), 0.16)
	local feet = ctx.Root.Position - Vector3.new(0, 2.8, 0)
	FX.Smoke(feet, Color3.fromRGB(210, 205, 195), 8, 1.5, 0.8, 2)
	FX.Ring(CFrame.new(feet), P.Primary, 1, 6, 0.3, 0.5)
	Kit.LimbTrail(ctx, "RightFoot", P.Primary, 0.9, 0.5, 0.2)
	Kit.LimbTrail(ctx, "LeftFoot", P.Accent, 0.6, 0.4)
	local foot = ctx:Limb("RightFoot")
	if foot then
		FX.Crackle(foot, P.Primary, 0.5, 1.5, 20)
	end
	if not ctx:Until(kick, "Contact") then
		return
	end
	local strike = ctx:Ground(ctx.Root.Position + frame.LookVector * 11)
	local from = if foot then foot.Position else ctx.Root.Position
	Kit.Contact(ctx, from, 2)
	ctx:HideProp(true)
	-- The ball is volleyed into the ground with the bolt riding on it
	ctx:Projectile({
		Origin = from,
		Direction = (strike - from),
		Speed = 260,
		Range = (strike - from).Magnitude + 2,
		Radius = 1,
		IgnoreWalls = true,
		Visual = ballWithTrail(1.1, P.Primary, Color3.new(1, 1, 1), P.Core, Kit.BallSkin(ctx)),
	})
	FX.Lightning(from, strike, P.Primary, { Thickness = 0.9, Jag = 2.5, Duration = 0.35, Flickers = 3, Branches = 2, Core = P.Core })
	Sound.Play("Soccer_BicycleLightning", strike)
	task.wait(0.06)
	FX.Thunderbolt(strike, P, 3)
	FX.Crater(strike, 9)
	FX.Debris(strike, 12, 40)
	FX.Shell(strike, P.Primary, 2, 10, 0.35, Enum.Material.Neon)
	Sound.Play("Soccer_BicycleImpact", strike)
	shake(strike, 0.7, 90)
	ctx:Sphere("Kick", strike + Vector3.new(0, 3, 0), 10)
	ctx:Sphere("Kick", ctx.Root.Position + frame.LookVector * 4, 7)
	ctx:Velocity(Vector3.new(0, -70, 0), 0.15)
	ctx:Until(kick, "End")
end

--------------------------------------------------------------------------------
-- Awakening: Storm Striker
--------------------------------------------------------------------------------
local function awaken(ctx: Ctx)
	local P = ctx.Palette
	Kit.Awaken(ctx, C.Awaken, function(c: Ctx)
		stormCloud(c.Root.Position + Vector3.new(0, 45, 0), P, 2.4, 30)
		local ball = c:PropPart()
		if ball then
			FX.Crackle(ball, P.Primary, 1.2, 2.2, 20)
		end
		FX.Charge(c.Root, P.Accent, 1.1, 9)
	end, function(_c: Ctx, at: Vector3)
		for _ = 1, 3 do
			FX.Thunderbolt(at + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 3, P, 2.8)
		end
		FX.Explosion(at, P, 9, { Lightning = true, Fire = false, Crater = true })
		FX.Popup(at + Vector3.new(0, 6, 0), "STORM STRIKER", P.Accent, 2.4, 1.5)
		Sound.Play("Thunder", at, 0.8)
	end, { Intro = "Soccer_AwakenIntro", Electricity = "Soccer_AwakenElectricity" })
end

--------------------------------------------------------------------------------
-- Awakened 1: Railgun
--------------------------------------------------------------------------------
local railParams = RaycastParams.new()
railParams.FilterType = Enum.RaycastFilterType.Exclude

local function railgun(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local strike = ctx:Play(C.Railgun)
	local ball = ctx:PropPart()
	if ball then
		FX.Charge(ball, P.Accent, 0.35, 6)
		FX.Crackle(ball, P.Primary, 0.38, 1.8, 26)
	end
	Sound.Play("Zap", ctx.Root.Position, 0.6)
	if not ctx:Until(strike, "Contact") then
		return
	end
	local origin = Kit.PropPosition(ctx)
	local dir = ctx.Aim
	Kit.Contact(ctx, origin, 2.5)
	local ignore: { Instance } = { FX.Folder(), ctx.Character }
	for _, name in { "Fighters", "Dummies" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	local walls = workspace:FindFirstChild("Stadium")
	local arena = walls and walls:FindFirstChild("ArenaWalls")
	if arena then
		table.insert(ignore, arena)
	end
	railParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, dir * 100, railParams)
	local finish = if hit then hit.Position else origin + dir * 100
	local length = (finish - origin).Magnitude
	ctx:HideProp(true)
	FX.Beam(origin, finish, P.Primary, 3.4, 0.45, P.Core)
	FX.Lightning(origin, finish, P.Accent, { Thickness = 0.5, Duration = 0.4, Flickers = 3, Core = P.Core })
	FX.Lightning(origin, finish, P.Secondary, { Thickness = 0.35, Duration = 0.35, Flickers = 3, Core = P.Core })
	for d = 8, length, 14 do
		local p = origin + dir * d
		FX.Ring(CFrame.lookAt(p, p + dir) * CFrame.Angles(math.pi / 2, 0, 0), P.Core, 1.5, 6, 0.3, 0.4, 14)
	end
	FX.Flash(origin, P.Core, 8, 0.15)
	FX.Explosion(finish, P, 6, { Lightning = true, Fire = false, Crater = false })
	Sound.Play("Thunder", origin, 1.6)
	Sound.Play("Explosion", finish, 1.4)
	if ctx.IsOwner then
		CameraFX.Shake(0.5)
		CameraFX.FOVPunch(10, 0.12)
		local mid = origin + dir * (length / 2)
		-- Report each victim where they stand (the server checks the impact point is near them)
		for _, victim in ctx:QueryBox(CFrame.lookAt(mid, finish), Vector3.new(5, 5, length)) do
			local r = victim:FindFirstChild("HumanoidRootPart")
			ctx:Report("Beam", { victim }, if r and r:IsA("BasePart") then r.Position else mid)
		end
	end
	ctx:Until(strike, "End")
end

--------------------------------------------------------------------------------
-- Awakened 2: Thunderclap Volley
--------------------------------------------------------------------------------
local function volley(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local track = ctx:Play(C.Volley)
	ctx:Velocity(Vector3.new(0, 18, 0), 0.12)
	for i = 1, 5 do
		if not ctx:Until(track, "Kick" .. i) then
			return
		end
		local right = i % 2 == 1
		local foot = ctx:Limb(if right then "RightFoot" else "LeftFoot")
		local origin = if foot then foot.Position else ctx.Root.Position
		local spread = Vector3.new((math.random() - 0.5) * 0.12, (math.random() - 0.5) * 0.06, (math.random() - 0.5) * 0.12)
		local dir = (ctx.Aim + spread).Unit
		FX.Flash(origin, P.Core, 3, 0.1)
		FX.Lightning(origin, origin + dir * 6, P.Primary, { Thickness = 0.3, Duration = 0.1, Flickers = 1, Branches = 0, Core = P.Core })
		Sound.Play("Zap", origin, 1 + i * 0.08)
		ctx:Projectile({
			Hit = "Shot",
			Origin = origin,
			Direction = dir,
			Speed = 165,
			Range = 70,
			Radius = 1.8,
			Visual = Kit.Orb(P.Primary, P.Core, 1.8),
			OnStep = function(position: Vector3)
				if math.random() < 0.6 then
					FX.Lightning(position, position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3.5, P.Primary, { Thickness = 0.14, Detail = 2, Duration = 0.07, Flickers = 1, Branches = 0 })
				end
			end,
			OnImpact = function(position: Vector3)
				FX.Flash(position, P.Core, 4, 0.12)
				FX.Sparks(position, P.Primary, 10, 30, 0.45)
				FX.Ring(CFrame.new(position), P.Primary, 0.5, 4, 0.2, 0.3, 12)
			end,
		})
	end
	ctx:Until(track, "End")
end

--------------------------------------------------------------------------------
-- Awakened 3: Flash Step
--------------------------------------------------------------------------------
local function flashStep(ctx: Ctx)
	local P = ctx.Palette
	local from = ctx.Root.Position
	FX.Afterimage(ctx.Character, P.Primary, 0.4)
	FX.Flash(from, P.Core, 6, 0.15)
	Sound.Play("Thunder", from, 2)
	if ctx.IsOwner then
		local target = ctx:Nearest(45)
		local destination: CFrame
		local r = target and target:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			local behind = r.Position - r.CFrame.LookVector * 4
			destination = CFrame.lookAt(Vector3.new(behind.X, math.max(behind.Y, from.Y - 2), behind.Z), r.Position)
			ctx.Aim = (r.Position - behind).Unit
		else
			local ahead = ctx:Ahead(30)
			destination = CFrame.lookAt(ahead, ahead + Kit.Frame(ctx).LookVector)
		end
		ctx:Teleport(destination)
		CameraFX.SpeedLines(0.2, P.Core)
	end
	task.wait(0.06)
	local to = ctx.Root.Position
	FX.Lightning(from, to, P.Primary, { Thickness = 0.8, Duration = 0.3, Flickers = 2, Branches = 2, Core = P.Core })
	FX.Flash(to, P.Core, 6, 0.15)
	FX.Ring(CFrame.new(to - Vector3.new(0, 2.6, 0)), P.Primary, 1, 7, 0.25, 0.5)
	local kick = ctx:Play(C.FlashStep)
	Kit.LimbTrail(ctx, "RightFoot", P.Primary, 1, 0.35, 0.2)
	if not ctx:Until(kick, "Contact") then
		return
	end
	local frame = Kit.Frame(ctx)
	Kit.Contact(ctx, (frame * CFrame.new(0, 0, -3)).Position, 2)
	FX.Slash(frame * CFrame.new(0, -0.4, -1.2), P.Primary, { Radius = 5, Arc = 200, Width = 1.4, Duration = 0.2, Core = P.Core })
	Kit.Front(ctx, "Kick", 3.4, Vector3.new(7, 6.5, 7))
	ctx:Until(kick, "End")
end

--------------------------------------------------------------------------------
-- Awakened 4: Storm of the Century
--------------------------------------------------------------------------------
local function storm(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local track = ctx:Play(C.Storm)
	local center = ctx:Ground(ctx:Ahead(24))
	if ctx.IsOwner then
		CameraFX.Orbit(ctx.Root, 0.9, 150, 200, 15, 1, 60)
	end
	if not ctx:Until(track, "Kick") then
		return
	end
	-- Kick the ball into the clouds
	local origin = Kit.PropPosition(ctx)
	Kit.Contact(ctx, origin, 2)
	ctx:HideProp(true)
	ctx:Projectile({
		Origin = origin,
		Direction = Vector3.new(0, 1, 0),
		Speed = 170,
		Range = 70,
		Radius = 1,
		IgnoreWalls = true,
		Visual = ballWithTrail(1.2, P.Primary, P.Accent, P.Core, Kit.BallSkin(ctx)),
	})
	FX.Flash(origin, P.Core, 6, 0.15)
	FX.Shockwave(CFrame.new(origin), P.Primary, 8, 0.4, P.Core)
	Sound.Play("Kick", origin, 0.6)
	stormCloud(center + Vector3.new(0, 55, 0), P, 2.1, 34)
	if not ctx:Until(track, "Rain") then
		return
	end
	-- Lightning rains down
	for _ = 1, 6 do
		if not ctx:Wait(0.2) then
			return
		end
		local a = math.random() * math.pi * 2
		local r = math.random() * 20
		local point = ctx:Ground(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		FX.Thunderbolt(point, P, 2.2)
		FX.Crater(point, 5)
		Sound.Play("Thunder", point, 1 + math.random() * 0.4)
		shake(point, 0.35, 100)
		ctx:Sphere("Strike", point + Vector3.new(0, 3, 0), 9)
	end
	if not ctx:Until(track, "Bolt") then
		return
	end
	-- The giant thunderbolt
	Kit.Climax(ctx, center)
	FX.Thunderbolt(center, P, 6)
	FX.Thunderbolt(center + Vector3.new(3, 0, 2), P, 4)
	FX.Explosion(center, P, 20, { Lightning = true, Fire = false, Crater = true })
	FX.Shockwave(CFrame.new(center + Vector3.new(0, 0.3, 0)), P.Accent, 40, 0.8, P.Core)
	Sound.Play("Thunder", center, 0.7)
	Sound.Play("Explosion", center, 0.8)
	shake(center, 1.3, 200)
	ctx:Sphere("Finale", center + Vector3.new(0, 4, 0), 22)
	ctx:Until(track, "End")
end

local scripts: { [string]: MoveScript } = {
	Soccer_M1 = { Run = m1, OnHit = m1Hit },
	Soccer_LightKick = { Run = lightKick, HitSound = "Soccer_LightKickHit" },
	Soccer_LightningShot = { Run = lightningShot },
	Soccer_DribbleDash = { Run = dribbleDash, OnHit = dribbleHit },
	Soccer_BicycleKick = { Run = bicycleKick },
	Soccer_Awaken = { Run = awaken },
	Soccer_Railgun = { Run = railgun },
	Soccer_Volley = { Run = volley },
	Soccer_FlashStep = { Run = flashStep },
	Soccer_Storm = { Run = storm },
}

return scripts
