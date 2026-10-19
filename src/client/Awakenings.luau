--[[
	Awakenings: puts the class aura (FX/Aura.luau) on every awakened fighter and takes it off again.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)

local Aura = require(script.Parent.FX.Aura)

local Awakenings = {}

local auras: { [Model]: Aura.Handle } = {}

local function refresh(model: Model)
	local awakened = model:GetAttribute("Awakened") == true
	local current = auras[model]
	if awakened and not current then
		local classId = (model:GetAttribute("Class") :: string?) or Characters.Default
		-- Let the transformation cinematic play first
		task.delay(1.1, function()
			if model.Parent and model:GetAttribute("Awakened") == true and not auras[model] then
				auras[model] = Aura.Attach(model, classId, Characters.Palette(classId, true))
			end
		end)
	elseif not awakened and current then
		current:Destroy()
		auras[model] = nil
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
