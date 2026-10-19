--[[
	Feed: kill feed (top right), big announcement banners (awakenings, streaks), toasts, the move-name
	banner for awakened finishers, and the K.O. screen with the respawn countdown.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Controller = require(script.Parent.Parent.Controller)
local Theme = require(script.Parent.Theme)

local Feed = {}

local player = Players.LocalPlayer :: Player
local feedList: Frame
local banner: TextLabel
local bannerSub: TextLabel
local toast: TextLabel
local moveBanner: TextLabel
local koScreen: Frame
local koCount: TextLabel

local function colorOf(classId: string): Color3
	local c = Characters.Get(classId)
	return if c then c.Color else Theme.Text
end

local function addKill(killer: string, victim: string, killerClass: string, victimClass: string)
	local row = Theme.Panel(feedList, UDim2.new(1, 0, 0, 30), UDim2.new())
	row.BackgroundTransparency = 0.35
	local label = Theme.Label(row, "", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4), Theme.Bold)
	label.RichText = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	local function hex(c: Color3): string
		return string.format("#%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
	end
	if killer ~= "" then
		label.Text = string.format('<font color="%s">%s</font>  K.O.  <font color="%s">%s</font>', hex(colorOf(killerClass)), killer, hex(colorOf(victimClass)), victim)
	else
		label.Text = string.format('<font color="%s">%s</font> was knocked out', hex(colorOf(victimClass)), victim)
	end
	row.LayoutOrder = -math.floor(os.clock() * 100)
	task.delay(7, function()
		TweenService:Create(row, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		row:Destroy()
	end)
	local rows = {}
	for _, c in feedList:GetChildren() do
		if c:IsA("Frame") then
			table.insert(rows, c)
		end
	end
	if #rows > 6 then
		table.sort(rows, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		rows[1]:Destroy()
	end
end

function Feed.Announce(text: string, color: Color3?, sub: string?)
	banner.Text = text
	banner.TextColor3 = color or Theme.Text
	bannerSub.Text = sub or ""
	banner.Visible = true
	bannerSub.Visible = true
	banner.TextTransparency = 0
	banner.Size = UDim2.new(1, 0, 0, 80)
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.new(1, 0, 0, 56) }):Play()
	local stamp = os.clock()
	banner:SetAttribute("Stamp", stamp)
	task.delay(3.2, function()
		if banner:GetAttribute("Stamp") == stamp then
			TweenService:Create(banner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			bannerSub.Visible = false
		end
	end)
end

function Feed.Toast(text: string)
	toast.Text = text
	toast.TextTransparency = 0
	toast.Visible = true
	local stamp = os.clock()
	toast:SetAttribute("Stamp", stamp)
	task.delay(3, function()
		if toast:GetAttribute("Stamp") == stamp then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

-- Big slanted move name when someone uses an awakened finisher.
function Feed.MoveName(text: string, color: Color3)
	moveBanner.Text = string.upper(text)
	moveBanner.TextColor3 = color
	moveBanner.TextTransparency = 0
	moveBanner.Position = UDim2.new(0.5, -60, 0.3, 0)
	moveBanner.Visible = true
	TweenService:Create(moveBanner, TweenInfo.new(1.4, Enum.EasingStyle.Quart), { Position = UDim2.new(0.5, 60, 0.3, 0) }):Play()
	task.delay(1.1, function()
		TweenService:Create(moveBanner, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	end)
end

function Feed.Build(screen: ScreenGui)
	feedList = Instance.new("Frame")
	feedList.BackgroundTransparency = 1
	feedList.AnchorPoint = Vector2.new(1, 0)
	feedList.Position = UDim2.new(1, -16, 0, 16)
	feedList.Size = UDim2.fromOffset(340, 240)
	feedList.Parent = screen
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = feedList

	banner = Theme.Label(screen, "", UDim2.new(1, 0, 0, 56), UDim2.new(0, 0, 0.17, 0), Theme.Heading)
	Theme.TextStroke(3).Parent = banner
	banner.Visible = false
	bannerSub = Theme.Label(screen, "", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0.17, 60), Theme.Bold, Theme.Muted)
	bannerSub.Visible = false

	toast = Theme.Label(screen, "", UDim2.new(0.6, 0, 0, 24), UDim2.new(0.2, 0, 0.75, 0), Theme.Bold)
	Theme.TextStroke(2).Parent = toast
	toast.Visible = false

	moveBanner = Theme.Label(screen, "", UDim2.fromOffset(900, 90), UDim2.new(0.5, 0, 0.3, 0), Theme.Heading)
	moveBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	moveBanner.Rotation = -6
	Theme.TextStroke(4).Parent = moveBanner
	moveBanner.Visible = false

	koScreen = Instance.new("Frame")
	koScreen.Size = UDim2.fromScale(1, 1)
	koScreen.BackgroundColor3 = Color3.new(0, 0, 0)
	koScreen.BackgroundTransparency = 0.55
	koScreen.Visible = false
	koScreen.ZIndex = 10
	koScreen.Parent = screen
	local ko = Theme.Label(koScreen, "K.O.", UDim2.new(1, 0, 0, 140), UDim2.new(0, 0, 0.3, 0), Theme.Heading, Theme.Danger)
	ko.ZIndex = 11
	Theme.TextStroke(5).Parent = ko
	koCount = Theme.Label(koScreen, "", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.3, 150), Theme.Bold)
	koCount.ZIndex = 11

	Remotes.Event("KillFeed").OnClientEvent:Connect(addKill)
	Remotes.Event("Announce").OnClientEvent:Connect(function(text: string, color: Color3)
		Feed.Announce(text, color)
	end)
	Remotes.Event("Notify").OnClientEvent:Connect(Feed.Toast)

	Controller.MoveUsed:Connect(function(move: Characters.Move)
		if move.Ultimate then
			Feed.MoveName(move.Name, Characters.Palette(move.Class, true).Accent)
		end
	end)
	Remotes.Event("MoveStarted").OnClientEvent:Connect(function(character: Model, moveId: string)
		local move = Characters.Move(moveId)
		if move and move.Ultimate and character then
			local camera = workspace.CurrentCamera
			local root = character:FindFirstChild("HumanoidRootPart")
			if camera and root and root:IsA("BasePart") and (root.Position - camera.CFrame.Position).Magnitude < 160 then
				Feed.MoveName(move.Name, Characters.Palette(move.Class, true).Accent)
			end
		end
	end)

	local function onCharacter(character: Model)
		koScreen.Visible = false
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.Died:Connect(function()
			koScreen.Visible = true
			local deadline = os.clock() + Config.Player.RespawnTime
			while koScreen.Visible and os.clock() < deadline do
				koCount.Text = string.format("Back in %d...", math.ceil(deadline - os.clock()))
				task.wait(0.1)
			end
		end)
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

return Feed
