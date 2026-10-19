--[[
	Optional uploaded assets (the Blender pack in /blender, sounds you pick from the Creator Store).

	The game is complete without any of these: every effect has a built-in version made from parts,
	beams and particles. Upload a file, paste its id here (just the number, or "rbxassetid://..."),
	and the matching effect switches to it automatically.
]]

local AssetIds = {}

-- Meshes from blender/out/meshes/*.obj (Studio: 3D Importer or Asset Manager -> Bulk Import, then
-- copy each Mesh id - the MeshId, not the id of a Model wrapping it). Rebuild with blender/build_pack.py.
AssetIds.Meshes = {
	Ring = "", -- ring.obj           shockwave rings
	Crescent = "", -- crescent.obj   slash arcs
	Spiral = "", -- spiral.obj       wind spirals around projectiles
	Bolt = "", -- bolt.obj           lightning strikes from the sky
	Burst = "", -- burst.obj         anime impact star
	Dome = "", -- dome.obj           explosion shell on the ground
}

-- Flipbook / effect textures from blender/out/textures/*.png
AssetIds.Textures = {
	Explosion = "", -- explosion_8x8.png (8x8 flipbook) fireballs in explosions
	Smoke = "", -- smoke_4x4.png (4x4 flipbook)    smoke puffs
	Lightning = "", -- lightning_4x4.png (4x4 flipbook) crackling electricity
	Spark = "", -- spark.png                       spark particles
	Shockwave = "", -- shockwave.png               ground shockwaves
	Impact = "", -- impact_star.png                impact stars (when the Burst mesh isn't set)
	SpeedLines = "", -- speedlines.png             screen speed lines
}

-- Sounds: an id here always wins. Empty slots are filled by the server's audio-library search
-- (Server/AudioService, terms in Shared/AudioCatalog), then by re-pitched built-in sounds. Several
-- ids separated by commas ("123,456") are picked at random per play.
AssetIds.Sounds = {
	Whoosh = "",
	HeavyWhoosh = "",
	Hit = "",
	HeavyHit = "",
	Block = "",
	GuardBreak = "",
	Explosion = "",
	Thunder = "",
	Zap = "",
	Fire = "",
	Wind = "",
	Kick = "",
	Bounce = "",
	BatCrack = "",
	Tackle = "",
	Awaken = "",
	CrowdAmbience = "",
	CrowdCheer = "",
	KO = "",
	Click = "",
	Ping = "",
	Helicopter = "", -- rotor loop for the helicopter that circles the stadium (silent until set)

	-- Soccer: ids you picked per move (names and fallbacks in Shared/AudioCatalog.Custom). A repeated
	-- id is on purpose: Soccer_M1_4 is also the Dribble Dash kick, and one lightning crack serves both
	-- the Dribble Dash and the Bicycle Kick.
	Soccer_M1_1 = "114637695466966",
	Soccer_M1_2 = "130907980308479",
	Soccer_M1_3 = "119801699610817",
	Soccer_M1_4 = "87240804552787",
	Soccer_LightKick = "9119327493", -- foot meets the ball
	Soccer_LightKickHit = "109316755832781", -- the ball meets an enemy
	Soccer_LightningShot = "110208060085134",
	Soccer_DashRun = "103677674954702",
	Soccer_DashKick = "87240804552787",
	Soccer_DashLightning = "136437776813407",
	Soccer_BicycleLeap = "123867785814212",
	Soccer_BicycleImpact = "74149238738530",
	Soccer_BicycleLightning = "136437776813407",
	Soccer_AwakenIntro = "18173968754",
	Soccer_AwakenElectricity = "134540810991378",
	Soccer_AwakenTheme = "126981868995896", -- loops for as long as the awakening lasts
}

-- Background music ids, played shuffled. Leave empty to use the audio-library search.
AssetIds.Music = {} :: { string }

-- "123" / "rbxassetid://123" -> "rbxassetid://123"; "" -> nil
function AssetIds.Resolve(id: string?): string?
	if not id or id == "" then
		return nil
	end
	if string.find(id, "://", 1, true) then
		return id
	end
	return "rbxassetid://" .. id
end

return AssetIds
