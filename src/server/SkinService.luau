--[[
	SkinService: decides which cosmetic skins (Shared/Skins) each player owns and which one their ball wears.

	Ownership lives only here. While Config.Shop.GrantAllSkins is on, everybody owns everything; after
	that it comes from the gamepasses (checked when a player joins, and again when they buy one). The
	owned skins are published on the player as the "Skins" attribute (comma separated) for any UI.
	A class's ball wears the first skin you own for it, so there is nothing to equip yet.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Signal)
local Skins = require(Shared.Skins)

local SkinService = {}

SkinService.Changed = Signal.new() -- (player) a purchase changed what they own

local WAIT_LIMIT = 5 -- seconds a spawn will wait for the first ownership check

local owned: { [Player]: { [string]: boolean } } = {}

local function publish(player: Player)
	local ids = {}
	for _, skin in Skins.List do
		if owned[player][skin.Id] then
			table.insert(ids, skin.Id)
		end
	end
	player:SetAttribute("Skins", table.concat(ids, ","))
end

local function ownsPass(player: Player, gamePassId: number): boolean
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamePassId)
	end)
	if not ok then
		warn("[SkinService] couldn't check gamepass", gamePassId, "for", player.Name, result)
		return false
	end
	return result == true
end

local function load(player: Player)
	local set: { [string]: boolean } = {}
	for _, skin in Skins.List do
		if Config.Shop.GrantAllSkins then
			set[skin.Id] = true
		elseif skin.GamePassId > 0 then
			set[skin.Id] = ownsPass(player, skin.GamePassId)
		end
	end
	owned[player] = set
	publish(player)
end

function SkinService.Owns(player: Player, skinId: string): boolean
	local waited = 0
	while not owned[player] and player.Parent and waited < WAIT_LIMIT do
		waited += task.wait(0.1)
	end
	local set = owned[player]
	return set ~= nil and set[skinId] == true
end

-- The skin `player`'s ball wears for `classId`, or nil for the plain ball.
function SkinService.Equipped(player: Player, classId: string): string?
	for _, skin in Skins.List do
		if skin.Class == classId and SkinService.Owns(player, skin.Id) then
			return skin.Id
		end
	end
	return nil
end

function SkinService.Init()
	local function onPlayer(player: Player)
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, purchased: boolean)
		if not purchased or not owned[player] then
			return
		end
		for _, skin in Skins.List do
			if skin.GamePassId == gamePassId then
				owned[player][skin.Id] = true
			end
		end
		publish(player)
		SkinService.Changed:Fire(player)
	end)
end

return SkinService
