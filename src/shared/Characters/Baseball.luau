--[[
	Baseball - "The Slugger". Bat swings and pitches, emerald-green wind.

	M1      bat swings (level, chop, backhand) finishing with a full swing
	1       Fastball - a blistering straight pitch
	2       Stolen Base - a slide that sweeps the first enemy off their feet
	3       Line Drive - toss and bat a ball: it flies inside a crescent of cutting wind
	4       Home Run - wind up and crush them out of the park
	Awakening "Grand Slam": Rapid Fire, Tornado Swing, Inside-the-Park, Walk-Off Homer
]]

local Common = require(script.Parent.Common)
local Types = require(script.Parent.Types)

local CLASS = "Baseball"

local Baseball: Types.Character = {
	Id = CLASS,
	DisplayName = "Baseball",
	Title = "The Slugger",
	Description = "Long reach and huge launches. Pitch from range, slide in, and knock them out of the park.",
	Color = Color3.fromRGB(40, 210, 110),
	Palette = {
		Core = Color3.fromRGB(235, 255, 240),
		Primary = Color3.fromRGB(40, 220, 110),
		Secondary = Color3.fromRGB(150, 255, 120),
		Dark = Color3.fromRGB(10, 50, 25),
		Accent = Color3.fromRGB(255, 255, 255),
		Light = Color3.fromRGB(80, 255, 140),
	},
	AwakenedPalette = {
		Core = Color3.fromRGB(255, 255, 235),
		Primary = Color3.fromRGB(20, 200, 90),
		Secondary = Color3.fromRGB(255, 215, 80),
		Dark = Color3.fromRGB(5, 40, 15),
		Accent = Color3.fromRGB(255, 240, 150),
		Light = Color3.fromRGB(120, 255, 150),
	},
	AwakeningName = "Grand Slam",
	M1 = Common.M1(CLASS, {
		Name = "Bat Swings",
		Description = "Level swing, chop, backhand - and a full swing to finish. A little more reach than fists and feet.",
		Range = 8.5,
	}),
	Moves = {
		{
			Id = "Baseball_Fastball",
			Name = "Fastball",
			Class = CLASS,
			Slot = "1",
			Description = "A blistering straight pitch. The fastest projectile in the game.",
			Cooldown = 4,
			Busy = 0.5,
			MaxTime = 1.0,
			Hits = {
				Ball = { Damage = 8, Stun = 0.95, Range = 95, Projectile = true, KnockBack = 14, KnockUp = 4 },
			},
		},
		{
			Id = "Baseball_StolenBase",
			Name = "Stolen Base",
			Class = CLASS,
			Slot = "2",
			Description = "Slide in feet-first and sweep the first enemy off their feet.",
			Cooldown = 7,
			Busy = 0.62,
			MaxTime = 0.85,
			Hits = {
				Trip = { Damage = 7, Stun = 1.45, Range = 30, KnockBack = 6, KnockUp = 34, Knockdown = 0.9, HitStop = 0.08 },
			},
		},
		{
			Id = "Baseball_LineDrive",
			Name = "Line Drive",
			Class = CLASS,
			Slot = "3",
			Description = "Toss a ball up and crush it. It flies inside a crescent of cutting wind.",
			Cooldown = 9,
			Busy = 0.75,
			MaxTime = 1.6,
			Hits = {
				Drive = { Damage = 12, Stun = 1.1, Range = 90, Projectile = true, KnockBack = 55, KnockUp = 14, HitStop = 0.1, Heavy = true },
			},
		},
		{
			Id = "Baseball_HomeRun",
			Name = "Home Run",
			Class = CLASS,
			Slot = "4",
			Description = "Wind up with the wind gathering on your bat, then send them flying out of the park.",
			Cooldown = 14,
			Busy = 1.0,
			MaxTime = 1.1,
			Hits = {
				Swing = { Damage = 18, Stun = 1.5, Range = 13, KnockBack = 120, KnockUp = 55, KnockTime = 0.3, Knockdown = 1.4, HitStop = 0.18, Heavy = true, GuardBreak = true },
			},
		},
	},
	Awakened = {
		{
			Id = "Baseball_RapidFire",
			Name = "Rapid Fire",
			Class = CLASS,
			Slot = "1",
			Description = "Six fastballs in the time it takes to blink.",
			Cooldown = 6,
			Busy = 0.85,
			MaxTime = 1.8,
			Awakened = true,
			Hits = {
				Ball = { Damage = 3, Stun = 0.6, Range = 95, Projectile = true, Repeat = 6, KnockBack = 5 },
			},
		},
		{
			Id = "Baseball_Tornado",
			Name = "Tornado Swing",
			Class = CLASS,
			Slot = "2",
			Description = "Spin into a green tornado that drags enemies in and batters them.",
			Cooldown = 9,
			Busy = 1.3,
			MaxTime = 1.5,
			Awakened = true,
			Hits = {
				Spin = { Damage = 2.5, Stun = 0.7, Range = 18, Repeat = 5, KnockBack = -28, Radial = true },
				Launch = { Damage = 6, Stun = 1.2, Range = 18, KnockBack = 50, KnockUp = 60, Radial = true, Knockdown = 1.0, HitStop = 0.12, Heavy = true },
			},
		},
		{
			Id = "Baseball_InsideThePark",
			Name = "Inside-the-Park",
			Class = CLASS,
			Slot = "3",
			Description = "Round the bases around your opponent - four lightning-fast hits from four sides.",
			Cooldown = 8,
			Busy = 1.0,
			MaxTime = 1.2,
			Awakened = true,
			Hits = {
				Base = { Damage = 4, Stun = 0.9, Range = 40, Repeat = 4, KnockBack = 2 },
			},
		},
		{
			Id = "Baseball_WalkOff",
			Name = "Walk-Off Homer",
			Class = CLASS,
			Slot = "4",
			Description = "Call your shot, then hit them so hard they twinkle in the sky before crashing back down.",
			Cooldown = 30,
			Busy = 2.0,
			MaxTime = 3.6,
			Awakened = true,
			HyperArmor = true,
			Ultimate = true,
			Hits = {
				Swing = { Damage = 12, Stun = 3.2, Range = 14, Unblockable = true, KnockUp = 150, KnockBack = 10, KnockTime = 0.4, HitStop = 0.25, Heavy = true },
				Crash = { Damage = 18, Stun = 1.4, Range = 200, Projectile = true, Unblockable = true, KnockUp = -120, Knockdown = 1.5, HitStop = 0.12, Heavy = true },
			},
		},
	},
	Awaken = Common.Awaken(CLASS, "Grand Slam"),
}

return Baseball
