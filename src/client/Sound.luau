--[[
	Sound: one-shot sound effects at a position (or on the camera) and looping ambience.

	Each named sound resolves, in order, to: an id set in Shared/AssetIds.Sounds, a sound the server
	found in Roblox's audio library (ReplicatedStorage.Audio attributes, see Server/AudioService), or
	a built-in sound that ships with every client, re-pitched per effect. Library sounds are preloaded
	first and only used once they actually load, so a bad id never means silence.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetIds = require(Shared.AssetIds)
local AudioCatalog = require(Shared.AudioCatalog)

local Sound = {}

type Def = { Id: string, Pitch: number, Volume: number, Library: boolean, Steady: boolean? }

local BUILTIN: { [string]: Def } = {
	Whoosh = { Id = "rbxasset://sounds/swordslash.wav", Pitch = 1.25, Volume = 0.45, Library = false },
	HeavyWhoosh = { Id = "rbxasset://sounds/swordlunge.wav", Pitch = 0.75, Volume = 0.6, Library = false },
	Hit = { Id = "rbxasset://sounds/action_jump_land.mp3", Pitch = 1.5, Volume = 0.9, Library = false },
	HeavyHit = { Id = "rbxasset://sounds/action_jump_land.mp3", Pitch = 0.75, Volume = 1, Library = false },
	Block = { Id = "rbxasset://sounds/unsheath.wav", Pitch = 0.9, Volume = 0.55, Library = false },
	GuardBreak = { Id = "rbxasset://sounds/unsheath.wav", Pitch = 0.55, Volume = 0.8, Library = false },
	Explosion = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Pitch = 0.45, Volume = 0.9, Library = false },
	Thunder = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Pitch = 0.3, Volume = 1, Library = false },
	Zap = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 0.55, Volume = 0.5, Library = false },
	Fire = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Pitch = 0.8, Volume = 0.5, Library = false },
	Wind = { Id = "rbxasset://sounds/swordlunge.wav", Pitch = 0.5, Volume = 0.45, Library = false },
	Kick = { Id = "rbxasset://sounds/action_jump_land.mp3", Pitch = 1.9, Volume = 0.7, Library = false },
	Bounce = { Id = "rbxasset://sounds/action_jump_land.mp3", Pitch = 2.4, Volume = 0.35, Library = false },
	BatCrack = { Id = "rbxasset://sounds/swordslash.wav", Pitch = 2.2, Volume = 0.7, Library = false },
	Tackle = { Id = "rbxasset://sounds/action_falling.mp3", Pitch = 0.6, Volume = 0.8, Library = false },
	Awaken = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Pitch = 0.6, Volume = 0.9, Library = false },
	KO = { Id = "rbxasset://sounds/action_falling.mp3", Pitch = 0.5, Volume = 0.8, Library = false },
	Click = { Id = "rbxasset://sounds/button.wav", Pitch = 1, Volume = 0.4, Library = false },
	Ping = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 1.2, Volume = 0.35, Library = false },
}

-- Library ids: nil = not checked yet, false = loading, true = loaded, "failed"
local status: { [string]: boolean | string } = {}
local groups: { [string]: SoundGroup } = {}
local loops: { { Sound: Sound, Name: string } } = {}
local audioFolder: Instance? = nil

local function group(name: string): SoundGroup
	local existing = groups[name]
	if existing then
		return existing
	end
	local g = Instance.new("SoundGroup")
	g.Name = "SB_" .. name
	g.Volume = if name == "SFX" then Config.Audio.SfxVolume else 1
	g.Parent = SoundService
	groups[name] = g
	return g
end
Sound.Group = group

local function splitIds(text: string?): { string }
	local out: { string } = {}
	if not text or text == "" then
		return out
	end
	for _, piece in string.split(text, ",") do
		local id = AssetIds.Resolve((string.gsub(piece, "%s", "")))
		if id then
			table.insert(out, id)
		end
	end
	return out
end
Sound.SplitIds = splitIds

local refreshLoops: () -> ()

-- Preloads a library id once; it's only played after it loads. `label` names the sound slot in the
-- warning, so a bad id is easy to find.
local function verify(id: string, label: string?)
	if status[id] ~= nil then
		return
	end
	status[id] = false
	task.spawn(function()
		local probe = Instance.new("Sound")
		probe.SoundId = id
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ probe }, function(_content: string, fetch: Enum.AssetFetchStatus)
				if fetch == Enum.AssetFetchStatus.Failure then
					status[id] = "failed"
				end
			end)
		end)
		if status[id] ~= "failed" then
			status[id] = if ok and probe.IsLoaded then true else "failed"
		end
		probe:Destroy()
		if status[id] == true then
			refreshLoops()
		else
			warn("[Sound] couldn't load " .. id .. (if label then " (" .. label .. ")" else "") .. "; using the built-in sound instead")
		end
	end)
end
Sound.Verify = verify

-- nil = never checked, false = loading, true = loaded, "failed"
function Sound.Status(id: string): boolean | string | nil
	return status[id]
end

local function pick(list: { string }): string?
	if #list == 0 then
		return nil
	end
	return list[math.random(1, #list)]
end

local function definition(name: string): Def?
	local base = BUILTIN[name]
	local spec = AudioCatalog.Effects[name]
	local custom = AudioCatalog.Custom[name]
	local volume = if spec then spec.Volume elseif custom then custom.Volume elseif base then base.Volume else 0.6
	-- 1. Chosen by hand: trusted, unless it has already failed to load
	local chosen: { string } = {}
	for _, id in splitIds((AssetIds.Sounds :: any)[name]) do
		if status[id] ~= "failed" then
			table.insert(chosen, id)
		end
	end
	local manual = pick(chosen)
	if manual then
		return { Id = manual, Pitch = 1, Volume = volume, Library = true, Steady = custom ~= nil and custom.Steady == true }
	end
	-- 2. Found by the server, once it has loaded here
	local folder = audioFolder
	if folder then
		local ready: { string } = {}
		for _, id in splitIds(folder:GetAttribute(name) :: string?) do
			verify(id, name)
			if status[id] == true then
				table.insert(ready, id)
			end
		end
		local found = pick(ready)
		if found then
			return { Id = found, Pitch = 1, Volume = volume, Library = true }
		end
	end
	-- 3. Built in, or the sound this one stands in for
	if base then
		return base
	end
	if custom and custom.Fallback then
		return definition(custom.Fallback)
	end
	return nil
end

-- Plays a named sound at a position (3D) or, with no position, on the listener (2D).
-- `pitch` was tuned for the built-in sounds, so real recordings only take a gentle version of it.
function Sound.Play(name: string, position: Vector3?, pitch: number?, volume: number?)
	local def = definition(name)
	if not def then
		return
	end
	local shift = pitch or 1
	if def.Library then
		shift = math.clamp(1 + (shift - 1) * 0.35, 0.8, 1.2)
	end
	local jitter = if def.Steady then 1 else 0.94 + math.random() * 0.12
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume * (volume or 1)
	sound.PlaybackSpeed = def.Pitch * (if def.Steady then 1 else shift) * jitter
	sound.RollOffMinDistance = 20
	sound.RollOffMaxDistance = 400
	sound.SoundGroup = group("SFX")
	if position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = workspace.Terrain
		sound.Parent = attachment
		sound.Ended:Connect(function()
			attachment:Destroy()
		end)
		task.delay(10, function()
			attachment:Destroy()
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		task.delay(10, function()
			sound:Destroy()
		end)
	end
	sound:Play()
end

-- Starts a long sound (a music theme, a rotor loop) on `parent` and hands it back so the caller can fade
-- and destroy it; nil when the name resolves to nothing at all. `groupName` is "SFX" (default), "Music"
-- or "Ambience".
function Sound.Start(name: string, parent: Instance, looped: boolean, volume: number?, groupName: string?): Sound?
	local def = definition(name)
	if not def then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume * (volume or 1)
	sound.PlaybackSpeed = def.Pitch
	sound.Looped = looped
	sound.RollOffMinDistance = 30
	sound.RollOffMaxDistance = 400
	sound.SoundGroup = group(groupName or "SFX")
	sound.Parent = parent
	sound:Play()
	return sound
end

local function loopId(name: string): string?
	local def = definition(name)
	return def and def.Id
end

-- The sound id a name would play right now (nil if it would be silent).
function Sound.Resolve(name: string): string?
	return loopId(name)
end

refreshLoops = function()
	for _, loop in loops do
		local id = loopId(loop.Name)
		if id and loop.Sound.SoundId ~= id then
			loop.Sound.SoundId = id
			loop.Sound:Play()
		end
	end
end

-- A looping 2D sound (crowd ambience). It starts as soon as the name resolves to something, which
-- for library-only sounds can be a few seconds after joining. Returns the Sound so callers can fade it.
function Sound.Loop(name: string, volume: number): Sound
	local sound = Instance.new("Sound")
	sound.Name = "Loop_" .. name
	sound.Looped = true
	sound.Volume = volume
	sound.SoundGroup = group("Ambience")
	sound.Parent = SoundService
	table.insert(loops, { Sound = sound, Name = name })
	local id = loopId(name)
	if id then
		sound.SoundId = id
		sound:Play()
	end
	return sound
end

function Sound.Init()
	-- Check the ids picked by hand up front, so a dead one is reported (and skipped) before it matters
	for name, ids in AssetIds.Sounds :: any do
		for _, id in splitIds(ids) do
			verify(id, name)
		end
	end
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Audio", 30)
		if not folder then
			return
		end
		audioFolder = folder
		local function check(attribute: string)
			if attribute == "Ready" or attribute == "Music" then
				return
			end
			for _, id in splitIds(folder:GetAttribute(attribute) :: string?) do
				verify(id, attribute)
			end
		end
		for attribute in folder:GetAttributes() do
			check(attribute)
		end
		folder.AttributeChanged:Connect(check)
	end)
end

return Sound
