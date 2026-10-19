--[[
	Awakenings: puts the class aura (FX/Aura.luau) on every awakened fighter and takes it off again,
	and plays the class's awakening theme while it lasts: on the listener for the awakened player
	(with the background music ducked under it), from the body for everyone else.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)

local Aura = require(script.Parent.FX.Aura)
local Sound = require(script.Parent.Sound)

local Awakenings = {}

local auras: { [Model]: Aura.Handle } = {}
local themes: { [Model]: Sound } = {}

-- Theme music per class (names in Shared/AssetIds.Sounds)
local THEMES: { [string]: string } = {
	Soccer = "SoccerAwakenTheme",
}
local THEME_VOLUME = 1 -- for the awakened player
local THEME_OTHERS = 0.6 -- heard from their body by everyone else
local MUSIC_DUCK = 0.15 -- background music while your own theme plays

local function stopTheme(model: Model)
	local theme = themes[model]
	if not theme then
		return
	end
	themes[model] = nil
	if model == Players.LocalPlayer.Character then
		Sound.Duck("Music", 1, 1.2)
	end
	TweenService:Create(theme, TweenInfo.new(1), { Volume = 0 }):Play()
	task.delay(1.05, function()
		theme:Destroy()
	end)
end

local function startTheme(model: Model, classId: string)
	local name = THEMES[classId]
	if not name or themes[model] then
		return
	end
	local mine = model == Players.LocalPlayer.Character
	local root = model:FindFirstChild("HumanoidRootPart")
	local theme = Sound.Attach(name, if mine then nil else root, true, if mine then THEME_VOLUME else THEME_OTHERS)
	if not theme then
		return
	end
	themes[model] = theme
	if mine then
		Sound.Duck("Music", MUSIC_DUCK)
	end
end

local function refresh(model: Model)
	local awakened = model:GetAttribute("Awakened") == true
	local current = auras[model]
	if awakened and not current then
		local classId = (model:GetAttribute("Class") :: string?) or Characters.Default
		-- Let the transformation cinematic play first
		task.delay(1.1, function()
			if model.Parent and model:GetAttribute("Awakened") == true and not auras[model] then
				auras[model] = Aura.Attach(model, classId, Characters.Palette(classId, true))
				startTheme(model, classId)
			end
		end)
	elseif not awakened and current then
		current:Destroy()
		auras[model] = nil
	end
	if not awakened then
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
		if parent == nil and auras[model] then
			auras[model]:Destroy()
			auras[model] = nil
		end
		if parent == nil then
			stopTheme(model)
		end
	end)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			stopTheme(model)
		end)
	end
	refresh(model)
end

function Awakenings.Init()
	for _, model in CollectionService:GetTagged("Fighter") do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("Fighter"):Connect(watch)
end

return Awakenings
