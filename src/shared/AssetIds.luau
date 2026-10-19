--[[
	Optional uploaded assets (the Blender pack in /blender, sounds you pick from the Creator Store).

	The game is complete without any of these: every effect has a built-in version made from parts,
	beams and particles. Upload a file, paste its id here (just the number, or "rbxassetid://..."),
	and the matching effect switches to it automatically.
]]

local AssetIds = {}

-- Meshes from blender/out/meshes/*.fbx (Studio: Asset Manager -> Bulk Import, then copy each Mesh id)
AssetIds.Meshes = {
	Ring = "", -- ring.fbx           shockwave rings
	Crescent = "", -- crescent.fbx   slash arcs
	Spiral = "", -- spiral.fbx       wind spirals around projectiles
	Bolt = "", -- bolt.fbx           lightning bolt strip
	Burst = "", -- burst.fbx         spiky impact star
	Dome = "", -- dome.fbx           explosion shell
}

-- Flipbook / effect textures from blender/out/textures/*.png
AssetIds.Textures = {
	Explosion = "", -- explosion_8x8.png (8x8 flipbook)
	Smoke = "", -- smoke_4x4.png (4x4 flipbook)
	Lightning = "", -- lightning_4x4.png (4x4 flipbook)
	Spark = "", -- spark.png
	Shockwave = "", -- shockwave.png (ring gradient)
	Slash = "", -- slash.png (crescent gradient)
	Impact = "", -- impact_star.png
	Confetti = "", -- confetti.png
	SpeedLines = "", -- speedlines.png (screen overlay)
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
