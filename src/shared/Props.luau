--[[
	Props: each class's ball / bat and its cosmetics, built from plain parts (no uploads needed).

	The prop's handle is driven by the procedural animator through a Motor6D named SB_Prop (see
	Rig.luau), so dribbling, tucking and swinging are part of each pose. Clients also build loose copies
	(Props.BuildBall) for projectiles.
]]

local Props = {}

local PROP_HANDLE = "SB_PropHandle"
local PROP_MOTOR = "SB_Prop"
Props.HANDLE = PROP_HANDLE

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- A thin disc (cylinder) whose axis is `axis`, centred on `origin`.
local function disc(name: string, origin: CFrame, axis: Vector3, diameter: number, thickness: number, color: Color3): Part
	local d = part(name, Vector3.new(thickness, diameter, diameter), color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local up = if math.abs(axis.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local right = axis.Unit
	local back = right:Cross(up).Unit
	local trueUp = back:Cross(right).Unit
	d.CFrame = origin * CFrame.fromMatrix(Vector3.zero, right, trueUp, back)
	return d
end

--------------------------------------------------------------------------------
-- Balls
--------------------------------------------------------------------------------
local WHITE = Color3.fromRGB(245, 245, 245)
local BLACK = Color3.fromRGB(22, 22, 26)

Props.Radius = {
	Soccer = 0.55,
	Basketball = 0.6,
	Football = 0.42,
	Baseball = 0.3,
}

local function soccerBall(origin: CFrame): { Part }
	local r = Props.Radius.Soccer
	local core = part("Ball", Vector3.one * r * 2, WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	core.CFrame = origin
	local parts = { core }
	-- Black pentagons at the 12 vertices of an icosahedron
	local g = (1 + math.sqrt(5)) / 2
	local dirs = {
		Vector3.new(0, 1, g),
		Vector3.new(0, 1, -g),
		Vector3.new(0, -1, g),
		Vector3.new(0, -1, -g),
		Vector3.new(1, g, 0),
		Vector3.new(1, -g, 0),
		Vector3.new(-1, g, 0),
		Vector3.new(-1, -g, 0),
		Vector3.new(g, 0, 1),
		Vector3.new(g, 0, -1),
		Vector3.new(-g, 0, 1),
		Vector3.new(-g, 0, -1),
	}
	for i, d in dirs do
		local n = d.Unit
		local patch = disc("Patch" .. i, origin * CFrame.new(n * (r - 0.03)), n, r * 0.74, 0.08, BLACK)
		table.insert(parts, patch)
	end
	return parts
end

local function basketball(origin: CFrame): { Part }
	local r = Props.Radius.Basketball
	local core = part("Ball", Vector3.one * r * 2, Color3.fromRGB(226, 104, 28), Enum.Material.Fabric, Enum.PartType.Ball)
	core.CFrame = origin
	local parts = { core }
	local lineColor = Color3.fromRGB(30, 18, 12)
	for i, axis in { Vector3.xAxis, Vector3.zAxis, Vector3.yAxis } do
		table.insert(parts, disc("Seam" .. i, origin, axis, r * 2 + 0.03, 0.045, lineColor))
	end
	return parts
end

local function football(origin: CFrame): { Part }
	local r = Props.Radius.Football
	local core = part("Ball", Vector3.new(r * 1.75, r * 1.75, r * 3.1), Color3.fromRGB(122, 58, 28), Enum.Material.Fabric)
	core.CFrame = origin
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = core
	local parts = { core }
	local top = r * 0.86
	local lace = part("Lace", Vector3.new(0.07, 0.05, r * 1.25), WHITE)
	lace.CFrame = origin * CFrame.new(0, top, 0)
	table.insert(parts, lace)
	for i = -2, 2 do
		local bar = part("LaceBar", Vector3.new(0.22, 0.05, 0.05), WHITE)
		bar.CFrame = origin * CFrame.new(0, top - 0.01, i * r * 0.22)
		table.insert(parts, bar)
	end
	-- White stripes near the tips
	for _, z in { -1, 1 } do
		local stripe = disc("Stripe", origin * CFrame.new(0, 0, z * r * 1.05), Vector3.zAxis, r * 1.42, 0.06, WHITE)
		table.insert(parts, stripe)
	end
	return parts
end

local function baseball(origin: CFrame): { Part }
	local r = Props.Radius.Baseball
	local core = part("Ball", Vector3.one * r * 2, WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	core.CFrame = origin
	local parts = { core }
	local red = Color3.fromRGB(205, 30, 40)
	table.insert(parts, disc("Stitch1", origin * CFrame.Angles(0, 0, math.rad(35)), Vector3.xAxis, r * 2 + 0.02, 0.035, red))
	table.insert(parts, disc("Stitch2", origin * CFrame.Angles(0, 0, math.rad(-35)), Vector3.xAxis, r * 2 + 0.02, 0.035, red))
	return parts
end

local BALLS: { [string]: (CFrame) -> { Part } } = {
	Soccer = soccerBall,
	Basketball = basketball,
	Football = football,
	Baseball = baseball,
}

-- A loose ball model (projectiles, held baseballs). PrimaryPart is the core sphere.
function Props.BuildBall(classId: string, anchored: boolean?): Model
	local model = Instance.new("Model")
	model.Name = classId .. "Ball"
	local build: (CFrame) -> { Part } = BALLS[classId] or soccerBall
	local parts = build(CFrame.identity)
	local core = parts[1]
	for i, p in parts do
		p.Anchored = anchored == true
		p.Parent = model
		if i > 1 and not anchored then
			weld(core, p)
		end
	end
	model.PrimaryPart = core
	return model
end

--------------------------------------------------------------------------------
-- Bat
--------------------------------------------------------------------------------
local function bat(origin: CFrame): { Part }
	-- Along +Y of origin (the grip), knob at the bottom
	local wood = Color3.fromRGB(196, 150, 96)
	local dark = Color3.fromRGB(70, 40, 25)
	local up = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis (X) -> Y
	local parts: { Part } = {}
	local function seg(name: string, y: number, length: number, diameter: number, color: Color3)
		local s = part(name, Vector3.new(length, diameter, diameter), color, Enum.Material.Wood, Enum.PartType.Cylinder)
		s.CFrame = origin * CFrame.new(0, y, 0) * up
		table.insert(parts, s)
	end
	seg("Knob", -0.38, 0.12, 0.34, dark)
	seg("Grip", -0.05, 0.62, 0.21, dark)
	seg("Handle", 0.75, 1.0, 0.24, wood)
	seg("Taper", 1.45, 0.5, 0.33, wood)
	seg("Barrel", 2.25, 1.2, 0.44, wood)
	local cap = part("Cap", Vector3.one * 0.44, wood, Enum.Material.Wood, Enum.PartType.Ball)
	cap.CFrame = origin * CFrame.new(0, 2.85, 0)
	table.insert(parts, cap)
	return parts
end

--------------------------------------------------------------------------------
-- Attaching to a character
--------------------------------------------------------------------------------
export type PropInfo = {
	Part0: string,
	Build: (CFrame) -> { Part },
	RestC0: (character: Model) -> CFrame,
}

local function groundY(character: Model): number
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local hip = if humanoid then humanoid.HipHeight else 2
	local half = if root and root:IsA("BasePart") then root.Size.Y / 2 else 1
	return -(hip + half)
end

Props.Info = {
	Soccer = {
		Part0 = "HumanoidRootPart",
		Build = soccerBall,
		RestC0 = function(character: Model): CFrame
			return CFrame.new(0.5, groundY(character) + Props.Radius.Soccer, -1.0)
		end,
	},
	Basketball = {
		Part0 = "HumanoidRootPart",
		Build = basketball,
		RestC0 = function(character: Model): CFrame
			return CFrame.new(1.4, groundY(character) + Props.Radius.Basketball, -0.45)
		end,
	},
	Football = {
		Part0 = "RightHand",
		Build = football,
		RestC0 = function(_character: Model): CFrame
			-- Cradled along the inside of the forearm, tip pointing up the arm
			return CFrame.new(-0.45, 0.55, -0.15) * CFrame.Angles(math.pi / 2, 0, 0)
		end,
	},
	Baseball = {
		Part0 = "RightHand",
		Build = bat,
		RestC0 = function(_character: Model): CFrame
			-- Bat sticks out forward from the fist
			return CFrame.new(0, -0.05, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
		end,
	},
} :: { [string]: PropInfo }

-- Cosmetics welded to the body: armband, headband, shoulder pads, cap.
local function cosmetics(character: Model, classId: string): { Part }
	local out: { Part } = {}
	local function onPart(name: string): BasePart?
		local p = character:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end
	if classId == "Soccer" then
		local arm = onPart("LeftUpperArm")
		if arm then
			local band = part("SB_Armband", Vector3.new(0.28, arm.Size.X * 1.08, arm.Size.Z * 1.08), Color3.fromRGB(40, 140, 255), Enum.Material.Fabric, Enum.PartType.Cylinder)
			band.CFrame = arm.CFrame * CFrame.new(0, arm.Size.Y * 0.18, 0) * CFrame.Angles(0, 0, math.pi / 2)
			weld(arm, band)
			table.insert(out, band)
		end
	elseif classId == "Basketball" then
		local head = onPart("Head")
		if head then
			local band = part("SB_Headband", Vector3.new(0.26, head.Size.X * 1.06, head.Size.Z * 1.06), WHITE, Enum.Material.Fabric, Enum.PartType.Cylinder)
			band.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2)
			weld(head, band)
			table.insert(out, band)
			local stripe = part("SB_HeadbandStripe", Vector3.new(0.08, head.Size.X * 1.08, head.Size.Z * 1.08), Color3.fromRGB(255, 120, 20), Enum.Material.Fabric, Enum.PartType.Cylinder)
			stripe.CFrame = band.CFrame
			weld(head, stripe)
			table.insert(out, stripe)
		end
		local hand = onPart("RightLowerArm")
		if hand then
			local wrist = part("SB_Wristband", Vector3.new(0.3, hand.Size.X * 1.1, hand.Size.Z * 1.1), Color3.fromRGB(255, 120, 20), Enum.Material.Fabric, Enum.PartType.Cylinder)
			wrist.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.32, 0) * CFrame.Angles(0, 0, math.pi / 2)
			weld(hand, wrist)
			table.insert(out, wrist)
		end
	elseif classId == "Football" then
		local torso = onPart("UpperTorso")
		if torso then
			local purple = Color3.fromRGB(110, 40, 200)
			for _, side in { -1, 1 } do
				local pad = part("SB_ShoulderPad", Vector3.new(1.35, 0.55, 1.35), purple, Enum.Material.SmoothPlastic)
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = pad
				pad.CFrame = torso.CFrame * CFrame.new(side * torso.Size.X * 0.42, torso.Size.Y * 0.5, 0) * CFrame.Angles(0, 0, math.rad(-side * 14))
				weld(torso, pad)
				table.insert(out, pad)
			end
			local collar = part("SB_PadCollar", Vector3.new(torso.Size.X * 0.7, 0.28, torso.Size.Z * 1.15), WHITE)
			collar.CFrame = torso.CFrame * CFrame.new(0, torso.Size.Y * 0.47, 0)
			weld(torso, collar)
			table.insert(out, collar)
		end
	elseif classId == "Baseball" then
		local head = onPart("Head")
		if head then
			local green = Color3.fromRGB(20, 120, 60)
			local dome = part("SB_Cap", Vector3.new(head.Size.X * 1.06, head.Size.Y * 0.75, head.Size.Z * 1.06), green, Enum.Material.Fabric)
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = dome
			dome.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.3, 0)
			weld(head, dome)
			table.insert(out, dome)
			local brim = part("SB_CapBrim", Vector3.new(0.06, head.Size.X * 0.9, head.Size.Z * 0.9), green, Enum.Material.Fabric, Enum.PartType.Cylinder)
			brim.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.2, -head.Size.Z * 0.42) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(math.rad(8), 0, 0)
			weld(head, brim)
			table.insert(out, brim)
			local button = part("SB_CapButton", Vector3.one * 0.14, WHITE, Enum.Material.Fabric, Enum.PartType.Ball)
			button.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.66, 0)
			weld(head, button)
			table.insert(out, button)
		end
	end
	return out
end

-- Removes any previous prop, then builds the class's prop and cosmetics onto the character.
function Props.Attach(character: Model, classId: string): BasePart?
	for _, child in character:GetChildren() do
		if child.Name == "SB_Props" then
			child:Destroy()
		end
	end
	local info = Props.Info[classId]
	if not info then
		return nil
	end
	local part0 = character:FindFirstChild(info.Part0)
	if not part0 or not part0:IsA("BasePart") then
		return nil
	end
	local folder = Instance.new("Model")
	folder.Name = "SB_Props"

	local rest = info.RestC0(character)
	local handle = part(PROP_HANDLE, Vector3.one * 0.2, WHITE)
	handle.Transparency = 1
	handle.CFrame = part0.CFrame * rest
	handle.Parent = folder
	for _, p in info.Build(handle.CFrame) do
		p.Parent = folder
		weld(handle, p)
	end
	for _, p in cosmetics(character, classId) do
		p.Parent = folder
	end
	local motor = Instance.new("Motor6D")
	motor.Name = PROP_MOTOR
	motor.Part0 = part0
	motor.Part1 = handle
	motor.C0 = rest
	motor.C1 = CFrame.identity
	motor.Parent = handle
	folder.Parent = character
	return handle
end

-- Every visible part of the attached prop (to hide it while the ball is in flight).
function Props.Visible(character: Model): { BasePart }
	local out: { BasePart } = {}
	local folder = character:FindFirstChild("SB_Props")
	if folder then
		for _, d in folder:GetChildren() do
			if d:IsA("BasePart") and d.Name ~= PROP_HANDLE and string.sub(d.Name, 1, 3) ~= "SB_" then
				table.insert(out, d)
			end
		end
	end
	return out
end

return Props
