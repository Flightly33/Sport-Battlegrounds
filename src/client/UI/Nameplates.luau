--[[
	Nameplates: name, health bar and class colour above every other fighter.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)

local Theme = require(script.Parent.Theme)

local Nameplates = {}

local player = Players.LocalPlayer :: Player
type Plate = { Model: Model, Humanoid: Humanoid, Fill: Frame, Name: TextLabel, Gui: BillboardGui }
local plates: { [Model]: Plate } = {}

local function attach(model: Instance)
	if not model:IsA("Model") or model == player.Character or plates[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
	local head = model:FindFirstChild("Head") or model:WaitForChild("Head", 5)
	if not humanoid or not humanoid:IsA("Humanoid") or not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "SB_Nameplate"
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Adornee = head
	gui.Parent = head
	local owner = Players:GetPlayerFromCharacter(model)
	local name = Theme.Label(gui, if owner then owner.DisplayName else model.Name, UDim2.new(1, 0, 0, 18), UDim2.new(), Theme.Heading)
	Theme.TextStroke(1.5).Parent = name
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, 8)
	back.Position = UDim2.fromOffset(0, 22)
	back.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
	back.BorderSizePixel = 0
	Theme.Corner(4).Parent = back
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Theme.Health
	Theme.Corner(4).Parent = fill
	fill.Parent = back
	plates[model] = { Model = model, Humanoid = humanoid, Fill = fill, Name = name, Gui = gui }
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			plates[model] = nil
		end
	end)
end

function Nameplates.Init()
	for _, model in CollectionService:GetTagged("Fighter") do
		task.spawn(attach, model)
	end
	CollectionService:GetInstanceAddedSignal("Fighter"):Connect(function(model)
		task.spawn(attach, model)
	end)
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		for model, plate in plates do
			local hp = math.clamp(plate.Humanoid.Health / math.max(1, plate.Humanoid.MaxHealth), 0, 1)
			plate.Fill.Size = UDim2.fromScale(hp, 1)
			plate.Fill.BackgroundColor3 = if hp > 0.5 then Theme.Health elseif hp > 0.25 then Theme.Gold else Theme.Danger
			local classId = model:GetAttribute("Class") :: string?
			local character = Characters.Get(classId)
			plate.Name.TextColor3 = if character then character.Color else Theme.Text
			plate.Gui.Enabled = plate.Humanoid.Health > 0
		end
	end)
end

return Nameplates
