--[[
	CameraFX: everything that happens to the local camera and screen.
		Shake        trauma-based shake (stacks, decays)
		ImpactFrame  the manga "impact frame": a few frames of inverted, high-contrast black & white with
		             the fighters outlined - used on heavy hits and finishers
		FOVPunch     quick zoom kick
		SpeedLines   radial anime speed lines over the screen
		Cinematic    scripted camera path for awakenings and ultimates (with letterbox bars)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetIds"))

local CameraFX = {}

local player = Players.LocalPlayer :: Player
local trauma = 0
local shakeFrequency = 18
local fovOffset = 0
local cinematicActive = false

local screen: ScreenGui
local flashFrame: Frame
local linesFrame: Frame
local linesImage: ImageLabel? -- the speedlines texture, when one is set in AssetIds
local barTop: Frame
local barBottom: Frame

local function camera(): Camera
	return workspace.CurrentCamera :: Camera
end

function CameraFX.Shake(amount: number, _duration: number?)
	trauma = math.clamp(trauma + amount, 0, 1.6)
end

function CameraFX.FOVPunch(amount: number, duration: number)
	fovOffset += amount
	task.delay(duration, function()
		fovOffset -= amount
	end)
end

-- White / coloured full-screen flash.
function CameraFX.Flash(color: Color3, duration: number, startTransparency: number?)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = startTransparency or 0.3
	TweenService:Create(flashFrame, TweenInfo.new(duration, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

-- Manga impact frame: ~0.1 s of inverted black/white with outlined fighters.
function CameraFX.ImpactFrame(characters: { Model }, duration: number?, accent: Color3?)
	local d = duration or 0.11
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SB_ImpactFrame"
	cc.Saturation = -1
	cc.Contrast = 2.5
	cc.Brightness = 0.25
	cc.TintColor = accent or Color3.new(1, 1, 1)
	cc.Parent = camera()
	local highlights: { Highlight } = {}
	for _, character in characters do
		if character.Parent then
			local h = Instance.new("Highlight")
			h.FillColor = Color3.new(0, 0, 0)
			h.FillTransparency = 0
			h.OutlineColor = Color3.new(1, 1, 1)
			h.OutlineTransparency = 0
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Adornee = character
			h.Parent = character
			table.insert(highlights, h)
		end
	end
	-- Second half: flip to the "negative" look
	task.delay(d * 0.5, function()
		cc.Brightness = -0.15
		cc.Contrast = 3
		for _, h in highlights do
			h.FillColor = Color3.new(1, 1, 1)
			h.OutlineColor = Color3.new(0, 0, 0)
		end
	end)
	task.delay(d, function()
		cc:Destroy()
		for _, h in highlights do
			h:Destroy()
		end
	end)
end

function CameraFX.SpeedLines(duration: number, color: Color3?)
	linesFrame.Visible = true
	for _, line in linesFrame:GetChildren() do
		if line:IsA("Frame") then
			line.BackgroundColor3 = color or Color3.new(1, 1, 1)
		end
	end
	local image = linesImage
	if image then
		image.ImageColor3 = color or Color3.new(1, 1, 1)
	end
	linesFrame:SetAttribute("Until", os.clock() + duration)
end

-- Scripted camera. path(t) returns the camera CFrame for t in 0..1.
function CameraFX.Cinematic(path: (number) -> CFrame, duration: number, fov: number?)
	if cinematicActive then
		return
	end
	cinematicActive = true
	local cam = camera()
	local previousType = cam.CameraType
	local previousFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(barTop, TweenInfo.new(0.25), { Size = UDim2.new(1, 0, 0.1, 0) }):Play()
	TweenService:Create(barBottom, TweenInfo.new(0.25), { Size = UDim2.new(1, 0, 0.1, 0) }):Play()
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / duration, 0, 1)
		cam.CFrame = path(t)
		if fov then
			cam.FieldOfView = fov
		end
		if t >= 1 then
			connection:Disconnect()
			cam.CameraType = previousType
			cam.FieldOfView = previousFov
			cinematicActive = false
			TweenService:Create(barTop, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) }):Play()
			TweenService:Create(barBottom, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		end
	end)
end

-- An orbit around a part: from angle a0 to a1 (degrees), at a distance and height.
function CameraFX.Orbit(subject: BasePart, duration: number, a0: number, a1: number, distance: number, height: number, fov: number?)
	local center = subject.Position
	local base = subject.CFrame - subject.CFrame.Position
	CameraFX.Cinematic(function(t)
		local e = 1 - (1 - t) ^ 2
		local a = math.rad(a0 + (a1 - a0) * e)
		local offset = base * Vector3.new(math.sin(a) * distance, height, -math.cos(a) * distance)
		local focus = (if subject.Parent then subject.Position else center) + Vector3.new(0, 1.5, 0)
		return CFrame.lookAt(focus + offset, focus)
	end, duration, fov)
end

function CameraFX.IsCinematic(): boolean
	return cinematicActive
end

function CameraFX.Init()
	screen = Instance.new("ScreenGui")
	screen.Name = "CameraFX"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.Parent = player:WaitForChild("PlayerGui")

	flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundTransparency = 1
	flashFrame.BorderSizePixel = 0
	flashFrame.Parent = screen

	barTop = Instance.new("Frame")
	barTop.BackgroundColor3 = Color3.new(0, 0, 0)
	barTop.BorderSizePixel = 0
	barTop.Size = UDim2.new(1, 0, 0, 0)
	barTop.Parent = screen
	barBottom = barTop:Clone()
	barBottom.AnchorPoint = Vector2.new(0, 1)
	barBottom.Position = UDim2.fromScale(0, 1)
	barBottom.Parent = screen

	-- Speed lines: thin white wedges radiating from the centre, re-rolled every frame
	linesFrame = Instance.new("Frame")
	linesFrame.Size = UDim2.fromScale(1, 1)
	linesFrame.BackgroundTransparency = 1
	linesFrame.Visible = false
	linesFrame.Parent = screen
	local lines: { Frame } = {}
	local linesTexture = AssetIds.Resolve(AssetIds.Textures.SpeedLines)
	if linesTexture then
		local image = Instance.new("ImageLabel")
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(1.5, 1.5)
		image.SizeConstraint = Enum.SizeConstraint.RelativeXX
		image.BackgroundTransparency = 1
		image.Image = linesTexture
		image.Parent = linesFrame
		linesImage = image
	end
	for _ = 1, if linesTexture then 0 else 36 do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.Parent = linesFrame
		table.insert(lines, line)
	end

	RunService:BindToRenderStep("SB_CameraFX", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local cam = camera()
		-- Shake
		if trauma > 0.001 then
			local t = os.clock() * shakeFrequency
			local power = trauma * trauma
			local rx = (math.noise(t, 0.3) * 2) * 0.035 * power
			local ry = (math.noise(t, 1.7) * 2) * 0.035 * power
			local rz = (math.noise(t, 3.1) * 2) * 0.05 * power
			cam.CFrame = cam.CFrame * CFrame.Angles(rx, ry, rz)
			trauma = math.max(0, trauma - dt * 1.8)
		end
		-- FOV punch (eased)
		if not cinematicActive then
			local target = 70 + fovOffset
			cam.FieldOfView += (target - cam.FieldOfView) * math.min(1, dt * 18)
		end
		-- Speed lines
		local untilTime = linesFrame:GetAttribute("Until") :: number?
		if untilTime and os.clock() < untilTime then
			linesFrame.Visible = true
			local size = screen.AbsoluteSize
			local cx, cy = size.X / 2, size.Y / 2
			local radius = math.max(cx, cy)
			local image = linesImage
			if image then
				-- Re-roll the texture each frame so the lines flicker like drawn frames
				image.Rotation = math.random() * 360
				image.ImageTransparency = math.random() * 0.25
			end
			for _, line in lines do
				local a = math.random() * math.pi * 2
				local length = radius * (0.25 + math.random() * 0.35)
				local r = radius * (0.75 + math.random() * 0.4) - length / 2
				line.Size = UDim2.fromOffset(math.floor(length), math.random(1, 4))
				line.Position = UDim2.fromOffset(math.floor(cx + math.cos(a) * r), math.floor(cy + math.sin(a) * r))
				line.Rotation = math.deg(a)
				line.BackgroundTransparency = 0.25 + math.random() * 0.5
			end
		elseif linesFrame.Visible then
			linesFrame.Visible = false
		end
	end)
end

return CameraFX
