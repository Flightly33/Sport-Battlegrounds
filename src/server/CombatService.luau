--[[
	CombatService: the server's view of every fighter (players and training dummies) and the rules for
	what a hit does - damage, stun chains, blocks and guard breaks, knockback, grabs, counters, the
	awakening / evasive meters and kill credit.

	State the clients need is mirrored onto the character model as attributes:
		Class, StunUntil, KnockdownUntil, InvulnUntil, Blocking, BlockHP (0..1), Awakened, AwakenUntil
	and onto the Player: Awaken (0..100), Evasive (0..100).
	All times are workspace:GetServerTimeNow().
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Characters = require(Shared.Characters)
local Rig = require(Shared.Anim.Rig)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

type Move = Characters.Move
type Hit = Characters.Hit

local CombatService = {}

CombatService.FighterDied = Signal.new() -- (fighter, killerPlayer?)
CombatService.Damaged = Signal.new() -- (attacker, victim, damage)

export type ActiveMove = {
	Move: Move,
	Token: number,
	Start: number,
	Aim: Vector3,
	Variant: string,
	Cancelled: number?,
	HitCounts: { [string]: { [Model]: number } },
}

export type Fighter = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Player: Player?,
	Class: string,
	Alive: boolean,
	Cooldowns: { [string]: number },
	Active: { [number]: ActiveMove },
	BusyUntil: number,
	M1ReadyAt: number,
	LastM1: number,
	StunUntil: number,
	StunChainStart: number,
	KnockdownUntil: number,
	InvulnUntil: number,
	HyperUntil: number,
	CounterUntil: number,
	CounterToken: number,
	Blocking: boolean,
	BlockHP: number,
	AwakenUntil: number,
	LastAttacker: Fighter?,
	LastAttackTime: number,
	LastCombat: number,
	Dummy: boolean,
}

local fighters: { [Model]: Fighter } = {}
CombatService.Fighters = fighters

local now = function(): number
	return workspace:GetServerTimeNow()
end
CombatService.Now = now

local hitConfirmed = Remotes.Event("HitConfirmed")
local knockbackRemote = Remotes.Event("Knockback")
local followRemote = Remotes.Event("Follow")
local moveCancelled = Remotes.Event("MoveCancelled")

--------------------------------------------------------------------------------
-- Registry
--------------------------------------------------------------------------------
function CombatService.Register(model: Model, player: Player?, classId: string): Fighter?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end
	local t = now()
	local fighter: Fighter = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Player = player,
		Class = classId,
		Alive = true,
		Cooldowns = {},
		Active = {},
		BusyUntil = 0,
		M1ReadyAt = 0,
		LastM1 = 0,
		StunUntil = 0,
		StunChainStart = 0,
		KnockdownUntil = 0,
		InvulnUntil = t + Config.Player.SpawnProtection,
		HyperUntil = 0,
		CounterUntil = 0,
		CounterToken = 0,
		Blocking = false,
		BlockHP = Config.Block.MaxDurability,
		AwakenUntil = 0,
		LastAttacker = nil,
		LastAttackTime = 0,
		LastCombat = 0,
		Dummy = player == nil,
	}
	fighters[model] = fighter
	model:SetAttribute("Class", classId)
	model:SetAttribute("StunUntil", 0)
	model:SetAttribute("KnockdownUntil", 0)
	model:SetAttribute("InvulnUntil", fighter.InvulnUntil)
	model:SetAttribute("Blocking", false)
	model:SetAttribute("BlockHP", 1)
	model:SetAttribute("Awakened", false)
	model:SetAttribute("AwakenUntil", 0)
	CollectionService:AddTag(model, "Fighter")

	humanoid.Died:Connect(function()
		CombatService.OnDied(fighter)
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			fighters[model] = nil
		end
	end)
	return fighter
end

function CombatService.Get(model: Instance?): Fighter?
	if model and model:IsA("Model") then
		return fighters[model]
	end
	return nil
end

function CombatService.ForPlayer(player: Player): Fighter?
	local character = player.Character
	return if character then fighters[character] else nil
end

function CombatService.SetClass(fighter: Fighter, classId: string)
	fighter.Class = classId
	fighter.Model:SetAttribute("Class", classId)
	fighter.Cooldowns = {}
	CombatService.EndAwakening(fighter)
end

--------------------------------------------------------------------------------
-- Status helpers
--------------------------------------------------------------------------------
function CombatService.IsStunned(fighter: Fighter, t: number?): boolean
	return fighter.StunUntil > (t or now())
end

function CombatService.IsAwakened(fighter: Fighter): boolean
	return fighter.AwakenUntil > now()
end

function CombatService.SetBlocking(fighter: Fighter, blocking: boolean)
	if fighter.Blocking == blocking then
		return
	end
	fighter.Blocking = blocking
	fighter.Model:SetAttribute("Blocking", blocking)
end

local function addMeter(player: Player?, attribute: string, amount: number)
	if not player or amount <= 0 then
		return
	end
	local value = (player:GetAttribute(attribute) :: number?) or 0
	player:SetAttribute(attribute, math.clamp(value + amount, 0, 100))
end
CombatService.AddMeter = addMeter

function CombatService.Stun(fighter: Fighter, seconds: number)
	local t = now()
	if fighter.StunUntil < t then
		-- A new stun chain starts (if they've been free long enough)
		if t - fighter.StunUntil > Config.Combat.StunlockRecovery then
			fighter.StunChainStart = t
		end
	end
	if t - fighter.StunChainStart > Config.Combat.MaxStunChain then
		seconds = math.min(seconds, Config.Combat.StunlockCap)
	end
	local untilTime = math.max(fighter.StunUntil, t + seconds)
	fighter.StunUntil = untilTime
	fighter.Model:SetAttribute("StunUntil", untilTime)
	CombatService.SetBlocking(fighter, false)
	-- Interrupt whatever they were doing (unless it has hyper armor)
	for token, active in fighter.Active do
		if not active.Cancelled and t - active.Start < active.Move.Busy and not active.Move.HyperArmor then
			active.Cancelled = t
			moveCancelled:FireAllClients(fighter.Model, token)
		end
	end
	fighter.BusyUntil = math.min(fighter.BusyUntil, t)
	fighter.CounterUntil = 0
end

function CombatService.ClearStun(fighter: Fighter)
	fighter.StunUntil = 0
	fighter.KnockdownUntil = 0
	fighter.Model:SetAttribute("StunUntil", 0)
	fighter.Model:SetAttribute("KnockdownUntil", 0)
end

function CombatService.Invulnerable(fighter: Fighter, seconds: number)
	local untilTime = math.max(fighter.InvulnUntil, now() + seconds)
	fighter.InvulnUntil = untilTime
	fighter.Model:SetAttribute("InvulnUntil", untilTime)
end

function CombatService.StartAwakening(fighter: Fighter)
	local t = now()
	fighter.AwakenUntil = t + Config.Awakening.Duration + Config.Awakening.TransformTime
	fighter.Model:SetAttribute("Awakened", true)
	fighter.Model:SetAttribute("AwakenUntil", fighter.AwakenUntil)
	if fighter.Player then
		fighter.Player:SetAttribute("Awaken", 0)
	end
	local humanoid = fighter.Humanoid
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.Awakening.Heal)
	-- Awakened moves start ready
	for id in fighter.Cooldowns do
		local move = Characters.Move(id)
		if move and move.Awakened then
			fighter.Cooldowns[id] = nil
		end
	end
end

function CombatService.EndAwakening(fighter: Fighter)
	if fighter.Model:GetAttribute("Awakened") then
		fighter.AwakenUntil = 0
		fighter.Model:SetAttribute("Awakened", false)
		fighter.Model:SetAttribute("AwakenUntil", 0)
	end
end

--------------------------------------------------------------------------------
-- Knockback / grabs
--------------------------------------------------------------------------------
local function applyVelocity(fighter: Fighter, velocity: Vector3, duration: number, knockdown: number)
	if fighter.Player then
		knockbackRemote:FireClient(fighter.Player, velocity, duration, knockdown)
		return
	end
	-- Dummies are simulated by the server
	local root = fighter.Root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "SB_Knockback"
	lv.Attachment0 = Rig.MotionAttachment(root)
	lv.MaxForce = math.huge
	lv.VectorVelocity = velocity
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	task.delay(duration, function()
		lv:Destroy()
	end)
end
CombatService.ApplyVelocity = applyVelocity

local function grab(attacker: Fighter, victim: Fighter, seconds: number)
	local offset = CFrame.new(0, 0, -3.2) * CFrame.Angles(0, math.pi, 0)
	if victim.Player then
		followRemote:FireClient(victim.Player, attacker.Root, offset, seconds)
		return
	end
	-- Dummy: weld it in front of the attacker for the duration
	victim.Root.CFrame = attacker.Root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Name = "SB_Grab"
	weld.Part0 = attacker.Root
	weld.Part1 = victim.Root
	weld.Parent = victim.Root
	victim.Humanoid.PlatformStand = true
	task.delay(seconds, function()
		weld:Destroy()
		victim.Humanoid.PlatformStand = false
	end)
end

--------------------------------------------------------------------------------
-- Hits
--------------------------------------------------------------------------------
export type HitResult = {
	Attacker: Model,
	Victim: Model,
	Move: string,
	Hit: string,
	Token: number,
	Position: Vector3,
	Damage: number,
	Blocked: boolean,
	GuardBroken: boolean,
	Countered: boolean,
	Killed: boolean,
	Variant: string,
}

local function facing(victim: Fighter, from: Vector3): boolean
	local look = victim.Root.CFrame.LookVector
	local to = from - victim.Root.Position
	to = Vector3.new(to.X, 0, to.Z)
	if to.Magnitude < 1e-3 then
		return true
	end
	return look:Dot(to.Unit) > Config.Block.FrontDot
end

-- Applies one validated hit. Returns what happened (also broadcast to every client).
function CombatService.ApplyHit(attacker: Fighter, victim: Fighter, active: ActiveMove, hitName: string, hit: Hit, position: Vector3): HitResult?
	local t = now()
	if not victim.Alive or victim.Humanoid.Health <= 0 then
		return nil
	end
	if victim.InvulnUntil > t then
		return nil
	end
	local move = active.Move
	local result: HitResult = {
		Attacker = attacker.Model,
		Victim = victim.Model,
		Move = move.Id,
		Hit = hitName,
		Token = active.Token,
		Position = position,
		Damage = 0,
		Blocked = false,
		GuardBroken = false,
		Countered = false,
		Killed = false,
		Variant = active.Variant,
	}
	attacker.LastCombat = t
	victim.LastCombat = t

	-- Counter stance (Goal Line Stand): the hit is shrugged off and the attacker is left wide open
	if victim.CounterUntil > t and attacker ~= victim then
		victim.CounterUntil = 0
		result.Countered = true
		result.Token = victim.CounterToken
		CombatService.Stun(attacker, 1.1)
		hitConfirmed:FireAllClients(result)
		return result
	end

	local damage = hit.Damage
	if CombatService.IsAwakened(attacker) then
		damage *= Config.Awakening.DamageMultiplier
	end
	if victim.Class == "Football" and CombatService.IsAwakened(victim) then
		damage *= 0.8 -- Juggernaut armor
	end

	-- Blocking
	if victim.Blocking and not hit.Unblockable and facing(victim, attacker.Root.Position) then
		local wear = damage * Config.Block.DurabilityPerDamage
		if hit.GuardBreak or victim.BlockHP - wear <= 0 then
			result.GuardBroken = true
			victim.BlockHP = Config.Block.MaxDurability * 0.35
			CombatService.SetBlocking(victim, false)
			victim.Model:SetAttribute("BlockHP", victim.BlockHP / Config.Block.MaxDurability)
			CombatService.Stun(victim, Config.Block.GuardBreakStun)
			if not hit.GuardBreak then
				-- Broken by attrition: no damage from this hit
				hitConfirmed:FireAllClients(result)
				return result
			end
		else
			victim.BlockHP -= wear
			victim.Model:SetAttribute("BlockHP", victim.BlockHP / Config.Block.MaxDurability)
			result.Blocked = true
			local chip = if move.Slot == "M1" then 0 else damage * Config.Block.ChipDamage
			result.Damage = chip
			if chip > 0 then
				victim.Humanoid.Health = math.max(0, victim.Humanoid.Health - chip)
			end
			-- A little push back
			local push = attacker.Root.CFrame.LookVector * 14
			applyVelocity(victim, Vector3.new(push.X, 0, push.Z), 0.12, 0)
			hitConfirmed:FireAllClients(result)
			return result
		end
	end

	result.Damage = damage
	local humanoid = victim.Humanoid
	humanoid.Health = math.max(0, humanoid.Health - damage)

	victim.LastAttacker = attacker
	victim.LastAttackTime = t

	-- Meters (no awakening gain while awakened)
	if not CombatService.IsAwakened(attacker) then
		addMeter(attacker.Player, "Awaken", damage * Config.Awakening.PerDamageDealt)
	end
	if not CombatService.IsAwakened(victim) then
		addMeter(victim.Player, "Awaken", damage * Config.Awakening.PerDamageTaken)
	end
	addMeter(victim.Player, "Evasive", damage * Config.Evasive.PerDamage)

	local armored = victim.HyperUntil > t
	if not armored then
		CombatService.Stun(victim, hit.Stun)
		-- Knockback along the aim (or away from the hit position for radial hits)
		local dir: Vector3
		if hit.Radial then
			local away = victim.Root.Position - position
			away = Vector3.new(away.X, 0, away.Z)
			dir = if away.Magnitude > 0.1 then away.Unit else active.Aim
		else
			dir = Vector3.new(active.Aim.X, 0, active.Aim.Z)
			dir = if dir.Magnitude > 0.1 then dir.Unit else attacker.Root.CFrame.LookVector
		end
		local velocity = dir * (hit.KnockBack or 0) + Vector3.new(0, hit.KnockUp or 0, 0)
		local knockdown = hit.Knockdown or 0
		if knockdown > 0 then
			victim.KnockdownUntil = math.max(victim.KnockdownUntil, t + knockdown)
			victim.Model:SetAttribute("KnockdownUntil", victim.KnockdownUntil)
		end
		if velocity.Magnitude > 0.5 then
			applyVelocity(victim, velocity, hit.KnockTime or 0.2, knockdown)
		end
		if hit.Grab then
			grab(attacker, victim, hit.Grab)
		end
	end

	result.Killed = humanoid.Health <= 0
	hitConfirmed:FireAllClients(result)
	CombatService.Damaged:Fire(attacker, victim, damage)
	return result
end

--------------------------------------------------------------------------------
-- Death
--------------------------------------------------------------------------------
function CombatService.OnDied(fighter: Fighter)
	if not fighter.Alive then
		return
	end
	fighter.Alive = false
	CombatService.EndAwakening(fighter)
	local killer: Player? = nil
	local last = fighter.LastAttacker
	if last and last ~= fighter and now() - fighter.LastAttackTime <= Config.Combat.KillCreditWindow then
		killer = last.Player
	end
	CombatService.FighterDied:Fire(fighter, killer)
end

--------------------------------------------------------------------------------
-- Upkeep: awakening timers, regeneration, block durability, evasive fill
--------------------------------------------------------------------------------
function CombatService.Init()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		local step = accumulator
		accumulator = 0
		local t = now()
		for _, fighter in fighters do
			if not fighter.Alive then
				continue
			end
			if fighter.AwakenUntil > 0 and t >= fighter.AwakenUntil then
				CombatService.EndAwakening(fighter)
			end
			local humanoid = fighter.Humanoid
			if t - fighter.LastCombat > Config.Player.RegenDelay and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Config.Player.RegenPerSecond * step)
			end
			if not fighter.Blocking and fighter.BlockHP < Config.Block.MaxDurability then
				fighter.BlockHP = math.min(Config.Block.MaxDurability, fighter.BlockHP + Config.Block.RegenPerSecond * step)
				fighter.Model:SetAttribute("BlockHP", fighter.BlockHP / Config.Block.MaxDurability)
			end
			addMeter(fighter.Player, "Evasive", Config.Evasive.PerSecond * step)
			-- Forget finished moves
			for token, active in fighter.Active do
				if t - active.Start > active.Move.MaxTime + 3 then
					fighter.Active[token] = nil
				end
			end
		end
	end)

	local function onPlayer(player: Player)
		player:SetAttribute("Awaken", if RunService:IsStudio() and Config.Awakening.StudioStartFull then 100 else 0)
		player:SetAttribute("Evasive", 100)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return CombatService
