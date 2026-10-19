--[[
	StadiumFX: the stadium coming alive, drawn locally.
		LED boards / ribbon boards   scrolling text in each stand's colours, flashing on big moments
		Jumbotrons                   title card, announcements, the kill feed and the top KOs
		Floodlights                  soft light shafts from the masts and the roof onto the pitch, and the
		                             light grid that lights the pitch for the night match
		Crowd ambience               (only if a sound id is set in Shared/AssetIds)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Layout = require(Shared.Stadium.Layout)
local Characters = require(Shared.Characters)
local Remotes = require(Shared.Remotes)

local Sound = require(script.Parent.Sound)

local StadiumFX = {}

local TICKER = "SPORTS BATTLEGROUNDS   ★   SOCCER   ★   BASKETBALL   ★   FOOTBALL   ★   BASEBALL   ★   "
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

type Board = { Part: BasePart, Label: TextLabel, Base: Color3, Speed: number }
local boards: { Board } = {}
local flashUntil = 0
local flashText = ""
local flashColor = Color3.new(1, 1, 1)

type Screen = { Gui: SurfaceGui, Headline: TextLabel, Sub: TextLabel, Feed: TextLabel, Top: TextLabel }
local screens: { Screen } = {}
local feed: { string } = {}

local function stadium(): Instance?
	return workspace:FindFirstChild("Stadium") or workspace:WaitForChild("Stadium", 30)
end

--------------------------------------------------------------------------------
-- LED boards
--------------------------------------------------------------------------------
local function makeBoard(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- the face looking at the pitch
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 14
	gui.LightInfluence = 0
	gui.Brightness = 2.2
	gui.ClipsDescendants = true
	gui.Adornee = part
	gui.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.new(0.02, 0.02, 0.04)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 4000, 1, 0)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = string.rep(TICKER, 3)
	label.TextScaled = true
	label.FontFace = FONT
	label.TextColor3 = part.Color
	label.Parent = bg
	table.insert(boards, { Part = part, Label = label, Base = part.Color, Speed = 60 + math.random() * 30 })
end

local function updateBoards()
	local t = os.clock()
	local flashing = t < flashUntil
	for i, board in boards do
		local label = board.Label
		if flashing then
			label.Text = string.rep(flashText .. "   ", 12)
			label.TextColor3 = if math.floor(t * 8) % 2 == 0 then flashColor else Color3.new(1, 1, 1)
			label.Position = UDim2.fromOffset(-math.floor((t * 300 + i * 40) % 600), 0)
		else
			if label.Text ~= string.rep(TICKER, 3) then
				label.Text = string.rep(TICKER, 3)
			end
			-- Slow colour drift around the stand's own colour
			local pulse = (math.sin(t * 1.5 + i * 0.4) + 1) * 0.5
			label.TextColor3 = board.Base:Lerp(Color3.new(1, 1, 1), pulse * 0.35)
			label.Position = UDim2.fromOffset(-math.floor((t * board.Speed + i * 120) % 1400), 0)
		end
	end
end

function StadiumFX.Flash(text: string, color: Color3, duration: number)
	flashText = string.upper(text)
	flashColor = color
	flashUntil = os.clock() + duration
end

--------------------------------------------------------------------------------
-- Jumbotrons
--------------------------------------------------------------------------------
local function makeScreen(part: BasePart)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.Adornee = part
	gui.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BorderSizePixel = 0
	bg.BackgroundColor3 = Color3.fromRGB(10, 12, 30)
	bg.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 110, 230)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(240, 110, 20)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(120, 40, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 150, 70)),
	})
	gradient.Transparency = NumberSequence.new(0.75)
	gradient.Rotation = 20
	gradient.Parent = bg
	local function label(y: number, h: number, size: number?): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.04, y)
		l.Size = UDim2.fromScale(0.92, h)
		l.TextScaled = size == nil
		l.TextSize = size or 14
		l.TextWrapped = true
		l.FontFace = FONT
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Parent = bg
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Transparency = 0.4
		stroke.Parent = l
		return l
	end
	local headline = label(0.05, 0.3)
	headline.Text = "SPORTS BATTLEGROUNDS"
	local sub = label(0.36, 0.13)
	sub.Text = "WHO RULES THE STADIUM?"
	sub.TextColor3 = Color3.fromRGB(255, 220, 90)
	local feedLabel = label(0.54, 0.4)
	feedLabel.TextScaled = false
	feedLabel.TextSize = 34
	feedLabel.TextXAlignment = Enum.TextXAlignment.Left
	feedLabel.TextYAlignment = Enum.TextYAlignment.Top
	feedLabel.Size = UDim2.fromScale(0.55, 0.42)
	feedLabel.Text = ""
	local top = label(0.54, 0.4)
	top.TextScaled = false
	top.TextSize = 34
	top.TextXAlignment = Enum.TextXAlignment.Right
	top.TextYAlignment = Enum.TextYAlignment.Top
	top.Position = UDim2.fromScale(0.5, 0.54)
	top.Size = UDim2.fromScale(0.46, 0.42)
	top.Text = ""
	table.insert(screens, { Gui = gui, Headline = headline, Sub = sub, Feed = feedLabel, Top = top })
end

local function setScreens(headline: string, sub: string, color: Color3?)
	for _, s in screens do
		s.Headline.Text = headline
		s.Headline.TextColor3 = color or Color3.new(1, 1, 1)
		s.Sub.Text = sub
	end
end

local function refreshFeed()
	local text = table.concat(feed, "\n")
	for _, s in screens do
		s.Feed.Text = text
	end
end

local function refreshTop()
	local list = {}
	for _, p in Players:GetPlayers() do
		local stats = p:FindFirstChild("leaderstats")
		local kos = stats and stats:FindFirstChild("KOs")
		table.insert(list, { Name = p.DisplayName, KOs = if kos and kos:IsA("IntValue") then kos.Value else 0 })
	end
	table.sort(list, function(a, b)
		return a.KOs > b.KOs
	end)
	local lines = { "TOP KOs" }
	for i = 1, math.min(4, #list) do
		table.insert(lines, string.format("%d. %s  %d", i, list[i].Name, list[i].KOs))
	end
	local text = table.concat(lines, "\n")
	for _, s in screens do
		s.Top.Text = text
	end
end

--------------------------------------------------------------------------------
-- Floodlight shafts
--------------------------------------------------------------------------------
local function lightShaft(lamp: BasePart)
	local a0 = Instance.new("Attachment")
	a0.Parent = lamp
	local target = Vector3.new(lamp.Position.X * 0.25, 0, lamp.Position.Z * 0.25)
	local a1 = Instance.new("Attachment")
	a1.WorldPosition = target
	a1.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 248, 225))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(0.6, 0.94), NumberSequenceKeypoint.new(1, 1) })
	beam.Width0 = 10
	beam.Width1 = 70
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 2
	beam.Parent = lamp
end

-- Night match: a grid of downlights over the pitch (a light only reaches 60 studs, so the floodlights
-- themselves are too high up to light it). Cool white, no shadows, so it stays cheap.
-- Off: Roblox lights reach 60 studs, so a grid leaves dark gaps across a pitch this big. The night
-- lighting (Lighting's ambient in default.project.json) lights the field and stands evenly instead.
local PITCH_LIGHTS = false
local PITCH_LIGHT_HEIGHT = 35
local PITCH_LIGHT_SPACING = 85
local function pitchLights()
	local folder = Instance.new("Folder")
	folder.Name = "PitchLights"
	local nx = math.ceil(Layout.BARRIER_HALF_X * 2 / PITCH_LIGHT_SPACING)
	local nz = math.ceil(Layout.BARRIER_HALF_Z * 2 / PITCH_LIGHT_SPACING)
	for i = 1, nx do
		for j = 1, nz do
			local x = (i - (nx + 1) / 2) * Layout.BARRIER_HALF_X * 2 / nx
			local z = (j - (nz + 1) / 2) * Layout.BARRIER_HALF_Z * 2 / nz
			local emitter = Instance.new("Part")
			emitter.Name = "PitchLight"
			emitter.Anchored = true
			emitter.CanCollide = false
			emitter.CanQuery = false
			emitter.CanTouch = false
			emitter.Transparency = 1
			emitter.Size = Vector3.one
			emitter.CFrame = CFrame.new(x, PITCH_LIGHT_HEIGHT, z)
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Bottom
			light.Angle = 120
			light.Range = 60
			light.Brightness = 2.2
			light.Color = Color3.fromRGB(225, 232, 255)
			light.Shadows = false
			light.Parent = emitter
			emitter.Parent = folder
		end
	end
	folder.Parent = workspace
end

function StadiumFX.Init()
	if PITCH_LIGHTS then
		pitchLights()
	end
	task.spawn(function()
		local root = stadium()
		if not root then
			return
		end
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				if d:GetAttribute("LED") then
					makeBoard(d)
				elseif d.Name == "Jumbotron" then
					makeScreen(d)
				elseif d:GetAttribute("Floodlight") and d.Name == "Lamp" then
					lightShaft(d)
				end
			end
		end
		refreshTop()
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator >= 1 / 30 then
			accumulator = 0
			updateBoards()
		end
	end)

	Remotes.Event("KillFeed").OnClientEvent:Connect(function(killer: string, victim: string, killerClass: string, _victimClass: string)
		local line = if killer ~= "" then string.format("%s  K.O.  %s", killer, victim) else string.format("%s was knocked out", victim)
		table.insert(feed, 1, line)
		if #feed > 5 then
			table.remove(feed)
		end
		refreshFeed()
		local character = Characters.Get(killerClass)
		if killer ~= "" then
			StadiumFX.Flash("K.O.!  " .. killer, if character then character.Color else Color3.new(1, 1, 1), 2.5)
			Sound.Play("CrowdCheer", nil, 1, 1)
		end
		task.delay(0.5, refreshTop)
	end)
	Remotes.Event("Announce").OnClientEvent:Connect(function(text: string, color: Color3)
		StadiumFX.Flash(text, color, 3)
		setScreens(text, "", color)
		Sound.Play("CrowdCheer", nil, 1, 0.8)
		task.delay(5, function()
			setScreens("SPORTS BATTLEGROUNDS", "WHO RULES THE STADIUM?", nil)
		end)
	end)
	Sound.Loop("CrowdAmbience", Config.Audio.AmbienceVolume)
end

return StadiumFX
