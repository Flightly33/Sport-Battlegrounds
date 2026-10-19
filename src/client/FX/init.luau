--[[
	FX: the visual-effects toolkit every move is built from. Everything is drawn locally by each client
	(nothing here replicates) and cleans itself up.

	Built from parts, beams and particles only, so it works without uploads. When a matching asset from
	the Blender pack is set in Shared/AssetIds, the primitive uses it instead (rings, slashes, flipbooks).

	Look: anime / battlegrounds - white-hot cores, saturated colour, hard edges, quick timing. Every
	character passes its own Palette (Shared/Characters) so their effects never look alike.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared.AssetIds)
local Characters = require(Shared.Characters)

type Palette = Characters.Palette

local FX = {}

FX.Textures = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	FireSparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
}

local folder: Folder

function FX.Folder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local existing = workspace:FindFirstChild("FX")
	if existing and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = "FX"
	f.Parent = workspace
	folder = f
	return f
end

--------------------------------------------------------------------------------
-- Basics
--------------------------------------------------------------------------------
export type PartOptions = {
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Transparency: number?,
	Shape: Enum.PartType?,
	Life: number?, -- destroy after this many seconds
}

function FX.Part(o: PartOptions): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = o.Size
	p.CFrame = o.CFrame
	p.Color = o.Color
	p.Material = o.Material or Enum.Material.Neon
	p.Transparency = o.Transparency or 0
	if o.Shape then
		p.Shape = o.Shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = FX.Folder()
	if o.Life then
		Debris:AddItem(p, o.Life)
	end
	return p
end

function FX.Tween(instance: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end
local tween = FX.Tween

-- An attachment at a world position (parented to Terrain so it needs no part).
function FX.Point(position: Vector3, life: number?): Attachment
	local a = Instance.new("Attachment")
	a.WorldPosition = position
	a.Parent = workspace.Terrain
	Debris:AddItem(a, life or 4)
	return a
end

local function numberSeq(...: number): NumberSequence
	local values = { ... }
	if #values == 1 then
		return NumberSequence.new(values[1])
	end
	local points = {}
	for i, v in values do
		table.insert(points, NumberSequenceKeypoint.new((i - 1) / (#values - 1), v))
	end
	return NumberSequence.new(points)
end
FX.Seq = numberSeq

local function colorSeq(a: Color3, b: Color3?): ColorSequence
	return if b then ColorSequence.new(a, b) else ColorSequence.new(a)
end

export type EmitOptions = {
	Texture: string?,
	Color: Color3,
	Color2: Color3?,
	Count: number,
	Speed: NumberRange?,
	Size: NumberSequence?,
	Transparency: NumberSequence?,
	Lifetime: NumberRange?,
	Spread: Vector2?,
	Acceleration: Vector3?,
	Drag: number?,
	LightEmission: number?,
	Rotation: NumberRange?,
	RotSpeed: NumberRange?,
	Orientation: Enum.ParticleOrientation?,
	ZOffset: number?,
	Flipbook: Enum.ParticleFlipbookLayout?,
}

-- One burst of particles from a point.
function FX.Emit(position: Vector3, o: EmitOptions): ParticleEmitter
	local attachment = FX.Point(position, ((o.Lifetime and o.Lifetime.Max) or 1) + 0.5)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.Texture or FX.Textures.Spark
	e.Color = colorSeq(o.Color, o.Color2)
	e.LightEmission = o.LightEmission or 1
	e.LightInfluence = 0
	e.Size = o.Size or numberSeq(1, 0)
	e.Transparency = o.Transparency or numberSeq(0, 1)
	e.Lifetime = o.Lifetime or NumberRange.new(0.3, 0.6)
	e.Speed = o.Speed or NumberRange.new(20, 40)
	e.SpreadAngle = o.Spread or Vector2.new(180, 180)
	e.Acceleration = o.Acceleration or Vector3.zero
	e.Drag = o.Drag or 0
	e.Rotation = o.Rotation or NumberRange.new(0, 360)
	e.RotSpeed = o.RotSpeed or NumberRange.new(-90, 90)
	e.Orientation = o.Orientation or Enum.ParticleOrientation.FacingCamera
	e.ZOffset = o.ZOffset or 0
	if o.Flipbook then
		e.FlipbookLayout = o.Flipbook
		e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	e.Rate = 0
	e.Enabled = false
	e.Parent = attachment
	e:Emit(o.Count)
	return e
end

--------------------------------------------------------------------------------
-- Shapes
--------------------------------------------------------------------------------
-- A bright ball that blows up and fades: the core of every impact.
function FX.Flash(position: Vector3, color: Color3, size: number, duration: number?)
	local d = duration or 0.18
	local p = FX.Part({ Size = Vector3.one * size * 0.25, CFrame = CFrame.new(position), Color = color, Shape = Enum.PartType.Ball, Life = d + 0.05 })
	tween(p, d, { Size = Vector3.one * size, Transparency = 1 }, Enum.EasingStyle.Quart)
end

-- An energy shell (force field material) growing from r0 to r1.
function FX.Shell(position: Vector3, color: Color3, r0: number, r1: number, duration: number, material: Enum.Material?)
	local p = FX.Part({
		Size = Vector3.one * r0 * 2,
		CFrame = CFrame.new(position),
		Color = color,
		Shape = Enum.PartType.Ball,
		Material = material or Enum.Material.ForceField,
		Life = duration + 0.05,
	})
	tween(p, duration, { Size = Vector3.one * r1 * 2, Transparency = 1 }, Enum.EasingStyle.Quart)
end

local function ringMesh(): string?
	return AssetIds.Resolve(AssetIds.Meshes.Ring)
end

-- A part showing one of the Blender pack's meshes (native size 1 stud; scale is in studs).
local function meshPart(meshId: string, cf: CFrame, color: Color3, scale: Vector3, life: number, transparency: number?): (Part, SpecialMesh)
	local p = FX.Part({ Size = Vector3.one, CFrame = cf, Color = color, Transparency = transparency, Life = life })
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.FileMesh
	m.MeshId = meshId
	m.Scale = scale
	m.Parent = p
	return p, m
end

-- A crisp expanding ring lying in cf's XZ plane, built from short neon segments (or the ring mesh).
function FX.Ring(cf: CFrame, color: Color3, r0: number, r1: number, duration: number, width: number?, segments: number?)
	local w = width or 0.8
	local mesh = ringMesh()
	if mesh then
		local p = FX.Part({ Size = Vector3.one, CFrame = cf, Color = color, Life = duration + 0.05 })
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.FileMesh
		m.MeshId = mesh
		m.Scale = Vector3.new(r0 * 2, w, r0 * 2)
		m.Parent = p
		tween(m, duration, { Scale = Vector3.new(r1 * 2, w * 0.3, r1 * 2) }, Enum.EasingStyle.Quart)
		tween(p, duration, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		return
	end
	local n = segments or 20
	local parts: { BasePart } = {}
	for i = 1, n do
		table.insert(parts, FX.Part({ Size = Vector3.new(1, w * 0.5, w), CFrame = cf, Color = color, Life = duration + 0.1 }))
	end
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		local e = 1 - (1 - t) ^ 3
		local r = r0 + (r1 - r0) * e
		local seg = 2 * r * math.sin(math.pi / n) * 1.08
		local thin = 1 - t * 0.7
		local cframes = table.create(n)
		for i, p in parts do
			local a = (i / n) * math.pi * 2
			cframes[i] = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r)
			p.Size = Vector3.new(seg, w * 0.5 * thin, w * thin)
			p.Transparency = t * t
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		if t >= 1 then
			connection:Disconnect()
		end
	end)
end

-- A flat shockwave: a force-field disc (soft) plus a crisp ring on top.
function FX.Shockwave(cf: CFrame, color: Color3, radius: number, duration: number?, core: Color3?)
	local d = duration or 0.45
	local disc = FX.Part({
		Size = Vector3.new(1.2, 2, 2),
		CFrame = cf * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = Enum.Material.ForceField,
		Shape = Enum.PartType.Cylinder,
		Life = d + 0.05,
	})
	tween(disc, d, { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 }, Enum.EasingStyle.Quart)
	FX.Ring(cf, core or color, radius * 0.15, radius, d * 0.8, math.clamp(radius * 0.08, 0.4, 2.2))
	local texture = AssetIds.Resolve(AssetIds.Textures.Shockwave)
	if texture then
		-- One particle lying flat (VelocityPerpendicular + upward emission), growing to the radius
		FX.Emit(cf.Position, {
			Texture = texture,
			Color = core or color,
			Count = 1,
			Speed = NumberRange.new(0.01),
			Spread = Vector2.zero,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			Size = numberSeq(radius * 0.2, radius * 2.2),
			Transparency = numberSeq(0, 1),
			Lifetime = NumberRange.new(d),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(0),
		})
	end
end

-- Anime impact lines: thin streaks bursting out from a point, facing the camera.
function FX.ImpactLines(position: Vector3, color: Color3, count: number, length: number, duration: number?)
	local d = duration or 0.18
	local camera = workspace.CurrentCamera
	local look = if camera then (position - camera.CFrame.Position).Unit else Vector3.new(0, 0, -1)
	local basis = CFrame.lookAt(position, position + look)
	for _ = 1, count do
		local a = math.random() * math.pi * 2
		local dir = (basis.RightVector * math.cos(a) + basis.UpVector * math.sin(a))
		local len = length * (0.6 + math.random() * 0.8)
		local startOffset = length * 0.15
		local p = FX.Part({
			Size = Vector3.new(0.12, 0.12, len * 0.2),
			CFrame = CFrame.lookAt(position + dir * startOffset, position + dir * (startOffset + 1)),
			Color = color,
			Life = d + 0.05,
		})
		local mid = position + dir * (startOffset + len * 0.6)
		tween(p, d, { Size = Vector3.new(0.05, 0.05, len), CFrame = CFrame.lookAt(mid, mid + dir), Transparency = 1 }, Enum.EasingStyle.Quart)
	end
end

-- Sparks: glitter particles plus a few streaks.
function FX.Sparks(position: Vector3, color: Color3, count: number, speed: number?, size: number?)
	local s = speed or 40
	FX.Emit(position, {
		Texture = AssetIds.Resolve(AssetIds.Textures.Spark),
		Color = color,
		Count = count,
		Speed = NumberRange.new(s * 0.5, s),
		Size = numberSeq(size or 0.6, 0),
		Lifetime = NumberRange.new(0.2, 0.45),
		Drag = 4,
		Acceleration = Vector3.new(0, -30, 0),
	})
end

function FX.Smoke(position: Vector3, color: Color3, count: number, size: number, lifetime: number?, rise: number?)
	local smokeTexture = AssetIds.Resolve(AssetIds.Textures.Smoke)
	FX.Emit(position, {
		Texture = smokeTexture or FX.Textures.Smoke,
		Flipbook = if smokeTexture then Enum.ParticleFlipbookLayout.Grid4x4 else nil,
		Color = color,
		Count = count,
		LightEmission = 0,
		Speed = NumberRange.new(size * 0.5, size * 1.6),
		Size = numberSeq(size * 0.6, size * 1.6, size * 2.2),
		Transparency = numberSeq(0.25, 0.55, 1),
		Lifetime = NumberRange.new(0.8, (lifetime or 1.6)),
		Drag = 3,
		Acceleration = Vector3.new(0, rise or 6, 0),
		RotSpeed = NumberRange.new(-40, 40),
	})
end

function FX.FireBurst(position: Vector3, color: Color3, color2: Color3, count: number, size: number, lifetime: number?)
	FX.Emit(position, {
		Texture = FX.Textures.Fire,
		Color = color,
		Color2 = color2,
		Count = count,
		Speed = NumberRange.new(size * 1.5, size * 4),
		Size = numberSeq(size, size * 1.4, 0),
		Transparency = numberSeq(0, 0.3, 1),
		Lifetime = NumberRange.new(0.35, lifetime or 0.8),
		Drag = 3,
		Acceleration = Vector3.new(0, size * 6, 0),
	})
end

function FX.Light(position: Vector3, color: Color3, brightness: number, range: number, duration: number)
	local a = FX.Point(position, duration + 0.1)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = math.min(range, 60)
	light.Shadows = false
	light.Parent = a
	tween(light, duration, { Brightness = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

--------------------------------------------------------------------------------
-- Lightning
--------------------------------------------------------------------------------
local function boltPoints(from: Vector3, to: Vector3, jag: number, depth: number): { Vector3 }
	local points = { from, to }
	local offset = jag
	local dir = (to - from)
	local up = if math.abs(dir.Unit.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local side = dir:Cross(up).Unit
	local other = dir:Cross(side).Unit
	for _ = 1, depth do
		local refined = { points[1] }
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local mid = (a + b) / 2 + side * (math.random() * 2 - 1) * offset + other * (math.random() * 2 - 1) * offset
			table.insert(refined, mid)
			table.insert(refined, b)
		end
		points = refined
		offset *= 0.55
	end
	return points
end

export type LightningOptions = {
	Thickness: number?,
	Jag: number?, -- how far the bolt wanders (studs)
	Detail: number?, -- subdivision levels (3 = 9 segments)
	Duration: number?,
	Flickers: number?, -- times the shape re-rolls while visible
	Branches: number?,
	Core: Color3?,
}

-- A jagged lightning bolt between two points (white-hot core inside a coloured glow).
function FX.Lightning(from: Vector3, to: Vector3, color: Color3, options: LightningOptions?)
	local o: LightningOptions = options or {}
	local thickness = o.Thickness or 0.5
	local length = (to - from).Magnitude
	local jag = o.Jag or math.clamp(length * 0.14, 0.6, 14)
	local detail = o.Detail or (if length > 40 then 4 else 3)
	local duration = o.Duration or 0.22
	local flickers = o.Flickers or 2
	local core = o.Core or Color3.new(1, 1, 1)

	local segmentCount = 2 ^ detail
	local outer: { BasePart } = {}
	local inner: { BasePart } = {}
	for _ = 1, segmentCount do
		table.insert(outer, FX.Part({ Size = Vector3.one * thickness, CFrame = CFrame.new(from), Color = color, Transparency = 0.15, Life = duration + 0.1 }))
		table.insert(inner, FX.Part({ Size = Vector3.one * thickness * 0.4, CFrame = CFrame.new(from), Color = core, Life = duration + 0.1 }))
	end
	local function layout()
		local points = boltPoints(from, to, jag, detail)
		local cfO, cfI = table.create(segmentCount), table.create(segmentCount)
		for i = 1, segmentCount do
			local a, b = points[i], points[i + 1]
			local len = (b - a).Magnitude
			local cf = CFrame.lookAt((a + b) / 2, b)
			-- Taper towards the end of the bolt
			local taper = 1 - (i / segmentCount) * 0.45
			outer[i].Size = Vector3.new(thickness * taper, thickness * taper, len + thickness * 0.5)
			inner[i].Size = Vector3.new(thickness * 0.4 * taper, thickness * 0.4 * taper, len + thickness * 0.2)
			cfO[i] = cf
			cfI[i] = cf
		end
		workspace:BulkMoveTo(outer, cfO, Enum.BulkMoveMode.FireCFrameChanged)
		workspace:BulkMoveTo(inner, cfI, Enum.BulkMoveMode.FireCFrameChanged)
		return points
	end
	local points = layout()
	-- Branches
	for _ = 1, o.Branches or (if length > 15 then 2 else 0) do
		local i = math.random(2, math.max(2, #points - 2))
		local start = points[i]
		local dir = ((to - from).Unit + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6).Unit
		FX.Lightning(start, start + dir * length * (0.15 + math.random() * 0.2), color, {
			Thickness = thickness * 0.5,
			Detail = 2,
			Duration = duration * 0.8,
			Flickers = 1,
			Branches = 0,
			Core = core,
		})
	end
	task.spawn(function()
		local step = duration / (flickers + 1)
		for _ = 1, flickers do
			task.wait(step * 0.6)
			layout()
		end
		local fade = TweenInfo.new(step, Enum.EasingStyle.Quad)
		for i = 1, segmentCount do
			TweenService:Create(outer[i], fade, { Transparency = 1 }):Play()
			TweenService:Create(inner[i], fade, { Transparency = 1 }):Play()
		end
	end)
end

-- Little arcs crackling around a part (charged limbs, balls). Runs for `duration`.
function FX.Crackle(part: BasePart, color: Color3, duration: number, radius: number?, rate: number?)
	local r = radius or 1.5
	local interval = 1 / (rate or 14)
	local flipbook = AssetIds.Resolve(AssetIds.Textures.Lightning)
	if flipbook then
		local stopAt = os.clock() + duration
		task.spawn(function()
			while os.clock() < stopAt and part.Parent do
				FX.Emit(part.Position, {
					Texture = flipbook,
					Flipbook = Enum.ParticleFlipbookLayout.Grid4x4,
					Color = color,
					Count = 1,
					Speed = NumberRange.new(0),
					Size = numberSeq(r * 1.6, r * 1.9),
					Transparency = numberSeq(0, 0.2, 1),
					Lifetime = NumberRange.new(0.12, 0.2),
					RotSpeed = NumberRange.new(0),
				})
				task.wait(interval * 2)
			end
		end)
	end
	task.spawn(function()
		local stop = os.clock() + duration
		while os.clock() < stop and part.Parent do
			local center = part.Position
			local a = center + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit * r * (0.3 + math.random() * 0.5)
			local b = center + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit * r
			FX.Lightning(a, b, color, { Thickness = 0.14, Detail = 2, Duration = 0.09, Flickers = 1, Branches = 0 })
			task.wait(interval)
		end
	end)
end

--------------------------------------------------------------------------------
-- Beams, slashes, spirals, trails
--------------------------------------------------------------------------------
-- A straight energy beam that blasts on and thins out.
function FX.Beam(from: Vector3, to: Vector3, color: Color3, width: number, duration: number, core: Color3?)
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt((from + to) / 2, to)
	local outer = FX.Part({ Size = Vector3.new(width, width, len), CFrame = cf, Color = color, Transparency = 0.2, Life = duration + 0.05 })
	local glow = FX.Part({ Size = Vector3.new(width * 2.2, width * 2.2, len), CFrame = cf, Color = color, Material = Enum.Material.ForceField, Life = duration + 0.05 })
	local inner = FX.Part({ Size = Vector3.new(width * 0.45, width * 0.45, len), CFrame = cf, Color = core or Color3.new(1, 1, 1), Life = duration + 0.05 })
	tween(outer, duration, { Size = Vector3.new(0, 0, len), Transparency = 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	tween(glow, duration, { Size = Vector3.new(width * 3.5, width * 3.5, len), Transparency = 1 })
	tween(inner, duration * 0.8, { Size = Vector3.new(0, 0, len) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
end

export type SlashOptions = {
	Radius: number,
	Arc: number?, -- degrees
	Width: number?,
	Duration: number?,
	Reverse: boolean?, -- sweep the other way
	Core: Color3?,
}

-- A crescent slash arc in cf's XZ plane, centred on cf's -Z (forward). Sweeps in, then fades.
function FX.Slash(cf: CFrame, color: Color3, options: SlashOptions)
	local radius = options.Radius
	local arc = math.rad(options.Arc or 150)
	local width = options.Width or radius * 0.18
	local duration = options.Duration or 0.25
	local core = options.Core or Color3.new(1, 1, 1)
	local n = math.clamp(math.floor(math.deg(arc) / 8), 8, 26)
	local outer: { BasePart } = {}
	local inner: { BasePart } = {}
	local sweep = 0.07
	for i = 1, n do
		local t = (i - 0.5) / n
		local k = if options.Reverse then 1 - t else t
		local a = -arc / 2 + arc * k
		local profile = math.sin(math.pi * t) ^ 0.6
		local seg = 2 * radius * math.sin(arc / n / 2) * 1.15
		local placement = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
		local o = FX.Part({ Size = Vector3.new(seg, 0.12, width * profile), CFrame = placement, Color = color, Transparency = 1, Life = duration + sweep + 0.1 })
		local c = FX.Part({ Size = Vector3.new(seg, 0.14, width * 0.35 * profile), CFrame = placement * CFrame.new(0, 0, width * 0.2 * profile), Color = core, Transparency = 1, Life = duration + sweep + 0.1 })
		table.insert(outer, o)
		table.insert(inner, c)
		task.delay(sweep * t, function()
			o.Transparency = 0.1
			c.Transparency = 0
			tween(o, duration, { Transparency = 1, Size = Vector3.new(seg, 0.05, width * profile * 0.4) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(c, duration * 0.7, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end
	-- Wider, softer echo of the arc
	local echo = AssetIds.Resolve(AssetIds.Meshes.Crescent)
	if echo then
		local p = FX.Part({ Size = Vector3.one, CFrame = cf * CFrame.new(0, 0, -radius * 0.5), Color = color, Transparency = 0.3, Life = duration + 0.1 })
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.FileMesh
		m.MeshId = echo
		m.Scale = Vector3.new(radius * 2, 1, radius)
		m.Parent = p
		tween(p, duration, { Transparency = 1 })
	end
end

-- Wind spiral: strands of streaks spinning around cf's forward axis (projectiles, dashes, tornados).
function FX.Spiral(cf: CFrame, color: Color3, radius: number, length: number, duration: number, strands: number?)
	local s = strands or 3
	local perStrand = 9
	local spiralMesh = AssetIds.Resolve(AssetIds.Meshes.Spiral)
	if spiralMesh then
		local p, m = meshPart(spiralMesh, cf, color, Vector3.new(radius * 2, radius * 2, length), duration + 0.1, 0.2)
		local start = os.clock()
		local spinConnection
		spinConnection = RunService.RenderStepped:Connect(function()
			local t = (os.clock() - start) / duration
			if t >= 1 or not p.Parent then
				spinConnection:Disconnect()
				return
			end
			p.CFrame = cf * CFrame.Angles(0, 0, t * math.pi * 6)
			p.Transparency = 0.2 + 0.8 * t * t
			m.Scale = Vector3.new(radius * 2, radius * 2, length) * (0.85 + 0.3 * t)
		end)
		return
	end
	local parts: { BasePart } = {}
	for _ = 1, s * perStrand do
		table.insert(parts, FX.Part({ Size = Vector3.new(0.18, 0.18, 1), CFrame = cf, Color = color, Transparency = 0.25, Life = duration + 0.1 }))
	end
	local start = os.clock()
	local spin = math.random() * math.pi * 2
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		local cframes = table.create(#parts)
		local r = radius * (0.6 + t * 0.6)
		for strand = 0, s - 1 do
			for i = 1, perStrand do
				local idx = strand * perStrand + i
				local u = i / perStrand
				local angle = spin + strand * (math.pi * 2 / s) + u * math.pi * 1.6 + t * 9
				local z = -length * u
				local p1 = cf * Vector3.new(math.cos(angle) * r, math.sin(angle) * r, z)
				local angle2 = angle + 0.35
				local p2 = cf * Vector3.new(math.cos(angle2) * r, math.sin(angle2) * r, z - length / perStrand)
				cframes[idx] = CFrame.lookAt((p1 + p2) / 2, p2)
				parts[idx].Size = Vector3.new(0.16 * (1 - t), 0.16 * (1 - t), (p2 - p1).Magnitude)
				parts[idx].Transparency = 0.25 + t * 0.75
			end
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		if t >= 1 then
			connection:Disconnect()
		end
	end)
end

-- A Trail on a moving part (limbs, balls). Returns it so the caller can disable / remove it.
function FX.Trail(part: BasePart, color: Color3, width: number, lifetime: number?, core: Color3?): Trail
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = part
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(core or color, color)
	trail.Transparency = numberSeq(0.05, 1)
	trail.Lifetime = lifetime or 0.18
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.WidthScale = numberSeq(1, 0)
	trail.Parent = part
	trail.Destroying:Connect(function()
		a0:Destroy()
		a1:Destroy()
	end)
	return trail
end

-- Ghost copies of a character, frozen where it stood (dashes, teleports).
function FX.Afterimage(character: Model, color: Color3, duration: number, material: Enum.Material?)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
			local ghost: BasePart
			if d:IsA("MeshPart") then
				local ok, clone = pcall(function()
					return d:Clone()
				end)
				if not ok or not clone then
					continue
				end
				ghost = clone
				for _, c in ghost:GetChildren() do
					c:Destroy()
				end
			else
				local block = Instance.new("Part")
				block.Size = d.Size
				if d:IsA("Part") then
					block.Shape = d.Shape
				end
				ghost = block
			end
			ghost.Anchored = true
			ghost.CanCollide = false
			ghost.CanQuery = false
			ghost.CanTouch = false
			ghost.CastShadow = false
			ghost.Massless = true
			ghost.CFrame = d.CFrame
			ghost.Color = color
			ghost.Material = material or Enum.Material.Neon
			ghost.Transparency = 0.35
			ghost.Parent = FX.Folder()
			Debris:AddItem(ghost, duration + 0.05)
			tween(ghost, duration, { Transparency = 1 })
		end
	end
end

--------------------------------------------------------------------------------
-- Ground: debris, craters
--------------------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundBelow(position: Vector3): (Vector3, Color3, Enum.Material)
	local ignore: { Instance } = { FX.Folder() }
	local fighters = workspace:FindFirstChild("Fighters")
	if fighters then
		table.insert(ignore, fighters)
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		table.insert(ignore, dummies)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(position + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), rayParams)
	if result and result.Instance:IsA("BasePart") then
		return result.Position, result.Instance.Color, result.Material
	end
	return Vector3.new(position.X, 0, position.Z), Color3.fromRGB(90, 80, 70), Enum.Material.Ground
end
FX.GroundBelow = groundBelow

local debrisPieces: { { Part: BasePart, Velocity: Vector3, Spin: CFrame, Floor: number, Life: number, Age: number } } = {}
local debrisRunning = false

local function runDebris()
	if debrisRunning then
		return
	end
	debrisRunning = true
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		local parts, cframes = {}, {}
		local i = 1
		while i <= #debrisPieces do
			local d = debrisPieces[i]
			d.Age += dt
			if d.Age >= d.Life or not d.Part.Parent then
				d.Part:Destroy()
				table.remove(debrisPieces, i)
			else
				d.Velocity += Vector3.new(0, -workspace.Gravity * 0.6 * dt, 0)
				local cf = d.Part.CFrame
				local pos = cf.Position + d.Velocity * dt
				if pos.Y < d.Floor then
					pos = Vector3.new(pos.X, d.Floor, pos.Z)
					d.Velocity = Vector3.new(d.Velocity.X * 0.6, -d.Velocity.Y * 0.3, d.Velocity.Z * 0.6)
				end
				table.insert(parts, d.Part)
				table.insert(cframes, (cf - cf.Position) * d.Spin + pos)
				if d.Life - d.Age < 0.4 then
					d.Part.Transparency = 1 - (d.Life - d.Age) / 0.4
				end
				i += 1
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
		if #debrisPieces == 0 then
			debrisRunning = false
			connection:Disconnect()
		end
	end)
end

-- Chunks of ground flying out of an impact.
function FX.Debris(position: Vector3, count: number, power: number, size: number?)
	local ground, groundColor, material = groundBelow(position)
	local s = size or 1
	for _ = 1, count do
		local dir = Vector3.new(math.random() - 0.5, 0.6 + math.random(), math.random() - 0.5).Unit
		local chunk: BasePart = FX.Part({
			Size = Vector3.new(s * (0.5 + math.random()), s * (0.4 + math.random() * 0.6), s * (0.5 + math.random())),
			CFrame = CFrame.new(ground + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Color = groundColor:Lerp(Color3.fromRGB(80, 70, 60), 0.35),
			Material = if material == Enum.Material.Grass then Enum.Material.Ground else material,
		})
		table.insert(debrisPieces, {
			Part = chunk,
			Velocity = dir * power * (0.5 + math.random() * 0.7),
			Spin = CFrame.Angles(math.random() * 0.4, math.random() * 0.4, math.random() * 0.4),
			Floor = ground.Y + chunk.Size.Y / 2,
			Life = 1.6 + math.random(),
			Age = 0,
		})
	end
	runDebris()
end

-- The battlegrounds crater: a ring of slabs tilting out of the ground around the impact, which sink
-- back after a few seconds.
function FX.Crater(position: Vector3, radius: number, count: number?)
	local ground, groundColor, material = groundBelow(position)
	local n = count or math.clamp(math.floor(radius * 1.4), 8, 22)
	local color = groundColor:Lerp(Color3.fromRGB(70, 60, 50), 0.4)
	local mat = if material == Enum.Material.Grass then Enum.Material.Ground else material
	-- Scorch in the middle
	local scorch = FX.Part({
		Size = Vector3.new(0.2, radius * 1.5, radius * 1.5),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(30, 26, 24),
		Material = Enum.Material.Slate,
		Shape = Enum.PartType.Cylinder,
		Transparency = 0.2,
		Life = 6,
	})
	task.delay(4, function()
		tween(scorch, 1.8, { Transparency = 1 })
	end)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + math.random() * 0.2
		local r = radius * (0.85 + math.random() * 0.3)
		local w = radius * 0.5 * (0.7 + math.random() * 0.5)
		local h = radius * 0.4 * (0.6 + math.random() * 0.6)
		local base = ground + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local outward = Vector3.new(math.cos(a), 0, math.sin(a))
		-- Tilt the slab outwards around its tangent
		local finalCF = CFrame.lookAt(base, base + outward) * CFrame.Angles(math.rad(-(35 + math.random() * 25)), 0, 0) * CFrame.new(0, h * 0.3, 0)
		local slab = FX.Part({
			Size = Vector3.new(w, h, w * 0.6),
			CFrame = finalCF - Vector3.new(0, h, 0),
			Color = color,
			Material = mat,
			Life = 5.5,
		})
		tween(slab, 0.12, { CFrame = finalCF }, Enum.EasingStyle.Back)
		task.delay(3.2 + math.random() * 0.6, function()
			tween(slab, 1.4, { CFrame = finalCF - Vector3.new(0, h * 1.2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end
	FX.Smoke(ground, Color3.fromRGB(150, 140, 125), math.floor(radius), radius * 0.4, 1.4, 4)
end

--------------------------------------------------------------------------------
-- Gathering energy, text popups
--------------------------------------------------------------------------------
-- Particles rushing in towards a point (charging up). Follows `part` if given.
function FX.Charge(at: BasePart | Vector3, color: Color3, duration: number, radius: number)
	local holder = FX.Part({ Size = Vector3.one * radius * 2, CFrame = CFrame.new(if typeof(at) == "Vector3" then at else at.Position), Color = color, Transparency = 1, Life = duration + 0.8, Shape = Enum.PartType.Ball })
	local e = Instance.new("ParticleEmitter")
	e.Texture = FX.Textures.Spark
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	e.Speed = NumberRange.new(radius / 0.35, radius / 0.3)
	e.Lifetime = NumberRange.new(0.3, 0.35)
	e.Size = numberSeq(0.25, 0.6)
	e.Transparency = numberSeq(1, 0, 0.2)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Rate = 120
	e.Parent = holder
	if typeof(at) ~= "Vector3" then
		local part = at
		local connection
		connection = RunService.RenderStepped:Connect(function()
			if not holder.Parent or not part.Parent then
				connection:Disconnect()
				return
			end
			holder.CFrame = CFrame.new(part.Position)
		end)
	end
	task.delay(duration, function()
		e.Enabled = false
	end)
end

-- Floating text (damage numbers, "GUARD BREAK!").
function FX.Popup(position: Vector3, text: string, color: Color3, scale: number?, duration: number?)
	local d = duration or 0.8
	local s = scale or 1
	local a = FX.Point(position, d + 0.1)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(5 * s, 1.6 * s)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.Parent = a
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label
	gui.StudsOffsetWorldSpace = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
	tween(gui, d, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 2.5, 0) }, Enum.EasingStyle.Quart)
	tween(label, d, { TextTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	tween(stroke, d, { Transparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
end

--------------------------------------------------------------------------------
-- Composites
--------------------------------------------------------------------------------
-- A standard hit: flash, impact lines, sparks, a small ring. strength 0.5 (M1) .. 3 (finisher).
function FX.Impact(position: Vector3, palette: Palette, strength: number)
	local s = strength
	FX.Flash(position, palette.Core, 2.2 * s, 0.12)
	FX.Flash(position, palette.Primary, 3.5 * s, 0.2)
	FX.ImpactLines(position, palette.Core, math.floor(6 + 4 * s), 3 + 2.5 * s, 0.16)
	FX.Sparks(position, palette.Primary, math.floor(8 + 8 * s), 30 + 15 * s, 0.5 + 0.2 * s)
	local camera = workspace.CurrentCamera
	local facing = if camera then CFrame.lookAt(position, camera.CFrame.Position) * CFrame.Angles(math.pi / 2, 0, 0) else CFrame.new(position)
	FX.Ring(facing, palette.Secondary, 0.5 * s, 3 * s, 0.22, 0.25 + 0.15 * s, 14)
	FX.Light(position, palette.Light, 3 * s, 10 + 6 * s, 0.25)
	-- Anime impact star
	local burstMesh = AssetIds.Resolve(AssetIds.Meshes.Burst)
	local starTexture = AssetIds.Resolve(AssetIds.Textures.Impact)
	if burstMesh then
		local toCamera = if camera then CFrame.lookAt(position, camera.CFrame.Position) else CFrame.new(position)
		local p, m = meshPart(burstMesh, toCamera * CFrame.Angles(0, 0, math.random() * math.pi * 2), palette.Core, Vector3.one * 1.5 * s, 0.25)
		tween(m, 0.18, { Scale = Vector3.one * 5 * s }, Enum.EasingStyle.Quart)
		tween(p, 0.2, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	elseif starTexture then
		FX.Emit(position, {
			Texture = starTexture,
			Color = palette.Core,
			Count = 1,
			Speed = NumberRange.new(0),
			Size = numberSeq(1.5 * s, 5 * s),
			Transparency = numberSeq(0, 1),
			Lifetime = NumberRange.new(0.18),
			RotSpeed = NumberRange.new(0),
		})
	end
end

export type ExplosionOptions = {
	Lightning: boolean?,
	Fire: boolean?,
	Smoke: boolean?,
	Crater: boolean?,
	Debris: boolean?,
}

-- A big explosion in a character's palette: core flash, fireballs, shockwave, smoke, debris.
function FX.Explosion(position: Vector3, palette: Palette, size: number, options: ExplosionOptions?)
	local o: ExplosionOptions = options or {}
	FX.Flash(position, palette.Core, size * 1.2, 0.15)
	FX.Shell(position, palette.Primary, size * 0.2, size * 0.9, 0.35, Enum.Material.Neon)
	FX.Shell(position, palette.Secondary, size * 0.3, size * 1.4, 0.5)
	-- Fireballs: overlapping neon balls in the palette, rising and fading
	for i = 1, 7 do
		local offset = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5) * size * 0.7
		local color = if i % 3 == 0 then palette.Accent elseif i % 3 == 1 then palette.Primary else palette.Secondary
		local ball = FX.Part({
			Size = Vector3.one * size * 0.25,
			CFrame = CFrame.new(position + offset * 0.3),
			Color = color,
			Shape = Enum.PartType.Ball,
			Life = 0.8,
		})
		tween(ball, 0.55 + math.random() * 0.2, {
			Size = Vector3.one * size * (0.5 + math.random() * 0.35),
			CFrame = CFrame.new(position + offset + Vector3.new(0, size * 0.25, 0)),
			Transparency = 1,
		}, Enum.EasingStyle.Quart)
	end
	local ground = groundBelow(position)
	FX.Shockwave(CFrame.new(Vector3.new(position.X, ground.Y + 0.2, position.Z)), palette.Primary, size * 1.8, 0.55, palette.Core)
	local flipbook = AssetIds.Resolve(AssetIds.Textures.Explosion)
	if flipbook then
		FX.Emit(position, {
			Texture = flipbook,
			Flipbook = Enum.ParticleFlipbookLayout.Grid8x8,
			Color = palette.Secondary,
			Color2 = palette.Dark,
			Count = 3,
			Speed = NumberRange.new(size * 0.3, size * 0.8),
			Size = numberSeq(size * 1.2, size * 1.8),
			Transparency = numberSeq(0, 0, 0.3),
			Lifetime = NumberRange.new(0.7, 0.9),
			RotSpeed = NumberRange.new(-30, 30),
		})
	end
	local domeMesh = AssetIds.Resolve(AssetIds.Meshes.Dome)
	if domeMesh and (position.Y - ground.Y) < size then
		local base = CFrame.new(Vector3.new(position.X, ground.Y, position.Z))
		local p, m = meshPart(domeMesh, base, palette.Primary, Vector3.one * size * 0.6, 0.6, 0.15)
		p.Material = Enum.Material.ForceField
		tween(m, 0.5, { Scale = Vector3.one * size * 2.6 }, Enum.EasingStyle.Quart)
		tween(p, 0.5, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	FX.ImpactLines(position, palette.Core, 16, size * 1.4, 0.22)
	FX.Sparks(position, palette.Accent, 40, size * 6, 0.9)
	FX.Light(position, palette.Light, 8, size * 4, 0.6)
	if o.Fire ~= false then
		FX.FireBurst(position, palette.Secondary, palette.Primary, 24, size * 0.35, 0.9)
	end
	if o.Smoke ~= false then
		FX.Smoke(position, palette.Dark:Lerp(Color3.fromRGB(70, 70, 75), 0.5), 18, size * 0.35, 2.2, 8)
	end
	if o.Lightning then
		for _ = 1, 6 do
			local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5).Unit
			FX.Lightning(position, position + dir * size * (0.8 + math.random() * 0.6), palette.Primary, { Thickness = 0.35, Duration = 0.3, Flickers = 2, Core = palette.Core })
		end
	end
	if o.Debris ~= false then
		FX.Debris(position, 10, size * 3)
	end
	if o.Crater and (position.Y - ground.Y) < size then
		FX.Crater(ground, size * 0.75)
	end
end

-- Lightning strike from the sky onto a spot.
function FX.Thunderbolt(position: Vector3, palette: Palette, size: number)
	local ground = groundBelow(position)
	local top = ground + Vector3.new((math.random() - 0.5) * 8, 140, (math.random() - 0.5) * 8)
	FX.Lightning(top, ground, palette.Primary, { Thickness = size * 0.35, Jag = size * 1.2, Detail = 4, Duration = 0.35, Flickers = 3, Branches = 3, Core = palette.Core })
	FX.Beam(top, ground, palette.Accent, size * 0.6, 0.25, palette.Core)
	local boltMesh = AssetIds.Resolve(AssetIds.Meshes.Bolt)
	if boltMesh then
		local height = (top - ground).Magnitude
		local mid = CFrame.lookAt((top + ground) / 2, ground) * CFrame.Angles(math.pi / 2, 0, 0)
		local p, m = meshPart(boltMesh, mid, palette.Core, Vector3.new(size * 2, height, size * 2), 0.35)
		tween(m, 0.3, { Scale = Vector3.new(size * 0.6, height, size * 0.6) }, Enum.EasingStyle.Quad)
		tween(p, 0.3, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	FX.Flash(ground, palette.Core, size * 2.5, 0.2)
	FX.Shockwave(CFrame.new(ground + Vector3.new(0, 0.2, 0)), palette.Primary, size * 2.2, 0.5, palette.Core)
	FX.Sparks(ground, palette.Accent, 30, size * 8, 0.8)
	FX.Light(ground, palette.Light, 10, 50, 0.4)
end

return FX
