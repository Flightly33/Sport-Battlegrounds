--[[
	Football move scripts. Royal purple energy, shockwaves, cracked ground, rubble.

	1  Stiff Arm (guard break)   2  Hail Mary   3  Blitz Tackle (grab + spear)   4  Touchdown Spike
	Awakening  Juggernaut: Pancake Block, Spiral Cannon, Goal Line Stand (counter), Meteor Sack
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

local C = Clips.Football

local function shake(position: Vector3, amount: number, range: number)
	local camera = workspace.CurrentCamera
	if camera then
		local d = (camera.CFrame.Position - position).Magnitude
		if d < range then
			CameraFX.Shake(amount * (1 - d / range))
		end
	end
end

-- Glowing cracks radiating across the ground.
local function cracks(center: Vector3, palette: Palette, radius: number, count: number)
	local ground = FX.GroundBelow(center)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random() * 0.3
		local length = radius * (0.6 + math.random() * 0.5)
		local mid = ground + Vector3.new(math.cos(a), 0, math.sin(a)) * length / 2
		local crack = FX.Part({
			Size = Vector3.new(0.35, 0.08, length),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.06, 0), mid + Vector3.new(math.cos(a), 0, math.sin(a)) + Vector3.new(0, 0.06, 0)),
			Color = palette.Secondary,
			Life = 3.5,
		})
		task.delay(1.5, function()
			FX.Tween(crack, 1.8, { Transparency = 1, Color = palette.Dark })
		end)
	end
end

local function slam(at: Vector3, palette: Palette, size: number)
	local ground = FX.GroundBelow(at)
	FX.Flash(ground + Vector3.new(0, 1, 0), palette.Core, size * 1.5, 0.15)
	FX.Shockwave(CFrame.new(ground + Vector3.new(0, 0.3, 0)), palette.Primary, size * 2.2, 0.55, palette.Core)
	FX.Shell(ground, palette.Secondary, size * 0.3, size * 1.4, 0.4)
	cracks(ground, palette, size * 1.8, math.floor(6 + size))
	FX.Crater(ground, size * 0.8)
	FX.Debris(ground, math.floor(8 + size), size * 3.5)
	FX.Smoke(ground, Color3.fromRGB(150, 140, 130), math.floor(10 + size), size * 0.5, 1.6, 4)
	FX.Light(ground, palette.Light, 6, size * 4, 0.4)
end

local function spiralBall(palette: Palette, scale: number): () -> Instance
	return function(): Instance
		local model = (Kit.Ball("Football", scale))() :: Model
		local core = model.PrimaryPart
		if core then
			FX.Trail(core, palette.Primary, 0.9 * scale, 0.25, palette.Core)
			local light = Instance.new("PointLight")
			light.Color = palette.Light
			light.Brightness = 2
			light.Range = 12 * scale
			light.Parent = core
		end
		return model
	end
end

--------------------------------------------------------------------------------
-- M1
--------------------------------------------------------------------------------
local M1: Kit.M1Set = {
	Hits = {
		{ Clip = C.Shiver, Limb = "LeftLowerArm" },
		{ Clip = C.ShiverR, Limb = "RightLowerArm" },
		{ Clip = C.Shove, Limb = "LeftHand" },
		{ Clip = C.ShoulderCharge, Limb = "LeftUpperArm" },
	},
	Uppercut = { Clip = C.Uppercut, Limb = "LeftLowerArm" },
	Downslam = { Clip = C.Hammer, Limb = "RightHand" },
	Size = Vector3.new(6, 6, 6),
	Swing = function(ctx: Ctx, step: number, _mirrored: boolean, position: Vector3)
		local P = ctx.Palette
		local frame = Kit.Frame(ctx)
		local big = step >= 4 or string.sub(ctx.Variant, 1, 1) == "U" or string.sub(ctx.Variant, 1, 1) == "D"
		FX.Ring(CFrame.lookAt(position, position + frame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 0.6, if big then 5 else 3, 0.2, if big then 0.6 else 0.35, 16)
		FX.Flash(position, P.Secondary, if big then 4 else 2.4, 0.12)
		if string.sub(ctx.Variant, 1, 1) == "D" then
			slam(position, P, 4)
		elseif big then
			FX.Smoke(ctx.Root.Position - Vector3.new(0, 2.6, 0), Color3.fromRGB(170, 160, 150), 6, 1.4, 0.8, 2)
		end
	end,
}

local function m1(ctx: Ctx)
	Kit.M1(ctx, M1)
end

--------------------------------------------------------------------------------
-- 1: Stiff Arm
--------------------------------------------------------------------------------
local function stiffArm(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local track = ctx:Play(C.StiffArm)
	Kit.LimbTrail(ctx, "LeftHand", P.Primary, 0.8, 0.3)
	ctx:Forward(30, 0.2)
	Sound.Play("HeavyWhoosh", ctx.Root.Position)
	if not ctx:Until(track, "Contact") then
		return
	end
	local frame = Kit.Frame(ctx)
	local palm = (frame * CFrame.new(-0.4, 0.6, -3.4)).Position
	Kit.Contact(ctx, palm, 1.8)
	FX.Flash(palm, P.Core, 4, 0.12)
	FX.Shockwave(CFrame.lookAt(palm, palm + frame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 6, 0.3, P.Core)
	FX.Ring(CFrame.lookAt(palm + frame.LookVector * 2, palm + frame.LookVector * 3) * CFrame.Angles(math.pi / 2, 0, 0), P.Secondary, 1, 4, 0.25, 0.4, 14)
	FX.Smoke(ctx.Root.Position - Vector3.new(0, 2.6, 0), Color3.fromRGB(170, 160, 150), 6, 1.4, 0.8, 2)
	Kit.Front(ctx, "Shove", 3.5, Vector3.new(6, 6, 7))
	ctx:Until(track, "End")
end

--------------------------------------------------------------------------------
-- 2: Hail Mary
--------------------------------------------------------------------------------
local function hailMary(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local throw = ctx:Play(C.HailMary)
	local hand = ctx:Limb("RightHand")
	if hand then
		FX.Charge(hand, P.Accent, 0.28, 4)
	end
	if not ctx:Until(throw, "Release") then
		return
	end
	local origin = if hand then hand.Position else ctx.Root.Position + Vector3.new(0, 2, 0)
	Kit.Contact(ctx, origin, 1)
	ctx:HideProp(true)
	local dir = (ctx.Aim + Vector3.new(0, 0.06, 0)).Unit
	FX.Flash(origin, P.Core, 3, 0.12)
	Sound.Play("HeavyWhoosh", origin, 1.2)
	local spiralTimer = 0
	ctx:Projectile({
		Hit = "Ball",
		Origin = origin,
		Direction = dir,
		Speed = 130,
		Gravity = 22,
		Range = 115,
		Radius = 1.9,
		Visual = spiralBall(P, 1),
		Spin = Vector3.new(0, 0, 30),
		OnStep = function(position: Vector3, direction: Vector3, dt: number)
			spiralTimer += dt
			if spiralTimer > 0.06 then
				spiralTimer = 0
				FX.Spiral(CFrame.lookAt(position, position - direction), P.Primary, 1.1, 6, 0.3, 2)
			end
		end,
		OnImpact = function(position: Vector3)
			FX.Flash(position, P.Core, 5, 0.15)
			FX.Shell(position, P.Primary, 1, 7, 0.35)
			FX.Sparks(position, P.Secondary, 16, 35, 0.5)
			Sound.Play("HeavyHit", position, 1.1)
		end,
	})
	ctx:Until(throw, "End")
end

--------------------------------------------------------------------------------
-- 3: Blitz Tackle
--------------------------------------------------------------------------------
local function spear(ctx: Ctx, target: Model?)
	local P = ctx.Palette
	local track = ctx:Play(C.Spear)
	ctx:Forward(40, 0.25)
	Sound.Play("Tackle", ctx.Root.Position)
	if not ctx:Until(track, "Contact") then
		return
	end
	local at = (Kit.Frame(ctx) * CFrame.new(0, -1, -3)).Position
	Kit.Contact(ctx, at + Vector3.new(0, 1, 0), 2.2)
	slam(at, P, 7)
	FX.Popup(at + Vector3.new(0, 5, 0), "SACKED!", P.Secondary, 1.8, 1)
	Sound.Play("HeavyHit", at, 0.7)
	shake(at, 0.8, 100)
	if ctx.IsOwner and target then
		ctx:Report("Spear", { target }, at)
	end
	ctx:Until(track, "End")
end

local function blitz(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local charge = ctx:Play(C.Charge)
	local frame = Kit.Frame(ctx)
	local velocity = ctx:Velocity(frame.LookVector * 58, 0.72)
	Kit.Afterimages(ctx, P.Primary, 0.7, 0.08, 0.25)
	if ctx.IsOwner then
		CameraFX.SpeedLines(0.7, P.Secondary)
	end
	Sound.Play("HeavyWhoosh", ctx.Root.Position, 0.8)
	local target: Model? = nil
	local start = os.clock()
	while os.clock() - start < 0.72 and ctx:Alive() do
		FX.Smoke(ctx.Root.Position - Vector3.new(0, 2.7, 0), Color3.fromRGB(170, 160, 150), 2, 1.2, 0.6, 1)
		if ctx.IsOwner then
			local found = ctx:Report("Grab", ctx:QueryBox(ctx.Root.CFrame * CFrame.new(0, 0, -3), Vector3.new(6, 6, 6)), ctx.Root.Position)
			if #found > 0 then
				target = found[1]
				break
			end
		elseif ctx.Data.Grabbed then
			break
		end
		task.wait()
	end
	if charge then
		charge:Stop(0.05)
	end
	if velocity then
		velocity:Destroy()
	end
	if not ctx:Alive() then
		return
	end
	if target or ctx.Data.Grabbed then
		FX.Flash(ctx.Root.Position + ctx.Root.CFrame.LookVector * 3, P.Core, 5, 0.15)
		FX.Ring(CFrame.lookAt(ctx.Root.Position, ctx.Root.Position + ctx.Root.CFrame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0) + ctx.Root.CFrame.LookVector * 3, P.Primary, 1, 6, 0.25, 0.5, 16)
		spear(ctx, target)
	end
end

local function blitzHit(hit: MoveRunner.HitInfo, _palette: Palette)
	if hit.Hit == "Grab" then
		local ctx = MoveRunner.Find(hit.Attacker, hit.Token)
		if ctx and not ctx.IsOwner then
			ctx.Data.Grabbed = true
		end
	end
end

--------------------------------------------------------------------------------
-- 4: Touchdown Spike
--------------------------------------------------------------------------------
local function spike(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local track = ctx:Play(C.Spike)
	if not ctx:Until(track, "Jump") then
		return
	end
	ctx:Velocity(Kit.Frame(ctx).LookVector * 6 + Vector3.new(0, 40, 0), 0.14)
	Kit.Dust(ctx, "LeftFoot", 1.2)
	local hand = ctx:Limb("RightHand")
	if hand then
		FX.Charge(hand, P.Accent, 0.3, 5)
	end
	if not ctx:Until(track, "Dive") then
		return
	end
	ctx:Velocity(Vector3.new(0, -80, 0), 0.08)
	if not ctx:Until(track, "Spike") then
		return
	end
	local at = ctx:Ground(ctx.Root.Position + Kit.Frame(ctx).LookVector * 1.5)
	Kit.Contact(ctx, at + Vector3.new(0, 1, 0), 2.4)
	ctx:HideProp(true)
	slam(at, P, 9)
	FX.Shockwave(CFrame.new(at + Vector3.new(0, 1.5, 0)), P.Secondary, 24, 0.7, P.Core)
	FX.Popup(at + Vector3.new(0, 6, 0), "TOUCHDOWN!", P.Accent, 2, 1.1)
	Sound.Play("Explosion", at, 1)
	Sound.Play("HeavyHit", at, 0.6)
	shake(at, 0.9, 110)
	ctx:Sphere("Shockwave", at + Vector3.new(0, 2, 0), 20)
	ctx:Until(track, "End")
end

--------------------------------------------------------------------------------
-- Awakening: Juggernaut
--------------------------------------------------------------------------------
local function awaken(ctx: Ctx)
	local P = ctx.Palette
	Kit.Awaken(ctx, C.Awaken, function(c: Ctx)
		local track = c.Tracks[#c.Tracks]
		if not c:Until(track, "Fists") then
			return
		end
		-- Fists slam together
		local chest = c.Root.Position + c.Root.CFrame.LookVector * 1.5 + Vector3.new(0, 1, 0)
		FX.Flash(chest, P.Core, 5, 0.15)
		FX.Shell(chest, P.Primary, 1, 8, 0.3)
		Sound.Play("HeavyHit", chest, 0.6)
	end, function(_c: Ctx, at: Vector3)
		slam(at, P, 12)
		FX.Explosion(at, P, 10, { Fire = false, Crater = false })
		FX.Smoke(at, P.Dark, 30, 4, 2.2, 6)
		FX.Popup(at + Vector3.new(0, 7, 0), "JUGGERNAUT", P.Secondary, 2.4, 1.5)
	end)
end

--------------------------------------------------------------------------------
-- Awakened 1: Pancake Block
--------------------------------------------------------------------------------
local function pancake(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local track = ctx:Play(C.Pancake)
	if not ctx:Until(track, "Contact") then
		return
	end
	local frame = Kit.Frame(ctx)
	Kit.Contact(ctx, (frame * CFrame.new(0, 0.5, -3)).Position, 2.4)
	Sound.Play("Explosion", ctx.Root.Position, 1.5)
	for i = 1, 3 do
		local p = (frame * CFrame.new(0, 0.5, -2 - i * 3.2)).Position
		task.delay(i * 0.04, function()
			FX.Shockwave(CFrame.lookAt(p, p + frame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0), if i == 2 then P.Secondary else P.Primary, 4 + i * 2, 0.35, P.Core)
		end)
	end
	FX.Smoke((frame * CFrame.new(0, -2.6, -6)).Position, Color3.fromRGB(170, 160, 150), 14, 2.5, 1, 2)
	FX.Debris((frame * CFrame.new(0, 0, -5)).Position, 8, 30)
	if ctx.IsOwner then
		CameraFX.Shake(0.45)
	end
	ctx:Hitbox("Blast", frame * CFrame.new(0, 0, -7), Vector3.new(10, 7, 14))
	ctx:Until(track, "End")
end

--------------------------------------------------------------------------------
-- Awakened 2: Spiral Cannon
--------------------------------------------------------------------------------
local function cannon(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local throw = ctx:Play(C.Cannon)
	local hand = ctx:Limb("RightHand")
	if hand then
		FX.Charge(hand, P.Accent, 0.36, 7)
	end
	if not ctx:Until(throw, "Release") then
		return
	end
	local origin = (if hand then hand.Position else ctx.Root.Position) + ctx.Aim * 2
	Kit.Contact(ctx, origin, 2.2)
	ctx:HideProp(true)
	FX.Flash(origin, P.Core, 7, 0.15)
	FX.Shockwave(CFrame.lookAt(origin, origin + ctx.Aim) * CFrame.Angles(math.pi / 2, 0, 0), P.Primary, 7, 0.35, P.Core)
	Sound.Play("Explosion", origin, 1.8)
	if ctx.IsOwner then
		CameraFX.Shake(0.4)
	end
	local timer = 0
	ctx:Projectile({
		Hit = "Drill",
		Origin = origin,
		Direction = ctx.Aim,
		Speed = 115,
		Range = 110,
		Radius = 4,
		Pierce = true,
		Visual = spiralBall(P, 3),
		Spin = Vector3.new(0, 0, 40),
		OnStep = function(position: Vector3, direction: Vector3, dt: number)
			timer += dt
			if timer > 0.04 then
				timer = 0
				FX.Spiral(CFrame.lookAt(position, position - direction), P.Primary, 3.2, 10, 0.35, 3)
				local ground = FX.GroundBelow(position)
				if position.Y - ground.Y < 6 then
					FX.Smoke(ground, Color3.fromRGB(160, 150, 140), 2, 1.6, 0.7, 2)
				end
			end
		end,
		OnImpact = function(position: Vector3)
			FX.Explosion(position, P, 8, { Fire = false, Crater = true })
			Sound.Play("Explosion", position, 1.2)
		end,
	})
	ctx:Until(throw, "End")
end

--------------------------------------------------------------------------------
-- Awakened 3: Goal Line Stand
--------------------------------------------------------------------------------
local function goalLine(ctx: Ctx)
	local P = ctx.Palette
	local brace = ctx:Play(C.Brace)
	local ground = FX.GroundBelow(ctx.Root.Position)
	FX.Ring(CFrame.new(ground + Vector3.new(0, 0.2, 0)), P.Primary, 1, 6, 0.4, 0.5)
	FX.Shell(ctx.Root.Position, P.Primary, 3, 4, 0.85)
	Sound.Play("Block", ctx.Root.Position, 0.6)
	local countered = false
	ctx.Counter = function()
		countered = true
		local attacker = ctx.Data.CounterTarget :: Model?
		if brace then
			brace:Stop(0.05)
		end
		local r = attacker and attacker:FindFirstChild("HumanoidRootPart")
		if ctx.IsOwner and r and r:IsA("BasePart") then
			local front = r.Position + r.CFrame.LookVector * 3
			ctx:Teleport(CFrame.lookAt(Vector3.new(front.X, ctx.Root.Position.Y, front.Z), Vector3.new(r.Position.X, ctx.Root.Position.Y, r.Position.Z)))
			ctx.Aim = (r.Position - front).Unit
		end
		FX.Flash(ctx.Root.Position, P.Core, 8, 0.15)
		FX.Afterimage(ctx.Character, P.Secondary, 0.3)
		local charge = ctx:Play(C.ShoulderCharge)
		ctx:Until(charge, "Contact")
		local at = ctx.Root.Position + ctx.Root.CFrame.LookVector * 3
		Kit.Contact(ctx, at, 2.4)
		slam(at, P, 7)
		Sound.Play("Tackle", at)
		if ctx.IsOwner and attacker then
			ctx:Report("Counter", { attacker }, at)
		end
	end
	local start = os.clock()
	while os.clock() - start < 0.85 and ctx:Alive() and not countered do
		task.wait(0.05)
	end
	if not countered and brace then
		brace:Stop()
	end
	ctx:Wait(if countered then 0.5 else 0.05)
end

--------------------------------------------------------------------------------
-- Awakened 4: Meteor Sack
--------------------------------------------------------------------------------
local function meteorSack(ctx: Ctx)
	local P = ctx.Palette
	ctx:Face()
	local track = ctx:Play(C.MeteorSack)
	local frame = Kit.Frame(ctx)
	local velocity = ctx:Velocity(frame.LookVector * 70, 0.36)
	Kit.Afterimages(ctx, P.Primary, 0.36, 0.06, 0.25)
	local target: Model? = nil
	local start = os.clock()
	while os.clock() - start < 0.36 and ctx:Alive() do
		if ctx.IsOwner then
			local found = ctx:Report("Grab", ctx:QueryBox(ctx.Root.CFrame * CFrame.new(0, 0, -3), Vector3.new(7, 7, 7)), ctx.Root.Position)
			if #found > 0 then
				target = found[1]
				break
			end
		end
		task.wait()
	end
	if velocity then
		velocity:Destroy()
	end
	if not ctx:Alive() then
		return
	end
	if ctx.IsOwner and not target then
		return -- whiffed
	end
	-- The grab can connect early: jump the animation to the lift so pose and motion stay together
	if track then
		track.Time = math.max(track.Time, C.MeteorSack.Marks.Grab)
	end
	-- Rocket into the sky with them
	ctx:Velocity(Vector3.new(0, 140, 0), 0.32)
	slam(ctx.Root.Position - Vector3.new(0, 2.6, 0), P, 7)
	if ctx.IsOwner then
		CameraFX.Orbit(ctx.Root, 1.25, 30, 120, 26, -12, 60)
	end
	if not ctx:Until(track, "Hover") then
		return
	end
	local marks = C.MeteorSack.Marks
	local hold = ctx:Velocity(Vector3.new(0, 2, 0), marks.Dive - marks.Hover + 0.1)
	FX.Shell(ctx.Root.Position, P.Primary, 3, 12, 0.6)
	if not ctx:Until(track, "Dive") then
		return
	end
	if hold then
		hold:Destroy()
	end
	-- Meteor
	local landing = ctx:Ground(ctx.Root.Position + frame.LookVector * 6)
	ctx:Velocity((landing - ctx.Root.Position).Unit * 220, 0.2)
	task.spawn(function()
		for _ = 1, 6 do
			FX.FireBurst(ctx.Root.Position, P.Secondary, P.Primary, 14, 3, 0.4)
			FX.Spiral(CFrame.lookAt(ctx.Root.Position, ctx.Root.Position + Vector3.new(0, 1, 0)), P.Primary, 3, 14, 0.3, 3)
			task.wait(0.03)
		end
	end)
	if not ctx:Until(track, "Slam") then
		return
	end
	local at = landing
	Kit.Climax(ctx, at)
	slam(at, P, 16)
	FX.Explosion(at, P, 18, { Fire = true, Crater = true })
	FX.Shockwave(CFrame.new(at + Vector3.new(0, 0.5, 0)), P.Accent, 40, 0.9, P.Core)
	Sound.Play("Explosion", at, 0.6)
	Sound.Play("HeavyHit", at, 0.5)
	shake(at, 1.4, 220)
	if ctx.IsOwner then
		if target then
			ctx:Report("Impact", { target }, at)
		end
		ctx:Report("Quake", Kit.Without(ctx:Query(at + Vector3.new(0, 3, 0), 20), target), at)
	end
	ctx:Until(track, "End")
end

local scripts: { [string]: MoveScript } = {
	Football_M1 = { Run = m1 },
	Football_StiffArm = { Run = stiffArm },
	Football_HailMary = { Run = hailMary },
	Football_BlitzTackle = { Run = blitz, OnHit = blitzHit },
	Football_TouchdownSpike = { Run = spike },
	Football_Awaken = { Run = awaken },
	Football_PancakeBlock = { Run = pancake },
	Football_SpiralCannon = { Run = cannon },
	Football_GoalLineStand = { Run = goalLine },
	Football_MeteorSack = { Run = meteorSack },
}

return scripts
