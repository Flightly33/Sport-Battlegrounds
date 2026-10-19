--[[
	Sound: one-shot sound effects at a position (or on the camera).

	Until you upload or pick sounds (Shared/AssetIds.Sounds), the built-in sounds that ship with every
	Roblox client are used, re-pitched per effect. They're serviceable, not great - real impact,
	thunder and crowd sounds from the Creator Store make a big difference.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared.AssetIds)

local Sound = {}

type Def = { Id: string, Pitch: number, Volume: number }

local BUILTIN: { [string]: Def } = {
	Whoosh = { Id = "rbxasset://sounds/swordslash.wav", Pitch = 1.25, Volume = 0.45 },
	HeavyWhoosh = { Id = "rbxasset://sounds/swordlunge.wav", Pitch = 0.75, Volume = 0.6 },
	Hit = { Id = "rbxasset://sounds/action_jump_land.mp3", Pitch = 1.5, Volume = 0.9 },
	HeavyHit = { Id = "rbxasset://sounds/action_jump_land.mp3", Pitch = 0.75, Volume = 1 },
	Block = { Id = "rbxasset://sounds/unsheath.wav", Pitch = 0.9, Volume = 0.55 },
	GuardBreak = { Id = "rbxasset://sounds/unsheath.wav", Pitch = 0.55, Volume = 0.8 },
	Explosion = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Pitch = 0.45, Volume = 0.9 },
	Thunder = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Pitch = 0.3, Volume = 1 },
	Zap = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 0.55, Volume = 0.5 },
	Fire = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Pitch = 0.8, Volume = 0.5 },
	Wind = { Id = "rbxasset://sounds/swordlunge.wav", Pitch = 0.5, Volume = 0.45 },
	Kick = { Id = "rbxasset://sounds/action_jump_land.mp3", Pitch = 1.9, Volume = 0.7 },
	Bounce = { Id = "rbxasset://sounds/action_jump_land.mp3", Pitch = 2.4, Volume = 0.35 },
	BatCrack = { Id = "rbxasset://sounds/swordslash.wav", Pitch = 2.2, Volume = 0.7 },
	Tackle = { Id = "rbxasset://sounds/action_falling.mp3", Pitch = 0.6, Volume = 0.8 },
	Awaken = { Id = "rbxasset://sounds/Rocket whoosh 01.wav", Pitch = 0.6, Volume = 0.9 },
	KO = { Id = "rbxasset://sounds/action_falling.mp3", Pitch = 0.5, Volume = 0.8 },
	Click = { Id = "rbxasset://sounds/button.wav", Pitch = 1, Volume = 0.4 },
	Ping = { Id = "rbxasset://sounds/electronicpingshort.wav", Pitch = 1.2, Volume = 0.35 },
}

local function definition(name: string): Def?
	local base = BUILTIN[name]
	local custom = AssetIds.Resolve((AssetIds.Sounds :: any)[name])
	if custom then
		return { Id = custom, Pitch = 1, Volume = if base then math.max(base.Volume, 0.6) else 0.7 }
	end
	return base
end

-- Plays a named sound at a position (3D) or, with no position, on the listener (2D).
function Sound.Play(name: string, position: Vector3?, pitch: number?, volume: number?)
	local def = definition(name)
	if not def then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume * (volume or 1)
	sound.PlaybackSpeed = def.Pitch * (pitch or 1) * (0.94 + math.random() * 0.12)
	sound.RollOffMinDistance = 20
	sound.RollOffMaxDistance = 400
	if position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = workspace.Terrain
		sound.Parent = attachment
		sound.Ended:Connect(function()
			attachment:Destroy()
		end)
		task.delay(6, function()
			attachment:Destroy()
		end)
	else
		sound.Parent = SoundService
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		task.delay(6, function()
			sound:Destroy()
		end)
	end
	sound:Play()
end

-- A looping sound (crowd ambience). Returns the Sound so the caller can fade it.
function Sound.Loop(name: string, volume: number): Sound?
	local def = definition(name)
	if not def then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Looped = true
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	return sound
end

return Sound
