--[[
	Sports Battlegrounds - server entry point.
	Makes sure the stadium exists, then starts every service.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Creating the remotes first lets clients connect while the stadium is still building.
local Shared = ReplicatedStorage:WaitForChild("Shared")
require(Shared.Remotes)

local Builder = require(Shared.Stadium.Builder)
local CombatService = require(script.CombatService)
local MoveService = require(script.MoveService)
local CharacterService = require(script.CharacterService)
local DummyService = require(script.DummyService)
local MatchService = require(script.MatchService)
local AudioService = require(script.AudioService)

local started = os.clock()
-- The stadium is baked into the place (Workspace.Stadium). If it was deleted, build a fresh one.
if not workspace:FindFirstChild("Stadium") then
	Builder.Build().Parent = workspace
end
AudioService.Init()
CombatService.Init()
MoveService.Init()
MatchService.Init()
CharacterService.Init()
DummyService.Init()

print(string.format("[Sports Battlegrounds] Server ready in %.2fs", os.clock() - started))
