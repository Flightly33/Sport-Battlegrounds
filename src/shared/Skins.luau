--[[
	Skins: cosmetic looks for the class props, applied on top of the normal build (Shared/Props).

	A character's equipped skin is its "BallSkin" attribute, set by the server on spawn
	(Server/CharacterService). Every client reads it, so everyone sees the same ball on the player and
	on the balls they kick.

	Ownership: until the game passes are set up, everyone owns every skin (FREE_FOR_EVERYONE). To sell
	one, put its game pass id in GamePassId and turn FREE_FOR_EVERYONE off; the server then checks
	MarketplaceService:UserOwnsGamePassAsync.
]]

local Skins = {}

Skins.FREE_FOR_EVERYONE = true

export type Skin = {
	Name: string,
	Class: string, -- whose prop it re-skins
	GamePassId: number, -- 0 = not on sale yet
	Apply: (parts: { Part }) -> (),
}

-- Cosmic: a deep-space ball with glowing star patches, twinkling sparkles and a violet glow.
local function cosmic(parts: { Part })
	local core = parts[1]
	core.Color = Color3.fromRGB(28, 12, 66)
	core.Material = Enum.Material.Glass
	core.Reflectance = 0.15
	for i = 2, #parts do
		local patch = parts[i]
		patch.Color = if i % 2 == 0 then Color3.fromRGB(140, 90, 255) else Color3.fromRGB(80, 220, 255)
		patch.Material = Enum.Material.Neon
	end
	local stars = Instance.new("ParticleEmitter")
	stars.Name = "CosmicStars"
	stars.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 140, 255))
	stars.LightEmission = 1
	stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.18), NumberSequenceKeypoint.new(1, 0) })
	stars.Lifetime = NumberRange.new(0.5, 0.9)
	stars.Rate = 14
	stars.Speed = NumberRange.new(0.3, 1)
	stars.SpreadAngle = Vector2.new(180, 180)
	stars.Parent = core
	local glow = Instance.new("PointLight")
	glow.Name = "CosmicGlow"
	glow.Color = Color3.fromRGB(150, 100, 255)
	glow.Brightness = 1.5
	glow.Range = 6
	glow.Parent = core
end

Skins.List = {
	Cosmic = { Name = "Cosmic Ball", Class = "Soccer", GamePassId = 0, Apply = cosmic },
} :: { [string]: Skin }

-- The skin `skinId` for `classId`'s prop, or nil when it doesn't apply.
function Skins.Get(skinId: unknown, classId: string): Skin?
	if typeof(skinId) ~= "string" then
		return nil
	end
	local skin = Skins.List[skinId]
	if skin and skin.Class == classId then
		return skin
	end
	return nil
end

return Skins
