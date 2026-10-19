--[[
	Types for character and move definitions. These are shared data: the server validates hits with
	them, the client plays the matching move scripts (Client/Moves/<Class>.luau) and shows them in the UI.

	A move's timeline (when each hit happens, VFX, movement) lives in the client script; the server only
	needs to know how hard each named hit is and how far / how late it may land.
]]

export type Hit = {
	Damage: number,
	Stun: number, -- seconds of stun (refreshes; the longest stun wins)
	Range: number, -- max distance attacker -> victim when it lands (studs, before tolerance)
	KnockBack: number?, -- studs/s along the attacker's aim (or away from AoE centre)
	KnockUp: number?, -- studs/s upwards (negative = slam down)
	KnockTime: number?, -- how long the knockback velocity is held (default 0.2)
	Knockdown: number?, -- seconds lying on the floor
	GuardBreak: boolean?, -- breaks a block
	Unblockable: boolean?, -- ignores blocks entirely (grabs)
	Grab: number?, -- the victim is held in front of the attacker for this many seconds
	Projectile: boolean?, -- can still land after the attacker gets interrupted
	Repeat: number?, -- how many times this hit may land on the same victim (multi-hit), default 1
	Radial: boolean?, -- knockback points away from the hit position instead of along the aim
	HitStop: number?, -- freeze frames (default Config.Combat.HitStop)
	Heavy: boolean?, -- big impact (impact frame, strong camera shake)
}

export type Move = {
	Id: string,
	Name: string,
	Class: string,
	Slot: string, -- "M1" | "1".."4" | "Awaken" | "Dash" | "Evasive"
	Description: string,
	Cooldown: number,
	Busy: number, -- seconds the user can't start another move (or block)
	MaxTime: number, -- hits are accepted up to this long after the start (+ tolerance)
	Hits: { [string]: Hit },
	Awakened: boolean?, -- only usable while awakened
	HyperArmor: boolean?, -- hits don't stun / knock back the user while it runs
	Invulnerable: number?, -- seconds of invulnerability from the start
	Counter: number?, -- counter stance window (seconds)
	Aerial: boolean?, -- may be used in the air
	Ultimate: boolean?, -- awakened finisher (cinematic camera, move-name banner)
}

export type Palette = {
	Core: Color3, -- hottest / brightest colour (white-ish)
	Primary: Color3,
	Secondary: Color3,
	Dark: Color3, -- smoke / outlines
	Accent: Color3,
	Light: Color3, -- PointLight colour
}

export type Character = {
	Id: string,
	DisplayName: string,
	Title: string,
	Description: string,
	Color: Color3,
	Palette: Palette,
	AwakenedPalette: Palette,
	AwakeningName: string,
	M1: Move,
	Moves: { Move }, -- 1..4
	Awakened: { Move }, -- 1..4
	Awaken: Move,
}

return {}
