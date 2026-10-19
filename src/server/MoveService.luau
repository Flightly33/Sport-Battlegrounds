--[[
	MoveService: validates move and hit requests from clients.

	Clients start their own moves immediately (no input lag) and tell the server; the server checks
	cooldowns, stuns and meters, then tells everyone else to play the move. Hitboxes and projectiles run
	on the attacking client, which reports what it touched; the server checks that the hit belongs to a
	move that is really running, isn't too late, hasn't already landed, and that the victim is in range,
	then CombatService applies it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)

type Fighter = CombatService.Fighter
type Move = Characters.Move

local MoveService = {}

local now = CombatService.Now
local moveStarted = Remotes.Event("MoveStarted")
local moveRejected = Remotes.Event("MoveRejected")
local cooldownRemote = Remotes.Event("Cooldown")
local announce = Remotes.Event("Announce")

local BUSY_TOLERANCE = 0.12
local COOLDOWN_TOLERANCE = 0.15
local MAX_TARGETS = 16

local function log(...: any)
	if RunService:IsStudio() and Config.Debug.LogRejectedHits then
		print("[MoveService]", ...)
	end
end

local function reject(player: Player, token: number, moveId: string, reason: string)
	log("rejected", player.Name, moveId, reason)
	moveRejected:FireClient(player, token, moveId, reason)
	local fighter = CombatService.ForPlayer(player)
	if fighter then
		local ready = fighter.Cooldowns[moveId]
		cooldownRemote:FireClient(player, moveId, if ready then math.max(0, ready - now()) else 0)
	end
end

local function broadcastStart(fighter: Fighter, move: Move, token: number, start: number, aim: Vector3, variant: string)
	for _, other in Players:GetPlayers() do
		if other ~= fighter.Player then
			moveStarted:FireClient(other, fighter.Model, move.Id, token, start, aim, variant)
		end
	end
end

-- Starts a move for a fighter (players via requests; dummies could call this directly).
local function start(fighter: Fighter, move: Move, token: number, aim: Vector3, variant: string): (boolean, string?)
	local t = now()
	local slot = move.Slot
	local awakened = CombatService.IsAwakened(fighter)
	local stunned = CombatService.IsStunned(fighter, t + 0.08)
	local knocked = fighter.KnockdownUntil > t + 0.08

	if not fighter.Alive then
		return false, "dead"
	end
	if move.Class ~= "Common" and move.Class ~= fighter.Class then
		return false, "wrong class"
	end
	if slot == "Evasive" then
		if not (stunned or knocked) then
			return false, "not stunned"
		end
		local meter = if fighter.Player then (fighter.Player:GetAttribute("Evasive") :: number?) or 0 else 100
		if meter < Config.Evasive.Cost - 0.5 then
			return false, "evasive not ready"
		end
	else
		if stunned then
			return false, "stunned"
		end
		if knocked then
			return false, "knocked down"
		end
	end
	if t < fighter.BusyUntil - BUSY_TOLERANCE then
		return false, "busy"
	end
	local ready = fighter.Cooldowns[move.Id]
	if ready and t < ready - COOLDOWN_TOLERANCE then
		return false, "cooldown"
	end
	if move.Awakened and not awakened then
		return false, "not awakened"
	end
	if (slot == "1" or slot == "2" or slot == "3" or slot == "4") and not move.Awakened and awakened then
		return false, "awakened"
	end
	if slot == "Awaken" then
		if awakened then
			return false, "already awakened"
		end
		local meter = if fighter.Player then (fighter.Player:GetAttribute("Awaken") :: number?) or 0 else 0
		if meter < 99.5 then
			return false, "meter not full"
		end
	end
	if slot == "M1" then
		if t < fighter.M1ReadyAt - COOLDOWN_TOLERANCE then
			return false, "m1 cooldown"
		end
		local step = tonumber(string.sub(variant, 1, 1)) or 1
		local finisher = step >= 4 or string.sub(variant, 1, 1) == "U" or string.sub(variant, 1, 1) == "D"
		fighter.LastM1 = t
		if finisher then
			fighter.M1ReadyAt = t + Config.Combat.ComboEndCooldown
		end
	end

	-- Accepted
	fighter.Active[token] = {
		Move = move,
		Token = token,
		Start = t,
		Aim = aim,
		Variant = variant,
		Cancelled = nil,
		HitCounts = {},
	}
	fighter.BusyUntil = t + move.Busy
	if move.Cooldown > 0 then
		fighter.Cooldowns[move.Id] = t + move.Cooldown
	end
	if slot == "Dash" then
		-- Dashes share one cooldown so you can't chain three in a row
		local shared = t + Config.Dash.Cooldown
		for _, id in { "Dash_Front", "Dash_Side", "Dash_Back" } do
			fighter.Cooldowns[id] = math.max(fighter.Cooldowns[id] or 0, if id == move.Id then t + move.Cooldown else shared)
		end
	end
	CombatService.SetBlocking(fighter, false)
	fighter.LastCombat = math.max(fighter.LastCombat, t - Config.Player.RegenDelay + 3)
	if move.Invulnerable then
		CombatService.Invulnerable(fighter, move.Invulnerable)
	end
	if move.HyperArmor then
		fighter.HyperUntil = t + move.Busy
	end
	if move.Counter then
		fighter.CounterUntil = t + move.Counter
		fighter.CounterToken = token
	end
	if slot == "Evasive" then
		CombatService.ClearStun(fighter)
		if fighter.Player then
			fighter.Player:SetAttribute("Evasive", 0)
		end
	elseif slot == "Awaken" then
		CombatService.StartAwakening(fighter)
		local character = Characters.Get(fighter.Class)
		local who = if fighter.Player then fighter.Player.DisplayName else fighter.Model.Name
		if character then
			announce:FireAllClients(string.format("%s AWAKENED: %s", string.upper(who), string.upper(character.AwakeningName)), character.Color)
		end
	end

	broadcastStart(fighter, move, token, t, aim, variant)
	return true, nil
end
MoveService.Start = start

local function onMoveRequest(player: Player, token: unknown, moveId: unknown, aim: unknown, variant: unknown)
	if typeof(token) ~= "number" or typeof(moveId) ~= "string" or typeof(aim) ~= "Vector3" then
		return
	end
	local variantText = if typeof(variant) == "string" then string.sub(variant, 1, 16) else ""
	local fighter = CombatService.ForPlayer(player)
	local move = Characters.Move(moveId)
	if not fighter or not move then
		return
	end
	if fighter.Active[token] then
		return -- duplicate token
	end
	local aimUnit = if aim.Magnitude > 1e-3 then aim.Unit else fighter.Root.CFrame.LookVector
	local ok, reason = start(fighter, move, token, aimUnit, variantText)
	if not ok then
		reject(player, token, moveId, reason or "?")
	end
end

-- A hit reported by the attacking client.
local function onHitRequest(player: Player, token: unknown, hitName: unknown, targets: unknown, position: unknown)
	if typeof(token) ~= "number" or typeof(hitName) ~= "string" or typeof(targets) ~= "table" or typeof(position) ~= "Vector3" then
		return
	end
	local attacker = CombatService.ForPlayer(player)
	if not attacker or not attacker.Alive then
		return
	end
	local active = attacker.Active[token]
	if not active then
		log("hit for unknown token", player.Name, hitName)
		return
	end
	local move = active.Move
	local hit = move.Hits[hitName]
	if not hit then
		log("unknown hit", move.Id, hitName)
		return
	end
	local t = now()
	local elapsed = t - active.Start
	if elapsed > move.MaxTime + Config.Combat.TimeTolerance then
		log("late hit", move.Id, hitName, string.format("%.2f", elapsed))
		return
	end
	if active.Cancelled and not hit.Projectile and t > active.Cancelled + 0.1 then
		log("hit after interrupt", move.Id, hitName)
		return
	end
	local origin = attacker.Root.Position
	local maxRange = hit.Range + Config.Combat.RangeTolerance
	if (position - origin).Magnitude > maxRange + 10 then
		log("hit position too far", move.Id, hitName)
		return
	end
	local counts = active.HitCounts[hitName]
	if not counts then
		counts = {}
		active.HitCounts[hitName] = counts
	end
	local list = targets :: { any }
	local applied = 0
	for i = 1, math.min(#list, MAX_TARGETS) do
		local target = list[i]
		if typeof(target) ~= "Instance" then
			continue
		end
		local victim = CombatService.Get(target :: Instance)
		if not victim or victim == attacker or not victim.Alive then
			continue
		end
		local distance = (victim.Root.Position - origin).Magnitude
		if distance > maxRange then
			log("out of range", move.Id, hitName, string.format("%.1f > %.1f", distance, maxRange))
			continue
		end
		if hit.Projectile and (victim.Root.Position - position).Magnitude > 30 then
			log("projectile impact too far from victim", move.Id, hitName)
			continue
		end
		local used = counts[victim.Model] or 0
		if used >= (hit.Repeat or 1) then
			continue
		end
		counts[victim.Model] = used + 1
		CombatService.ApplyHit(attacker, victim, active, hitName, hit, position)
		applied += 1
	end
	return applied
end

local function onBlockRequest(player: Player, holding: unknown)
	local fighter = CombatService.ForPlayer(player)
	if not fighter or typeof(holding) ~= "boolean" then
		return
	end
	if holding then
		local t = now()
		if not fighter.Alive or CombatService.IsStunned(fighter) or fighter.KnockdownUntil > t or t < fighter.BusyUntil - BUSY_TOLERANCE then
			return
		end
	end
	CombatService.SetBlocking(fighter, holding)
end

function MoveService.Init()
	Remotes.Event("MoveRequest").OnServerEvent:Connect(onMoveRequest)
	Remotes.Event("HitRequest").OnServerEvent:Connect(onHitRequest)
	Remotes.Event("BlockRequest").OnServerEvent:Connect(onBlockRequest)
end

return MoveService
