--[[
	Baseball move scripts. Emerald-green wind: crescent slashes, gusts, streaking pitches.

	1  Fastball   2  Stolen Base (slide + trip)   3  Line Drive (ball inside a wind crescent)
	4  Home Run (charged swing, launches far)
	Awakening  Grand Slam: Rapid Fire, Tornado Swing, Inside-the-Park, Walk-Off Homer
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clips = require(Shared.Anim.Clips)
local Characters = require(Shared.Characters)
local Props = require(Shared.Props)

local CameraFX = require(script.Parent.Parent.CameraFX)
local FX = require(script.Parent.Parent.FX)
local MoveRunner = require(script.Parent.Parent.MoveRunner)
local Sound = require(script.Parent.Parent.Sound)
local Kit = require(script.Parent.Kit)

type Ctx = MoveRunner.Ctx
type Palette = Characters.Palette
type MoveScript = MoveRunner.MoveScript

local C = Clips.Baseball

local function shake(position: Vector3, amount: number, range: number)
	local camera = workspace.CurrentCamera
	if camera then
		local d = (camera.CFrame.Position - position).Magnitude
		if d < range then
			CameraFX.Shake(amount * (1 - d / range))
		end
	end
end

local function pitchBall(palette: Palette): () -> Instance
	return function(): Instance
		local model = (Kit.Ball("Baseball"))() :: Model
		local core = model.PrimaryPart
		if core then
			FX.Trail(core, palette.Primary, 0.6, 0.2, Color3.new(1, 1, 1))
		end
		return model
	end
end

-- Where the tip of the bat is (wind gathers there).
local function batTip(ctx: Ctx): Vector3
	local handle = ctx:PropPart()
	if handle then
		return (handle.CFrame * CFrame.new(0, 2.6, 0)).Position
	end
	return ctx.Root.Position + Vector3.new(0, 1, 0)
end

local function gust(cf: CFrame, palette: Palette, size: number)
	FX.Slash(cf, palette.Primary, { Radius = size, Arc = 160, Width = size * 0.22, Duration = 0.22, Core = palette.Core })
	FX.Slash(cf * CFrame.new(0, 0.6, 0), palette.Secondary, { Radius = size * 1.25, Arc = 120, Width = size * 0.12, Duration = 0.28, Core = palette.Core })
end

--------------------------------------------------------------------------------
-- M1
--------------------------------------------------------------------------------
local M1: Kit.M1Set = {
	Hits = {
		{ Clip = C.Level, Time = 0.13 },
		{ Clip = C.Chop, Time = 0.13 },
		{ Clip = C.Backhand, Time = 0.13 },
		{ Clip = C.PowerSwing, Time = 0.22 },
	},
	Uppercut = { Clip = C.Golf, Time = 0.16 },
	Downslam = { Clip = C.Smash, Time = 0.22 },
	Reach = 4,
	Size = Vector3.new(7, 6, 6.5),
	Swing = function(ctx: Ctx, step: number, _mirrored: boolean, position: Vector3)
		local P = ctx.Palette
		local frame = Kit.Frame(ctx)
		local first = string.sub(ctx.Variant, 1, 1)
		local big = step >= 4 or first == "U" or first == "D"
		local plane: CFrame
		if step == 2 or first == "D" or first == "U" then
			plane = CFrame.Angles(0, 0, math.pi / 2) -- vertical arc
		else
			plane = CFrame.Angles(0, 0, if step == 3 then -0.15 else 0.15)
		end
		gust(frame * CFrame.new(0, 0.2, -0.5) * plane, P, if big then 6 else 4.4)
		FX.Sparks(position, P.Secondary, if big then 10 else 4, 22, 0.35)
		local handle = ctx:PropPart()
		if handle then
			local trail = FX.Trail(handle, P.Primary, 1.2, 0.15, P.Core)
			task.delay(0.15, function()
				trail:Destroy()
			end)
		end
		if big then
			Sound.Play("BatCrack", position, 0.9)
		end
	end,
}

local function m1(ctx: Ctx)
	Kit.M1(ctx, M1)
end

--------------------------------------------------------------------------------
-- 1: Fastball
--------------------------------------------------------------------------------
local function throwBall(ctx: Ctx, hitName: string, dir: Vector3, speed: number)
	local P = ctx.Palette
	local hand = ctx:Limb("LeftHand")
	local origin = if hand then hand.Position else ctx.Root.Position + Vector3.new(0, 1.5, 0)
	FX.Flash(origin, P.Core, 2.5, 0.1)
	FX.Ring(CFrame.lookAt(origin, origin + dir) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 0.4, 2.5, 0.16, 0.25, 12)
	Sound.Play("Whoosh", origin, 1.5)
	local timer = 0
	ctx:Projectile({
		Hit = hitName,
		Origin = origin,
		Direction = dir,
		Speed = speed,
		Range = 95,
		Radius = 1.4,
		Visual = pitchBall(P),
		Spin = Vector3.new(-40, 0, 0),
		OnStep = function(position: Vector3, direction: Vector3, dt: number)
			timer += dt
			if timer > 0.07 then
				timer = 0
				FX.Ring(CFrame.lookAt(position, position + direction) * CFrame.Angles(math.pi / 2, 0, 0), P.Secondary, 0.3, 1.6, 0.18, 0.15, 10)
			end
		end,
		OnImpact = function(position: Vector3)
			FX.Flash(position, P.Core, 3.5, 0.12)
			FX.Sparks(position, P.Primary, 12, 30, 0.45)
			FX.Ring(CFrame.new(position), P.Primary, 0.5, 4, 0.2, 0.3, 12)
		end,
	})
end

local function fastball(ctx: Ctx)
	ctx:Face()
	ctx:Play(C.Pitch)
	if not ctx:Wait(0.28) then
		return
	end
	throwBall(ctx, "Ball", ctx.Aim, 190)
	ctx:Wait(0.22)
end

--------------------------------------------------------------------------------
-- 2: Stolen Base
--------------------------------------------------------------------------------
local function stolenBase(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.Slide)
	if not ctx:Wait(0.08) then
		return
	end
	local frame = Kit.Frame(ctx)
	local velocity = ctx:Velocity(frame.LookVector * 58 + Vector3.new(0, -10, 0), 0.4)
	Sound.Play("Wind", ctx.Root.Position, 1.2)
	if ctx.IsOwner then
		CameraFX.SpeedLines(0.4, P.Core)
	end
	local start = os.clock()
	local tripped = false
	while os.clock() - start < 0.4 and ctx:Alive() do
		local feet = ctx.Root.Position - Vector3.new(0, 2.7, 0)
		FX.Smoke(feet, Color3.fromRGB(190, 160, 120), 3, 1.4, 0.8, 1)
		FX.Spiral(CFrame.lookAt(feet + Vector3.new(0, 1, 0), feet + Vector3.new(0, 1, 0) - frame.LookVector), P.Primary, 1.2, 4, 0.25, 2)
		if ctx.IsOwner and #ctx:Hitbox("Trip", ctx.Root.CFrame * CFrame.new(0, -1.5, -3), Vector3.new(6, 3.5, 6)) > 0 then
			tripped = true
			break
		end
		task.wait(0.03)
	end
	if tripped and velocity then
		velocity:Destroy()
		local at = ctx.Root.Position + frame.LookVector * 3
		FX.Flash(at, P.Core, 4, 0.12)
		FX.Debris(at, 6, 22)
		FX.Popup(at + Vector3.new(0, 3, 0), "SAFE!", Color3.new(1, 1, 1), 1.3)
	end
	ctx:Wait(0.15)
end

--------------------------------------------------------------------------------
-- 3: Line Drive
--------------------------------------------------------------------------------
local function lineDrive(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.LineDrive)
	-- Toss
	if not ctx:Wait(0.1) then
		return
	end
	local hand = ctx:Limb("LeftHand")
	local tossed = Props.BuildBall("Baseball", true)
	local start = if hand then hand.Position else ctx.Root.Position + Vector3.new(-1, 1, -1)
	tossed:PivotTo(CFrame.new(start))
	tossed.Parent = FX.Folder()
	local core = tossed.PrimaryPart :: BasePart
	FX.Tween(core, 0.28, { CFrame = CFrame.new(start + Vector3.new(0.6, 3, -0.5)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, p in tossed:GetChildren() do
		if p:IsA("BasePart") and p ~= core then
			local offset = core.CFrame:ToObjectSpace(p.CFrame)
			task.spawn(function()
				local stop = os.clock() + 0.3
				while os.clock() < stop and p.Parent do
					p.CFrame = core.CFrame * offset
					task.wait()
				end
			end)
		end
	end
	ctx:OnCleanup(function()
		tossed:Destroy()
	end)
	if not ctx:Wait(0.3) then
		return
	end
	tossed:Destroy()
	local tip = batTip(ctx)
	local frame = Kit.Frame(ctx)
	gust(frame * CFrame.new(0, 0.4, -0.5), P, 6)
	FX.Flash(tip, P.Core, 5, 0.12)
	Sound.Play("BatCrack", tip)
	if ctx.IsOwner then
		CameraFX.Shake(0.25)
	end
	local timer = 0
	ctx:Projectile({
		Hit = "Drive",
		Origin = ctx.Root.Position + frame.LookVector * 3 + Vector3.new(0, 1, 0),
		Direction = ctx.Aim,
		Speed = 125,
		Range = 90,
		Radius = 3,
		Visual = pitchBall(P),
		Spin = Vector3.new(-50, 0, 0),
		OnStep = function(position: Vector3, direction: Vector3, dt: number)
			timer += dt
			if timer > 0.06 then
				timer = 0
				-- The crescent of wind riding with the ball
				local cf = CFrame.lookAt(position, position + direction) * CFrame.new(0, 0, 2.6) * CFrame.Angles(0, 0, math.pi / 2)
				FX.Slash(cf, P.Primary, { Radius = 3.2, Arc = 150, Width = 0.9, Duration = 0.16, Core = P.Core })
			end
		end,
		OnImpact = function(position: Vector3)
			FX.Flash(position, P.Core, 6, 0.15)
			gust(CFrame.lookAt(position, position + ctx.Aim) * CFrame.Angles(0, 0, math.pi / 2), P, 5)
			FX.Sparks(position, P.Secondary, 18, 40, 0.5)
			Sound.Play("HeavyHit", position, 1.2)
		end,
	})
	ctx:Wait(0.35)
end

--------------------------------------------------------------------------------
-- 4: Home Run
--------------------------------------------------------------------------------
local function twinkle(model: Model, palette: Palette, delay: number)
	task.delay(delay, function()
		local r = model:FindFirstChild("HumanoidRootPart")
		if not r or not r:IsA("BasePart") then
			return
		end
		local star = FX.Part({ Size = Vector3.one * 2, CFrame = r.CFrame, Color = palette.Core, Shape = Enum.PartType.Ball, Life = 0.6 })
		FX.Tween(star, 0.5, { Size = Vector3.one * 7, Transparency = 1 })
		FX.ImpactLines(r.Position, palette.Core, 8, 6, 0.4)
		FX.Light(r.Position, palette.Light, 6, 30, 0.4)
		Sound.Play("Ping", r.Position, 1.6)
	end)
end

local function homeRun(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.HomeRun)
	-- Wind gathers on the bat
	local handle = ctx:PropPart()
	if handle then
		FX.Charge(handle, P.Primary, 0.55, 7)
		local trail = FX.Trail(handle, P.Primary, 1.4, 0.3, P.Core)
		ctx:OnCleanup(function()
			trail:Destroy()
		end)
	end
	task.spawn(function()
		for _ = 1, 5 do
			if not ctx:Alive() then
				return
			end
			FX.Spiral(CFrame.new(ctx.Root.Position - Vector3.new(0, 2.7, 0)) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 3, 6, 0.3, 3)
			task.wait(0.1)
		end
	end)
	Sound.Play("Wind", ctx.Root.Position, 0.8)
	if ctx.IsOwner then
		CameraFX.FOVPunch(-6, 0.55)
	end
	if not ctx:Wait(0.62) then
		return
	end
	local frame = Kit.Frame(ctx)
	gust(frame * CFrame.new(0, 0.3, -0.5), P, 8)
	FX.Shockwave(CFrame.lookAt(ctx.Root.Position + frame.LookVector * 4, ctx.Root.Position + frame.LookVector * 5) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 9, 0.4, P.Core)
	Sound.Play("BatCrack", ctx.Root.Position, 0.7)
	if ctx.IsOwner then
		CameraFX.Shake(0.5)
	end
	Kit.Front(ctx, "Swing", 4, Vector3.new(9, 7, 9))
	ctx:Wait(0.38)
end

local function homeRunHit(hit: MoveRunner.HitInfo, palette: Palette)
	if hit.Blocked then
		return
	end
	FX.Popup(hit.Position + Vector3.new(0, 4, 0), "HOME RUN!", palette.Secondary, 2, 1.3)
	twinkle(hit.Victim, palette, 0.7)
end

--------------------------------------------------------------------------------
-- Awakening: Grand Slam
--------------------------------------------------------------------------------
local function awaken(ctx: Ctx)
	local P = ctx.Palette
	Kit.Awaken(ctx, C.Awaken, 1.2, function(c: Ctx)
		task.wait(0.5)
		local tip = batTip(c)
		-- A beam of light from the bat into the sky: the called shot
		FX.Beam(tip, tip + Vector3.new(0, 80, 0), P.Secondary, 1.5, 0.7, P.Core)
		for _ = 1, 6 do
			if not c:Alive() then
				return
			end
			FX.Spiral(CFrame.new(c.Root.Position - Vector3.new(0, 2.8, 0)) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 3.5 + math.random(), 8, 0.4, 3)
			task.wait(0.1)
		end
	end, function(_c: Ctx, at: Vector3)
		FX.Explosion(at, P, 9, { Fire = false, Crater = false })
		for i = 1, 4 do
			local cf = CFrame.new(at) * CFrame.Angles(0, i * math.pi / 2, 0)
			gust(cf, P, 9)
		end
		FX.Popup(at + Vector3.new(0, 6, 0), "GRAND SLAM", P.Secondary, 2.4, 1.5)
		Sound.Play("Wind", at, 0.6)
	end)
end

--------------------------------------------------------------------------------
-- Awakened 1: Rapid Fire
--------------------------------------------------------------------------------
local function rapidFire(ctx: Ctx)
	ctx:Face()
	ctx:Play(C.RapidFire)
	local elapsed = 0
	for i = 0, 5 do
		local t = 0.1 + i * 0.12
		if not ctx:Wait(t - elapsed) then
			return
		end
		elapsed = t
		local spread = Vector3.new((math.random() - 0.5) * 0.1, (math.random() - 0.5) * 0.04, (math.random() - 0.5) * 0.1)
		throwBall(ctx, "Ball", (ctx.Aim + spread).Unit, 195)
	end
	ctx:Wait(0.15)
end

--------------------------------------------------------------------------------
-- Awakened 2: Tornado Swing
--------------------------------------------------------------------------------
local function tornado(ctx: Ctx)
	local P = ctx.Palette
	ctx:Play(C.Tornado)
	Sound.Play("Wind", ctx.Root.Position, 0.7)
	local start = os.clock()
	local nextPull = 0
	while os.clock() - start < 1.2 and ctx:Alive() do
		local base = ctx.Root.Position - Vector3.new(0, 2.8, 0)
		FX.Spiral(CFrame.new(base) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 4 + math.random() * 2, 14, 0.35, 3)
		FX.Spiral(CFrame.new(base) * CFrame.Angles(math.pi / 2, 0, 0), P.Secondary, 7, 10, 0.4, 2)
		FX.Smoke(base, Color3.fromRGB(170, 190, 160), 3, 2, 0.8, 6)
		if os.clock() - start >= nextPull then
			nextPull += 0.24
			ctx:Sphere("Spin", ctx.Root.Position, 14)
		end
		task.wait(0.06)
	end
	if not ctx:Alive() then
		return
	end
	local at = ctx.Root.Position
	FX.Explosion(at, P, 8, { Fire = false, Crater = false })
	for i = 1, 3 do
		gust(CFrame.new(at) * CFrame.Angles(0, i * 2.1, 0), P, 8)
	end
	Sound.Play("BatCrack", at, 0.8)
	ctx:Sphere("Launch", at, 16)
	ctx:Wait(0.1)
end

--------------------------------------------------------------------------------
-- Awakened 3: Inside-the-Park
--------------------------------------------------------------------------------
-- A white base plate on the ground (the diamond marks).
local function basePlate(position: Vector3, palette: Palette)
	local ground = FX.GroundBelow(position)
	local plate = FX.Part({ Size = Vector3.new(2.6, 0.12, 2.6), CFrame = CFrame.new(ground + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, Life = 2.6 })
	task.delay(1.8, function()
		FX.Tween(plate, 0.7, { Transparency = 1 })
	end)
	FX.Ring(CFrame.new(ground + Vector3.new(0, 0.2, 0)), palette.Primary, 0.5, 3, 0.25, 0.3, 12)
end

local function insideThePark(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.InsideThePark)
	local target = ctx:Nearest(40)
	local center = ctx:Ahead(9)
	local r = target and target:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		center = r.Position
	end
	local bases: { Vector3 } = {}
	local frame = Kit.Frame(ctx)
	for i = 0, 3 do
		local a = i * math.pi / 2
		table.insert(bases, center + (frame.LookVector * -math.cos(a) + frame.RightVector * math.sin(a)) * 5)
	end
	-- The diamond lines connecting the bases
	for i = 1, 4 do
		local a = FX.GroundBelow(bases[i]) + Vector3.new(0, 0.1, 0)
		local b = FX.GroundBelow(bases[i % 4 + 1]) + Vector3.new(0, 0.1, 0)
		local line = FX.Part({ Size = Vector3.new(0.4, 0.06, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = P.Primary, Life = 2 })
		task.delay(1.2, function()
			FX.Tween(line, 0.7, { Transparency = 1 })
		end)
	end
	local elapsed = 0
	for i, base in bases do
		local t = 0.2 * i
		if not ctx:Wait(t - elapsed - 0.06) then
			return
		end
		elapsed = t - 0.06
		local from = ctx.Root.Position
		local look = Vector3.new(center.X - base.X, 0, center.Z - base.Z)
		if ctx.IsOwner and look.Magnitude > 0.1 then
			ctx:Teleport(CFrame.lookAt(Vector3.new(base.X, from.Y, base.Z), Vector3.new(center.X, from.Y, center.Z)))
			ctx.Aim = look.Unit
		end
		FX.Afterimage(ctx.Character, P.Primary, 0.3)
		basePlate(base, P)
		Sound.Play("Whoosh", base, 1.3)
		if not ctx:Wait(0.06) then
			return
		end
		elapsed = t
		local to = ctx.Root.Position
		FX.Beam(from, to, P.Secondary, 0.5, 0.2, P.Core)
		gust(Kit.Frame(ctx) * CFrame.new(0, 0.3, -0.5), P, 4.5)
		Kit.Front(ctx, "Base", 4, Vector3.new(7, 7, 7))
	end
	ctx:Wait(0.2)
end

--------------------------------------------------------------------------------
-- Awakened 4: Walk-Off Homer
--------------------------------------------------------------------------------
local function walkOff(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.WalkOff)
	if ctx.IsOwner then
		-- Low angle on the called shot
		local root = ctx.Root
		local base = root.CFrame
		CameraFX.Cinematic(function(t: number): CFrame
			local eye = base * Vector3.new(4 - t * 2, -1.5, -7)
			return CFrame.lookAt(eye, base * Vector3.new(0, 3 + t * 2, 0))
		end, 0.75, 55)
	end
	task.delay(0.3, function()
		local tip = batTip(ctx)
		FX.Beam(tip, tip + Vector3.new(0, 120, 0), P.Secondary, 1.8, 0.5, P.Core)
		FX.Sparks(tip, P.Secondary, 20, 20, 0.6)
	end)
	if not ctx:Wait(0.95) then
		return
	end
	local frame = Kit.Frame(ctx)
	for i = 1, 3 do
		gust(frame * CFrame.new(0, 0.3, -0.5) * CFrame.Angles(0, 0, (i - 2) * 0.25), P, 7 + i * 1.5)
	end
	FX.Shockwave(CFrame.lookAt(ctx.Root.Position + frame.LookVector * 4, ctx.Root.Position + frame.LookVector * 5) * CFrame.Angles(math.pi / 2, 0, 0), P.Secondary, 12, 0.5, P.Core)
	Sound.Play("BatCrack", ctx.Root.Position, 0.6)
	local victims = Kit.Front(ctx, "Swing", 4, Vector3.new(10, 8, 10))
	if ctx.IsOwner then
		CameraFX.Shake(0.7)
	end
	if not ctx.IsOwner or #victims == 0 then
		ctx:Wait(1.05)
		return
	end
	-- They twinkle in the sky... then come crashing back down
	local victim = victims[1]
	twinkle(victim, P, 1.0)
	local start = os.clock()
	local r = victim:FindFirstChild("HumanoidRootPart")
	local peak = -math.huge
	while os.clock() - start < 2.4 do
		task.wait(0.05)
		if not r or not r:IsA("BasePart") or not r.Parent then
			return
		end
		peak = math.max(peak, r.Position.Y)
		if os.clock() - start > 1.2 and r.Position.Y < peak - 6 then
			break
		end
	end
	if r and r:IsA("BasePart") then
		local at = FX.GroundBelow(r.Position)
		ctx:Report("Crash", { victim }, r.Position)
		FX.Explosion(at, P, 14, { Fire = false, Crater = true })
		FX.Popup(at + Vector3.new(0, 7, 0), "WALK-OFF!", P.Secondary, 2.6, 1.4)
		Sound.Play("Explosion", at, 0.8)
	end
end

local function walkOffHit(hit: MoveRunner.HitInfo, palette: Palette)
	local ctx = MoveRunner.Find(hit.Attacker, hit.Token)
	local isOwner = ctx ~= nil and ctx.IsOwner
	if hit.Hit == "Crash" and not isOwner then
		local at = FX.GroundBelow(hit.Position)
		FX.Explosion(at, palette, 14, { Fire = false, Crater = true })
		shake(at, 1.0, 160)
	elseif hit.Hit == "Swing" then
		FX.Popup(hit.Position + Vector3.new(0, 4, 0), "GOING... GOING...", palette.Secondary, 1.8, 1.2)
	end
end

local scripts: { [string]: MoveScript } = {
	Baseball_M1 = { Run = m1 },
	Baseball_Fastball = { Run = fastball },
	Baseball_StolenBase = { Run = stolenBase },
	Baseball_LineDrive = { Run = lineDrive },
	Baseball_HomeRun = { Run = homeRun, OnHit = homeRunHit },
	Baseball_Awaken = { Run = awaken },
	Baseball_RapidFire = { Run = rapidFire },
	Baseball_Tornado = { Run = tornado },
	Baseball_InsideThePark = { Run = insideThePark },
	Baseball_WalkOff = { Run = walkOff, OnHit = walkOffHit },
}

return scripts
