--[[
	Awakenings: puts the class aura (FX/Aura.luau) on every awakened fighter and takes it off again, and
	plays the class's awakening theme (AssetIds.Sounds.<Class>_AwakenTheme, if set) for as long as the
	awakening lasts. Your own theme plays over the stadium music, which ducks underneath it; other
	fighters' themes are heard from where they stand.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)

local Aura = require(script.Parent.FX.Aura)
local Music = require(script.Parent.Music)
local Sound = require(script.Parent.Sound)

local Awakenings = {}

local THEME_DELAY = 1.1 -- the transformation cinematic plays first (same beat as the aura)
local THEME_FADE_IN = 0.5
local THEME_FADE_OUT = 1.5
local OTHERS_VOLUME = 0.6
local OTHERS_RANGE = 240
local DUCK = 0.25 -- what the stadium music drops to under your own theme

local auras: { [Model]: Aura.Handle } = {}
local themes: { [Model]: Sound } = {}

local function fade(sound: Sound, volume: number, time: number): Tween
	local tween = TweenService:Create(sound, TweenInfo.new(time, Enum.EasingStyle.Sine), { Volume = volume })
	tween:Play()
	return tween
end

local function stopTheme(model: Model)
	local sound = themes[model]
	if not sound then
		return
	end
	themes[model] = nil
	if model == Players.LocalPlayer.Character then
		Music.SetDuck(1)
	end
	fade(sound, 0, THEME_FADE_OUT).Completed:Once(function()
		sound:Destroy()
	end)
	task.delay(THEME_FADE_OUT + 0.5, function()
		sound:Destroy()
	end)
end

local function startTheme(model: Model, classId: string)
	local mine = model == Players.LocalPlayer.Character
	local root = model:FindFirstChild("HumanoidRootPart")
	local parent: Instance? = if mine then SoundService else root
	if not parent then
		return
	end
	local sound = Sound.Start(classId .. "_AwakenTheme", parent, true, if mine then 1 else OTHERS_VOLUME, if mine then "Music" else "SFX")
	if not sound then
		return -- this class has no theme
	end
	if not mine then
		sound.RollOffMaxDistance = OTHERS_RANGE
	end
	themes[model] = sound
	local target = sound.Volume
	sound.Volume = 0
	fade(sound, target, THEME_FADE_IN)
	if mine then
		Music.SetDuck(DUCK)
	end
end

local function refresh(model: Model)
	local awakened = model:GetAttribute("Awakened") == true
	local current = auras[model]
	if awakened and not current then
		local classId = (model:GetAttribute("Class") :: string?) or Characters.Default
		-- Let the transformation cinematic play first
		task.delay(THEME_DELAY, function()
			if model.Parent and model:GetAttribute("Awakened") == true and not auras[model] then
				auras[model] = Aura.Attach(model, classId, Characters.Palette(classId, true))
			end
			if model.Parent and model:GetAttribute("Awakened") == true and not themes[model] then
				startTheme(model, classId)
			end
		end)
	elseif not awakened then
		if current then
			current:Destroy()
			auras[model] = nil
		end
		stopTheme(model)
	end
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Awakened"):Connect(function()
		refresh(model)
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			if auras[model] then
				auras[model]:Destroy()
				auras[model] = nil
			end
			stopTheme(model)
		end
	end)
	refresh(model)
end

function Awakenings.Init()
	for _, model in CollectionService:GetTagged("Fighter") do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("Fighter"):Connect(watch)
end

return Awakenings
