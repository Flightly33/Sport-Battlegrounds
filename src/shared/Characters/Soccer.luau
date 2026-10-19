--[[
	Soccer - "The Lightning Striker". Kicks and leg work, electric-blue lightning.

	M1      body kicks; each kick picks a leg at random (cosmetic only, same damage)
	1       Light Kick - quick snap shot, small damage, 4 s cooldown
	2       Lightning Shot - charged strong kick: leg and ball light up with blue lightning, the ball
	        flies wrapped in wind and explodes on impact in smoky, fiery lightning. A third of max health,
	        10 s cooldown
	3       Lightning Dribble Dash - dash forward dribbling a crackling ball; the first enemy you reach
	        gets the ball flicked into their chin and is launched (combo starter)
	4       Thunder Bicycle Kick - leap, flip, bicycle-kick a lightning bolt into the ground in front;
	        slams airborne enemies (combo ender after the Dribble Dash)
	Awakening "Storm Striker": Railgun, Thunderclap Volley, Flash Step, Storm of the Century
]]

local Common = require(script.Parent.Common)
local Types = require(script.Parent.Types)

local CLASS = "Soccer"
local MAX_HEALTH = 100

local Soccer: Types.Character = {
	Id = CLASS,
	DisplayName = "Soccer",
	Title = "The Lightning Striker",
	Description = "Fast footwork and long-range lightning shots. Strike from a distance, dash in, launch, and slam.",
	Color = Color3.fromRGB(40, 160, 255),
	Palette = {
		Core = Color3.fromRGB(230, 250, 255),
		Primary = Color3.fromRGB(40, 170, 255),
		Secondary = Color3.fromRGB(0, 90, 255),
		Dark = Color3.fromRGB(18, 26, 64),
		Accent = Color3.fromRGB(160, 240, 255),
		Light = Color3.fromRGB(90, 190, 255),
	},
	AwakenedPalette = {
		Core = Color3.fromRGB(255, 255, 255),
		Primary = Color3.fromRGB(70, 130, 255),
		Secondary = Color3.fromRGB(150, 115, 255),
		Dark = Color3.fromRGB(10, 10, 40),
		Accent = Color3.fromRGB(200, 232, 255),
		Light = Color3.fromRGB(120, 150, 255),
	},
	AwakeningName = "Storm Striker",
	M1 = Common.M1(CLASS, {
		Name = "Body Kicks",
		Description = "Four kicks to the body. Each kick switches legs at random - it only changes the look.",
	}),
	Moves = {
		{
			Id = "Soccer_LightKick",
			Name = "Light Kick",
			Class = CLASS,
			Slot = "1",
			Description = "A quick snap shot. Small damage, short stun - a fast poke to start or extend combos.",
			Cooldown = 4,
			Busy = 0.45,
			MaxTime = 1.1,
			Hits = {
				Ball = { Damage = 8, Stun = 1.0, Range = 78, Projectile = true, KnockBack = 16, KnockUp = 6, KnockTime = 0.15 },
			},
		},
		{
			Id = "Soccer_LightningShot",
			Name = "Lightning Shot",
			Class = CLASS,
			Slot = "2",
			Description = "Charge the ball with blue lightning and blast it. Explodes on impact for a third of their health.",
			Cooldown = 10,
			Busy = 0.95,
			MaxTime = 2.2,
			Hits = {
				Ball = {
					Damage = MAX_HEALTH / 3,
					Stun = 1.4,
					Range = 125,
					Projectile = true,
					KnockBack = 85,
					KnockUp = 40,
					KnockTime = 0.25,
					Knockdown = 1.2,
					HitStop = 0.14,
					Heavy = true,
				},
				-- Splash for anyone else caught in the explosion
				Blast = { Damage = 10, Stun = 0.9, Range = 135, Projectile = true, KnockBack = 60, KnockUp = 30, Radial = true, Knockdown = 0.8 },
			},
		},
		{
			Id = "Soccer_DribbleDash",
			Name = "Lightning Dribble Dash",
			Class = CLASS,
			Slot = "3",
			Description = "Dash forward dribbling a crackling ball, then flick it into the first enemy's chin and launch them.",
			Cooldown = 8,
			Busy = 0.8,
			MaxTime = 1.0,
			Hits = {
				Flick = { Damage = 9, Stun = 1.6, Range = 34, KnockBack = 6, KnockUp = 66, KnockTime = 0.2, HitStop = 0.08 },
			},
		},
		{
			Id = "Soccer_BicycleKick",
			Name = "Thunder Bicycle Kick",
			Class = CLASS,
			Slot = "4",
			Description = "Leap, flip and bicycle-kick a lightning bolt into the ground. Slams enemies out of the air.",
			Cooldown = 12,
			Busy = 1.0,
			MaxTime = 1.3,
			Aerial = true,
			Hits = {
				Kick = { Damage = 15, Stun = 1.3, Range = 22, KnockBack = 20, KnockUp = -80, Knockdown = 1.1, HitStop = 0.12, Heavy = true },
			},
		},
	},
	Awakened = {
		{
			Id = "Soccer_Railgun",
			Name = "Railgun",
			Class = CLASS,
			Slot = "1",
			Description = "Supercharge the ball and fire it as a piercing beam of lightning through everyone in a line.",
			Cooldown = 6,
			Busy = 0.7,
			MaxTime = 1.0,
			Awakened = true,
			Hits = {
				Beam = { Damage = 12, Stun = 1.1, Range = 100, Projectile = true, KnockBack = 45, KnockUp = 12, HitStop = 0.1, Heavy = true },
			},
		},
		{
			Id = "Soccer_Volley",
			Name = "Thunderclap Volley",
			Class = CLASS,
			Slot = "2",
			Description = "Five lightning volleys in a blink. Keeps them stunned the whole time.",
			Cooldown = 9,
			Busy = 0.9,
			MaxTime = 1.8,
			Awakened = true,
			Hits = {
				Shot = { Damage = 3, Stun = 0.7, Range = 70, Projectile = true, Repeat = 5, KnockBack = 4 },
			},
		},
		{
			Id = "Soccer_FlashStep",
			Name = "Flash Step",
			Class = CLASS,
			Slot = "3",
			Description = "Turn into a bolt of lightning, reappear behind the nearest enemy and roundhouse them.",
			Cooldown = 7,
			Busy = 0.65,
			MaxTime = 0.9,
			Awakened = true,
			Hits = {
				Kick = { Damage = 10, Stun = 1.3, Range = 60, KnockBack = 55, KnockUp = 22, Knockdown = 0.8, HitStop = 0.1, Heavy = true },
			},
		},
		{
			Id = "Soccer_Storm",
			Name = "Storm of the Century",
			Class = CLASS,
			Slot = "4",
			Description = "Kick the ball into the clouds and call down a storm of lightning, ending in one giant thunderbolt.",
			Cooldown = 30,
			Busy = 2.3,
			MaxTime = 3.2,
			Awakened = true,
			HyperArmor = true,
			Ultimate = true,
			Hits = {
				Strike = { Damage = 4, Stun = 0.9, Range = 60, Projectile = true, Repeat = 6, KnockUp = 10 },
				Finale = { Damage = 20, Stun = 1.5, Range = 60, Projectile = true, KnockBack = 70, KnockUp = 55, Radial = true, Knockdown = 1.4, HitStop = 0.16, Heavy = true },
			},
		},
	},
	Awaken = Common.Awaken(CLASS, "Storm Striker"),
}

return Soccer
