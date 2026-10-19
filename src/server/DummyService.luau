--[[
	DummyService: training dummies on the track behind the east goal, so combos can be practised
	alone (and the game can be tested in Studio with one player). They respawn after being KO'd.
	The last one blocks, to practise guard breaks. A classic Roblox noob stands on the centre spot.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rig = require(Shared.Anim.Rig)
local StadiumLayout = require(Shared.Stadium.Layout)

local CombatService = require(script.Parent.CombatService)

local DummyService = {}

local folder: Folder

type Look = { Name: string, Head: Color3, Torso: Color3, Arms: Color3, Legs: Color3 }

local GRAY = Color3.fromRGB(150, 150, 160)
local LOOKS: { [string]: Look } = {
	Training = { Name = "Training Dummy", Head = Color3.fromRGB(220, 220, 225), Torso = GRAY, Arms = GRAY, Legs = Color3.fromRGB(90, 90, 100) },
	Blocking = { Name = "Blocking Dummy", Head = Color3.fromRGB(220, 220, 225), Torso = Color3.fromRGB(70, 90, 160), Arms = GRAY, Legs = Color3.fromRGB(90, 90, 100) },
	-- The classic noob: Bright yellow, Bright blue, Bright green
	Noob = { Name = "Noob", Head = Color3.fromRGB(245, 205, 48), Torso = Color3.fromRGB(13, 105, 172), Arms = Color3.fromRGB(245, 205, 48), Legs = Color3.fromRGB(75, 151, 75) },
}

local function build(spot: CFrame, index: number, kind: string)
	local look = LOOKS[kind]
	local blocking = kind == "Blocking"
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.Head
	description.TorsoColor = look.Torso
	description.LeftArmColor = look.Arms
	description.RightArmColor = look.Arms
	description.LeftLegColor = look.Legs
	description.RightLegColor = look.Legs
	local model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	model.Name = if kind == "Training" then look.Name .. " " .. index else look.Name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		animator:Destroy()
	end
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	Rig.Prepare(model)
	model:PivotTo(spot)
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root:SetNetworkOwner(nil)

	local fighter = CombatService.Register(model, nil, "Dummy")
	if not fighter then
		return
	end
	fighter.InvulnUntil = 0
	model:SetAttribute("InvulnUntil", 0)
	model:SetAttribute("Dummy", true)
	if blocking then
		-- Keeps blocking whenever it isn't stunned
		task.spawn(function()
			while model.Parent and fighter.Alive do
				if not CombatService.IsStunned(fighter) and fighter.KnockdownUntil < CombatService.Now() then
					CombatService.SetBlocking(fighter, true)
				end
				task.wait(0.3)
			end
		end)
	end
	-- Walk back to its spot after being knocked around
	task.spawn(function()
		while model.Parent and fighter.Alive do
			task.wait(2.5)
			if fighter.Alive and not CombatService.IsStunned(fighter) and (root.Position - spot.Position).Magnitude > 6 then
				root.AssemblyLinearVelocity = Vector3.zero
				model:PivotTo(spot)
			end
		end
	end)
	humanoid.Died:Connect(function()
		task.delay(Config.Arena.DummyRespawn, function()
			model:Destroy()
			build(spot, index, kind)
		end)
	end)
end

function DummyService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Dummies"
	folder.Parent = workspace
	local spots = StadiumLayout.DummySpots(Config.Arena.DummyCount)
	for i, spot in spots do
		task.spawn(build, spot, i, if i == #spots then "Blocking" else "Training")
	end
	task.spawn(build, StadiumLayout.CenterSpot(), 0, "Noob")
end

return DummyService
