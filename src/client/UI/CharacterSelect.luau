--[[
	CharacterSelect: pick your sport. Opens when you join and with [M]. Shows each character's colours,
	title, play style and full move list (base moves and awakened moves).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Remotes = require(Shared.Remotes)

local Theme = require(script.Parent.Theme)
local Sound = require(script.Parent.Parent.Sound)

local CharacterSelect = {}

local player = Players.LocalPlayer :: Player
local root: Frame
local detail: Frame
local detailTitle: TextLabel
local detailText: TextLabel
local detailMoves: TextLabel
local selected = Characters.Default

local function showDetail(character: Characters.Character)
	selected = character.Id
	detailTitle.Text = string.upper(character.DisplayName) .. "  -  " .. string.upper(character.Title)
	detailTitle.TextColor3 = character.Color
	detailText.Text = character.Description
	local lines = { "<b>M1</b>  " .. character.M1.Name }
	for i, move in character.Moves do
		table.insert(lines, string.format("<b>%d</b>  %s <font color=\"#9aa3bd\">- %s</font>", i, move.Name, move.Description))
	end
	table.insert(lines, string.format("<b>G</b>  <font color=\"#ffd246\">AWAKENING: %s</font>", string.upper(character.AwakeningName)))
	for i, move in character.Awakened do
		table.insert(lines, string.format("<b>%d</b>  %s <font color=\"#9aa3bd\">- %s</font>", i, move.Name, move.Description))
	end
	detailMoves.Text = table.concat(lines, "\n")
end

function CharacterSelect.Open()
	root.Visible = true
	root.Position = UDim2.fromScale(0.5, 0.55)
	TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	local current = player:GetAttribute("Class") :: string?
	local character = Characters.Get(current) or Characters.Get(Characters.Default)
	if character then
		showDetail(character)
	end
end

function CharacterSelect.Close()
	root.Visible = false
end

function CharacterSelect.Toggle()
	if root.Visible then
		CharacterSelect.Close()
	else
		CharacterSelect.Open()
	end
end

function CharacterSelect.Build(screen: ScreenGui)
	root = Theme.Panel(screen, UDim2.fromOffset(820, 520), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	root.Name = "CharacterSelect"
	root.BackgroundTransparency = 0.08
	root.ZIndex = 20
	local scale = Instance.new("UISizeConstraint")
	scale.MaxSize = Vector2.new(820, 520)
	scale.Parent = root
	local aspect = Instance.new("UIScale")
	aspect.Parent = root
	local function rescale()
		local view = screen.AbsoluteSize
		aspect.Scale = math.min(1, (view.X - 20) / 820, (view.Y - 20) / 520)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	rescale()

	local title = Theme.Label(root, "CHOOSE YOUR SPORT", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 14), Theme.Heading)
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.TextStroke(2).Parent = title

	local cards = Instance.new("Frame")
	cards.BackgroundTransparency = 1
	cards.Position = UDim2.fromOffset(20, 64)
	cards.Size = UDim2.new(1, -40, 0, 150)
	cards.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 12)
	layout.Parent = cards

	for _, character in Characters.List do
		local card = Instance.new("TextButton")
		card.AutoButtonColor = false
		card.Text = ""
		card.Size = UDim2.new(0.25, -9, 1, 0)
		card.BackgroundColor3 = character.Color
		card.BorderSizePixel = 0
		Theme.Corner(12).Parent = card
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(40, 40, 60))
		gradient.Rotation = 70
		gradient.Parent = card
		local stroke = Theme.Stroke(Color3.new(1, 1, 1), 2, 0.6)
		stroke.Parent = card
		local name = Theme.Label(card, string.upper(character.DisplayName), UDim2.new(1, -16, 0, 34), UDim2.new(0, 8, 1, -78), Theme.Heading)
		name.TextXAlignment = Enum.TextXAlignment.Left
		Theme.TextStroke(2.5).Parent = name
		local sub = Theme.Label(card, character.Title, UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 1, -42), Theme.Bold)
		sub.TextXAlignment = Enum.TextXAlignment.Left
		Theme.TextStroke(1.5).Parent = sub
		local emblem = Theme.Label(card, string.sub(character.DisplayName, 1, 1), UDim2.fromOffset(70, 70), UDim2.new(1, -78, 0, 6), Theme.Heading)
		emblem.TextTransparency = 0.55
		card.MouseEnter:Connect(function()
			stroke.Transparency = 0
			showDetail(character)
		end)
		card.MouseLeave:Connect(function()
			stroke.Transparency = 0.6
		end)
		card.Activated:Connect(function()
			Sound.Play("Click")
			showDetail(character)
			Remotes.Event("SelectCharacter"):FireServer(character.Id)
			CharacterSelect.Close()
		end)
		card.Parent = cards
	end

	detail = Instance.new("Frame")
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromOffset(20, 226)
	detail.Size = UDim2.new(1, -40, 1, -246)
	detail.Parent = root
	detailTitle = Theme.Label(detail, "", UDim2.new(1, 0, 0, 26), UDim2.new(), Theme.Heading)
	detailTitle.TextXAlignment = Enum.TextXAlignment.Left
	detailText = Theme.Label(detail, "", UDim2.new(1, 0, 0, 20), UDim2.fromOffset(0, 30), Theme.Body, Theme.Muted)
	detailText.TextXAlignment = Enum.TextXAlignment.Left
	detailMoves = Theme.Label(detail, "", UDim2.new(1, 0, 1, -60), UDim2.fromOffset(0, 58), Theme.Body)
	detailMoves.RichText = true
	detailMoves.TextScaled = false
	detailMoves.TextSize = 15
	detailMoves.TextWrapped = true
	detailMoves.TextXAlignment = Enum.TextXAlignment.Left
	detailMoves.TextYAlignment = Enum.TextYAlignment.Top

	local close = Instance.new("TextButton")
	close.Text = "PLAY"
	close.FontFace = Theme.Heading
	close.TextScaled = true
	close.TextColor3 = Color3.new(0, 0, 0)
	close.BackgroundColor3 = Theme.Gold
	close.Size = UDim2.fromOffset(120, 40)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -20, 0, 14)
	Theme.Corner(10).Parent = close
	close.Parent = root
	close.Activated:Connect(function()
		Sound.Play("Click")
		Remotes.Event("SelectCharacter"):FireServer(selected)
		CharacterSelect.Close()
	end)

	local first = Characters.Get(Characters.Default)
	if first then
		showDetail(first)
	end
end

return CharacterSelect
