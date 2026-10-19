--[[
	Stadium layout: every dimension of the bowl, shared by the map builder (server / offline bake) and
	the crowd (client), so fans always sit exactly on the seats.

	The arena floor is a rounded rectangle centred on the origin: the pitch, a running track around it
	and then a barrier where the stands begin. The stands are rows offset outwards from that barrier,
	so each row is the same rounded rectangle, grown by the row's distance.

	Each side stand is themed after one sport: North = Soccer (blue), East = Basketball (orange),
	South = Football (purple), West = Baseball (green).
]]

local Layout = {}

-- Real-world scale, in Roblox's own units: 1 stud = 0.28 m (create.roblox.com/docs/physics/units), the
-- scale avatars are designed at. The measurements below are real ones (metres) converted with it, so
-- goals, seats, stands and fans are sized for the players standing next to them.
Layout.STUDS_PER_METER = 1 / 0.28
local M = Layout.STUDS_PER_METER

-- Stretches the playing area (pitch, markings) for more room to fight, without growing goals, seats,
-- fans or players. 1 = a regulation pitch.
Layout.FIELD_SCALE = 1

-- The pitch: regulation 105 x 68 m.
Layout.PITCH_HALF_X = 105 / 2 * M * Layout.FIELD_SCALE
Layout.PITCH_HALF_Z = 68 / 2 * M * Layout.FIELD_SCALE
-- Run-off and track between the pitch and the barrier: behind the goals / along the touchlines.
Layout.RUNOFF_X = 10.5 * M
Layout.RUNOFF_Z = 9 * M
Layout.BARRIER_HALF_X = Layout.PITCH_HALF_X + Layout.RUNOFF_X
Layout.BARRIER_HALF_Z = Layout.PITCH_HALF_Z + Layout.RUNOFF_Z
Layout.CORNER_RADIUS = 15 * M
Layout.BARRIER_HEIGHT = 2 * M -- the wall in front of the first row (with LED boards on it)

export type Tier = {
	Name: string,
	FirstRow: number,
	Rows: number,
	Start: number, -- distance from the barrier where the tier begins
	BaseHeight: number, -- floor height of the first row
	Depth: number, -- row depth
	Rise: number, -- height gained per row
}

-- Rows: 0.82 m deep (seat pitch), rising 0.4 m in the shallow lower tier and 0.56 m in the steep upper.
local ROW_DEPTH = 0.82 * M
local LOWER_ROWS, UPPER_ROWS = 22, 26
local lowerTop = Layout.BARRIER_HEIGHT + 0.5 + LOWER_ROWS * 0.4 * M

-- The ring of private boxes between the tiers
Layout.BOX_START = 0.7 * M + LOWER_ROWS * ROW_DEPTH + 0.5 * M
Layout.BOX_DEPTH = 3.3 * M
Layout.BOX_FLOOR = math.ceil(lowerTop)
Layout.BOX_HEIGHT = 4.5 * M

Layout.Tiers = {
	{ Name = "Lower", FirstRow = 0, Rows = LOWER_ROWS, Start = 0.7 * M, BaseHeight = Layout.BARRIER_HEIGHT + 0.5, Depth = ROW_DEPTH, Rise = 0.4 * M },
	{
		Name = "Upper",
		FirstRow = LOWER_ROWS,
		Rows = UPPER_ROWS,
		Start = Layout.BOX_START + Layout.BOX_DEPTH + 0.5,
		BaseHeight = Layout.BOX_FLOOR + Layout.BOX_HEIGHT + 0.5 * M,
		Depth = ROW_DEPTH,
		Rise = 0.56 * M,
	},
} :: { Tier }

local upper = Layout.Tiers[2]
Layout.ROOF_START = upper.Start + upper.Rows * upper.Depth - 18 -- the canopy overhangs the top rows
Layout.ROOF_DEPTH = 40
Layout.ROOF_HEIGHT = upper.BaseHeight + upper.Rows * upper.Rise + 22
Layout.OUTER_DISTANCE = upper.Start + upper.Rows * upper.Depth + 4

Layout.SIDES = {
	North = { Theme = "Soccer", Color = Color3.fromRGB(30, 110, 230), Alt = Color3.fromRGB(235, 240, 255) },
	East = { Theme = "Basketball", Color = Color3.fromRGB(240, 110, 20), Alt = Color3.fromRGB(30, 30, 35) },
	South = { Theme = "Football", Color = Color3.fromRGB(120, 40, 200), Alt = Color3.fromRGB(245, 205, 60) },
	West = { Theme = "Baseball", Color = Color3.fromRGB(25, 150, 70), Alt = Color3.fromRGB(240, 240, 240) },
}

--------------------------------------------------------------------------------
-- The rounded-rectangle path, grown by `offset` studs
--------------------------------------------------------------------------------
local STRAIGHT_X = Layout.BARRIER_HALF_X - Layout.CORNER_RADIUS -- half length of the long straights
local STRAIGHT_Z = Layout.BARRIER_HALF_Z - Layout.CORNER_RADIUS

export type Segment = {
	Kind: "Straight" | "Corner",
	Side: string, -- North / East / South / West, or the corner name (NorthEast...)
	Length: number,
	-- Straights
	From: Vector3?,
	To: Vector3?,
	Normal: Vector3?,
	-- Corners
	Center: Vector3?,
	Radius: number?,
	A0: number?, -- start angle (radians, x = cos, z = sin)
	A1: number?,
}

function Layout.Path(offset: number): { Segment }
	local r = Layout.CORNER_RADIUS + offset
	local ax = Layout.BARRIER_HALF_X + offset
	local az = Layout.BARRIER_HALF_Z + offset
	local function straight(side: string, from: Vector3, to: Vector3, normal: Vector3): Segment
		return { Kind = "Straight", Side = side, Length = (to - from).Magnitude, From = from, To = to, Normal = normal }
	end
	local function corner(side: string, cx: number, cz: number, a0: number): Segment
		return { Kind = "Corner", Side = side, Length = r * math.pi / 2, Center = Vector3.new(cx, 0, cz), Radius = r, A0 = a0, A1 = a0 + math.pi / 2 }
	end
	return {
		straight("North", Vector3.new(-STRAIGHT_X, 0, -az), Vector3.new(STRAIGHT_X, 0, -az), Vector3.new(0, 0, -1)),
		corner("NorthEast", STRAIGHT_X, -STRAIGHT_Z, -math.pi / 2),
		straight("East", Vector3.new(ax, 0, -STRAIGHT_Z), Vector3.new(ax, 0, STRAIGHT_Z), Vector3.new(1, 0, 0)),
		corner("SouthEast", STRAIGHT_X, STRAIGHT_Z, 0),
		straight("South", Vector3.new(STRAIGHT_X, 0, az), Vector3.new(-STRAIGHT_X, 0, az), Vector3.new(0, 0, 1)),
		corner("SouthWest", -STRAIGHT_X, STRAIGHT_Z, math.pi / 2),
		straight("West", Vector3.new(-ax, 0, STRAIGHT_Z), Vector3.new(-ax, 0, -STRAIGHT_Z), Vector3.new(-1, 0, 0)),
		corner("NorthWest", -STRAIGHT_X, -STRAIGHT_Z, math.pi),
	}
end

function Layout.Perimeter(offset: number): number
	local total = 0
	for _, segment in Layout.Path(offset) do
		total += segment.Length
	end
	return total
end

-- Point and outward normal at distance `s` along the path (wraps around).
function Layout.PointAt(path: { Segment }, s: number): (Vector3, Vector3, string)
	local total = 0
	for _, segment in path do
		total += segment.Length
	end
	s = s % total
	for _, segment in path do
		if s <= segment.Length then
			local t = s / segment.Length
			if segment.Kind == "Straight" then
				local from, to = segment.From :: Vector3, segment.To :: Vector3
				return from:Lerp(to, t), segment.Normal :: Vector3, segment.Side
			end
			local a = (segment.A0 :: number) + ((segment.A1 :: number) - (segment.A0 :: number)) * t
			local normal = Vector3.new(math.cos(a), 0, math.sin(a))
			return (segment.Center :: Vector3) + normal * (segment.Radius :: number), normal, segment.Side
		end
		s -= segment.Length
	end
	local first = path[1]
	return first.From :: Vector3, first.Normal :: Vector3, first.Side
end

-- Row geometry: distance from the barrier (seat centre) and floor height.
export type Row = { Index: number, Tier: Tier, Offset: number, Height: number }

function Layout.Rows(): { Row }
	local rows: { Row } = {}
	for _, tier in Layout.Tiers do
		for i = 0, tier.Rows - 1 do
			table.insert(rows, {
				Index = tier.FirstRow + i,
				Tier = tier,
				Offset = tier.Start + (i + 0.5) * tier.Depth,
				Height = tier.BaseHeight + (i + 1) * tier.Rise,
			})
		end
	end
	return rows
end

-- Which themed side a position belongs to (corners split down the diagonal).
function Layout.SideOf(position: Vector3): string
	local x = position.X / Layout.BARRIER_HALF_X
	local z = position.Z / Layout.BARRIER_HALF_Z
	if math.abs(x) > math.abs(z) then
		return if x > 0 then "East" else "West"
	end
	return if z > 0 then "South" else "North"
end

-- How far `position` is inside the barrier's rounded rectangle (studs, negative = outside), and the
-- outward normal of the nearest stretch of wall. Movement uses these to stop at the edge of the arena.
function Layout.InsideDistance(position: Vector3): number
	local r = Layout.CORNER_RADIUS
	local qx = math.abs(position.X) - (Layout.BARRIER_HALF_X - r)
	local qz = math.abs(position.Z) - (Layout.BARRIER_HALF_Z - r)
	local outside = math.sqrt(math.max(qx, 0) ^ 2 + math.max(qz, 0) ^ 2) + math.min(math.max(qx, qz), 0) - r
	return -outside
end

function Layout.WallNormal(position: Vector3): Vector3
	local r = Layout.CORNER_RADIUS
	local sx = if position.X < 0 then -1 else 1
	local sz = if position.Z < 0 then -1 else 1
	local qx = math.abs(position.X) - (Layout.BARRIER_HALF_X - r)
	local qz = math.abs(position.Z) - (Layout.BARRIER_HALF_Z - r)
	if qx > 0 and qz > 0 then
		return Vector3.new(qx * sx, 0, qz * sz).Unit
	elseif qx > qz then
		return Vector3.new(sx, 0, 0)
	end
	return Vector3.new(0, 0, sz)
end

-- A random point on the pitch to spawn at (feet on the ground, y = HumanoidRootPart height).
function Layout.RandomSpawn(rng: Random): Vector3
	local x = rng:NextNumber(-Layout.PITCH_HALF_X + 20, Layout.PITCH_HALF_X - 20)
	local z = rng:NextNumber(-Layout.PITCH_HALF_Z + 15, Layout.PITCH_HALF_Z - 15)
	return Vector3.new(x, 4, z)
end

-- The practice noob stands on the centre spot, facing the west goal.
function Layout.CenterSpot(): CFrame
	return CFrame.lookAt(Vector3.new(0, 3, 0), Vector3.new(-1, 3, 0))
end

-- Training dummies stand on the track behind the east goal.
function Layout.DummySpots(count: number): { CFrame }
	local spots: { CFrame } = {}
	local x = Layout.PITCH_HALF_X + 5.5 * M
	for i = 1, count do
		local z = (i - (count + 1) / 2) * 12
		table.insert(spots, CFrame.lookAt(Vector3.new(x, 3, z), Vector3.new(0, 3, z)))
	end
	return spots
end

return Layout
