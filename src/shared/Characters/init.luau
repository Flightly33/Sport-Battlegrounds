--[[
	Character registry: every class, and every move by id.
]]

local Common = require(script.Common)
local Types = require(script.Types)

export type Character = Types.Character
export type Move = Types.Move
export type Hit = Types.Hit
export type Palette = Types.Palette

local Characters = {}

Characters.Default = "Soccer"

Characters.List = {
	require(script.Soccer),
	require(script.Basketball),
	require(script.Football),
	require(script.Baseball),
} :: { Character }

Characters.ById = {} :: { [string]: Character }
Characters.Moves = {} :: { [string]: Move }

local function register(move: Move)
	assert(Characters.Moves[move.Id] == nil, "duplicate move id " .. move.Id)
	Characters.Moves[move.Id] = move
end

for _, character in Characters.List do
	Characters.ById[character.Id] = character
	register(character.M1)
	register(character.Awaken)
	for _, move in character.Moves do
		register(move)
	end
	for _, move in character.Awakened do
		register(move)
	end
end
register(Common.DashFront)
register(Common.DashSide)
register(Common.DashBack)
register(Common.Evasive)

function Characters.Get(id: string?): Character?
	return if id then Characters.ById[id] else nil
end

function Characters.Move(id: string): Move?
	return Characters.Moves[id]
end

-- The move a key triggers for a class right now ("M1", "1".."4", "Awaken").
function Characters.MoveFor(classId: string, slot: string, awakened: boolean): Move?
	local character = Characters.ById[classId]
	if not character then
		return nil
	end
	if slot == "M1" then
		return character.M1
	elseif slot == "Awaken" then
		return character.Awaken
	end
	local index = tonumber(slot)
	if not index then
		return nil
	end
	local list = if awakened then character.Awakened else character.Moves
	return list[index]
end

function Characters.Palette(classId: string, awakened: boolean): Palette
	local character = Characters.ById[classId] or Characters.ById[Characters.Default]
	return if awakened then character.AwakenedPalette else character.Palette
end

return Characters
