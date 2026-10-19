--[[
	AudioCatalog: what each sound slot should sound like, as Roblox audio-library searches.

	The server (AudioService) runs these through AssetService:SearchAudioAsync when it starts and
	shares the ids it finds; it also prints them as a table you can paste into Shared/AssetIds so the
	picks stop changing between servers. Keywords are tried in order until one returns results.
	Volume is what a found sound plays at (library sounds are mastered loud, so most sit under 1).
]]

local AudioCatalog = {}

export type Search = {
	Keywords: { string },
	MinDuration: number?,
	MaxDuration: number?,
	Volume: number,
	Pick: number?, -- how many of the top results to keep (one is chosen per play); default 1
}

AudioCatalog.Effects = {
	Whoosh = { Keywords = { "swoosh", "whoosh fast", "swing whoosh" }, MaxDuration = 1.5, Volume = 0.45, Pick = 3 },
	HeavyWhoosh = { Keywords = { "heavy whoosh", "big swing whoosh", "whoosh" }, MaxDuration = 2.5, Volume = 0.6 },
	Hit = { Keywords = { "punch", "punch impact", "hit impact" }, MaxDuration = 1.2, Volume = 0.7, Pick = 3 },
	HeavyHit = { Keywords = { "heavy punch", "heavy impact", "body hit" }, MaxDuration = 2.5, Volume = 0.85, Pick = 2 },
	Block = { Keywords = { "shield block", "block impact", "parry" }, MaxDuration = 1.5, Volume = 0.6 },
	GuardBreak = { Keywords = { "glass shatter", "shield break", "shatter" }, MaxDuration = 3, Volume = 0.7 },
	Explosion = { Keywords = { "explosion", "big explosion", "blast" }, MaxDuration = 4, Volume = 0.75, Pick = 2 },
	Thunder = { Keywords = { "lightning strike", "thunder crack", "thunder" }, MaxDuration = 5, Volume = 0.75 },
	Zap = { Keywords = { "electric zap", "electricity spark", "zap" }, MaxDuration = 2, Volume = 0.5 },
	Fire = { Keywords = { "fire whoosh", "fireball", "flame burst" }, MaxDuration = 3, Volume = 0.55 },
	Wind = { Keywords = { "wind gust", "wind whoosh", "gust" }, MaxDuration = 4, Volume = 0.5 },
	Kick = { Keywords = { "soccer ball kick", "ball kick", "kick" }, MaxDuration = 1.5, Volume = 0.65 },
	Bounce = { Keywords = { "basketball bounce", "ball bounce", "bounce" }, MaxDuration = 1.5, Volume = 0.45 },
	BatCrack = { Keywords = { "baseball bat hit", "bat crack", "baseball hit" }, MaxDuration = 2, Volume = 0.7 },
	Tackle = { Keywords = { "body slam", "tackle", "body fall" }, MaxDuration = 2.5, Volume = 0.75 },
	Awaken = { Keywords = { "power up", "energy charge", "anime power up" }, MaxDuration = 5, Volume = 0.7 },
	KO = { Keywords = { "knockout", "body fall heavy", "ko" }, MaxDuration = 3, Volume = 0.7 },
	CrowdCheer = { Keywords = { "crowd cheer", "stadium cheer", "crowd applause" }, MinDuration = 2, MaxDuration = 10, Volume = 0.45 },
	CrowdAmbience = { Keywords = { "stadium crowd", "crowd ambience", "crowd" }, MinDuration = 15, Volume = 0.35 },
	Click = { Keywords = { "ui click", "button click", "click" }, MaxDuration = 0.8, Volume = 0.4 },
	Ping = { Keywords = { "notification", "ui ping", "ding" }, MaxDuration = 1.5, Volume = 0.35 },
} :: { [string]: Search }

-- Sounds that belong to one move. Their ids are set by hand in Shared/AssetIds.Sounds (nothing is
-- searched for them); if an id is empty or fails to load, `Fallback` (one of the Effects above) plays
-- instead, so a move is never silent. Steady sounds skip the small random pitch change that keeps
-- repeated hits from sounding identical, because they are lined up with an animation.
export type Custom = { Fallback: string?, Volume: number, Steady: boolean? }

AudioCatalog.Custom = {
	Soccer_M1_1 = { Fallback = "Kick", Volume = 0.8 },
	Soccer_M1_2 = { Fallback = "Kick", Volume = 0.8 },
	Soccer_M1_3 = { Fallback = "Kick", Volume = 0.8 },
	Soccer_M1_4 = { Fallback = "Kick", Volume = 0.95 },
	Soccer_LightKick = { Fallback = "Kick", Volume = 0.8 },
	Soccer_LightKickHit = { Fallback = "Hit", Volume = 0.85 },
	Soccer_LightningShot = { Fallback = "Thunder", Volume = 0.85, Steady = true },
	Soccer_DashRun = { Fallback = "Whoosh", Volume = 0.7, Steady = true },
	Soccer_DashKick = { Fallback = "Kick", Volume = 0.95 },
	Soccer_DashLightning = { Fallback = "Zap", Volume = 0.8 },
	Soccer_BicycleLeap = { Fallback = "Whoosh", Volume = 0.75, Steady = true },
	Soccer_BicycleImpact = { Fallback = "Explosion", Volume = 0.95, Steady = true },
	Soccer_BicycleLightning = { Fallback = "Thunder", Volume = 0.85, Steady = true },
	Soccer_AwakenIntro = { Fallback = "Awaken", Volume = 0.9, Steady = true },
	Soccer_AwakenElectricity = { Fallback = "Zap", Volume = 0.7, Steady = true },
	Soccer_AwakenTheme = { Volume = 0.5, Steady = true }, -- music: no fallback, the stadium music just carries on
	Helicopter = { Volume = 0.35, Steady = true },
} :: { [string]: Custom }

-- Background music: a few searches, pooled into one shuffled playlist.
AudioCatalog.Music = {
	Keywords = { "sports anthem", "hype rock", "epic battle", "drum and bass", "stadium rock" },
	MinDuration = 60,
	MaxDuration = 400,
	PerKeyword = 3,
	MaxTracks = 10,
}

return AudioCatalog
