--[[
	Moves every character shares (dash, evasive) and the M1 chain builder.

	M1 chain: Hit1-Hit3 stun just long enough to land the next click; Hit4 knocks the victim away.
	Holding Space on the 4th hit turns it into an Uppercut (launch), using it in the air into a
	Downslam.
]]

local Types = require(script.Parent.Types)
local Config = require(script.Parent.Parent.Config)

type Move = Types.Move
type Hit = Types.Hit

local Common = {}

Common.M1_INTERVAL = 0.3 -- seconds between clicks in the chain (also the Busy of hits 1-3)
Common.M1_RANGE = 7.5

export type M1Options = {
	Name: string,
	Description: string,
	Damage: number?,
	FinisherDamage: number?,
	Range: number?,
}

function Common.M1(class: string, options: M1Options): Move
	local damage = options.Damage or 3
	local finisher = options.FinisherDamage or 4
	local range = options.Range or Common.M1_RANGE
	local function chain(): Hit
		return { Damage = damage, Stun = 0.72, Range = range, KnockBack = 6, KnockTime = 0.12 }
	end
	return {
		Id = class .. "_M1",
		Name = options.Name,
		Class = class,
		Slot = "M1",
		Description = options.Description,
		Cooldown = 0, -- handled by the chain (Config.Combat.ComboEndCooldown after Hit4)
		Busy = Common.M1_INTERVAL,
		MaxTime = 0.6,
		Aerial = true,
		Hits = {
			Hit1 = chain(),
			Hit2 = chain(),
			Hit3 = chain(),
			Hit4 = {
				Damage = finisher,
				Stun = 1.1,
				Range = range + 0.5,
				KnockBack = 62,
				KnockUp = 16,
				KnockTime = 0.25,
				Knockdown = 0.9,
				HitStop = 0.1,
				Heavy = true,
			},
			Uppercut = {
				Damage = finisher,
				Stun = 1.35,
				Range = range + 0.5,
				KnockBack = 4,
				KnockUp = 62,
				KnockTime = 0.22,
				HitStop = 0.1,
				Heavy = true,
			},
			Downslam = {
				Damage = finisher,
				Stun = 1.2,
				Range = range + 2,
				KnockBack = 8,
				KnockUp = -90,
				KnockTime = 0.2,
				Knockdown = 1.0,
				HitStop = 0.1,
				Heavy = true,
			},
		},
	}
end

local function dash(id: string, cooldown: number): Move
	return {
		Id = id,
		Name = "Dash",
		Class = "Common",
		Slot = "Dash",
		Description = "Dash in the direction you're moving.",
		Cooldown = cooldown,
		Busy = Config.Dash.Duration,
		MaxTime = 0,
		Aerial = true,
		Hits = {},
	}
end

Common.DashFront = dash("Dash_Front", Config.Dash.FrontCooldown)
Common.DashSide = dash("Dash_Side", Config.Dash.Cooldown)
Common.DashBack = dash("Dash_Back", Config.Dash.Cooldown)

Common.Evasive = {
	Id = "Evasive",
	Name = "Evasive",
	Class = "Common",
	Slot = "Evasive",
	Description = "Break out of a combo when your Evasive bar is full (Dash while stunned).",
	Cooldown = 3,
	Busy = 0.35,
	MaxTime = 0,
	Aerial = true,
	Invulnerable = 0.6,
	Hits = {},
} :: Move

-- The awakening transformation (G). Each class plays its own cinematic for it.
function Common.Awaken(class: string, name: string): Move
	return {
		Id = class .. "_Awaken",
		Name = name,
		Class = class,
		Slot = "Awaken",
		Description = "Transform when your Awakening meter is full.",
		Cooldown = 0,
		Busy = 2.2,
		MaxTime = 2.4,
		Invulnerable = 2.3,
		HyperArmor = true,
		Aerial = true,
		Hits = {
			-- Everyone close by gets blown back by the transformation
			Burst = { Damage = 4, Stun = 0.8, Range = 18, KnockBack = 70, KnockUp = 25, Radial = true, Knockdown = 0.8, Unblockable = true },
		},
	}
end

return Common
