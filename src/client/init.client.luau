--[[
	Sports Battlegrounds - client entry point.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Animator = require(script.Animator)
local CameraFX = require(script.CameraFX)
local MoveRunner = require(script.MoveRunner)
local Controller = require(script.Controller)
local HitFeedback = require(script.HitFeedback)
local Awakenings = require(script.Awakenings)
local Crowd = require(script.Crowd)
local StadiumFX = require(script.StadiumFX)
local SkyShow = require(script.SkyShow)
local UI = require(script.UI)
local Sound = require(script.Sound)
local Music = require(script.Music)

-- Move scripts
for _, name in { "Common", "Soccer", "Basketball", "Football", "Baseball" } do
	MoveRunner.Register(require(script.Moves:WaitForChild(name)) :: any)
end

-- Roblox's own health bar and backpack don't fit a battlegrounds HUD
for _, coreType in { Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(coreType, false)
	end)
end

Sound.Init()
CameraFX.Init()
Animator.Init()
MoveRunner.Init()
Controller.Init()
HitFeedback.Init()
Awakenings.Init()
UI.Init()
StadiumFX.Init()
SkyShow.Init()
Crowd.Init()
Music.Init()

-- Other players' moves: play them on this client
Remotes.Event("MoveStarted").OnClientEvent:Connect(function(character: Model, moveId: string, token: number, startTime: number, aim: Vector3, variant: string)
	if not character or not character.Parent then
		return
	end
	local late = math.clamp(workspace:GetServerTimeNow() - startTime, 0, 0.25)
	MoveRunner.Start(character, moveId, token, aim, variant, false, late)
end)
Remotes.Event("MoveCancelled").OnClientEvent:Connect(function(character: Model, token: number)
	if character then
		MoveRunner.Cancel(character, token)
	end
end)

Remotes.Event("ClientReady"):FireServer()
