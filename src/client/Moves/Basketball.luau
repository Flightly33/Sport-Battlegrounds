--[[
	Basketball move scripts. Blazing orange fire, embers, hoop rings.

	Every move stuns long enough to start the next:
		M1 x3 -> Ankle Breaker -> Chest Pass -> Alley-Oop -> Slam Dunk
	Awakening  On Fire: Heat Check, Fast Break, Crossover Combo, Supernova Dunk
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Clips = require(Shared.Anim.Clips)
local Characters = require(Shared.Characters)

local Animator = require(script.Parent.Parent.Animator)
local CameraFX = require(script.Parent.Parent.CameraFX)
local FX = require(script.Parent.Parent.FX)
local MoveRunner = require(script.Parent.Parent.MoveRunner)
local Sound = require(script.Parent.Parent.Sound)
local Kit = require(script.Parent.Kit)

type Ctx = MoveRunner.Ctx
type Palette = Characters.Palette
type MoveScript = MoveRunner.MoveScript

local C = Clips.Basketball

local function shake(position: Vector3, amount: number, range: number)
	local camera = workspace.CurrentCamera
	if camera then
		local d = (camera.CFrame.Position - position).Magnitude
		if d < range then
			CameraFX.Shake(amount * (1 - d / range))
		end
	end
end

-- A flaming basketball for projectiles.
local function fireBall(palette: Palette, scale: number?): () -> Instance
	return function(): Instance
		local model = (Kit.Ball("Basketball", scale))() :: Model
		local core = model.PrimaryPart
		if core then
			local e = Instance.new("ParticleEmitter")
			e.Texture = FX.Textures.Fire
			e.Color = ColorSequence.new(palette.Secondary, palette.Accent)
			e.LightEmission = 1
			e.LightInfluence = 0
			e.Size = FX.Seq(1.4 * (scale or 1), 0.4)
			e.Transparency = FX.Seq(0.1, 1)
			e.Lifetime = NumberRange.new(0.2, 0.35)
			e.Speed = NumberRange.new(1, 3)
			e.Rate = 60
			e.Parent = core
			FX.Trail(core, palette.Primary, 1.1 * (scale or 1), 0.22, palette.Core)
			local light = Instance.new("PointLight")
			light.Color = palette.Light
			light.Brightness = 2.5
			light.Range = 14
			light.Parent = core
		end
		return model
	end
end

-- The hoop: a flat orange ring with a net of sparks (signature of Basketball impacts).
local function hoop(position: Vector3, palette: Palette, radius: number)
	FX.Ring(CFrame.new(position), palette.Primary, radius * 0.4, radius, 0.4, math.max(0.5, radius * 0.08), 24)
	FX.Ring(CFrame.new(position + Vector3.new(0, 0.3, 0)), palette.Core, radius * 0.3, radius * 0.75, 0.3, math.max(0.3, radius * 0.04), 20)
	FX.Emit(position, { Color = palette.Secondary, Count = 20, Speed = NumberRange.new(10, 25), Spread = Vector2.new(70, 70), Size = FX.Seq(0.4, 0), Lifetime = NumberRange.new(0.3, 0.6), Acceleration = Vector3.new(0, -40, 0) })
end

local function flames(position: Vector3, palette: Palette, size: number)
	FX.FireBurst(position, palette.Secondary, palette.Accent, math.floor(10 + size * 4), size, 0.7)
	FX.Flash(position, palette.Core, size * 2, 0.15)
end

--------------------------------------------------------------------------------
-- M1
--------------------------------------------------------------------------------
local M1: Kit.M1Set = {
	Hits = {
		{ Clip = C.Jab, Time = 0.12, Limb = "RightHand" },
		{ Clip = C.Elbow, Time = 0.12, Limb = "LeftLowerArm" },
		{ Clip = C.Slam, Time = 0.14, Limb = "RightHand" },
		{ Clip = C.ChestPassHit, Time = 0.2, Limb = "RightHand" },
	},
	Uppercut = { Clip = C.Uppercut, Time = 0.16, Limb = "RightHand" },
	Downslam = { Clip = C.Downslam, Time = 0.2, Limb = "RightHand" },
	Swing = function(ctx: Ctx, step: number, _mirrored: boolean, position: Vector3)
		local P = ctx.Palette
		local frame = Kit.Frame(ctx)
		local big = step >= 4 or string.sub(ctx.Variant, 1, 1) == "U" or string.sub(ctx.Variant, 1, 1) == "D"
		if step == 2 then
			FX.Slash(frame * CFrame.new(0, 0.4, -1), P.Primary, { Radius = 3, Arc = 110, Width = 0.8, Duration = 0.16, Reverse = true, Core = P.Core })
		else
			FX.Flash(position, P.Secondary, if big then 4 else 2.2, 0.12)
		end
		FX.FireBurst(position, P.Secondary, P.Accent, if big then 12 else 5, if big then 1.4 else 0.8, 0.45)
		if big then
			FX.Ring(CFrame.lookAt(position, position + frame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 0.5, 4, 0.22, 0.4, 16)
		end
	end,
}

local function m1(ctx: Ctx)
	Kit.M1(ctx, M1)
end

--------------------------------------------------------------------------------
-- 1: Ankle Breaker
--------------------------------------------------------------------------------
local function ankleBreaker(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.AnkleBreaker)
	local frame = Kit.Frame(ctx)
	local ball = ctx:PropPart()
	if ball then
		local trail = FX.Trail(ball, P.Primary, 1, 0.25, P.Core)
		ctx:OnCleanup(function()
			trail:Destroy()
		end)
	end
	Kit.Afterimages(ctx, P.Primary, 0.3, 0.06, 0.2)
	Sound.Play("Bounce", ctx.Root.Position)
	ctx:Velocity(frame.RightVector * 26, 0.1)
	if not ctx:Wait(0.12) then
		return
	end
	Sound.Play("Bounce", ctx.Root.Position, 1.2)
	ctx:Velocity(-frame.RightVector * 20 + frame.LookVector * 48, 0.14)
	FX.Smoke(ctx.Root.Position - Vector3.new(0, 2.6, 0), Color3.fromRGB(210, 200, 190), 6, 1.2, 0.6, 2)
	if not ctx:Wait(0.23) then
		return
	end
	local at = (Kit.Frame(ctx) * CFrame.new(0, 0, -3.5)).Position
	flames(at, P, 1.2)
	Kit.Front(ctx, "Jab", 3.6, Vector3.new(7, 6, 7.5))
	ctx:Wait(0.2)
end

local function ankleHit(hit: MoveRunner.HitInfo, palette: Palette)
	if hit.Blocked then
		return
	end
	-- Ankles broken: down to one knee
	Animator.Play(hit.Victim, Clips.Common.Kneel)
	FX.Popup(hit.Position + Vector3.new(0, 3.5, 0), "ANKLES BROKEN!", palette.Secondary, 1.5, 1.1)
	local r = hit.Victim:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		hoop(r.Position - Vector3.new(0, 2.8, 0), palette, 5)
	end
end

--------------------------------------------------------------------------------
-- 2: Chest Pass
--------------------------------------------------------------------------------
local function chestPass(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.ChestPass)
	if not ctx:Wait(0.15) then
		return
	end
	local origin = ctx.Root.Position + Kit.Frame(ctx).LookVector * 2.5 + Vector3.new(0, 0.6, 0)
	ctx:HideProp(true)
	FX.Flash(origin, P.Core, 3.5, 0.12)
	FX.Ring(CFrame.lookAt(origin, origin + ctx.Aim) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 0.5, 3.5, 0.2, 0.35, 14)
	Sound.Play("Whoosh", origin, 1.1)
	ctx:Projectile({
		Hit = "Pass",
		ReturnHit = "Rebound",
		ReturnTo = ctx.Root,
		Origin = origin,
		Direction = ctx.Aim,
		Speed = 120,
		Range = 62,
		Radius = 1.9,
		Visual = fireBall(P),
		Spin = Vector3.new(-20, 0, 0),
		OnImpact = function(position: Vector3)
			flames(position, P, 1.3)
			FX.Ring(CFrame.new(position), P.Primary, 0.5, 4.5, 0.22, 0.35, 14)
			Sound.Play("Bounce", position, 0.9)
		end,
	})
	ctx:Wait(0.27)
end

--------------------------------------------------------------------------------
-- 3: Alley-Oop
--------------------------------------------------------------------------------
local function alleyOop(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.AlleyOop)
	local ball = ctx:PropPart()
	if ball then
		local trail = FX.Trail(ball, P.Primary, 1.1, 0.3, P.Core)
		ctx:OnCleanup(function()
			trail:Destroy()
		end)
	end
	if not ctx:Wait(0.25) then
		return
	end
	local at = (Kit.Frame(ctx) * CFrame.new(0, 0, -3.5)).Position
	local ground = FX.GroundBelow(at)
	-- Pillar of fire shooting up through the target
	FX.Emit(ground, {
		Texture = FX.Textures.Fire,
		Color = P.Secondary,
		Color2 = P.Accent,
		Count = 40,
		Speed = NumberRange.new(30, 55),
		Spread = Vector2.new(12, 12),
		Size = FX.Seq(2.2, 1.2, 0),
		Transparency = FX.Seq(0, 0.3, 1),
		Lifetime = NumberRange.new(0.35, 0.6),
		Drag = 2,
	})
	local column = FX.Part({ Size = Vector3.new(3, 1, 3), CFrame = CFrame.new(ground + Vector3.new(0, 0.5, 0)), Color = P.Primary, Material = Enum.Material.Neon, Shape = Enum.PartType.Ball, Transparency = 0.2, Life = 0.5 })
	FX.Tween(column, 0.4, { Size = Vector3.new(4, 26, 4), CFrame = CFrame.new(ground + Vector3.new(0, 13, 0)), Transparency = 1 })
	hoop(ground + Vector3.new(0, 0.3, 0), P, 6)
	Sound.Play("Fire", ground)
	Kit.Front(ctx, "Launch", 3.5, Vector3.new(7, 10, 7.5), 2)
	ctx:Wait(0.35)
end

--------------------------------------------------------------------------------
-- 4: Slam Dunk
--------------------------------------------------------------------------------
local function slamDunk(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.SlamDunk)
	local frame = Kit.Frame(ctx)
	local distance = 14
	local target = ctx:Nearest(34, 50)
	if target then
		local r = target:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			distance = math.clamp((Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(ctx.Root.Position.X, 0, ctx.Root.Position.Z)).Magnitude - 2, 4, 32)
		end
	end
	if not ctx:Wait(0.14) then
		return
	end
	ctx:Velocity(frame.LookVector * (distance / 0.46) + Vector3.new(0, 55, 0), 0.22)
	FX.Smoke(ctx.Root.Position - Vector3.new(0, 2.6, 0), Color3.fromRGB(210, 200, 190), 8, 1.5, 0.8, 2)
	Kit.Afterimages(ctx, P.Primary, 0.4, 0.08, 0.25)
	local ball = ctx:PropPart()
	if ball then
		local trail = FX.Trail(ball, P.Primary, 1.4, 0.35, P.Core)
		ctx:OnCleanup(function()
			trail:Destroy()
		end)
	end
	if not ctx:Wait(0.34) then
		return
	end
	-- Meteor down
	ctx:Velocity(frame.LookVector * 10 + Vector3.new(0, -95, 0), 0.14)
	if ball then
		FX.FireBurst(ball.Position, P.Secondary, P.Accent, 16, 1.5, 0.4)
	end
	if not ctx:Wait(0.14) then
		return
	end
	local at = ctx:Ground(ctx.Root.Position + frame.LookVector * 2)
	FX.Explosion(at, P, 9, { Crater = true, Lightning = false })
	hoop(at + Vector3.new(0, 0.3, 0), P, 12)
	FX.Popup(at + Vector3.new(0, 6, 0), "SLAM!", P.Secondary, 2, 1)
	Sound.Play("Explosion", at, 1.1)
	Sound.Play("HeavyHit", at, 0.8)
	shake(at, 0.8, 100)
	if ctx.IsOwner then
		local inside = ctx:Query(at + Vector3.new(0, 3, 0), 11)
		local air, ground = {}, {}
		for _, m in inside do
			table.insert(if Kit.Airborne(m) then air else ground, m)
		end
		ctx:Report("Posterize", air, at)
		ctx:Report("Dunk", ground, at)
	end
	ctx:Wait(0.4)
end

local function dunkHit(hit: MoveRunner.HitInfo, palette: Palette)
	if hit.Hit == "Posterize" and not hit.Blocked then
		FX.Popup(hit.Position + Vector3.new(0, 4, 0), "POSTERIZED!", palette.Accent, 2, 1.2)
	end
end

--------------------------------------------------------------------------------
-- Awakening: On Fire
--------------------------------------------------------------------------------
local function awaken(ctx: Ctx)
	local P = ctx.Palette
	Kit.Awaken(ctx, C.Awaken, 1.25, function(c: Ctx)
		local ball = c:PropPart()
		if ball then
			local trail = FX.Trail(ball, P.Primary, 1.2, 0.3, P.Core)
			c:OnCleanup(function()
				trail:Destroy()
			end)
		end
		for _ = 1, 5 do
			task.wait(0.2)
			if not c:Alive() then
				return
			end
			local feet = c.Root.Position - Vector3.new(0, 2.8, 0)
			FX.FireBurst(feet, P.Secondary, P.Accent, 10, 1.5, 0.6)
		end
	end, function(_c: Ctx, at: Vector3)
		-- Flames erupt from the feet up
		local ground = FX.GroundBelow(at)
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			FX.FireBurst(ground + Vector3.new(math.cos(a) * 4, 0, math.sin(a) * 4), P.Secondary, P.Accent, 14, 2, 0.9)
		end
		FX.Explosion(at, P, 10, { Crater = true })
		hoop(ground + Vector3.new(0, 0.3, 0), P, 14)
		FX.Popup(at + Vector3.new(0, 6, 0), "HE'S ON FIRE!", P.Secondary, 2.6, 1.6)
		Sound.Play("Fire", at, 0.7)
	end)
end

--------------------------------------------------------------------------------
-- Awakened 1: Heat Check
--------------------------------------------------------------------------------
local GRAVITY = 110

local function heatCheck(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.HeatCheck)
	local target = ctx:Nearest(80, 40)
	local elapsed = 0
	for i, t in { 0.15, 0.35, 0.55 } do
		if not ctx:Wait(t - elapsed) then
			return
		end
		elapsed = t
		local landing: Vector3
		local r = target and target:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			landing = r.Position + r.AssemblyLinearVelocity * 0.3 + Vector3.new((math.random() - 0.5) * 3, -2.5, (math.random() - 0.5) * 3)
		else
			landing = ctx:Ground(ctx:Ahead(20 + i * 8))
		end
		local origin = ctx.Root.Position + Vector3.new(0, 4, 0)
		local flight = 0.65
		local velocity = (landing - origin) / flight + Vector3.new(0, 0.5 * GRAVITY * flight, 0)
		Sound.Play("Whoosh", origin, 1.2)
		ctx:Projectile({
			Hit = "Shot",
			Origin = origin,
			Direction = velocity.Unit,
			Speed = velocity.Magnitude,
			Gravity = GRAVITY,
			Range = 200,
			Radius = 2,
			Visual = fireBall(P),
			Spin = Vector3.new(-15, 0, 0),
			OnImpact = function(position: Vector3)
				FX.Explosion(position, P, 6, { Crater = false, Debris = false })
				hoop(FX.GroundBelow(position) + Vector3.new(0, 0.3, 0), P, 6)
				Sound.Play("Explosion", position, 1.5)
				if ctx.IsOwner then
					ctx:Sphere("Shot", position, 7)
				end
			end,
		})
	end
	ctx:Wait(0.25)
end

--------------------------------------------------------------------------------
-- Awakened 2: Fast Break
--------------------------------------------------------------------------------
local function fastBreak(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.FastBreak)
	ctx:Forward(72, 0.48)
	Kit.Afterimages(ctx, P.Primary, 0.48, 0.06, 0.25)
	if ctx.IsOwner then
		CameraFX.SpeedLines(0.5, P.Secondary)
	end
	Sound.Play("Fire", ctx.Root.Position, 1.2)
	local start = os.clock()
	while os.clock() - start < 0.5 and ctx:Alive() do
		local feet = ctx.Root.Position - Vector3.new(0, 2.7, 0)
		FX.FireBurst(feet, P.Secondary, P.Accent, 5, 1.6, 0.9)
		Kit.Front(ctx, "Burn", 1, Vector3.new(7, 6, 7))
		task.wait(0.04)
	end
	ctx:Wait(0.1)
end

--------------------------------------------------------------------------------
-- Awakened 3: Crossover Combo
--------------------------------------------------------------------------------
local function crossoverCombo(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.CrossoverCombo)
	ctx:Forward(14, 0.15)
	local elapsed = 0
	for i = 0, 4 do
		local t = 0.1 + i * 0.12
		if not ctx:Wait(t - elapsed) then
			return
		end
		elapsed = t
		local at = (Kit.Frame(ctx) * CFrame.new((i % 2 == 0 and 0.8 or -0.8), 0.4, -3)).Position
		FX.FireBurst(at, P.Secondary, P.Accent, 6, 0.9, 0.4)
		FX.Slash(Kit.Frame(ctx) * CFrame.new(0, 0.3, -1) * CFrame.Angles(0, 0, (i % 2 == 0 and 0.4 or -0.4)), P.Primary, { Radius = 3, Arc = 100, Width = 0.7, Duration = 0.12, Reverse = i % 2 == 1, Core = P.Core })
		Sound.Play("Whoosh", at, 1.3)
		ctx:Forward(10, 0.06)
		Kit.Front(ctx, "Flurry", 3.2, Vector3.new(6.5, 6, 6.5))
	end
	if not ctx:Wait(0.8 - elapsed) then
		return
	end
	local frame = Kit.Frame(ctx)
	local at = (frame * CFrame.new(0, 0.5, -3)).Position
	FX.Flash(at, P.Core, 7, 0.15)
	FX.Emit(at, { Texture = FX.Textures.Fire, Color = P.Secondary, Color2 = P.Accent, Count = 40, Speed = NumberRange.new(40, 70), Spread = Vector2.new(25, 25), Size = FX.Seq(2, 0), Lifetime = NumberRange.new(0.25, 0.45) })
	FX.Ring(CFrame.lookAt(at, at + frame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 1, 8, 0.3, 0.6, 18)
	Sound.Play("Explosion", at, 1.6)
	Kit.Front(ctx, "Finish", 3.5, Vector3.new(7, 6.5, 8))
	ctx:Wait(0.2)
end

--------------------------------------------------------------------------------
-- Awakened 4: Supernova Dunk
--------------------------------------------------------------------------------
local function supernova(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	ctx:Play(C.Supernova)
	local frame = Kit.Frame(ctx)
	local target = ctx:Nearest(60, 50)
	local landing = ctx:Ground(ctx:Ahead(16))
	local r = target and target:FindFirstChild("HumanoidRootPart")
	if r and r:IsA("BasePart") then
		landing = ctx:Ground(r.Position)
	end
	if not ctx:Wait(0.2) then
		return
	end
	ctx:Velocity(Vector3.new(0, 125, 0), 0.25)
	FX.Explosion(ctx.Root.Position - Vector3.new(0, 2.5, 0), P, 5, { Crater = false, Debris = false })
	if ctx.IsOwner then
		CameraFX.Orbit(ctx.Root, 1.2, 160, 230, 22, -6, 60)
	end
	if not ctx:Wait(0.25) then
		return
	end
	-- Hover while the ball becomes a sun
	local hold = ctx:Velocity(Vector3.new(0, 1, 0), 0.9)
	local sun = FX.Part({ Size = Vector3.one * 2, CFrame = ctx.Root.CFrame * CFrame.new(0, 6, 0), Color = P.Secondary, Shape = Enum.PartType.Ball, Life = 1.3 })
	local shell = FX.Part({ Size = Vector3.one * 3, CFrame = sun.CFrame, Color = P.Primary, Shape = Enum.PartType.Ball, Material = Enum.Material.ForceField, Life = 1.3 })
	FX.Tween(sun, 0.9, { Size = Vector3.one * 9 })
	FX.Tween(shell, 0.9, { Size = Vector3.one * 14 })
	FX.Charge(sun, P.Accent, 0.9, 14)
	ctx:HideProp(true)
	local light = Instance.new("PointLight")
	light.Color = P.Light
	light.Brightness = 6
	light.Range = 60
	light.Parent = sun
	task.spawn(function()
		local stop = os.clock() + 0.9
		while os.clock() < stop and sun.Parent do
			local cf = ctx.Root.CFrame * CFrame.new(0, 6, 0)
			sun.CFrame = cf
			shell.CFrame = cf
			FX.FireBurst(cf.Position, P.Secondary, P.Accent, 6, 3, 0.5)
			task.wait(0.05)
		end
	end)
	Sound.Play("Fire", ctx.Root.Position, 0.5)
	if not ctx:Wait(0.9) then
		return
	end
	if hold then
		hold:Destroy()
	end
	-- Slam the sun into the court
	local from = ctx.Root.Position
	local dir = (landing - from)
	ctx:Velocity(dir.Unit * math.max(150, dir.Magnitude / 0.15), 0.15)
	sun:Destroy()
	shell:Destroy()
	FX.Beam(from, landing, P.Secondary, 6, 0.3, P.Core)
	if not ctx:Wait(0.15) then
		return
	end
	FX.Explosion(landing, P, 22, { Crater = true })
	FX.Shockwave(CFrame.new(landing + Vector3.new(0, 0.3, 0)), P.Accent, 45, 0.9, P.Core)
	hoop(landing + Vector3.new(0, 0.4, 0), P, 24)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local p = landing + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)
		FX.Emit(p, { Texture = FX.Textures.Fire, Color = P.Secondary, Color2 = P.Accent, Count = 20, Speed = NumberRange.new(30, 60), Spread = Vector2.new(10, 10), Size = FX.Seq(3, 1.5, 0), Lifetime = NumberRange.new(0.4, 0.8) })
	end
	Sound.Play("Explosion", landing, 0.6)
	Sound.Play("HeavyHit", landing, 0.6)
	shake(landing, 1.4, 220)
	ctx:Sphere("Nova", landing + Vector3.new(0, 4, 0), 22)
	ctx:Wait(0.5)
end

local scripts: { [string]: MoveScript } = {
	Basketball_M1 = { Run = m1 },
	Basketball_AnkleBreaker = { Run = ankleBreaker, OnHit = ankleHit },
	Basketball_ChestPass = { Run = chestPass },
	Basketball_AlleyOop = { Run = alleyOop },
	Basketball_SlamDunk = { Run = slamDunk, OnHit = dunkHit },
	Basketball_Awaken = { Run = awaken },
	Basketball_HeatCheck = { Run = heatCheck },
	Basketball_FastBreak = { Run = fastBreak },
	Basketball_CrossoverCombo = { Run = crossoverCombo },
	Basketball_Supernova = { Run = supernova },
}

return scripts
