--[[
	Skins: cosmetic skins sold for Robux as gamepasses.

	Who owns what is decided on the server (Server/SkinService), never the client. While the gamepasses
	aren't set up, Config.Shop.GrantAllSkins gives every player every skin. To go live: create each
	gamepass in the Creator Dashboard, paste its id into GamePassId below, then turn GrantAllSkins off.
]]

local Skins = {}

export type Skin = {
	Id: string,
	Name: string,
	Class: string, -- the class whose ball it reskins
	Blurb: string, -- the line under the name on the sky billboards
	GamePassId: number, -- 0 until the gamepass exists
	Price: number, -- Robux, shown on the billboards once skins stop being free; keep it equal to the gamepass price
	Colors: { Deep: Color3, Glow: Color3, Spark: Color3 },
}

Skins.List = {
	{
		Id = "CosmicBall",
		Name = "Cosmic Ball",
		Class = "Soccer",
		Blurb = "SOCCER BALL SKIN",
		GamePassId = 0,
		Price = 199, -- placeholder: set to your real price
		Colors = {
			Deep = Color3.fromRGB(18, 10, 52),
			Glow = Color3.fromRGB(0, 220, 255),
			Spark = Color3.fromRGB(255, 70, 225),
		},
	},
} :: { Skin }

function Skins.Get(id: string?): Skin?
	if not id then
		return nil
	end
	for _, skin in Skins.List do
		if skin.Id == id then
			return skin
		end
	end
	return nil
end

-- The skin that applies to `classId`'s ball, if `id` is one.
function Skins.ForClass(id: string?, classId: string): Skin?
	local skin = Skins.Get(id)
	return if skin and skin.Class == classId then skin else nil
end

return Skins
