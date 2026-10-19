--[[
	UI: builds every screen and wires the character menu.
]]

local Players = game:GetService("Players")

local Controller = require(script.Parent.Controller)
local CharacterSelect = require(script.CharacterSelect)
local Feed = require(script.Feed)
local HUD = require(script.HUD)
local Mobile = require(script.Mobile)
local Nameplates = require(script.Nameplates)
local Theme = require(script.Theme)

local UI = {}

local player = Players.LocalPlayer :: Player

function UI.Init()
	local screen = Instance.new("ScreenGui")
	screen.Name = "SportsHUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = player:WaitForChild("PlayerGui")

	HUD.Build(screen)
	Feed.Build(screen)
	Mobile.Build(screen)
	Nameplates.Init()
	CharacterSelect.Build(screen)

	-- Controls hint (bottom left, keyboard only)
	if not (game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled) then
		local hint = Theme.Label(screen, "Click M1  ·  1-4 Moves  ·  G Awaken  ·  F Block  ·  Q Dash  ·  Ctrl / W W Run  ·  Shift Lock: Shift  ·  M Characters", UDim2.fromOffset(620, 16), UDim2.new(0, 16, 1, -26), Theme.Body, Theme.Muted)
		hint.TextXAlignment = Enum.TextXAlignment.Left
	end

	Controller.MenuRequested:Connect(CharacterSelect.Toggle)
	CharacterSelect.Open()
end

return UI
