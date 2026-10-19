--[[
	SkyFX: life above the stadium, drawn locally.
		Helicopter   circles over the pitch with a searchlight that picks out one fighter after another
		Blimps       drift across the night sky with glowing billboards advertising the Robux skins
		             (Shared/Skins), swapping to the game's own banner between ads

	Everything moves as a function of server time, so every player sees the same helicopter and the same
	blimps in the same places, with nothing to replicate.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Stadium.Layout)
local Skins = require(Shared.Skins)

local Sound = require(script.Parent.Sound)

local SkyFX = {}

local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

-- Helicopter: an oval lap over the pitch, above the roof (132 studs) and the floodlight masts (192)
local HELI_HEIGHT = 215
local HELI_RADIUS_X = Layout.BARRIER_HALF_X * 0.8
local HELI_RADIUS_Z = Layout.BARRIER_HALF_Z * 0.8
local HELI_LAP = 75 -- seconds
local ROTOR_SPEED = 20 -- radians per second
local SPOT_SHIFT = 9 -- seconds the searchlight stays on one fighter
local SPOT_FOLLOW = 1.6 -- how quickly the light catches up with whoever it is on

-- Blimps: a straight pass across the sky every few minutes, each one a little different
local BLIMP_LENGTH = 220
local BLIMP_HEIGHT = 60
local PANEL_WIDTH = 132
local PANEL_HEIGHT = 44
local FLY_RANGE = 1400 -- half the length of a pass
local SLIDE_TIME = 7 -- seconds per billboard slide

local WARM = Color3.fromRGB(255, 244, 214)

type Placed = { Part: BasePart, Offset: CFrame }

--------------------------------------------------------------------------------
-- Building blocks
--------------------------------------------------------------------------------
local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function ellipsoid(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = part(parent, name, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

--------------------------------------------------------------------------------
-- Billboard screens
--------------------------------------------------------------------------------
type Screen = {
	Back: UIGradient,
	Picture: Frame, -- holds the orb and its rings
	Stars: { Frame },
	Orb: Frame,
	OrbFill: UIGradient,
	OrbStroke: UIStroke,
	RingA: Frame,
	RingB: Frame,
	RingStrokeA: UIStroke,
	RingStrokeB: UIStroke,
	Title: TextLabel,
	Blurb: TextLabel,
	Tag: Frame,
	TagText: TextLabel,
	Slide: number,
}

local BRAND_A = Color3.fromRGB(20, 40, 110)
local BRAND_B = Color3.fromRGB(190, 80, 20)

local function label(parent: Instance, position: UDim2, size: UDim2, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = position
	l.Size = size
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.FontFace = FONT
	l.TextColor3 = color
	l.Text = ""
	l.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Transparency = 0.45
	stroke.Parent = l
	return l
end

local function roundFrame(parent: Instance, position: UDim2, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = position
	f.Size = size
	f.BorderSizePixel = 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	return f
end

-- A glowing digital billboard on one face of `panel`.
local function buildScreen(panel: BasePart, face: Enum.NormalId, rng: Random): Screen
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 9
	gui.LightInfluence = 0
	gui.Brightness = 2.4
	gui.ClipsDescendants = true
	gui.Adornee = panel
	gui.Parent = panel

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BorderSizePixel = 0
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.Parent = gui
	local backGradient = Instance.new("UIGradient")
	backGradient.Color = ColorSequence.new(BRAND_A, BRAND_B)
	backGradient.Parent = back

	local stars: { Frame } = {}
	for _ = 1, 40 do
		local star = Instance.new("Frame")
		local size = rng:NextInteger(3, 8)
		star.Size = UDim2.fromOffset(size, size)
		star.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
		star.BorderSizePixel = 0
		star.BackgroundColor3 = Color3.new(1, 1, 1)
		star.BackgroundTransparency = 0.5
		star.Parent = back
		table.insert(stars, star)
	end

	-- The product picture: an orb wrapped in two rings
	local area = Instance.new("Frame")
	area.BackgroundTransparency = 1
	area.AnchorPoint = Vector2.new(0, 0.5)
	area.Position = UDim2.fromScale(0.035, 0.5)
	area.Size = UDim2.fromScale(0.8 * PANEL_HEIGHT / PANEL_WIDTH, 0.8)
	area.Parent = back
	local orb = roundFrame(area, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.62, 0.62))
	orb.BackgroundColor3 = Color3.new(1, 1, 1)
	local orbFill = Instance.new("UIGradient")
	orbFill.Parent = orb
	local orbStroke = Instance.new("UIStroke")
	orbStroke.Thickness = 5
	orbStroke.Parent = orb
	local ringA = roundFrame(area, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 0.34))
	ringA.BackgroundTransparency = 1
	local ringStrokeA = Instance.new("UIStroke")
	ringStrokeA.Thickness = 4
	ringStrokeA.Parent = ringA
	local ringB = roundFrame(area, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.86, 0.3))
	ringB.BackgroundTransparency = 1
	local ringStrokeB = Instance.new("UIStroke")
	ringStrokeB.Thickness = 3
	ringStrokeB.Parent = ringB

	local title = label(back, UDim2.fromScale(0.34, 0.07), UDim2.fromScale(0.62, 0.44), Color3.new(1, 1, 1))
	title.Name = "Title"
	local blurb = label(back, UDim2.fromScale(0.34, 0.52), UDim2.fromScale(0.62, 0.15), Color3.fromRGB(255, 220, 90))
	local tag = Instance.new("Frame")
	tag.Position = UDim2.fromScale(0.34, 0.7)
	tag.Size = UDim2.fromScale(0.6, 0.23)
	tag.BorderSizePixel = 0
	tag.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	tag.Parent = back
	local tagCorner = Instance.new("UICorner")
	tagCorner.CornerRadius = UDim.new(0.3, 0)
	tagCorner.Parent = tag
	local tagText = label(tag, UDim2.fromScale(0.04, 0.08), UDim2.fromScale(0.92, 0.84), Color3.fromRGB(20, 14, 40))
	tagText.TextXAlignment = Enum.TextXAlignment.Center
	local tagStroke = tagText:FindFirstChildOfClass("UIStroke") :: UIStroke
	tagStroke.Transparency = 1

	return {
		Back = backGradient,
		Picture = area,
		Stars = stars,
		Orb = orb,
		OrbFill = orbFill,
		OrbStroke = orbStroke,
		RingA = ringA,
		RingB = ringB,
		RingStrokeA = ringStrokeA,
		RingStrokeB = ringStrokeB,
		Title = title,
		Blurb = blurb,
		Tag = tag,
		TagText = tagText,
		Slide = 0,
	}
end

-- Shows slide `slide` (a skin's ad, or the game's own banner after the last skin), animated at time `t`.
local function updateScreen(screen: Screen, slide: number, t: number)
	local skin = Skins.List[slide]
	if screen.Slide ~= slide then
		screen.Slide = slide
		if skin then
			local c = skin.Colors
			screen.Back.Color = ColorSequence.new(c.Deep, c.Deep:Lerp(c.Spark, 0.45))
			screen.OrbFill.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, c.Deep),
				ColorSequenceKeypoint.new(0.55, c.Glow:Lerp(c.Deep, 0.55)),
				ColorSequenceKeypoint.new(1, c.Spark),
			})
			screen.OrbStroke.Color = c.Glow
			screen.RingStrokeA.Color = c.Glow
			screen.RingStrokeB.Color = c.Spark
			screen.Title.Text = string.upper(skin.Name)
			screen.Blurb.Text = skin.Blurb
			screen.TagText.Text = if Config.Shop.GrantAllSkins then "FREE FOR A LIMITED TIME" else string.format("GAMEPASS  ·  R$ %d", skin.Price)
		else
			screen.Back.Color = ColorSequence.new(BRAND_A, BRAND_B)
			screen.Title.Text = "SPORTS BATTLEGROUNDS"
			screen.Blurb.Text = "WHO RULES THE STADIUM?"
		end
		screen.Picture.Visible = skin ~= nil
		screen.Tag.Visible = skin ~= nil
		screen.Title.Size = if skin then UDim2.fromScale(0.62, 0.44) else UDim2.fromScale(0.9, 0.44)
		screen.Blurb.Size = if skin then UDim2.fromScale(0.62, 0.15) else UDim2.fromScale(0.9, 0.15)
		screen.Title.Position = if skin then UDim2.fromScale(0.34, 0.07) else UDim2.fromScale(0.05, 0.2)
		screen.Blurb.Position = if skin then UDim2.fromScale(0.34, 0.52) else UDim2.fromScale(0.05, 0.68)
	end
	screen.Back.Rotation = (t * 14) % 360
	screen.RingA.Rotation = -28 + math.sin(t * 1.3) * 22
	screen.RingB.Rotation = 62 + math.cos(t * 1.1) * 22
	screen.OrbFill.Rotation = (t * 40) % 360
	for i, star in screen.Stars do
		star.BackgroundTransparency = 0.25 + 0.6 * (math.sin(t * 2.2 + i * 1.7) * 0.5 + 0.5)
	end
	screen.Tag.BackgroundColor3 = Color3.fromRGB(255, 200, 40):Lerp(Color3.new(1, 1, 1), (math.sin(t * 4) * 0.5 + 0.5) * 0.45)
end

--------------------------------------------------------------------------------
-- Helicopter
--------------------------------------------------------------------------------
type Helicopter = {
	Parts: { Placed }, -- rigid parts, placed relative to the body
	MainRotor: { Placed }, -- spun about the mast
	TailRotor: { Placed }, -- spun about the tail axle
	Strobe: Part,
	Lamp: Part,
	Lens: Part,
	Target: Part, -- invisible, on the ground where the searchlight lands
	Pool: Part,
	PoolCore: Part,
	PoolLight: Part,
	Spot: Vector3, -- where the light is landing now
	Goal: Vector3, -- where it is heading
	GoalAt: number, -- when Goal was last chosen
}

local function buildHelicopter(folder: Folder): Helicopter
	local model = Instance.new("Model")
	model.Name = "Helicopter"
	model.Parent = folder
	local rigid: { Placed } = {}
	local main: { Placed } = {}
	local tail: { Placed } = {}
	local function add(list: { Placed }, p: Part, offset: CFrame)
		table.insert(list, { Part = p, Offset = offset })
	end
	local hull = Color3.fromRGB(64, 70, 88)
	local dark = Color3.fromRGB(28, 30, 38)

	add(rigid, ellipsoid(model, "Body", Vector3.new(9, 8, 22), CFrame.identity, hull, Enum.Material.Metal), CFrame.identity)
	add(rigid, ellipsoid(model, "Canopy", Vector3.new(7, 5.4, 10), CFrame.new(0, 1.2, -6.2), Color3.fromRGB(120, 180, 230), Enum.Material.Glass), CFrame.new(0, 1.2, -6.2))
	add(rigid, part(model, "Boom", Vector3.new(2.2, 2.4, 20), CFrame.new(0, 0.8, 17), hull, Enum.Material.Metal), CFrame.new(0, 0.8, 17))
	add(rigid, part(model, "Fin", Vector3.new(0.5, 7, 3.6), CFrame.new(0, 4.2, 26), hull, Enum.Material.Metal), CFrame.new(0, 4.2, 26))
	add(rigid, part(model, "Mast", Vector3.new(1.4, 2, 1.4), CFrame.new(0, 5, 0), dark, Enum.Material.Metal), CFrame.new(0, 5, 0))
	for _, side in { -1, 1 } do
		add(rigid, part(model, "Skid", Vector3.new(0.6, 0.6, 15), CFrame.new(side * 3.6, -5.6, -1), dark, Enum.Material.Metal), CFrame.new(side * 3.6, -5.6, -1))
		for _, z in { -4, 3 } do
			add(rigid, part(model, "Strut", Vector3.new(0.5, 4.4, 0.5), CFrame.new(side * 3.2, -3.5, z) * CFrame.Angles(0, 0, side * 0.2), dark, Enum.Material.Metal), CFrame.new(side * 3.2, -3.5, z) * CFrame.Angles(0, 0, side * 0.2))
		end
	end
	-- Navigation lights: red left, green right, white strobe on the tail fin
	add(rigid, part(model, "NavRed", Vector3.new(0.9, 0.9, 0.9), CFrame.new(-4.4, 0, 1), Color3.fromRGB(255, 40, 40), Enum.Material.Neon, Enum.PartType.Ball), CFrame.new(-4.4, 0, 1))
	add(rigid, part(model, "NavGreen", Vector3.new(0.9, 0.9, 0.9), CFrame.new(4.4, 0, 1), Color3.fromRGB(60, 255, 90), Enum.Material.Neon, Enum.PartType.Ball), CFrame.new(4.4, 0, 1))
	local strobe = part(model, "Strobe", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 7.8, 26), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball)
	add(rigid, strobe, CFrame.new(0, 7.8, 26))

	-- Main rotor: two crossed blades under a faint blur disc
	for i = 0, 1 do
		local offset = CFrame.new(0, 6.2, 0) * CFrame.Angles(0, i * math.pi / 2, 0)
		add(main, part(model, "Blade", Vector3.new(38, 0.25, 1.8), offset, dark, Enum.Material.Metal), offset)
	end
	local blur = part(model, "RotorBlur", Vector3.new(0.1, 38, 38), CFrame.new(0, 6.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(200, 205, 220), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	blur.Transparency = 0.9
	add(rigid, blur, CFrame.new(0, 6.2, 0) * CFrame.Angles(0, 0, math.pi / 2))
	-- Tail rotor
	for i = 0, 1 do
		local offset = CFrame.new(1.4, 3, 26) * CFrame.Angles(i * math.pi / 2, 0, 0)
		add(tail, part(model, "TailBlade", Vector3.new(0.25, 7, 0.9), offset, dark, Enum.Material.Metal), offset)
	end

	-- Searchlight: a lamp under the nose that swings to wherever the light should land
	local lamp = part(model, "Lamp", Vector3.new(2.4, 2.4, 3.6), CFrame.identity, dark, Enum.Material.Metal)
	local lens = part(model, "Lens", Vector3.new(1.9, 1.9, 0.3), CFrame.identity, WARM, Enum.Material.Neon)
	local origin = Instance.new("Attachment")
	origin.Parent = lens
	local target = part(folder, "SpotTarget", Vector3.one, CFrame.identity, WARM, Enum.Material.SmoothPlastic)
	target.Transparency = 1
	local landing = Instance.new("Attachment")
	landing.Parent = target
	local beam = Instance.new("Beam")
	beam.Attachment0 = origin
	beam.Attachment1 = landing
	beam.Color = ColorSequence.new(WARM)
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 0.9) })
	beam.Width0 = 2.5
	beam.Width1 = 62
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 2
	beam.Parent = lens

	-- Where it lands: a soft pool of light on the grass, and a real light above it
	local floorY = Config.Arena.FloorY
	local pool = part(folder, "SpotPool", Vector3.new(0.15, 58, 58), CFrame.new(0, floorY + 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), WARM, Enum.Material.Neon, Enum.PartType.Cylinder)
	pool.Transparency = 0.86
	local poolCore = part(folder, "SpotCore", Vector3.new(0.1, 28, 28), CFrame.new(0, floorY + 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), WARM, Enum.Material.Neon, Enum.PartType.Cylinder)
	poolCore.Transparency = 0.8
	local poolLight = part(folder, "SpotLight", Vector3.one, CFrame.identity, WARM, Enum.Material.SmoothPlastic)
	poolLight.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 60
	light.Brightness = 2.5
	light.Shadows = false
	light.Parent = poolLight

	local rotor = Sound.Start("Helicopter", rigid[1].Part, true, 1, "SFX")
	if rotor then
		rotor.RollOffMinDistance = 60
		rotor.RollOffMaxDistance = 900
	end

	return {
		Parts = rigid,
		MainRotor = main,
		TailRotor = tail,
		Strobe = strobe,
		Lamp = lamp,
		Lens = lens,
		Target = target,
		Pool = pool,
		PoolCore = poolCore,
		PoolLight = poolLight,
		Spot = Vector3.new(0, floorY, 0),
		Goal = Vector3.new(0, floorY, 0),
		GoalAt = 0,
	}
end

-- The fighter the searchlight is on right now: the same one on every screen (chosen by server time).
local function spotlightTarget(t: number): Vector3?
	local list: { BasePart } = {}
	for _, model in CollectionService:GetTagged("Fighter") do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(list, root)
		end
	end
	if #list == 0 then
		return nil
	end
	table.sort(list, function(a, b)
		return (a.Parent :: Instance).Name < (b.Parent :: Instance).Name
	end)
	return list[math.floor(t / SPOT_SHIFT) % #list + 1].Position
end

local function updateHelicopter(heli: Helicopter, dt: number, t: number)
	local a = t / HELI_LAP * math.pi * 2
	local position = Vector3.new(math.cos(a) * HELI_RADIUS_X, HELI_HEIGHT + math.sin(t * 0.7) * 3, math.sin(a) * HELI_RADIUS_Z)
	local tangent = Vector3.new(-math.sin(a) * HELI_RADIUS_X, 0, math.cos(a) * HELI_RADIUS_Z)
	-- Nose down a touch and banked into the turn
	local base = CFrame.lookAt(position, position + tangent) * CFrame.Angles(math.rad(-4), 0, math.rad(-9))
	for _, placed in heli.Parts do
		placed.Part.CFrame = base * placed.Offset
	end
	local spin = (t * ROTOR_SPEED) % (math.pi * 2)
	for _, placed in heli.MainRotor do
		placed.Part.CFrame = base * CFrame.new(0, 6.2, 0) * CFrame.Angles(0, spin, 0) * CFrame.new(0, -6.2, 0) * placed.Offset
	end
	for _, placed in heli.TailRotor do
		placed.Part.CFrame = base * CFrame.new(1.4, 3, 26) * CFrame.Angles(spin * 2.2, 0, 0) * CFrame.new(-1.4, -3, -26) * placed.Offset
	end
	heli.Strobe.Transparency = if t % 1.4 < 0.12 then 0 else 1

	-- The light eases onto its fighter (or drifts over the pitch if nobody is playing)
	local floorY = Config.Arena.FloorY
	if t - heli.GoalAt > 0.25 then
		heli.GoalAt = t
		heli.Goal = spotlightTarget(t) or Vector3.new(math.sin(t * 0.13) * Layout.PITCH_HALF_X * 0.5, floorY, math.cos(t * 0.17) * Layout.PITCH_HALF_Z * 0.5)
	end
	local goal = Vector3.new(heli.Goal.X + math.sin(t * 0.9) * 10, floorY, heli.Goal.Z + math.cos(t * 0.7) * 10)
	heli.Spot = heli.Spot:Lerp(goal, 1 - math.exp(-dt * SPOT_FOLLOW))
	local lampAt = (base * CFrame.new(0, -4.6, -8)).Position
	heli.Lamp.CFrame = CFrame.lookAt(lampAt, heli.Spot)
	heli.Lens.CFrame = heli.Lamp.CFrame * CFrame.new(0, 0, -1.9)
	heli.Target.Position = heli.Spot
	heli.Pool.Position = heli.Spot + Vector3.new(0, 0.25, 0)
	heli.PoolCore.Position = heli.Spot + Vector3.new(0, 0.3, 0)
	heli.PoolLight.Position = heli.Spot + Vector3.new(0, 9, 0)
end

--------------------------------------------------------------------------------
-- Blimps
--------------------------------------------------------------------------------
type Blimp = {
	Index: number,
	Model: Model,
	Screens: { Screen },
	Cycle: number, -- seconds between the starts of its passes
	Offset: number,
	Pass: number, -- which pass the settings below are for
	Direction: Vector3,
	Side: Vector3,
	Lateral: number,
	Altitude: number,
	Speed: number,
	SlideStart: number,
	Visible: boolean,
	Lights: { Part },
}

local function buildBlimp(index: number, count: number): Blimp
	local model = Instance.new("Model")
	model.Name = "Blimp" .. index
	local rng = Random.new(index * 7919)
	local screens: { Screen } = {}
	local lights: { Part } = {}
	local fabric = Color3.fromRGB(30, 34, 56)
	local trim = Color3.fromRGB(70, 78, 110)

	local envelope = ellipsoid(model, "Envelope", Vector3.new(BLIMP_HEIGHT, BLIMP_HEIGHT, BLIMP_LENGTH), CFrame.identity, fabric, Enum.Material.SmoothPlastic)
	model.PrimaryPart = envelope
	-- Tail fins (top, bottom, left, right)
	for i = 0, 3 do
		local roll = CFrame.Angles(0, 0, i * math.pi / 2)
		part(model, "Fin", Vector3.new(1.2, 22, 38), CFrame.new(0, 0, BLIMP_LENGTH / 2 - 26) * roll * CFrame.new(0, BLIMP_HEIGHT / 2 + 4, 0), trim, Enum.Material.SmoothPlastic)
	end
	-- Gondola with lit windows
	part(model, "Gondola", Vector3.new(11, 8, 44), CFrame.new(0, -BLIMP_HEIGHT / 2 - 3, 12), trim, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		part(model, "Windows", Vector3.new(0.4, 2.2, 34), CFrame.new(side * 5.6, -BLIMP_HEIGHT / 2 - 2, 12), Color3.fromRGB(255, 230, 150), Enum.Material.Neon)
	end
	-- Anti-collision lights
	table.insert(lights, part(model, "NoseLight", Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 0, -BLIMP_LENGTH / 2 + 2), Color3.new(1, 1, 1), Enum.Material.Neon, Enum.PartType.Ball))
	table.insert(lights, part(model, "TailLight", Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, BLIMP_HEIGHT / 2 + 26, BLIMP_LENGTH / 2 - 26), Color3.fromRGB(255, 50, 50), Enum.Material.Neon, Enum.PartType.Ball))

	-- A billboard hung on each side, glowing
	for _, side in { -1, 1 } do
		local x = side * (BLIMP_HEIGHT / 2 + 3)
		part(model, "Frame", Vector3.new(1.2, PANEL_HEIGHT + 3, PANEL_WIDTH + 3), CFrame.new(x - side * 0.3, 2, -4), Color3.fromRGB(14, 14, 24), Enum.Material.Metal)
		for _, y in { -1, 1 } do
			part(model, "Trim", Vector3.new(1.5, 0.8, PANEL_WIDTH + 3), CFrame.new(x, 2 + y * (PANEL_HEIGHT / 2 + 1.5), -4), Color3.fromRGB(0, 220, 255), Enum.Material.Neon)
		end
		local panel = part(model, "Billboard", Vector3.new(1, PANEL_HEIGHT, PANEL_WIDTH), CFrame.new(x, 2, -4), Color3.fromRGB(8, 8, 16), Enum.Material.SmoothPlastic)
		table.insert(screens, buildScreen(panel, if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left, rng))
	end

	return {
		Index = index,
		Model = model,
		Screens = screens,
		Cycle = 150 + index * 23,
		Offset = (index - 1) * 150 / count + index * 41,
		Pass = -1,
		Direction = Vector3.zAxis,
		Side = Vector3.xAxis,
		Lateral = 0,
		Altitude = 300,
		Speed = 26,
		SlideStart = 0,
		Visible = false,
		Lights = lights,
	}
end

local function updateBlimp(blimp: Blimp, t: number, folder: Folder, redraw: boolean)
	local shifted = t + blimp.Offset
	local pass = math.floor(shifted / blimp.Cycle)
	if pass ~= blimp.Pass then
		-- A new pass: its heading, height and speed come from the pass number, so every player sees the same one
		blimp.Pass = pass
		local rng = Random.new(blimp.Index * 100003 + pass)
		local heading = rng:NextNumber(0, math.pi * 2)
		blimp.Direction = Vector3.new(math.cos(heading), 0, math.sin(heading))
		blimp.Side = Vector3.new(-math.sin(heading), 0, math.cos(heading))
		blimp.Lateral = rng:NextNumber(-350, 350)
		blimp.Altitude = rng:NextNumber(270, 340)
		blimp.Speed = rng:NextNumber(22, 32)
		blimp.SlideStart = rng:NextInteger(0, 9)
	end
	local into = shifted - pass * blimp.Cycle
	local travelled = into * blimp.Speed
	local onPass = travelled < FLY_RANGE * 2
	if not onPass then
		if blimp.Visible then
			blimp.Visible = false
			blimp.Model.Parent = nil
		end
		return
	end
	if not blimp.Visible then
		blimp.Visible = true
		blimp.Model.Parent = folder
	end
	local position = blimp.Side * blimp.Lateral + blimp.Direction * (travelled - FLY_RANGE) + Vector3.new(0, blimp.Altitude + math.sin(t * 0.3 + blimp.Index) * 4, 0)
	blimp.Model:PivotTo(CFrame.lookAt(position, position + blimp.Direction) * CFrame.Angles(0, 0, math.sin(t * 0.4 + blimp.Index) * 0.03))
	local blink = (t * 1.5 + blimp.Index) % 2 < 0.25
	blimp.Lights[1].Transparency = if blink then 0 else 1
	blimp.Lights[2].Transparency = if blink then 1 else 0
	if redraw then
		local slide = math.floor(t / SLIDE_TIME + blimp.SlideStart) % (#Skins.List + 1) + 1
		for _, screen in blimp.Screens do
			updateScreen(screen, slide, t)
		end
	end
end

--------------------------------------------------------------------------------
function SkyFX.Init()
	if not Config.Sky.Enabled then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "SB_Sky"
	folder.Parent = workspace

	local heli = buildHelicopter(folder)
	local count = if UserInputService.TouchEnabled then Config.Sky.MobileBlimps else Config.Sky.Blimps
	local blimps: { Blimp } = {}
	for i = 1, count do
		table.insert(blimps, buildBlimp(i, count))
	end

	local redrawAt = 0
	RunService.RenderStepped:Connect(function(dt)
		local t = workspace:GetServerTimeNow()
		updateHelicopter(heli, dt, t)
		local redraw = os.clock() >= redrawAt
		if redraw then
			redrawAt = os.clock() + 0.1
		end
		for _, blimp in blimps do
			updateBlimp(blimp, t, folder, redraw)
		end
	end)
end

return SkyFX
