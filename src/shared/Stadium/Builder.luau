--[[
	Stadium builder: the pitch, running track, LED boards, two tiers of seats, the ring of private
	boxes, the roof canopy with its floodlights, floodlight masts, jumbotrons and a skyline beyond.

	The result is baked into the place file (map/Stadium.rbxm, made by tools/lune/bake_stadium.luau) so
	it can be edited in Studio; the server only calls Build() if Workspace.Stadium is missing. Pure
	instance construction - no services - so it also runs offline under Lune.

	The crowd is NOT built here: every client draws (and animates) its own fans on these seats
	(Client/Crowd.luau), which keeps the place small and lets mobile players use fewer fans.

	Nothing in the stands casts shadows: with the sun low, the stands would otherwise put the whole
	pitch in shadow (and it saves a lot of rendering).
]]

local Layout = require(script.Parent.Layout)

local Builder = {}

local GRASS_A = Color3.fromRGB(58, 148, 64)
local GRASS_B = Color3.fromRGB(70, 166, 76)
local LINE = Color3.fromRGB(245, 248, 245)
local TRACK = Color3.fromRGB(176, 66, 48)
local CONCRETE = Color3.fromRGB(104, 104, 116)
local CONCRETE_DARK = Color3.fromRGB(70, 70, 82)
local METAL = Color3.fromRGB(38, 40, 50)
local GLASS = Color3.fromRGB(120, 170, 220)

export type PartProps = {
	Name: string?,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	Collide: boolean?,
	Shadow: boolean?,
	Reflectance: number?,
}

local function part(parent: Instance, props: PartProps): Part
	local p = Instance.new("Part")
	p.Name = props.Name or "Part"
	p.Anchored = true
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or CONCRETE
	p.Material = props.Material or Enum.Material.SmoothPlastic
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Transparency = props.Transparency or 0
	p.Reflectance = props.Reflectance or 0
	p.CanCollide = props.Collide == true
	p.CanTouch = false
	p.CanQuery = props.Collide == true
	p.CastShadow = props.Shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
Builder.Part = part

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, math.clamp(t, 0, 1))
end

--------------------------------------------------------------------------------
-- Walking the rounded-rectangle path
--------------------------------------------------------------------------------
-- Calls fn(cf, length, side, sideBlend) for pieces of the path at `offset`. cf is centred on the path
-- with X along it, Y up and Z pointing in towards the pitch. Straights are split into `pieces`, corners
-- into chords of about `chord` studs. sideBlend is 0..1 across a corner (from the previous side).
type PathFn = (cf: CFrame, length: number, side: string, blend: number, index: number) -> ()

local function forPath(offset: number, pieces: number, chord: number, gap: number, fn: PathFn)
	local index = 0
	for _, segment in Layout.Path(offset) do
		if segment.Kind == "Straight" then
			local from, to = segment.From :: Vector3, segment.To :: Vector3
			local dir = (to - from).Unit
			local len = segment.Length / pieces
			for i = 0, pieces - 1 do
				index += 1
				local mid = from + dir * (len * (i + 0.5))
				fn(CFrame.fromMatrix(mid, dir, Vector3.yAxis), len - gap, segment.Side, 0, index)
			end
		else
			local radius = segment.Radius :: number
			local a0, a1 = segment.A0 :: number, segment.A1 :: number
			local n = math.max(3, math.ceil(segment.Length / chord))
			local step = (a1 - a0) / n
			local center = segment.Center :: Vector3
			for i = 0, n - 1 do
				index += 1
				local a = a0 + step * (i + 0.5)
				local normal = Vector3.new(math.cos(a), 0, math.sin(a))
				local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
				local mid = center + normal * radius
				local len = 2 * radius * math.sin(step / 2) + 0.25 - gap
				fn(CFrame.fromMatrix(mid, tangent, Vector3.yAxis), len, segment.Side, (i + 0.5) / n, index)
			end
		end
	end
end
Builder.ForPath = forPath

local CORNER_SIDES = {
	NorthEast = { "North", "East" },
	SouthEast = { "East", "South" },
	SouthWest = { "South", "West" },
	NorthWest = { "West", "North" },
}

-- The themed colour for a place on the path (corners fade between their two sides).
local function sideColor(side: string, blend: number, alt: boolean): Color3
	local pair = CORNER_SIDES[side]
	if pair then
		local a = Layout.SIDES[pair[1]]
		local b = Layout.SIDES[pair[2]]
		return lerpColor(if alt then a.Alt else a.Color, if alt then b.Alt else b.Color, blend)
	end
	local s = Layout.SIDES[side]
	return if alt then s.Alt else s.Color
end
Builder.SideColor = sideColor

--------------------------------------------------------------------------------
-- Pitch
--------------------------------------------------------------------------------
local function line(parent: Instance, a: Vector3, b: Vector3, width: number)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	part(parent, {
		Name = "Line",
		Size = Vector3.new(width, 0.05, len + width),
		CFrame = CFrame.lookAt(mid, b) * CFrame.new(0, 0, 0),
		Color = LINE,
		Material = Enum.Material.SmoothPlastic,
	})
end

local function arc(parent: Instance, center: Vector3, radius: number, a0: number, a1: number, width: number)
	local n = math.max(6, math.ceil(math.abs(a1 - a0) * radius / 3))
	for i = 0, n - 1 do
		local t0 = a0 + (a1 - a0) * i / n
		local t1 = a0 + (a1 - a0) * (i + 1) / n
		line(parent, center + Vector3.new(math.cos(t0), 0, math.sin(t0)) * radius, center + Vector3.new(math.cos(t1), 0, math.sin(t1)) * radius, width)
	end
end

local function goal(parent: Instance, x: number)
	local side = if x > 0 then 1 else -1
	local g = folder(parent, if x > 0 then "GoalEast" else "GoalWest")
	local white = Color3.fromRGB(250, 250, 250)
	-- Regulation goal: 7.32 x 2.44 m, about 2 m deep
	local m = Layout.STUDS_PER_METER
	local halfWidth, height, depth = 3.66 * m, 2.44 * m, 2 * m
	local post = 0.15 * m
	for _, z in { -halfWidth, halfWidth } do
		part(g, { Name = "Post", Size = Vector3.new(height, post, post), CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.pi / 2), Color = white, Shape = Enum.PartType.Cylinder, Collide = true, Shadow = true })
		part(g, { Name = "BackPost", Size = Vector3.new(height, 0.3, 0.3), CFrame = CFrame.new(x + side * depth, height / 2, z) * CFrame.Angles(0, 0, math.pi / 2), Color = white, Shape = Enum.PartType.Cylinder })
		part(g, { Name = "Stay", Size = Vector3.new(depth, 0.3, 0.3), CFrame = CFrame.new(x + side * depth / 2, height, z), Color = white, Shape = Enum.PartType.Cylinder })
	end
	part(g, { Name = "Crossbar", Size = Vector3.new(halfWidth * 2 + post, post, post), CFrame = CFrame.new(x, height, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = white, Shape = Enum.PartType.Cylinder, Collide = true, Shadow = true })
	-- Net panels
	local net = { Color = Color3.fromRGB(235, 235, 240), Material = Enum.Material.Fabric, Transparency = 0.62 }
	part(g, { Name = "NetBack", Size = Vector3.new(0.1, height, halfWidth * 2), CFrame = CFrame.new(x + side * depth, height / 2, 0), Color = net.Color, Material = net.Material, Transparency = net.Transparency })
	part(g, { Name = "NetTop", Size = Vector3.new(depth, 0.1, halfWidth * 2), CFrame = CFrame.new(x + side * depth / 2, height, 0), Color = net.Color, Material = net.Material, Transparency = net.Transparency })
	for _, z in { -halfWidth, halfWidth } do
		part(g, { Name = "NetSide", Size = Vector3.new(depth, height, 0.1), CFrame = CFrame.new(x + side * depth / 2, height / 2, z), Color = net.Color, Material = net.Material, Transparency = net.Transparency })
	end
end

local function centerLogo(parent: Instance)
	local plate = part(parent, {
		Name = "CenterLogo",
		Size = Vector3.new(44, 0.05, 44),
		CFrame = CFrame.new(0, 0.07, 0),
		Transparency = 1,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Logo"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0.6
	gui.Parent = plate
	local function label(text: string, y: number, h: number, color: Color3, size: number)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, h, 0)
		t.Position = UDim2.new(0, 0, y, 0)
		t.Text = text
		t.TextColor3 = color
		t.TextScaled = true
		t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
		t.TextTransparency = 0.12
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 40, 25)
		stroke.Thickness = size
		stroke.Transparency = 0.3
		stroke.Parent = t
		t.Parent = gui
	end
	label("SPORTS", 0.27, 0.24, Color3.fromRGB(255, 255, 255), 6)
	label("BATTLEGROUNDS", 0.5, 0.17, Color3.fromRGB(255, 220, 90), 5)
end

local function cornerFlag(parent: Instance, x: number, z: number, color: Color3)
	-- 1.5 m pole, flag about 0.4 x 0.5 m
	local h = 1.5 * Layout.STUDS_PER_METER
	part(parent, { Name = "FlagPole", Size = Vector3.new(h, 0.2, 0.2), CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(240, 240, 240), Shape = Enum.PartType.Cylinder })
	part(parent, { Name = "Flag", Size = Vector3.new(0.05, 1.2, 1.5), CFrame = CFrame.new(x, h - 0.6, z + 0.75), Color = color, Material = Enum.Material.Fabric })
end

local function buildPitch(root: Instance)
	local pitch = folder(root, "Pitch")
	local hx, hz = Layout.PITCH_HALF_X, Layout.PITCH_HALF_Z
	-- Mowing stripes across the pitch
	local stripes = 16
	local w = (hx * 2 + 16) / stripes
	for i = 0, stripes - 1 do
		local x = -hx - 8 + w * (i + 0.5)
		part(pitch, {
			Name = "Grass",
			Size = Vector3.new(w, 1, hz * 2 + 16),
			CFrame = CFrame.new(x, -0.5, 0),
			Color = if i % 2 == 0 then GRASS_A else GRASS_B,
			Material = Enum.Material.Grass,
			Collide = true,
		})
	end
	local lines = folder(pitch, "Lines")
	local y = 0.03
	local W = 0.5 -- real lines are 0.12 m; a little wider reads better from the camera
	line(lines, Vector3.new(-hx, y, -hz), Vector3.new(hx, y, -hz), W)
	line(lines, Vector3.new(-hx, y, hz), Vector3.new(hx, y, hz), W)
	line(lines, Vector3.new(-hx, y, -hz), Vector3.new(-hx, y, hz), W)
	line(lines, Vector3.new(hx, y, -hz), Vector3.new(hx, y, hz), W)
	line(lines, Vector3.new(0, y, -hz), Vector3.new(0, y, hz), W)
	-- Regulation markings in metres, stretched with the pitch
	local m = Layout.STUDS_PER_METER * Layout.FIELD_SCALE
	arc(lines, Vector3.new(0, y, 0), 9.15 * m, 0, math.pi * 2, W)
	part(lines, { Name = "CenterSpot", Size = Vector3.new(0.05, 2, 2), CFrame = CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = LINE, Shape = Enum.PartType.Cylinder })
	for _, side in { -1, 1 } do
		local gx = side * hx
		-- Penalty box, goal box, spot and the arc
		local boxDepth, boxHalf = 16.5 * m, 20.16 * m
		local smallDepth, smallHalf = 5.5 * m, 9.16 * m
		line(lines, Vector3.new(gx, y, -boxHalf), Vector3.new(gx - side * boxDepth, y, -boxHalf), W)
		line(lines, Vector3.new(gx, y, boxHalf), Vector3.new(gx - side * boxDepth, y, boxHalf), W)
		line(lines, Vector3.new(gx - side * boxDepth, y, -boxHalf), Vector3.new(gx - side * boxDepth, y, boxHalf), W)
		line(lines, Vector3.new(gx, y, -smallHalf), Vector3.new(gx - side * smallDepth, y, -smallHalf), W)
		line(lines, Vector3.new(gx, y, smallHalf), Vector3.new(gx - side * smallDepth, y, smallHalf), W)
		line(lines, Vector3.new(gx - side * smallDepth, y, -smallHalf), Vector3.new(gx - side * smallDepth, y, smallHalf), W)
		local spot = Vector3.new(gx - side * 11 * m, y, 0)
		part(lines, { Name = "PenaltySpot", Size = Vector3.new(0.05, 1.4, 1.4), CFrame = CFrame.new(spot) * CFrame.Angles(0, 0, math.pi / 2), Color = LINE, Shape = Enum.PartType.Cylinder })
		-- The penalty arc: the part of a 9.15 m circle round the spot outside the box (5.5 m away)
		local a = math.acos(5.5 / 9.15)
		if side > 0 then
			arc(lines, spot, 9.15 * m, math.pi - a, math.pi + a, W)
		else
			arc(lines, spot, 9.15 * m, -a, a, W)
		end
		goal(pitch, gx)
	end
	centerLogo(pitch)
	cornerFlag(pitch, -hx, -hz, Layout.SIDES.North.Color)
	cornerFlag(pitch, hx, -hz, Layout.SIDES.East.Color)
	cornerFlag(pitch, hx, hz, Layout.SIDES.South.Color)
	cornerFlag(pitch, -hx, hz, Layout.SIDES.West.Color)
end

--------------------------------------------------------------------------------
-- Track, barrier, LED boards
--------------------------------------------------------------------------------
local function buildTrack(root: Instance)
	local track = folder(root, "Track")
	local bx, bz = Layout.BARRIER_HALF_X, Layout.BARRIER_HALF_Z
	part(track, {
		Name = "TrackBase",
		Size = Vector3.new(bx * 2 + 30, 1, bz * 2 + 30),
		CFrame = CFrame.new(0, -0.55, 0),
		Color = TRACK,
		Material = Enum.Material.Sand,
		Collide = true,
	})
	-- Lane lines just inside the barrier
	for lane = 1, 5 do
		forPath(-4 * lane, 1, 8, 0, function(cf, length)
			part(track, { Name = "Lane", Size = Vector3.new(length, 0.05, 0.4), CFrame = cf + Vector3.new(0, 0.02, 0), Color = Color3.fromRGB(245, 235, 230) })
		end)
	end
end

local function buildBarrier(root: Instance)
	local barrier = folder(root, "Barrier")
	local h = Layout.BARRIER_HEIGHT
	forPath(0.6, 1, 10, 0, function(cf, length, side, blend)
		part(barrier, { Name = "Wall", Size = Vector3.new(length, h, 1.2), CFrame = cf + Vector3.new(0, h / 2, 0), Color = CONCRETE_DARK, Material = Enum.Material.Concrete, Collide = true })
		local board = part(barrier, {
			Name = "LEDBoard",
			Size = Vector3.new(length, 3, 0.3),
			CFrame = cf * CFrame.new(0, h - 2, 0.75),
			Color = sideColor(side, blend, false),
			Material = Enum.Material.Neon,
		})
		if CORNER_SIDES[side] == nil then
			board:SetAttribute("LED", true)
		end
	end)
	-- Collision: invisible walls keep everyone on the pitch, however hard they're launched
	local walls = folder(root, "ArenaWalls")
	forPath(0, 1, 14, -0.5, function(cf, length)
		local wall = part(walls, { Name = "InvisibleWall", Size = Vector3.new(length, 400, 2), CFrame = cf * CFrame.new(0, 200, -1), Transparency = 1, Collide = true })
		wall.CanQuery = false
	end)
	part(walls, { Name = "Ceiling", Size = Vector3.new(Layout.BARRIER_HALF_X * 2 + 20, 2, Layout.BARRIER_HALF_Z * 2 + 20), CFrame = CFrame.new(0, 400, 0), Transparency = 1, Collide = true }).CanQuery = false
end

--------------------------------------------------------------------------------
-- Stands
--------------------------------------------------------------------------------
local function buildTier(root: Instance, tier: Layout.Tier, floorBase: number)
	local stands = folder(root, tier.Name .. "Tier")
	local steps = folder(stands, "Steps")
	local seats = folder(stands, "Seats")
	for i = 0, tier.Rows - 1 do
		local offset = tier.Start + (i + 0.5) * tier.Depth
		local height = tier.BaseHeight + (i + 1) * tier.Rise
		local stepHeight = height - floorBase
		forPath(offset, 1, 16, 0, function(cf, length)
			part(steps, {
				Name = "Step",
				Size = Vector3.new(length, stepHeight, tier.Depth + 0.05),
				CFrame = cf + Vector3.new(0, floorBase + stepHeight / 2, 0),
				Color = if i % 2 == 0 then CONCRETE else Color3.fromRGB(96, 96, 108),
				Material = Enum.Material.Concrete,
			})
		end)
		-- Seat blocks: themed colour per side, a stripe every few rows, gaps for the aisles
		local alt = (i % 7 == 3) or (i % 7 == 4)
		forPath(offset - tier.Depth * 0.1, 7, 11, 0, function(cf, length, side, blend, index)
			local isCorner = CORNER_SIDES[side] ~= nil
			local gap = if isCorner then (if index % 4 == 0 then 2.5 else 0.15) else 3
			part(seats, {
				Name = "Seat",
				-- 0.8 m seat backs, 0.37 m deep
				Size = Vector3.new(math.max(1, length - gap), 0.8 * Layout.STUDS_PER_METER, 0.37 * Layout.STUDS_PER_METER),
				CFrame = cf * CFrame.new(0, height + 0.4 * Layout.STUDS_PER_METER, -tier.Depth * 0.22),
				-- A little darker than the boards, so the fans in front of them pop
				Color = sideColor(side, blend, alt):Lerp(Color3.fromRGB(14, 14, 22), 0.32),
				Material = Enum.Material.SmoothPlastic,
			})
		end)
	end
end

local function buildBoxes(root: Instance)
	local boxes = folder(root, "Boxes")
	local mid = Layout.BOX_START + Layout.BOX_DEPTH / 2
	-- Concourse wall behind the lower tier, up to the box floor
	forPath(mid, 1, 14, 0, function(cf, length)
		part(boxes, { Name = "Concourse", Size = Vector3.new(length, Layout.BOX_FLOOR, Layout.BOX_DEPTH + 0.2), CFrame = cf + Vector3.new(0, Layout.BOX_FLOOR / 2, 0), Color = CONCRETE_DARK, Material = Enum.Material.Concrete })
	end)
	local top = Layout.BOX_FLOOR + Layout.BOX_HEIGHT
	forPath(Layout.BOX_START + 0.6, 6, 12, 0, function(cf, length, side, blend)
		local glassH = Layout.BOX_HEIGHT - 3
		part(boxes, { Name = "BoxGlass", Size = Vector3.new(length - 1.2, glassH, 0.4), CFrame = cf + Vector3.new(0, Layout.BOX_FLOOR + glassH / 2 + 0.5, 0), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.2 })
		part(boxes, { Name = "BoxMullion", Size = Vector3.new(1.2, glassH, 0.8), CFrame = cf * CFrame.new(length / 2, Layout.BOX_FLOOR + glassH / 2 + 0.5, 0), Color = METAL, Material = Enum.Material.Metal })
		-- Warm light inside each box
		part(boxes, { Name = "BoxLight", Size = Vector3.new(length - 2, 0.4, 0.4), CFrame = cf * CFrame.new(0, top - 3.4, -3), Color = Color3.fromRGB(255, 214, 160), Material = Enum.Material.Neon })
		part(boxes, { Name = "BoxBack", Size = Vector3.new(length, Layout.BOX_HEIGHT, 0.6), CFrame = cf * CFrame.new(0, Layout.BOX_FLOOR + Layout.BOX_HEIGHT / 2, -(Layout.BOX_DEPTH - 1)), Color = Color3.fromRGB(60, 44, 40), Material = Enum.Material.WoodPlanks })
		-- Ribbon board along the front of the upper tier
		local ribbon = part(boxes, { Name = "RibbonBoard", Size = Vector3.new(length, 2.6, 0.4), CFrame = cf + Vector3.new(0, top - 1.3, 0), Color = sideColor(side, blend, false), Material = Enum.Material.Neon })
		if CORNER_SIDES[side] == nil then
			ribbon:SetAttribute("LED", true)
		end
	end)
	-- Box ceilings / upper tier floor
	forPath(mid, 1, 14, 0, function(cf, length)
		part(boxes, { Name = "BoxCeiling", Size = Vector3.new(length, 1, Layout.BOX_DEPTH + 0.4), CFrame = cf + Vector3.new(0, top + 0.5, 0), Color = CONCRETE_DARK, Material = Enum.Material.Concrete })
		part(boxes, { Name = "BoxFloor", Size = Vector3.new(length, 0.6, Layout.BOX_DEPTH), CFrame = cf + Vector3.new(0, Layout.BOX_FLOOR + 0.3, 0), Color = Color3.fromRGB(120, 34, 40), Material = Enum.Material.Fabric })
	end)
end

local function buildRoof(root: Instance)
	local roof = folder(root, "Roof")
	local h = Layout.ROOF_HEIGHT
	local outer = Layout.OUTER_DISTANCE
	-- Outer facade from the ground to the roof
	forPath(outer + 1, 1, 18, 0, function(cf, length)
		part(roof, { Name = "Facade", Size = Vector3.new(length, h + 4, 2), CFrame = cf + Vector3.new(0, (h + 4) / 2, 0), Color = Color3.fromRGB(56, 58, 72), Material = Enum.Material.Concrete })
	end)
	-- Canopy
	local mid = Layout.ROOF_START + Layout.ROOF_DEPTH / 2
	forPath(mid, 1, 16, 0, function(cf, length)
		part(roof, { Name = "Canopy", Size = Vector3.new(length, 3, Layout.ROOF_DEPTH), CFrame = cf + Vector3.new(0, h + 1.5, 0), Color = METAL, Material = Enum.Material.Metal })
	end)
	-- Floodlight strip along the inner edge of the canopy
	forPath(Layout.ROOF_START + 1.5, 4, 12, 0, function(cf, length, _side, _blend, index)
		part(roof, { Name = "RoofTrim", Size = Vector3.new(length, 4, 1.5), CFrame = cf + Vector3.new(0, h + 1, 0), Color = Color3.fromRGB(28, 30, 38), Material = Enum.Material.Metal })
		local lamp = part(roof, { Name = "RoofLight", Size = Vector3.new(length * 0.7, 1.4, 0.6), CFrame = cf * CFrame.new(0, h - 1.2, 0.6) * CFrame.Angles(math.rad(-35), 0, 0), Color = Color3.fromRGB(255, 250, 235), Material = Enum.Material.Neon })
		lamp:SetAttribute("Floodlight", index % 3 == 0)
	end)
	-- Trusses on top of the canopy
	forPath(mid, 6, 26, 0, function(cf, length)
		part(roof, { Name = "Truss", Size = Vector3.new(1.6, 6, Layout.ROOF_DEPTH + 6), CFrame = cf * CFrame.new(length / 2, h + 5, 0), Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.DiamondPlate })
	end)
end

local function buildMasts(root: Instance)
	local masts = folder(root, "Floodlights")
	local d = Layout.OUTER_DISTANCE + 14
	for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local sx, sz = corner[1], corner[2]
		local r = Layout.CORNER_RADIUS + d
		local base = Vector3.new(sx * (Layout.BARRIER_HALF_X - Layout.CORNER_RADIUS + r * 0.7071), 0, sz * (Layout.BARRIER_HALF_Z - Layout.CORNER_RADIUS + r * 0.7071))
		local height = Layout.ROOF_HEIGHT + 60
		part(masts, { Name = "Mast", Size = Vector3.new(height, 5, 5), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(190, 195, 205), Material = Enum.Material.Metal, Shape = Enum.PartType.Cylinder })
		local head = CFrame.lookAt(base + Vector3.new(0, height, 0), Vector3.new(0, 0, 0))
		part(masts, { Name = "LightFrame", Size = Vector3.new(34, 22, 3), CFrame = head * CFrame.new(0, 4, 0), Color = METAL, Material = Enum.Material.Metal })
		for gx = -3, 3 do
			for gy = -2, 2 do
				local lamp = part(masts, { Name = "Lamp", Size = Vector3.new(3.6, 3.2, 0.5), CFrame = head * CFrame.new(gx * 4.6, 4 + gy * 4, -1.6), Color = Color3.fromRGB(255, 252, 240), Material = Enum.Material.Neon })
				lamp:SetAttribute("Floodlight", gx == 0 and gy == 0)
			end
		end
	end
end

local function buildJumbotrons(root: Instance)
	local screens = folder(root, "Jumbotrons")
	local upperTier = Layout.Tiers[2]
	local offset = upperTier.Start + upperTier.Rows * upperTier.Depth - 8
	for _, side in { "East", "West" } do
		local sx = if side == "East" then 1 else -1
		local x = sx * (Layout.BARRIER_HALF_X + offset)
		-- Hung just under the roof line
		local y = Layout.ROOF_HEIGHT - 16
		local cf = CFrame.lookAt(Vector3.new(x, y, 0), Vector3.new(0, y, 0))
		part(screens, { Name = "Frame", Size = Vector3.new(62, 30, 3), CFrame = cf * CFrame.new(0, 0, 1.6), Color = Color3.fromRGB(20, 20, 26), Material = Enum.Material.Metal })
		local screen = part(screens, { Name = "Jumbotron", Size = Vector3.new(58, 26, 0.5), CFrame = cf, Color = Color3.fromRGB(8, 10, 16), Material = Enum.Material.SmoothPlastic })
		screen:SetAttribute("Side", side)
		part(screens, { Name = "Support", Size = Vector3.new(3, 24, 3), CFrame = cf * CFrame.new(-20, -26, 3), Color = METAL, Material = Enum.Material.Metal })
		part(screens, { Name = "Support", Size = Vector3.new(3, 24, 3), CFrame = cf * CFrame.new(20, -26, 3), Color = METAL, Material = Enum.Material.Metal })
	end
end

local function buildTunnels(root: Instance)
	local tunnels = folder(root, "Tunnels")
	for _, z in { -1, 1 } do
		local wallZ = z * (Layout.BARRIER_HALF_Z + 0.6)
		local cf = CFrame.lookAt(Vector3.new(0, 0, wallZ), Vector3.new(0, 0, 0))
		part(tunnels, { Name = "TunnelMouth", Size = Vector3.new(18, 9, 1.4), CFrame = cf * CFrame.new(0, 4.5, 0.2), Color = Color3.fromRGB(10, 10, 14), Material = Enum.Material.SmoothPlastic })
		part(tunnels, { Name = "TunnelFrame", Size = Vector3.new(20, 1.2, 1.8), CFrame = cf * CFrame.new(0, 9.4, 0.3), Color = Layout.SIDES[if z < 0 then "North" else "South"].Color, Material = Enum.Material.Neon })
	end
end

local function buildSkyline(root: Instance)
	local city = folder(root, "Skyline")
	local rng = Random.new(42)
	for i = 1, 70 do
		local a = (i / 70) * math.pi * 2 + rng:NextNumber(-0.03, 0.03)
		local dist = rng:NextNumber(720, 1050)
		local h = rng:NextNumber(60, 260)
		local w = rng:NextNumber(40, 90)
		local pos = Vector3.new(math.cos(a) * dist * 1.25, h / 2, math.sin(a) * dist)
		local cf = CFrame.lookAt(pos, Vector3.new(0, h / 2, 0))
		part(city, { Name = "Tower", Size = Vector3.new(w, h, w * 0.7), CFrame = cf, Color = Color3.fromRGB(38, 34, 58), Material = Enum.Material.Concrete })
		-- A few lit window bands
		for b = 1, math.floor(h / 40) do
			if rng:NextNumber() < 0.6 then
				part(city, { Name = "Windows", Size = Vector3.new(w * 0.8, 2, 0.4), CFrame = cf * CFrame.new(0, -h / 2 + b * 40 - 10, -w * 0.35 - 0.3), Color = Color3.fromRGB(255, 205, 130), Material = Enum.Material.Neon })
			end
		end
	end
	part(city, { Name = "Ground", Size = Vector3.new(3000, 2, 3000), CFrame = CFrame.new(0, -2.2, 0), Color = Color3.fromRGB(44, 52, 46), Material = Enum.Material.Ground })
end

function Builder.Build(): Model
	local stadium = Instance.new("Model")
	stadium.Name = "Stadium"
	buildPitch(stadium)
	buildTrack(stadium)
	buildBarrier(stadium)
	local lower, upperTier = Layout.Tiers[1], Layout.Tiers[2]
	buildTier(stadium, lower, 0)
	buildBoxes(stadium)
	buildTier(stadium, upperTier, Layout.BOX_FLOOR + Layout.BOX_HEIGHT)
	buildRoof(stadium)
	buildMasts(stadium)
	buildJumbotrons(stadium)
	buildTunnels(stadium)
	buildSkyline(stadium)
	return stadium
end

return Builder
