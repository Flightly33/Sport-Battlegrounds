--[[
	Crowd: thousands of tiny colourful fans in the stands, cheering and throwing confetti.

	Built by each client from Shared/Stadium/CrowdLayout (same seed for everyone), so nothing about the
	crowd replicates. Mobile builds fewer fans (Config.Crowd.DefaultDensity).

	Animation runs in slices (a third of the fans per frame, only those in front of the camera), moved
	with workspace:BulkMoveTo. They bounce to their own rhythm, a Mexican wave rolls around the bowl
	now and then, and big moments (heavy hits, KOs, awakenings) make the whole stadium jump and fire
	confetti cannons.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CrowdLayout = require(Shared.Stadium.CrowdLayout)
local Layout = require(Shared.Stadium.Layout)
local Remotes = require(Shared.Remotes)

local HitFeedback = require(script.Parent.HitFeedback)

local Crowd = {}

local FAN_TARGET = 6500
local CONFETTI_POOL = { Desktop = 360, Mobile = 140 }
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 70, 90),
	Color3.fromRGB(255, 210, 50),
	Color3.fromRGB(60, 190, 255),
	Color3.fromRGB(110, 235, 110),
	Color3.fromRGB(255, 120, 220),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(170, 110, 255),
}

type FanRuntime = {
	Body: Part,
	Head: Part,
	Base: CFrame,
	HeadOffset: number,
	Phase: number,
	S: number,
	Energy: number,
	Position: Vector3,
}

local fans: { FanRuntime } = {}
local hype = 0.25
local waveStart = -100
local slice = 0
local folder: Folder

local function isMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function newPart(size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = size
	p.Color = color
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function build()
	local density = if isMobile() then Config.Crowd.DefaultDensity.Mobile else Config.Crowd.DefaultDensity.Desktop
	local layout = CrowdLayout.Generate(math.floor(FAN_TARGET * density), 2026)
	for i, fan in layout do
		local bodySize = CrowdLayout.BodySize(fan.Scale)
		local headSize = CrowdLayout.HeadSize(fan.Scale)
		local base = CFrame.lookAt(fan.Position, fan.Position + fan.Facing)
		local body = newPart(bodySize, fan.Color)
		local skin = if i % 3 == 0 then Color3.fromRGB(110, 75, 55) elseif i % 3 == 1 then Color3.fromRGB(235, 195, 160) else Color3.fromRGB(190, 140, 100)
		local head = newPart(headSize, skin, Enum.PartType.Ball)
		body.CFrame = base * CFrame.new(0, bodySize.Y / 2, 0)
		head.CFrame = base * CFrame.new(0, bodySize.Y + headSize.Y * 0.45, 0)
		body.Parent = folder
		head.Parent = folder
		table.insert(fans, {
			Body = body,
			Head = head,
			Base = base,
			HeadOffset = bodySize.Y + headSize.Y * 0.45 - bodySize.Y / 2,
			Phase = fan.Phase,
			S = fan.S,
			Energy = fan.Energy,
			Position = fan.Position,
		})
		if i % 400 == 0 then
			task.wait() -- spread the build over a few frames
		end
	end
end

--------------------------------------------------------------------------------
-- Confetti
--------------------------------------------------------------------------------
type Piece = { Part: Part, Velocity: Vector3, Spin: CFrame, Age: number, Life: number, Flutter: number, Active: boolean }
local pieces: { Piece } = {}
local nextPiece = 1

local function confettiBurst(origin: Vector3, direction: Vector3, count: number, power: number)
	for _ = 1, count do
		local piece = pieces[nextPiece]
		nextPiece = nextPiece % #pieces + 1
		if piece then
			local spread = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5) * 1.2
			piece.Velocity = (direction + spread).Unit * power * (0.6 + math.random() * 0.6)
			piece.Part.CFrame = CFrame.new(origin) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			piece.Part.Transparency = 0
			piece.Age = 0
			piece.Life = 3.5 + math.random() * 2
			piece.Flutter = math.random() * 10
			piece.Active = true
		end
	end
end

-- A burst thrown by fans somewhere in the stands.
local function standBurst()
	if #fans == 0 then
		return
	end
	local fan = fans[math.random(1, #fans)]
	local inward = fan.Base.LookVector
	confettiBurst(fan.Position + Vector3.new(0, 3, 0), inward * 0.6 + Vector3.new(0, 1, 0), 18, 32)
end

-- Cannons at the four corners of the pitch, over the field.
function Crowd.Cannons()
	local hx, hz = Layout.PITCH_HALF_X + 10, Layout.PITCH_HALF_Z + 8
	for _, c in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
		local origin = Vector3.new(c[1] * hx, 1, c[2] * hz)
		local toCenter = (Vector3.zero - origin).Unit
		confettiBurst(origin, toCenter * 0.5 + Vector3.new(0, 1, 0), 45, 75)
	end
end

local function updateConfetti(dt: number)
	local parts, cframes = {}, {}
	for _, piece in pieces do
		if piece.Active then
			piece.Age += dt
			if piece.Age >= piece.Life then
				piece.Active = false
				piece.Part.Transparency = 1
			else
				-- Drag + light gravity + flutter: paper falls slowly and swings side to side
				piece.Velocity = piece.Velocity * (1 - math.min(1, dt * 1.6)) + Vector3.new(0, -32 * dt, 0)
				local flutter = Vector3.new(math.sin(piece.Age * 6 + piece.Flutter), 0, math.cos(piece.Age * 5 + piece.Flutter)) * 2.5
				local cf = piece.Part.CFrame
				table.insert(parts, piece.Part)
				table.insert(cframes, (cf * piece.Spin) + (piece.Velocity + flutter) * dt)
				if piece.Life - piece.Age < 0.6 then
					piece.Part.Transparency = 1 - (piece.Life - piece.Age) / 0.6
				end
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

--------------------------------------------------------------------------------
-- Animation
--------------------------------------------------------------------------------
local function update(dt: number)
	local camera = workspace.CurrentCamera
	if not camera or #fans == 0 then
		return
	end
	hype = math.max(0.25, hype - dt * 0.12)
	local t = os.clock()
	local camPos = camera.CFrame.Position
	local camLook = camera.CFrame.LookVector
	local maxDistance = Config.Crowd.AnimateDistance
	-- Mexican wave: a band rolling around the bowl
	local waveAge = t - waveStart
	local waveS = (waveAge * 0.09) % 1
	local waveOn = waveAge < 11

	local slices = 3
	slice = slice % slices + 1
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for i = slice, #fans, slices do
		local fan = fans[i]
		local offset = fan.Position - camPos
		if offset:Dot(camLook) > -20 and offset.Magnitude < maxDistance then
			local bounce = math.abs(math.sin(t * (3.2 + fan.Energy) + fan.Phase)) * 0.55 * hype * fan.Energy
			local sway = math.sin(t * 1.3 + fan.Phase) * 0.12
			if waveOn then
				local d = math.abs(fan.S - waveS)
				d = math.min(d, 1 - d)
				if d < 0.012 then
					bounce += (1 - d / 0.012) * 2.2
				end
			end
			local cf = fan.Base * CFrame.new(0, bounce, 0) * CFrame.Angles(0, 0, sway)
			local body = cf * CFrame.new(0, fan.Body.Size.Y / 2, 0)
			table.insert(parts, fan.Body)
			table.insert(cframes, body)
			table.insert(parts, fan.Head)
			table.insert(cframes, body * CFrame.new(0, fan.HeadOffset, 0))
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Crowd.Hype(amount: number)
	hype = math.min(2.2, hype + amount)
end

function Crowd.Wave()
	waveStart = os.clock()
end

function Crowd.Init()
	folder = Instance.new("Folder")
	folder.Name = "Crowd"
	folder.Parent = workspace

	local poolSize = if isMobile() then CONFETTI_POOL.Mobile else CONFETTI_POOL.Desktop
	for i = 1, poolSize do
		local p = newPart(Vector3.new(0.5, 0.05, 0.32), CONFETTI_COLORS[(i % #CONFETTI_COLORS) + 1])
		p.Transparency = 1
		p.Material = Enum.Material.Neon
		p.CFrame = CFrame.new(0, -500, 0)
		p.Parent = folder
		table.insert(pieces, {
			Part = p,
			Velocity = Vector3.zero,
			Spin = CFrame.Angles(math.random() * 0.3, math.random() * 0.3, math.random() * 0.3),
			Age = 0,
			Life = 0,
			Flutter = 0,
			Active = false,
		})
	end

	task.spawn(build)

	RunService.RenderStepped:Connect(function(dt)
		update(dt)
		updateConfetti(dt)
	end)

	-- Confetti thrown from the stands all match long; more when the crowd is hyped
	task.spawn(function()
		while true do
			task.wait(1 / (Config.Crowd.ConfettiRate * (0.6 + hype)))
			standBurst()
		end
	end)
	-- A Mexican wave every so often
	task.spawn(function()
		task.wait(12)
		while true do
			Crowd.Wave()
			task.wait(45 + math.random() * 40)
		end
	end)

	HitFeedback.Hype:Connect(function(amount: number)
		Crowd.Hype(amount)
		if amount >= 1 then
			Crowd.Cannons()
		end
	end)
	Remotes.Event("Announce").OnClientEvent:Connect(function()
		Crowd.Hype(1.2)
		Crowd.Cannons()
	end)
end

return Crowd
