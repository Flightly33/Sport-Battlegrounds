--[[
	SkyShow: the night sky over the stadium, drawn locally from plain parts.
		Helicopter   circles above the pitch with a searchlight sweeping the grass (a light cone, a
		             lit pool on the ground and a real SpotLight), blinking nav lights, spinning rotors
		Blimps       drift past high above the bowl, glowing digital billboards on both sides
		             advertising the shop's skins, with the item spinning in a little 3D window

	All tuning is at the top. Nothing here collides or can be clicked.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Layout = require(Shared.Stadium.Layout)
local Props = require(Shared.Props)
local Skins = require(Shared.Skins)

local SkyShow = {}

-- Helicopter
local HELI_HEIGHT = 58 -- above the pitch (a SpotLight reaches 60 studs, so the pool is lit for real)
local HELI_ORBIT = 0.55 -- orbit size, as a share of the pitch
local HELI_SPEED = 0.07 -- how fast it circles
local SPOT_SWEEP = 0.23 -- how fast the searchlight wanders across the pitch
-- Blimps
local BLIMP_HEIGHT = Layout.ROOF_HEIGHT + 70
local BLIMP_SPEED = 9 -- studs per second
local BLIMP_COUNT = 2
-- Billboard lines, cycled (each skin in Shared/Skins also gets its own line)
local BILLBOARD_LINES = { "NEW IN THE SHOP", "SPORTS BATTLEGROUNDS" }
local LINE_TIME = 3 -- seconds per line

local folder: Folder

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function ellipsoid(size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = part({ Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Parts of a vehicle, each with its offset from the vehicle's frame, moved together every frame.
type Rigid = { Parts: { { Part: BasePart, Offset: CFrame } } }

local function add(rigid: Rigid, p: BasePart, offset: CFrame)
	p.Parent = folder
	table.insert(rigid.Parts, { Part = p, Offset = offset })
end

local function place(rigid: Rigid, cf: CFrame)
	for _, entry in rigid.Parts do
		entry.Part.CFrame = cf * entry.Offset
	end
end

--------------------------------------------------------------------------------
-- Helicopter
--------------------------------------------------------------------------------
local function helicopter()
	local rigid: Rigid = { Parts = {} }
	local body = Color3.fromRGB(32, 36, 46)
	add(rigid, ellipsoid(Vector3.new(5, 4.4, 9), body, Enum.Material.Metal), CFrame.identity)
	add(rigid, ellipsoid(Vector3.new(3.6, 2.4, 3), Color3.fromRGB(120, 190, 255), Enum.Material.Glass), CFrame.new(0, 0.6, -3.4))
	add(rigid, part({ Size = Vector3.new(0.8, 0.8, 8), Color = body, Material = Enum.Material.Metal }), CFrame.new(0, 0.6, 7.5))
	add(rigid, part({ Size = Vector3.new(0.3, 3, 1.6), Color = body, Material = Enum.Material.Metal }), CFrame.new(0, 1.6, 11.2))
	for _, x in { -1.8, 1.8 } do
		add(rigid, part({ Size = Vector3.new(0.3, 0.3, 8), Color = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Metal }), CFrame.new(x, -2.8, 0))
	end
	-- Nav lights: red left, green right, white strobe on the tail
	local navs: { Part } = {}
	for _, spec in { { X = -2.6, Color = Color3.fromRGB(255, 40, 40) }, { X = 2.6, Color = Color3.fromRGB(40, 255, 80) } } do
		local nav = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.5, Color = spec.Color, Material = Enum.Material.Neon })
		add(rigid, nav, CFrame.new(spec.X, 0, 0))
		table.insert(navs, nav)
	end
	local strobe = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.45, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })
	add(rigid, strobe, CFrame.new(0, 3.2, 11.2))
	-- Rotors spin on their own each frame
	local mainRotor = part({ Size = Vector3.new(22, 0.15, 0.7), Color = Color3.fromRGB(25, 25, 30) })
	mainRotor.Parent = folder
	local mainRotor2 = part({ Size = Vector3.new(0.7, 0.15, 22), Color = Color3.fromRGB(25, 25, 30) })
	mainRotor2.Parent = folder
	local tailRotor = part({ Size = Vector3.new(0.15, 4, 0.4), Color = Color3.fromRGB(25, 25, 30) })
	tailRotor.Parent = folder

	-- The searchlight: a lamp under the nose, a cone of light down to a lit pool on the grass
	local lamp = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Neon })
	lamp.Parent = folder
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 28
	light.Range = 60
	light.Brightness = 6
	light.Color = Color3.fromRGB(255, 248, 225)
	light.Shadows = true
	light.Parent = lamp
	local pool = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 26, 26), Color = Color3.fromRGB(255, 250, 225), Material = Enum.Material.Neon, Transparency = 0.82 })
	pool.Parent = folder
	local a0 = Instance.new("Attachment")
	a0.Parent = lamp
	local a1 = Instance.new("Attachment")
	a1.Parent = pool
	local cone = Instance.new("Beam")
	cone.Attachment0 = a0
	cone.Attachment1 = a1
	cone.Width0 = 1.5
	cone.Width1 = 24
	cone.FaceCamera = true
	cone.LightEmission = 1
	cone.LightInfluence = 0
	cone.Color = ColorSequence.new(Color3.fromRGB(255, 248, 225))
	cone.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.9) })
	cone.Segments = 2
	cone.Parent = lamp

	local t0 = os.clock()
	return function(now: number)
		local t = now - t0
		local a = t * HELI_SPEED * math.pi * 2 / 6
		local center = Vector3.new(
			math.cos(a) * Layout.PITCH_HALF_X * HELI_ORBIT,
			HELI_HEIGHT + math.sin(t * 0.5) * 2,
			math.sin(a) * Layout.PITCH_HALF_Z * HELI_ORBIT
		)
		local ahead = Vector3.new(-math.sin(a) * Layout.PITCH_HALF_X, 0, math.cos(a) * Layout.PITCH_HALF_Z).Unit
		-- Nose down and banked into the turn
		local frame = CFrame.lookAt(center, center + ahead) * CFrame.Angles(-0.12, 0, 0.18)
		place(rigid, frame)
		local spin = t * 28
		local hub = frame * CFrame.new(0, 2.7, 0)
		mainRotor.CFrame = hub * CFrame.Angles(0, spin, 0)
		mainRotor2.CFrame = hub * CFrame.Angles(0, spin, 0)
		tailRotor.CFrame = frame * CFrame.new(0.4, 1.6, 11.6) * CFrame.Angles(spin * 1.5, 0, 0)
		local blink = (t % 1.2) < 0.15
		strobe.Transparency = if blink then 0 else 1
		for _, nav in navs do
			nav.Transparency = if (t % 2) < 1.6 then 0 else 0.6
		end
		-- The searchlight wanders around a spot near the helicopter's track
		local target = Vector3.new(
			center.X * 0.7 + math.sin(t * SPOT_SWEEP * 3.1) * 40,
			0.15,
			center.Z * 0.7 + math.cos(t * SPOT_SWEEP * 2.3) * 30
		)
		local lampPos = (frame * CFrame.new(0, -2.4, -3.5)).Position
		lamp.CFrame = CFrame.lookAt(lampPos, target)
		pool.CFrame = CFrame.new(target) * CFrame.Angles(0, 0, math.pi / 2)
	end
end

--------------------------------------------------------------------------------
-- Blimps
--------------------------------------------------------------------------------
-- A spinning 3D view of a skin's ball, for the billboard.
local function itemWindow(parent: Instance, skinId: string?): () -> ()
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Size = UDim2.fromScale(0.3, 0.9)
	view.Position = UDim2.fromScale(0.02, 0.05)
	view.LightColor = Color3.new(1, 1, 1)
	view.Ambient = Color3.fromRGB(170, 160, 200)
	view.Parent = parent
	local ball = Props.BuildBall("Soccer", true, skinId)
	ball:PivotTo(CFrame.identity)
	ball.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.3, 2.6), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera
	return function()
		ball:PivotTo(CFrame.Angles(0.3, os.clock() * 1.2, 0))
	end
end

local function billboard(face: Part, side: Enum.NormalId, lines: { string }, skinId: string?): (number) -> ()
	local gui = Instance.new("SurfaceGui")
	gui.Face = side
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	gui.LightInfluence = 0
	gui.Brightness = 2.4
	gui.Parent = face
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(6, 4, 18)
	back.BorderSizePixel = 0
	back.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(Color3.fromRGB(70, 30, 160), Color3.fromRGB(10, 60, 140))
	gradient.Parent = back
	local spin = itemWindow(back, skinId)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.33, 0.1)
	label.Size = UDim2.fromScale(0.65, 0.8)
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(140, 255, 255)
	label.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(180, 80, 255)
	stroke.Thickness = 3
	stroke.Parent = label
	return function(now: number)
		local i = math.floor(now / LINE_TIME) % #lines + 1
		label.Text = lines[i]
		-- A digital-sign flicker when the line changes
		local into = now % LINE_TIME
		label.TextTransparency = if into < 0.12 then 0.6 else 0
		gradient.Offset = Vector2.new(math.sin(now * 0.6) * 0.3, 0)
		spin()
	end
end

local function blimp(index: number)
	local rigid: Rigid = { Parts = {} }
	local length = 70
	local envelope = Color3.fromRGB(215, 220, 232)
	add(rigid, ellipsoid(Vector3.new(18, 18, length), envelope), CFrame.identity)
	add(rigid, part({ Size = Vector3.new(4, 3, 12), Color = Color3.fromRGB(50, 52, 64), Material = Enum.Material.Metal }), CFrame.new(0, -10, 2))
	for _, fin in { CFrame.new(0, 7, 31), CFrame.new(0, -7, 31), CFrame.new(7, 0, 31) * CFrame.Angles(0, 0, math.pi / 2), CFrame.new(-7, 0, 31) * CFrame.Angles(0, 0, math.pi / 2) } do
		add(rigid, part({ Size = Vector3.new(0.6, 8, 10), Color = Color3.fromRGB(120, 60, 220) }), fin)
	end
	-- Running lights along the gondola
	for i = -1, 1 do
		add(rigid, part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, Color = Color3.fromRGB(255, 60, 60), Material = Enum.Material.Neon }), CFrame.new(0, -11.6, 2 + i * 4))
	end
	-- Billboard screens on both flanks
	local lines = table.clone(BILLBOARD_LINES)
	local skinId: string? = nil
	for id, skin in Skins.List do
		skinId = skinId or id
		table.insert(lines, 1, string.upper(skin.Name))
		table.insert(lines, 2, if Skins.FREE_FOR_EVERYONE then "FREE FOR NOW!" else "GET IT IN THE SHOP")
	end
	local screen = part({ Size = Vector3.new(19.4, 9, 36), Color = Color3.fromRGB(6, 4, 18), Material = Enum.Material.SmoothPlastic })
	add(rigid, screen, CFrame.new(0, 0, -2))
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Left
	light.Color = Color3.fromRGB(150, 110, 255)
	light.Brightness = 2
	light.Range = 20
	light.Parent = screen
	local updates = { billboard(screen, Enum.NormalId.Left, lines, skinId), billboard(screen, Enum.NormalId.Right, lines, skinId) }

	-- Drifts across the sky on a long straight line, then comes round again
	local span = (Layout.OUTER_DISTANCE + Layout.BARRIER_HALF_X) * 2 + 400
	local lane = (index - (BLIMP_COUNT + 1) / 2) * (Layout.BARRIER_HALF_Z * 1.6)
	local heading = if index % 2 == 0 then -1 else 1
	local offset = (index - 1) * span / BLIMP_COUNT
	return function(now: number)
		local x = ((now * BLIMP_SPEED + offset) % span - span / 2) * heading
		local position = Vector3.new(x, BLIMP_HEIGHT + index * 12 + math.sin(now * 0.3 + index) * 3, lane)
		place(rigid, CFrame.lookAt(position, position + Vector3.new(heading, 0, 0)) * CFrame.Angles(0, 0, math.sin(now * 0.4 + index) * 0.03))
		for _, update in updates do
			update(now)
		end
	end
end

function SkyShow.Init()
	folder = Instance.new("Folder")
	folder.Name = "SkyShow"
	folder.Parent = workspace
	local updates = { helicopter() }
	for i = 1, BLIMP_COUNT do
		table.insert(updates, blimp(i))
	end
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for _, update in updates do
			update(now)
		end
	end)
end

return SkyShow
