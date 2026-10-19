--[[
	Music: background playlist, shuffled, with crossfades and a mute toggle (key in Config.Audio, plus
	a small on-screen button).

	Tracks come from Shared/AssetIds.Music, or from the server's audio-library search
	(ReplicatedStorage.Audio "Music" attribute). Tracks that don't load are skipped.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetIds = require(Shared.AssetIds)

local Sound = require(script.Parent.Sound)
local Theme = require(script.Parent.UI.Theme)

local Music = {}

local FADE = 2.5
local LOAD_TIMEOUT = 10

local playlist: { string } = {}
local order: { number } = {}
local cursor = 0
local current: Sound? = nil
local muted = false
local generation = 0
local button: TextButton? = nil

local function shuffle()
	order = {}
	for i = 1, #playlist do
		table.insert(order, math.random(1, i), i)
	end
	cursor = 0
end

local function fadeTo(sound: Sound, volume: number, time: number): Tween
	local tween = TweenService:Create(sound, TweenInfo.new(time, Enum.EasingStyle.Sine), { Volume = volume })
	tween:Play()
	return tween
end

local function targetVolume(): number
	return if muted then 0 else Config.Audio.MusicVolume
end

local playNext: () -> ()

local function startTrack(id: string)
	generation += 1
	local mine = generation
	local old = current
	if old then
		fadeTo(old, 0, FADE).Completed:Once(function()
			old:Destroy()
		end)
	end
	local sound = Instance.new("Sound")
	sound.Name = "MusicTrack"
	sound.SoundId = id
	sound.Volume = 0
	sound.SoundGroup = Sound.Group("Music")
	sound.Parent = game:GetService("SoundService")
	current = sound
	sound.Ended:Connect(function()
		if generation == mine then
			playNext()
		end
	end)
	task.spawn(function()
		-- Preload through Sound's checker (shared with sound effects) before fading in
		Sound.Verify(id)
		local waited = 0
		while Sound.Status(id) == false and waited < LOAD_TIMEOUT and sound.Parent do
			waited += task.wait(0.25)
		end
		if generation ~= mine then
			return
		end
		if Sound.Status(id) ~= true then
			warn("[Music] track didn't load, skipping: " .. id)
			local index = table.find(playlist, id)
			if index then
				table.remove(playlist, index)
			end
			if #playlist > 0 then
				shuffle()
				playNext()
			end
			return
		end
		sound:Play()
		fadeTo(sound, targetVolume(), FADE)
	end)
end

playNext = function()
	if #playlist == 0 then
		return
	end
	cursor += 1
	if cursor > #order then
		shuffle()
		cursor = 1
	end
	startTrack(playlist[order[cursor]])
end

local function setPlaylist(ids: { string })
	if #ids == 0 then
		return
	end
	playlist = ids
	shuffle()
	playNext()
end

local function refreshButton()
	local b = button
	if b then
		b.Text = if muted then "♪ OFF" else "♪ ON"
		b.TextColor3 = if muted then Theme.Muted else Theme.Gold
	end
end

function Music.SetMuted(value: boolean)
	muted = value
	local sound = current
	if sound then
		fadeTo(sound, targetVolume(), 0.4)
	end
	refreshButton()
end

function Music.Toggle()
	Music.SetMuted(not muted)
end

local function makeButton()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "SportsMusic"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local b = Instance.new("TextButton")
	b.Name = "Toggle"
	b.AnchorPoint = Vector2.new(0, 0.5)
	b.Position = UDim2.new(0, 10, 0.36, 0)
	b.Size = UDim2.fromOffset(64, 26)
	b.BackgroundColor3 = Theme.PanelColor
	b.BackgroundTransparency = 0.3
	b.FontFace = Theme.Bold
	b.TextSize = 13
	b.AutoButtonColor = true
	Theme.Corner(8).Parent = b
	Theme.Stroke(Theme.PanelLight, 1, 0.3).Parent = b
	b.Parent = gui
	b.Activated:Connect(Music.Toggle)
	button = b
	refreshButton()
	gui.Parent = player:WaitForChild("PlayerGui")
end

function Music.Init()
	task.spawn(makeButton)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Config.Audio.MusicToggleKey then
			Music.Toggle()
		end
	end)
	local manual: { string } = {}
	for _, id in AssetIds.Music do
		local resolved = AssetIds.Resolve(id)
		if resolved then
			table.insert(manual, resolved)
		end
	end
	if #manual > 0 then
		setPlaylist(manual)
		return
	end
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Audio", 30)
		if not folder then
			return
		end
		local function fromFolder()
			if #playlist == 0 then
				setPlaylist(Sound.SplitIds(folder:GetAttribute("Music") :: string?))
			end
		end
		fromFolder()
		folder:GetAttributeChangedSignal("Music"):Connect(fromFolder)
	end)
end

return Music
