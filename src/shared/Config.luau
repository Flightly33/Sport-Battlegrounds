--[[
	Global tuning for Sports Battlegrounds. Per-move numbers (damage, stun, cooldowns) live with each
	character in Shared/Characters; everything that is shared by every fighter lives here.
]]

local Config = {}

Config.GameName = "Sports Battlegrounds"

Config.Player = {
	MaxHealth = 100,
	WalkSpeed = 16,
	RunSpeed = 27,
	BlockWalkSpeed = 6,
	StunWalkSpeed = 2,
	JumpPower = 50,
	RespawnTime = 4,
	SpawnProtection = 2, -- seconds of invulnerability after spawning
	-- Out-of-combat regeneration (no damage dealt or taken for RegenDelay seconds)
	RegenDelay = 10,
	RegenPerSecond = 2,
	-- Double-tap W (or hold Left Ctrl) to run. Running stops when you stop moving, block or get stunned.
	DoubleTapWindow = 0.3,
}

Config.Combat = {
	-- M1: a 4-hit chain. Each hit stuns long enough to land the next one; the 4th knocks back.
	ComboResetTime = 1.1, -- M1 chain resets if you wait longer than this between clicks
	ComboEndCooldown = 1.4, -- after the 4th hit
	-- How far (studs) a hit may be from the attacker on the server before it's rejected.
	-- Generous because the server sees everyone ~ping/2 in the past.
	RangeTolerance = 14,
	-- Hits may arrive this long after the move's own window (lag, projectile travel).
	TimeTolerance = 0.75,
	-- Anti-stunlock: after this many seconds of continuous stun, further stuns are cut to StunlockCap
	-- until the victim has been free for StunlockRecovery seconds. Evasive is the other way out.
	MaxStunChain = 6,
	StunlockCap = 0.25,
	StunlockRecovery = 1,
	-- Kill credit goes to the last attacker within this many seconds.
	KillCreditWindow = 12,
	HitStop = 0.06, -- freeze frames on normal hits (heavy hits use their own)
	ComboCounterWindow = 1.6, -- hits closer together than this count as one combo
}

Config.Block = {
	MaxDurability = 60,
	DurabilityPerDamage = 3, -- blocked damage x this is taken off durability
	RegenPerSecond = 22, -- while not blocking
	ChipDamage = 0.1, -- blocked moves still deal 10% (M1s deal none)
	GuardBreakStun = 1.6,
	FrontDot = -0.15, -- attacks from (roughly) behind are not blocked
}

Config.Dash = {
	Cooldown = 2.2, -- side / back dash
	FrontCooldown = 3.5,
	Distance = 42, -- studs covered by a forward dash
	SideDistance = 32,
	BackDistance = 30,
	Duration = 0.34, -- seconds
	-- Speed curve (see Client/Motion): starts at StartSpeed x the peak, reaches the peak over the first
	-- EaseIn of the dash, holds, then eases down to EndSpeed x the peak over the last EaseOut.
	StartSpeed = 0.45,
	EaseIn = 0.18,
	EaseOut = 0.4,
	EndSpeed = 0.18,
	Carry = 0.3, -- share of the final speed kept after the dash, so it doesn't stop dead
	-- Running into an enemy mid-dash stops the dash and throws the class's strike (kick / punch /
	-- forearm / bat swing). Damage and knockback are the Dash moves' Catch and Strike hits.
	StrikeReach = 3.2, -- how far ahead of the body an enemy counts as "ran into" (studs)
	StrikeSize = Vector3.new(5, 6, 4), -- the contact box in front of the body
	StrikeWindow = 1.0, -- the strike must land within this long of the dash starting (s)
}

-- Dashes, lunges, leaps and slides (Client/Motion).
Config.Motion = {
	Force = 1e6, -- LinearVelocity force limit; much below ~1e4 a Humanoid shrugs it off
	WallMargin = 2.2, -- studs kept between a moving character and the arena wall
	BodyRadius = 1.3, -- wall checks reach this far past the next step
}

Config.Evasive = {
	-- Fills while you're getting hit (and slowly over time); when full, press Dash while stunned to
	-- break out of a combo with a short burst of invulnerability.
	PerDamage = 4, -- % per point of damage taken
	PerSecond = 1.5, -- % per second, always
	Invulnerability = 0.6,
	Cost = 100,
}

Config.Awakening = {
	-- The meter fills from fighting. Full meter + G = cinematic transformation into the awakened
	-- moveset (new moves 1-4, stronger M1s) for Duration seconds.
	PerDamageDealt = 1.25,
	PerDamageTaken = 0.6,
	Duration = 55,
	TransformTime = 2.2, -- invulnerable during the cinematic
	Heal = 20,
	DamageMultiplier = 1.15,
	SpeedMultiplier = 1.12,
	-- Studio only: start with a full meter so you can try awakenings without fighting.
	StudioStartFull = true,
}

Config.Arena = {
	-- Players are kept inside the barrier (see Shared/Stadium/Layout.luau for the shape).
	FloorY = 0,
	-- Training dummies stand on the track behind the east goal.
	DummyCount = 4,
	DummyRespawn = 3,
}

Config.Crowd = {
	-- Fans are drawn by each client. Density 1 = a fan in ~62% of seats.
	DefaultDensity = { Desktop = 1, Mobile = 0.45 },
	AnimateDistance = 950,
	UpdateHz = 30,
	ConfettiRate = 3, -- bursts per second around the stadium
}

-- Keyboard / gamepad bindings. Mobile gets on-screen buttons for all of these.
Config.Keys = {
	M1 = Enum.UserInputType.MouseButton1,
	Move1 = Enum.KeyCode.One,
	Move2 = Enum.KeyCode.Two,
	Move3 = Enum.KeyCode.Three,
	Move4 = Enum.KeyCode.Four,
	Awaken = Enum.KeyCode.G,
	Block = Enum.KeyCode.F,
	Dash = Enum.KeyCode.Q,
	Run = Enum.KeyCode.LeftControl, -- hold (or double-tap W). Shift stays Roblox's shift-lock.
	Uppercut = Enum.KeyCode.Space, -- hold while landing the 4th M1
	CharacterMenu = Enum.KeyCode.M,
}

Config.GamepadKeys = {
	M1 = Enum.KeyCode.ButtonR2,
	Move1 = Enum.KeyCode.ButtonX,
	Move2 = Enum.KeyCode.ButtonY,
	Move3 = Enum.KeyCode.ButtonB,
	Move4 = Enum.KeyCode.DPadUp,
	Awaken = Enum.KeyCode.DPadDown,
	Block = Enum.KeyCode.ButtonL2,
	Dash = Enum.KeyCode.ButtonR1,
	Run = Enum.KeyCode.ButtonL3,
	CharacterMenu = Enum.KeyCode.DPadLeft,
}

-- Sound and music. Slots without an id in Shared/AssetIds are filled by searching Roblox's audio
-- library on the server at startup (Shared/AudioCatalog has the search terms); anything that fails
-- falls back to the built-in sounds.
Config.Audio = {
	Search = true,
	MusicVolume = 0.22,
	AmbienceVolume = 0.15, -- the stadium crowd loop, kept quiet...
	AmbienceNearWall = 2.6, -- ...and this many times louder right by the stadium wall
	AmbienceWallRange = 70, -- studs from the wall over which it swells
	SfxVolume = 1,
	MusicToggleKey = Enum.KeyCode.N,
}

Config.Debug = {
	ShowHitboxes = false, -- draw client hitboxes (Studio only)
	LogRejectedHits = true, -- print why the server threw a hit away (Studio only)
}

return Config
