--[[
	Football - "The Blitz". Raw power, grabs and shockwaves, royal purple energy.

	M1      forearm shivers and shoulder checks, finishing with a shoulder charge
	1       Stiff Arm - a straight-arm shove that breaks blocks
	2       Hail Mary - a long spiral throw wrapped in purple energy
	3       Blitz Tackle - charge with armor, grab the first enemy and spear them into the ground
	4       Touchdown Spike - leap and spike the ball: a shockwave launches everyone around you
	Awakening "Juggernaut": Pancake Block, Spiral Cannon, Goal Line Stand, Meteor Sack
]]

local Common = require(script.Parent.Common)
local Types = require(script.Parent.Types)

local CLASS = "Football"

local Football: Types.Character = {
	Id = CLASS,
	DisplayName = "Football",
	Title = "The Blitz",
	Description = "Unstoppable power. Break blocks, grab and slam, and shake the whole field.",
	Color = Color3.fromRGB(150, 60, 255),
	Palette = {
		Core = Color3.fromRGB(250, 232, 255),
		Primary = Color3.fromRGB(160, 60, 255),
		Secondary = Color3.fromRGB(255, 60, 200),
		Dark = Color3.fromRGB(30, 10, 50),
		Accent = Color3.fromRGB(210, 150, 255),
		Light = Color3.fromRGB(170, 80, 255),
	},
	AwakenedPalette = {
		Core = Color3.fromRGB(255, 220, 255),
		Primary = Color3.fromRGB(125, 25, 225),
		Secondary = Color3.fromRGB(255, 30, 160),
		Dark = Color3.fromRGB(12, 0, 22),
		Accent = Color3.fromRGB(255, 120, 230),
		Light = Color3.fromRGB(150, 40, 255),
	},
	AwakeningName = "Juggernaut",
	M1 = Common.M1(CLASS, {
		Name = "Forearm Shivers",
		Description = "Heavy forearms and shoulder checks, finishing with a shoulder charge.",
		Damage = 3.2,
		FinisherDamage = 4.5,
	}),
	Moves = {
		{
			Id = "Football_StiffArm",
			Name = "Stiff Arm",
			Class = CLASS,
			Slot = "1",
			Description = "Lunge with a straight-arm shove that smashes through blocks.",
			Cooldown = 5,
			Busy = 0.5,
			MaxTime = 0.7,
			Hits = {
				Shove = { Damage = 8, Stun = 1.0, Range = 14, GuardBreak = true, KnockBack = 48, KnockUp = 10, HitStop = 0.1, Heavy = true },
			},
		},
		{
			Id = "Football_HailMary",
			Name = "Hail Mary",
			Class = CLASS,
			Slot = "2",
			Description = "A tight spiral thrown the length of the field, wrapped in purple energy.",
			Cooldown = 8,
			Busy = 0.55,
			MaxTime = 1.8,
			Hits = {
				Ball = { Damage = 11, Stun = 1.15, Range = 115, Projectile = true, KnockBack = 35, KnockUp = 14, Knockdown = 0.6 },
			},
		},
		{
			Id = "Football_BlitzTackle",
			Name = "Blitz Tackle",
			Class = CLASS,
			Slot = "3",
			Description = "Charge with armor on. Grab the first enemy you hit, drive them back and spear them into the turf.",
			Cooldown = 11,
			Busy = 1.35,
			MaxTime = 1.6,
			HyperArmor = true,
			Hits = {
				Grab = { Damage = 3, Stun = 1.2, Range = 46, Unblockable = true, Grab = 0.75 },
				Spear = { Damage = 14, Stun = 1.3, Range = 60, Unblockable = true, KnockBack = 20, KnockUp = -60, Knockdown = 1.3, HitStop = 0.16, Heavy = true },
			},
		},
		{
			Id = "Football_TouchdownSpike",
			Name = "Touchdown Spike",
			Class = CLASS,
			Slot = "4",
			Description = "Leap and spike the ball into the ground. The shockwave launches everyone around you.",
			Cooldown = 13,
			Busy = 0.95,
			MaxTime = 1.2,
			Aerial = true,
			Hits = {
				Shockwave = { Damage = 12, Stun = 1.4, Range = 20, KnockBack = 22, KnockUp = 58, Radial = true, HitStop = 0.12, Heavy = true },
			},
		},
	},
	Awakened = {
		{
			Id = "Football_PancakeBlock",
			Name = "Pancake Block",
			Class = CLASS,
			Slot = "1",
			Description = "An explosive two-handed shove. Sends a shockwave forward that flattens anything in front of you.",
			Cooldown = 5,
			Busy = 0.55,
			MaxTime = 0.8,
			Awakened = true,
			Hits = {
				Blast = { Damage = 10, Stun = 1.1, Range = 20, GuardBreak = true, KnockBack = 90, KnockUp = 20, Knockdown = 0.9, HitStop = 0.12, Heavy = true },
			},
		},
		{
			Id = "Football_SpiralCannon",
			Name = "Spiral Cannon",
			Class = CLASS,
			Slot = "2",
			Description = "Hurl a giant drilling football that tears through everyone in a line.",
			Cooldown = 8,
			Busy = 0.7,
			MaxTime = 1.8,
			Awakened = true,
			Hits = {
				Drill = { Damage = 13, Stun = 1.2, Range = 110, Projectile = true, KnockBack = 40, KnockUp = 18, HitStop = 0.1, Heavy = true },
			},
		},
		{
			Id = "Football_GoalLineStand",
			Name = "Goal Line Stand",
			Class = CLASS,
			Slot = "3",
			Description = "Brace yourself. If anyone hits you during the stance, you shrug it off and flatten them.",
			Cooldown = 10,
			Busy = 0.9,
			MaxTime = 2.0,
			Awakened = true,
			Counter = 0.85,
			Hits = {
				Counter = { Damage = 15, Stun = 1.4, Range = 40, Unblockable = true, KnockBack = 70, KnockUp = 30, Knockdown = 1.2, HitStop = 0.16, Heavy = true },
			},
		},
		{
			Id = "Football_MeteorSack",
			Name = "Meteor Sack",
			Class = CLASS,
			Slot = "4",
			Description = "Grab your opponent, rocket into the sky and piledrive them back down like a meteor.",
			Cooldown = 30,
			Busy = 2.4,
			MaxTime = 2.8,
			Awakened = true,
			HyperArmor = true,
			Ultimate = true,
			Hits = {
				Grab = { Damage = 2, Stun = 2.2, Range = 36, Unblockable = true, Grab = 1.9 },
				Impact = { Damage = 30, Stun = 1.6, Range = 120, Unblockable = true, KnockBack = 30, KnockUp = 40, Knockdown = 1.6, HitStop = 0.2, Heavy = true },
				Quake = { Damage = 10, Stun = 1.0, Range = 120, KnockBack = 60, KnockUp = 45, Radial = true, Knockdown = 1.0 },
			},
		},
	},
	Awaken = Common.Awaken(CLASS, "Juggernaut"),
}

return Football
