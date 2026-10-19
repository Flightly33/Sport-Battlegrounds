--[[
	Mobile: on-screen buttons for touch devices (M1, moves 1-4, awaken, block, dash, run).
	Roblox's own thumbstick and jump button handle movement.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)

local Controller = require(script.Parent.Parent.Controller)
local Theme = require(script.Parent.Theme)

local Mobile = {}

local player = Players.LocalPlayer :: Player

local function button(parent: Instance, text: string, size: number, position: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(size, size)
	b.Position = position
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.3
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.FontFace = Theme.Heading
	b.AutoButtonColor = true
	Theme.Corner(size // 2).Parent = b
	Theme.Stroke(Color3.new(1, 1, 1), 2, 0.4).Parent = b
	Theme.TextStroke(1.5).Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	b.Parent = parent
	return b
end

local function bind(b: TextButton, action: string)
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			Controller.Action(action, true)
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			Controller.Action(action, false)
		end
	end)
end

function Mobile.Build(screen: ScreenGui)
	if not UserInputService.TouchEnabled then
		return
	end
	local pad = Instance.new("Frame")
	pad.BackgroundTransparency = 1
	pad.AnchorPoint = Vector2.new(1, 1)
	pad.Position = UDim2.new(1, -16, 1, -190)
	pad.Size = UDim2.fromOffset(300, 280)
	pad.Parent = screen

	local m1 = button(pad, "HIT", 96, UDim2.new(1, -60, 1, -60), Color3.fromRGB(230, 60, 60))
	bind(m1, "M1")
	local moves: { TextButton } = {}
	local positions = {
		UDim2.new(1, -170, 1, -40),
		UDim2.new(1, -160, 1, -130),
		UDim2.new(1, -95, 1, -195),
		UDim2.new(1, -20, 1, -170),
	}
	for i = 1, 4 do
		local b = button(pad, tostring(i), 62, positions[i], Color3.fromRGB(40, 50, 80))
		bind(b, "Move" .. i)
		table.insert(moves, b)
	end
	local dash = button(pad, "DASH", 56, UDim2.new(1, -250, 1, -100), Color3.fromRGB(60, 140, 255))
	bind(dash, "Dash")
	local block = button(pad, "BLOCK", 56, UDim2.new(1, -250, 1, -30), Color3.fromRGB(90, 110, 140))
	bind(block, "Block")
	local awaken = button(pad, "G", 50, UDim2.new(1, -240, 1, -180), Color3.fromRGB(255, 190, 40))
	bind(awaken, "Awaken")
	local run = button(screen, "RUN", 54, UDim2.new(0, 120, 1, -230), Color3.fromRGB(60, 160, 90))
	bind(run, "Run")
	local menu = button(screen, "M", 40, UDim2.new(0, 290, 0, 48), Color3.fromRGB(40, 50, 80))
	bind(menu, "CharacterMenu")

	-- Show each move's short name on its button
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		if not character then
			return
		end
		local classId = (character:GetAttribute("Class") :: string?) or Characters.Default
		local awakened = character:GetAttribute("Awakened") == true
		for i, b in moves do
			local move = Characters.MoveFor(classId, tostring(i), awakened)
			if move then
				local remaining = Controller.CooldownRemaining(move.Id)
				b.Text = if remaining > 0 then string.format("%.0f", math.ceil(remaining)) else tostring(i)
				b.BackgroundTransparency = if remaining > 0 then 0.6 else 0.3
			end
		end
	end)
end

return Mobile
