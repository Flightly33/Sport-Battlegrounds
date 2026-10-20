--[[
	Aura: the persistent look of an awakened fighter, different for every class.
		Soccer      blue lightning crackling over the body, sparks
		Basketball  flames licking up the limbs, embers ("He's on fire!")
		Football    dark purple energy rising like smoke, magenta glints, a pulsing ring at the feet
		Baseball    green wind swirling around the body, leaves of light
	Plus a coloured outline (Highlight) and a light. Destroy() removes it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)

local FX = require(script.Parent)

type Palette = Characters.Palette

local Aura = {}

export type Handle = { Destroy: (self: Handle) -> () }

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function bodyPart(character: Model, name: string): BasePart?
	local p = character:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

function Aura.Attach(character: Model, classId: string, palette: Palette): Handle
	local created: { Instance } = {}
	local alive = true
	local function keep(i: Instance)
		table.insert(created, i)
	end

	local highlight = Instance.new("Highlight")
	highlight.FillColor = palette.Primary
	highlight.FillTransparency = 0.88
	highlight.OutlineColor = palette.Primary
	highlight.OutlineTransparency = 0.15
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = character
	highlight.Parent = character
	keep(highlight)

	local torso = bodyPart(character, "UpperTorso")
	if torso then
		local light = Instance.new("PointLight")
		light.Color = palette.Light
		light.Brightness = 2.5
		light.Range = 14
		light.Parent = torso
		keep(light)
	end

	local limbs = { "UpperTorso", "LeftLowerArm", "RightLowerArm", "LeftLowerLeg", "RightLowerLeg" }
	if classId == "Basketball" then
		for _, name in limbs do
			local part = bodyPart(character, name)
			if part then
				keep(emitter(part, {
					Texture = FX.Textures.Fire,
					Color = ColorSequence.new(palette.Secondary, palette.Accent),
					LightEmission = 1,
					Size = FX.Seq(1.1, 0.7, 0),
					Transparency = FX.Seq(0.1, 0.4, 1),
					Lifetime = NumberRange.new(0.35, 0.6),
					Speed = NumberRange.new(2, 4),
					Acceleration = Vector3.new(0, 14, 0),
					Rate = if name == "UpperTorso" then 30 else 14,
					RotSpeed = NumberRange.new(-60, 60),
					Rotation = NumberRange.new(0, 360),
				}))
			end
		end
		if torso then
			keep(emitter(torso, {
				Texture = FX.Textures.Spark,
				Color = ColorSequence.new(palette.Secondary),
				LightEmission = 1,
				Size = FX.Seq(0.25, 0),
				Lifetime = NumberRange.new(0.8, 1.4),
				Speed = NumberRange.new(4, 9),
				SpreadAngle = Vector2.new(60, 60),
				Acceleration = Vector3.new(0, 8, 0),
				Rate = 18,
			}))
		end
	elseif classId == "Football" then
		for _, name in { "UpperTorso", "LeftUpperLeg", "RightUpperLeg" } do
			local part = bodyPart(character, name)
			if part then
				keep(emitter(part, {
					Texture = FX.Textures.Smoke,
					Color = ColorSequence.new(palette.Primary, palette.Dark),
					LightEmission = 0.6,
					Size = FX.Seq(1.2, 2.2),
					Transparency = FX.Seq(0.5, 0.75, 1),
					Lifetime = NumberRange.new(0.7, 1.1),
					Speed = NumberRange.new(1, 3),
					Acceleration = Vector3.new(0, 7, 0),
					Rate = 16,
					RotSpeed = NumberRange.new(-30, 30),
				}))
			end
		end
		if torso then
			keep(emitter(torso, {
				Texture = FX.Textures.Spark,
				Color = ColorSequence.new(palette.Secondary),
				LightEmission = 1,
				Size = FX.Seq(0.4, 0),
				Lifetime = NumberRange.new(0.3, 0.6),
				Speed = NumberRange.new(3, 6),
				Rate = 12,
			}))
		end
	elseif classId == "Baseball" then
		if torso then
			keep(emitter(torso, {
				Texture = FX.Textures.Spark,
				Color = ColorSequence.new(palette.Primary, palette.Secondary),
				LightEmission = 1,
				Size = FX.Seq(0.35, 0),
				Lifetime = NumberRange.new(0.6, 1.0),
				Speed = NumberRange.new(6, 10),
				SpreadAngle = Vector2.new(180, 20),
				Acceleration = Vector3.new(0, 6, 0),
				Rate = 20,
			}))
		end
		-- Wind swirling up around the body
		task.spawn(function()
			while alive and character.Parent do
				local root = bodyPart(character, "HumanoidRootPart")
				if root then
					FX.Spiral(CFrame.new(root.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(math.pi / 2, 0, 0), palette.Primary, 2.2, 5.5, 0.55, 2)
				end
				task.wait(0.5)
			end
		end)
	else
		-- Soccer: lightning crackling over the body
		if torso then
			keep(emitter(torso, {
				Texture = FX.Textures.Spark,
				Color = ColorSequence.new(palette.Accent),
				LightEmission = 1,
				Size = FX.Seq(0.3, 0),
				Lifetime = NumberRange.new(0.2, 0.4),
				Speed = NumberRange.new(5, 10),
				Rate = 24,
			}))
		end
		task.spawn(function()
			while alive and character.Parent do
				local parts = {}
				for _, name in limbs do
					local p = bodyPart(character, name)
					if p then
						table.insert(parts, p)
					end
				end
				if #parts >= 2 then
					local a = parts[math.random(1, #parts)]
					local b = parts[math.random(1, #parts)]
					if a ~= b then
						FX.Lightning(a.Position, b.Position + Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5), palette.Primary, { Thickness = 0.12, Detail = 2, Duration = 0.1, Flickers = 1, Branches = 0, Core = palette.Core })
					end
				end
				task.wait(0.12 + math.random() * 0.12)
			end
		end)
	end

	-- Breathing glow
	local pulse = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		highlight.OutlineTransparency = 0.1 + (math.sin(t * 6) + 1) * 0.12
	end)

	-- Denser aura, per Config.VFX
	for _, i in created do
		for _, d in i:GetDescendants() do
			if d:IsA("ParticleEmitter") then
				d.Rate *= Config.VFX.AuraDensity
			end
		end
		if i:IsA("ParticleEmitter") then
			i.Rate *= Config.VFX.AuraDensity
		end
	end

	local handle = {} :: any
	function handle.Destroy(_self: Handle)
		alive = false
		pulse:Disconnect()
		for _, i in created do
			i:Destroy()
		end
	end
	return handle :: Handle
end

return Aura
