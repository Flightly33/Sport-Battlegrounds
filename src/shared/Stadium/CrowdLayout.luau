--[[
	CrowdLayout: where every fan stands and what they wear. Deterministic (seeded), so every client
	builds the same crowd. Used by Client/Crowd.luau (and the offline preview).

	Fans are "tiny colourful silhouettes": a block body and a ball head, in bright colours, with a bias
	towards each stand's team colour (blue Soccer end, orange Basketball side...).
]]

local Layout = require(script.Parent.Layout)

local CrowdLayout = {}

CrowdLayout.SPACING = 2.3 -- studs between seat slots along a row

local BRIGHT = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(60, 200, 255),
	Color3.fromRGB(120, 230, 90),
	Color3.fromRGB(255, 120, 200),
	Color3.fromRGB(255, 150, 40),
	Color3.fromRGB(170, 110, 255),
	Color3.fromRGB(245, 245, 245),
	Color3.fromRGB(40, 40, 50),
	Color3.fromRGB(80, 255, 220),
}

export type Fan = {
	Position: Vector3, -- feet
	Facing: Vector3, -- towards the pitch
	Color: Color3,
	Scale: number,
	Phase: number,
	S: number, -- distance around the bowl (for the Mexican wave), 0..1
	Side: string,
	Energy: number, -- 0.5..1.5, how much this fan jumps around
}

local function sideColor(side: string): Color3
	local s = Layout.SIDES[side]
	return if s then s.Color else BRIGHT[1]
end

-- Builds about `target` fans.
function CrowdLayout.Generate(target: number, seed: number?): { Fan }
	local rng = Random.new(seed or 2026)
	local rows = Layout.Rows()
	local totalSlots = 0
	for _, row in rows do
		totalSlots += Layout.Perimeter(row.Offset) / CrowdLayout.SPACING
	end
	local base = math.clamp(target / totalSlots, 0, 1)
	local fans: { Fan } = {}
	for _, row in rows do
		local path = Layout.Path(row.Offset)
		local perimeter = Layout.Perimeter(row.Offset)
		local slots = math.floor(perimeter / CrowdLayout.SPACING)
		local tierBias = if row.Tier.Name == "Lower" then 1.3 else 0.85
		for i = 0, slots - 1 do
			local s = (i + rng:NextNumber(-0.3, 0.3)) * CrowdLayout.SPACING
			-- Sections fill unevenly (packed home ends, patchier corners)
			local section = math.noise(s / 60, row.Index / 9, 3.7) * 0.6 + 1
			if rng:NextNumber() < base * tierBias * section then
				local point, normal = Layout.PointAt(path, s)
				local side = Layout.SideOf(point)
				local color = if rng:NextNumber() < 0.42 then sideColor(side) else BRIGHT[rng:NextInteger(1, #BRIGHT)]
				local radial = rng:NextNumber(-0.35, 0.25)
				table.insert(fans, {
					Position = Vector3.new(point.X, row.Height, point.Z) + normal * radial,
					Facing = -normal,
					Color = color,
					Scale = rng:NextNumber(0.88, 1.12),
					Phase = rng:NextNumber(0, math.pi * 2),
					S = s / perimeter,
					Side = side,
					Energy = rng:NextNumber(0.5, 1.5),
				})
			end
		end
	end
	return fans
end

-- Body / head sizes for a fan (studs).
function CrowdLayout.BodySize(scale: number): Vector3
	return Vector3.new(1.6, 1.95, 0.85) * scale
end

function CrowdLayout.HeadSize(scale: number): Vector3
	return Vector3.one * 1.12 * scale
end

return CrowdLayout
