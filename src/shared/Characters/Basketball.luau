--[[
	Basketball - "Mr. Showtime". Ball-handling combos, blazing orange fire.

	Built to chain: every move stuns long enough to start the next one.
		M1 x3 -> Ankle Breaker -> Chest Pass -> Alley-Oop -> Slam Dunk
	M1      ball jabs, elbows and a chest-pass finisher, alternating hands
	1       Ankle Breaker - a crossover so nasty the victim drops to a knee (long stun)
	2       Chest Pass - a flaming pass that hits, then rebounds back to your hands (hits again)
	3       Alley-Oop - an upward ball strike that launches the target
	4       Slam Dunk - leap and dunk; extra damage on an airborne (alley-ooped) target
	Awakening "On Fire": Heat Check, Fast Break, Crossover Combo, Supernova Dunk
]]

local Common = require(script.Parent.Common)
local Types = require(script.Parent.Types)

local CLASS = "Basketball"

local Basketball: Types.Character = {
	Id = CLASS,
	DisplayName = "Basketball",
	Title = "Mr. Showtime",
	Description = "The combo king. Every move flows into the next and keeps your opponent locked down.",
	Color = Color3.fromRGB(255, 130, 25),
	Palette = {
		Core = Color3.fromRGB(255, 250, 215),
		Primary = Color3.fromRGB(255, 130, 20),
		Secondary = Color3.fromRGB(255, 205, 40),
		Dark = Color3.fromRGB(60, 22, 10),
		Accent = Color3.fromRGB(255, 82, 20),
		Light = Color3.fromRGB(255, 150, 60),
	},
	AwakenedPalette = {
		Core = Color3.fromRGB(255, 255, 240),
		Primary = Color3.fromRGB(255, 92, 10),
		Secondary = Color3.fromRGB(255, 232, 120),
		Dark = Color3.fromRGB(90, 12, 0),
		Accent = Color3.fromRGB(255, 40, 10),
		Light = Color3.fromRGB(255, 120, 40),
	},
	AwakeningName = "On Fire",
	M1 = Common.M1(CLASS, {
		Name = "Ball Handling",
		Description = "Ball jabs and elbows, finishing with a point-blank chest pass.",
	}),
	Moves = {
		{
			Id = "Basketball_AnkleBreaker",
			Name = "Ankle Breaker",
			Class = CLASS,
			Slot = "1",
			Description = "A lightning-quick crossover that drops your opponent to one knee. Long stun - combo starter.",
			Cooldown = 6,
			Busy = 0.55,
			MaxTime = 0.8,
			Hits = {
				Jab = { Damage = 6, Stun = 1.6, Range = 18, KnockBack = 4, HitStop = 0.08 },
			},
		},
		{
			Id = "Basketball_ChestPass",
			Name = "Chest Pass",
			Class = CLASS,
			Slot = "2",
			Description = "A flaming chest pass that hits, bounces off and comes back to you - hitting again on the way.",
			Cooldown = 7,
			Busy = 0.42,
			MaxTime = 1.8,
			Hits = {
				Pass = { Damage = 7, Stun = 1.25, Range = 64, Projectile = true, KnockBack = 10 },
				Rebound = { Damage = 4, Stun = 1.0, Range = 64, Projectile = true, KnockBack = 8 },
			},
		},
		{
			Id = "Basketball_AlleyOop",
			Name = "Alley-Oop",
			Class = CLASS,
			Slot = "3",
			Description = "Throw the ball up through your opponent and launch them into the air.",
			Cooldown = 9,
			Busy = 0.6,
			MaxTime = 0.8,
			Hits = {
				Launch = { Damage = 8, Stun = 1.8, Range = 12, KnockBack = 2, KnockUp = 72, KnockTime = 0.22, HitStop = 0.08 },
			},
		},
		{
			Id = "Basketball_SlamDunk",
			Name = "Slam Dunk",
			Class = CLASS,
			Slot = "4",
			Description = "Leap and dunk on them. Dunking an airborne opponent deals extra damage.",
			Cooldown = 12,
			Busy = 1.05,
			MaxTime = 1.3,
			Aerial = true,
			Hits = {
				Dunk = { Damage = 16, Stun = 1.3, Range = 34, KnockBack = 30, KnockUp = 22, Radial = true, Knockdown = 1.1, HitStop = 0.12, Heavy = true },
				Posterize = { Damage = 22, Stun = 1.4, Range = 34, KnockBack = 10, KnockUp = -95, Knockdown = 1.3, HitStop = 0.16, Heavy = true },
			},
		},
	},
	Awakened = {
		{
			Id = "Basketball_HeatCheck",
			Name = "Heat Check",
			Class = CLASS,
			Slot = "1",
			Description = "Three flaming jump shots that rain down and explode.",
			Cooldown = 6,
			Busy = 0.8,
			MaxTime = 2.2,
			Awakened = true,
			Hits = {
				Shot = { Damage = 6, Stun = 1.0, Range = 80, Projectile = true, Repeat = 3, KnockBack = 26, KnockUp = 18, Radial = true },
			},
		},
		{
			Id = "Basketball_FastBreak",
			Name = "Fast Break",
			Class = CLASS,
			Slot = "2",
			Description = "Blaze down the court, burning through everyone in your path.",
			Cooldown = 7,
			Busy = 0.6,
			MaxTime = 0.8,
			Awakened = true,
			Hits = {
				Burn = { Damage = 9, Stun = 1.2, Range = 45, KnockBack = 18, KnockUp = 30 },
			},
		},
		{
			Id = "Basketball_CrossoverCombo",
			Name = "Crossover Combo",
			Class = CLASS,
			Slot = "3",
			Description = "A blur of fiery crossovers that ends with a blazing chest pass to the face.",
			Cooldown = 9,
			Busy = 1.0,
			MaxTime = 1.2,
			Awakened = true,
			Hits = {
				Flurry = { Damage = 2.5, Stun = 0.8, Range = 10, Repeat = 5, KnockBack = 3 },
				Finish = { Damage = 7, Stun = 1.2, Range = 11, KnockBack = 75, KnockUp = 20, Knockdown = 0.9, HitStop = 0.12, Heavy = true },
			},
		},
		{
			Id = "Basketball_Supernova",
			Name = "Supernova Dunk",
			Class = CLASS,
			Slot = "4",
			Description = "Leap into the sky, turn the ball into a miniature sun and dunk it into the earth.",
			Cooldown = 30,
			Busy = 2.1,
			MaxTime = 2.6,
			Awakened = true,
			HyperArmor = true,
			Ultimate = true,
			Aerial = true,
			Hits = {
				Nova = { Damage = 28, Stun = 1.6, Range = 70, KnockBack = 90, KnockUp = 60, Radial = true, Knockdown = 1.5, HitStop = 0.18, Heavy = true, Unblockable = true },
			},
		},
	},
	Awaken = Common.Awaken(CLASS, "On Fire"),
}

return Basketball
