--[[
	MatchService: KOs, streaks and the kill feed.
	leaderstats: KOs (total) and Streak (KOs since your last death).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)

local MatchService = {}

local killFeed = Remotes.Event("KillFeed")
local announce = Remotes.Event("Announce")

local STREAK_NAMES = {
	[3] = "is ON FIRE",
	[5] = "is UNSTOPPABLE",
	[8] = "is LEGENDARY",
	[12] = "is a GOD OF THE STADIUM",
}

local function stat(player: Player, name: string): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild(name)
	return if value and value:IsA("IntValue") then value else nil
end

function MatchService.Init()
	local function onPlayer(player: Player)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		for _, name in { "KOs", "Streak" } do
			local value = Instance.new("IntValue")
			value.Name = name
			value.Parent = leaderstats
		end
		leaderstats.Parent = player
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	CombatService.FighterDied:Connect(function(fighter: CombatService.Fighter, killer: Player?)
		local victimName = if fighter.Player then fighter.Player.DisplayName else fighter.Model.Name
		local victimClass = fighter.Class
		if fighter.Player then
			local streak = stat(fighter.Player, "Streak")
			if streak then
				if streak.Value >= 3 and killer then
					announce:FireAllClients(string.format("%s ENDED %s'S STREAK", string.upper(killer.DisplayName), string.upper(victimName)), Color3.fromRGB(255, 255, 255))
				end
				streak.Value = 0
			end
		end
		local killerName = ""
		local killerClass = ""
		if killer then
			killerName = killer.DisplayName
			local killerFighter = CombatService.ForPlayer(killer)
			killerClass = if killerFighter then killerFighter.Class else ""
			local kos = stat(killer, "KOs")
			local streak = stat(killer, "Streak")
			if kos and fighter.Player then
				kos.Value += 1
			end
			if streak and fighter.Player then
				streak.Value += 1
				local title = STREAK_NAMES[streak.Value]
				if title then
					local character = Characters.Get(killerClass)
					announce:FireAllClients(string.format("%s %s", string.upper(killer.DisplayName), title), if character then character.Color else Color3.new(1, 1, 1))
				end
			end
		end
		killFeed:FireAllClients(killerName, victimName, killerClass, victimClass)
	end)
end

return MatchService
