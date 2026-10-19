--[[
	HUD: health, awakening and evasive meters, block durability, the move hotbar with cooldowns,
	the awakening timer, the combo counter and the class card.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)

local Controller = require(script.Parent.Parent.Controller)
local HitFeedback = require(script.Parent.Parent.HitFeedback)
local Theme = require(script.Parent.Theme)

local HUD = {}

local player = Players.LocalPlayer :: Player

type Slot = { Frame: Frame, Name: TextLabel, Key: TextLabel, Shade: Frame, Timer: TextLabel, Stroke: UIStroke, Slot: string }

local slots: { Slot } = {}
local healthFill: Frame
local healthText: TextLabel
local awakenFill: Frame
local awakenLabel: TextLabel
local awakenStroke: UIStroke
local evasiveFill: Frame
local blockBar: Frame
local blockFill: Frame
local className: TextLabel
local classTitle: TextLabel
local awakenTimer: Frame
local awakenTimerFill: Frame
local awakenTimerLabel: TextLabel
local comboFrame: Frame
local comboHits: TextLabel
local comboDamage: TextLabel
local comboShownAt = 0

local function bar(parent: Instance, size: UDim2, position: UDim2, color: Color3): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Size = size
	back.Position = position
	back.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	Theme.Corner(6).Parent = back
	back.Parent = parent
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	Theme.Corner(6).Parent = fill
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.25) })
	gradient.Rotation = 90
	gradient.Parent = fill
	fill.Parent = back
	return back, fill
end

local function keyLabel(slot: string): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return ""
	end
	if slot == "Awaken" then
		return "G"
	end
	return slot
end

local function currentMove(slot: string): Characters.Move?
	local character = player.Character
	if not character then
		return nil
	end
	local classId = (character:GetAttribute("Class") :: string?) or Characters.Default
	return Characters.MoveFor(classId, slot, character:GetAttribute("Awakened") == true)
end

function HUD.Build(screen: ScreenGui)
	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -16)
	bottom.Size = UDim2.fromOffset(460, 150)
	bottom.Parent = screen

	-- Hotbar
	local hotbar = Instance.new("Frame")
	hotbar.BackgroundTransparency = 1
	hotbar.Size = UDim2.new(1, 0, 0, 74)
	hotbar.Parent = bottom
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = hotbar
	for _, slot in { "1", "2", "3", "4", "Awaken" } do
		local f = Theme.Panel(hotbar, UDim2.fromOffset(if slot == "Awaken" then 74 else 80, 74), UDim2.new())
		local stroke = Theme.Stroke(Color3.new(1, 1, 1), 2, 0.7)
		stroke.Parent = f
		local key = Theme.Label(f, keyLabel(slot), UDim2.fromOffset(20, 18), UDim2.fromOffset(6, 4), Theme.Heading, Theme.Gold)
		key.TextXAlignment = Enum.TextXAlignment.Left
		local name = Theme.Label(f, "", UDim2.new(1, -8, 0, 34), UDim2.fromOffset(4, 30), Theme.Bold)
		name.TextWrapped = true
		local shade = Instance.new("Frame")
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = 0.35
		shade.BorderSizePixel = 0
		shade.AnchorPoint = Vector2.new(0, 1)
		shade.Position = UDim2.fromScale(0, 1)
		shade.Size = UDim2.fromScale(1, 0)
		Theme.Corner(10).Parent = shade
		shade.Parent = f
		local timer = Theme.Label(f, "", UDim2.new(1, 0, 0, 28), UDim2.fromOffset(0, 24), Theme.Heading)
		Theme.TextStroke(2).Parent = timer
		-- Click (or tap) a slot to use it
		f.Active = true
		f.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				Controller.Action(if slot == "Awaken" then "Awaken" else "Move" .. slot, true)
			end
		end)
		table.insert(slots, { Frame = f, Name = name, Key = key, Shade = shade, Timer = timer, Stroke = stroke, Slot = slot })
	end

	-- Health
	local healthBack, fill = bar(bottom, UDim2.new(1, 0, 0, 22), UDim2.fromOffset(0, 84), Theme.Health)
	healthFill = fill
	healthText = Theme.Label(healthBack, "100 / 100", UDim2.fromScale(1, 0.9), UDim2.fromScale(0, 0.05), Theme.Heading)
	Theme.TextStroke(1.5).Parent = healthText

	-- Awakening meter
	local awakenBack, aFill = bar(bottom, UDim2.new(1, 0, 0, 12), UDim2.fromOffset(0, 112), Theme.Gold)
	awakenFill = aFill
	awakenStroke = Theme.Stroke(Theme.Gold, 2, 1)
	awakenStroke.Parent = awakenBack
	awakenLabel = Theme.Label(bottom, "AWAKENING", UDim2.new(0.5, 0, 0, 16), UDim2.fromOffset(0, 128), Theme.Heading, Theme.Gold)
	awakenLabel.TextXAlignment = Enum.TextXAlignment.Left

	-- Evasive meter
	local _, eFill = bar(bottom, UDim2.new(0.3, 0, 0, 8), UDim2.new(0.7, 0, 0, 132), Color3.fromRGB(200, 230, 255))
	evasiveFill = eFill
	local eText = Theme.Label(bottom, "EVASIVE", UDim2.new(0.2, 0, 0, 12), UDim2.new(0.49, 0, 0, 130), Theme.Heading, Color3.fromRGB(200, 230, 255))
	eText.TextXAlignment = Enum.TextXAlignment.Right

	-- Block durability (shown while blocking)
	local bb, bf = bar(screen, UDim2.fromOffset(160, 8), UDim2.new(0.5, -80, 0.62, 0), Color3.fromRGB(170, 220, 255))
	blockBar = bb
	blockFill = bf
	blockBar.Visible = false

	-- Class card (top left)
	local card = Theme.Panel(screen, UDim2.fromOffset(250, 62), UDim2.fromOffset(16, 16))
	className = Theme.Label(card, "", UDim2.new(1, -16, 0, 28), UDim2.fromOffset(10, 6), Theme.Heading)
	className.TextXAlignment = Enum.TextXAlignment.Left
	classTitle = Theme.Label(card, "", UDim2.new(1, -16, 0, 18), UDim2.fromOffset(10, 36), Theme.Body, Theme.Muted)
	classTitle.TextXAlignment = Enum.TextXAlignment.Left
	local change = Theme.Label(card, "[M] change", UDim2.fromOffset(80, 14), UDim2.new(1, -86, 0, 8), Theme.Body, Theme.Muted)
	change.TextXAlignment = Enum.TextXAlignment.Right

	-- Awakening timer (top centre)
	awakenTimer = Theme.Panel(screen, UDim2.fromOffset(320, 40), UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0))
	awakenTimerLabel = Theme.Label(awakenTimer, "", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 3), Theme.Heading)
	local _, tf = bar(awakenTimer, UDim2.new(1, -16, 0, 8), UDim2.fromOffset(8, 26), Theme.Gold)
	awakenTimerFill = tf
	awakenTimer.Visible = false

	-- Combo counter (right)
	comboFrame = Instance.new("Frame")
	comboFrame.BackgroundTransparency = 1
	comboFrame.AnchorPoint = Vector2.new(1, 0.5)
	comboFrame.Position = UDim2.new(1, -40, 0.42, 0)
	comboFrame.Size = UDim2.fromOffset(240, 110)
	comboFrame.Parent = screen
	comboHits = Theme.Label(comboFrame, "", UDim2.new(1, 0, 0, 72), UDim2.new(), Theme.Heading, Theme.Gold)
	comboHits.TextXAlignment = Enum.TextXAlignment.Right
	Theme.TextStroke(3).Parent = comboHits
	comboDamage = Theme.Label(comboFrame, "", UDim2.new(1, 0, 0, 26), UDim2.fromOffset(0, 72), Theme.Bold)
	comboDamage.TextXAlignment = Enum.TextXAlignment.Right
	Theme.TextStroke(2).Parent = comboDamage
	comboFrame.Visible = false

	HitFeedback.Combo:Connect(function(hits: number, damage: number)
		comboFrame.Visible = true
		comboShownAt = os.clock()
		comboHits.Text = string.format("%d HIT%s", hits, if hits == 1 then "" else "S")
		comboDamage.Text = string.format("%d DAMAGE", math.floor(damage + 0.5))
		comboHits.Size = UDim2.new(1, 0, 0, 90)
		TweenService:Create(comboHits, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.new(1, 0, 0, 72) }):Play()
	end)

	RunService.RenderStepped:Connect(HUD.Update)
end

function HUD.Update()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end
	local classId = (character:GetAttribute("Class") :: string?) or Characters.Default
	local info = Characters.Get(classId)
	local awakened = character:GetAttribute("Awakened") == true
	local palette = Characters.Palette(classId, awakened)

	-- Health
	local hp = math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1)
	healthFill.Size = UDim2.fromScale(hp, 1)
	healthFill.BackgroundColor3 = if hp > 0.5 then Theme.Health elseif hp > 0.25 then Theme.Gold else Theme.Danger
	healthText.Text = string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)

	-- Meters
	local meter = ((player:GetAttribute("Awaken") :: number?) or 0) / 100
	awakenFill.Size = UDim2.fromScale(math.clamp(meter, 0, 1), 1)
	awakenFill.BackgroundColor3 = palette.Primary
	local full = meter >= 0.995 and not awakened
	awakenStroke.Transparency = if full then 0.2 + (math.sin(os.clock() * 8) + 1) * 0.3 else 1
	awakenStroke.Color = palette.Primary
	awakenLabel.Text = if awakened then "AWAKENED" elseif full then "AWAKENING READY - PRESS G" else "AWAKENING"
	awakenLabel.TextColor3 = if full then palette.Accent else Theme.Gold
	local evasive = ((player:GetAttribute("Evasive") :: number?) or 0) / Config.Evasive.Cost
	evasiveFill.Size = UDim2.fromScale(math.clamp(evasive, 0, 1), 1)

	-- Block durability
	local blocking = character:GetAttribute("Blocking") == true
	blockBar.Visible = blocking
	blockFill.Size = UDim2.fromScale(math.clamp((character:GetAttribute("BlockHP") :: number?) or 1, 0, 1), 1)

	-- Class card
	if info then
		className.Text = string.upper(info.DisplayName)
		className.TextColor3 = info.Color
		classTitle.Text = if awakened then info.AwakeningName else info.Title
	end

	-- Awakening timer
	local untilTime = (character:GetAttribute("AwakenUntil") :: number?) or 0
	local left = untilTime - workspace:GetServerTimeNow()
	awakenTimer.Visible = awakened and left > 0
	if awakened and info then
		awakenTimerLabel.Text = string.format("%s  %ds", string.upper(info.AwakeningName), math.max(0, math.ceil(left)))
		awakenTimerLabel.TextColor3 = palette.Accent
		awakenTimerFill.Size = UDim2.fromScale(math.clamp(left / (Config.Awakening.Duration + Config.Awakening.TransformTime), 0, 1), 1)
		awakenTimerFill.BackgroundColor3 = palette.Primary
	end

	-- Hotbar
	for _, s in slots do
		local move = currentMove(s.Slot)
		if move then
			s.Name.Text = string.upper(move.Name)
			local remaining = Controller.CooldownRemaining(move.Id)
			local fraction = if move.Cooldown > 0 then math.clamp(remaining / move.Cooldown, 0, 1) else 0
			if s.Slot == "Awaken" then
				fraction = if awakened then 1 else 1 - math.clamp(meter, 0, 1)
				remaining = 0
			end
			s.Shade.Size = UDim2.fromScale(1, fraction)
			s.Timer.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
			s.Stroke.Color = palette.Primary
			s.Stroke.Transparency = if fraction <= 0 then 0.1 else 0.75
		end
	end

	if comboFrame.Visible and os.clock() - comboShownAt > Config.Combat.ComboCounterWindow + 0.6 then
		comboFrame.Visible = false
	end
end

return HUD
