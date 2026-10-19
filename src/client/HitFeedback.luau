--[[
	HitFeedback: what every client shows when the server confirms a hit.

	Generic layer for every hit: impact flash, sparks and lines in the attacker's palette, a flinch and
	hit-stop on both fighters, camera shake (stronger if it's you), damage numbers and the combo counter
	for the attacker, the manga impact frame on heavy hits, block / guard break / counter effects.
	Then the move's own OnHit (Client/Moves) adds its signature effect (explosions, lightning...).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Signal = require(Shared.Signal)

local Animator = require(script.Parent.Animator)
local CameraFX = require(script.Parent.CameraFX)
local FX = require(script.Parent.FX)
local MoveRunner = require(script.Parent.MoveRunner)
local Sound = require(script.Parent.Sound)

type HitInfo = MoveRunner.HitInfo

local HitFeedback = {}

HitFeedback.Combo = Signal.new() -- (hits, damage) for the local attacker
HitFeedback.Landed = Signal.new() -- (hit: HitInfo) every confirmed hit
HitFeedback.Hype = Signal.new() -- (amount) the crowd reacts

local player = Players.LocalPlayer :: Player
local comboHits = 0
local comboDamage = 0
local lastComboHit = 0

local function rootOf(model: Model): BasePart?
	local r = model:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function onHit(hit: HitInfo)
	local attacker, victim = hit.Attacker, hit.Victim
	if not attacker or not victim then
		return
	end
	MoveRunner.OnHitConfirmed(hit)
	local move = Characters.Move(hit.Move)
	local def = move and move.Hits[hit.Hit]
	local classId = (attacker:GetAttribute("Class") :: string?) or Characters.Default
	local palette = Characters.Palette(classId, attacker:GetAttribute("Awakened") == true)
	local mine = attacker == player.Character
	local hurt = victim == player.Character
	local vRoot = rootOf(victim)
	local aRoot = rootOf(attacker)
	local position = if vRoot then vRoot.Position:Lerp(hit.Position, 0.35) else hit.Position

	if hit.Countered then
		-- The victim of the "hit" was in a counter stance: they own the follow-up
		FX.Popup(position + Vector3.new(0, 3, 0), "COUNTER!", Color3.fromRGB(255, 230, 90), 1.4)
		FX.Shell(position, palette.Core, 1, 7, 0.3)
		Sound.Play("GuardBreak", position, 1.2)
		if hurt then
			MoveRunner.OnCountered(victim, hit.Token, attacker)
		end
		if mine or hurt then
			CameraFX.ImpactFrame({ attacker, victim }, 0.1)
		end
		return
	end

	if hit.Blocked then
		local shieldColor = Color3.fromRGB(170, 220, 255)
		FX.Flash(position, shieldColor, 3, 0.12)
		if vRoot then
			FX.Ring(CFrame.lookAt(vRoot.Position, vRoot.Position + vRoot.CFrame.LookVector) * CFrame.Angles(math.pi / 2, 0, 0) + vRoot.CFrame.LookVector * 1.5, shieldColor, 1, 3.2, 0.18, 0.3, 12)
		end
		FX.Sparks(position, shieldColor, 8, 25, 0.4)
		Sound.Play("Block", position)
		Animator.HitStop(attacker, 0.04)
		if hurt or mine then
			CameraFX.Shake(0.15)
		end
		return
	end

	local heavy = def ~= nil and def.Heavy == true
	local strength = math.clamp(hit.Damage / 6, 0.6, 3)
	if hit.GuardBroken then
		FX.Popup(position + Vector3.new(0, 3, 0), "GUARD BREAK!", Color3.fromRGB(255, 90, 70), 1.5)
		FX.Shell(position, Color3.fromRGB(170, 220, 255), 2, 6, 0.25, Enum.Material.Glass)
		FX.Sparks(position, Color3.fromRGB(200, 230, 255), 25, 45, 0.6)
		Sound.Play("GuardBreak", position)
	end

	FX.Impact(position, palette, if heavy then strength * 1.3 else strength)
	Sound.Play(if heavy then "HeavyHit" else "Hit", position)

	-- Flinch + hit-stop
	local stop = (def and def.HitStop) or Config.Combat.HitStop
	Animator.HitStop(attacker, stop)
	Animator.HitStop(victim, stop)
	if vRoot and aRoot then
		local dir = vRoot.Position - aRoot.Position
		dir = if dir.Magnitude > 0.1 then dir.Unit else aRoot.CFrame.LookVector
		Animator.Flinch(victim, dir, if heavy then 0.9 else 0.5)
	end

	if hurt then
		CameraFX.Shake(if heavy then 0.75 else 0.35)
		CameraFX.Flash(Color3.fromRGB(255, 40, 40), 0.25, 0.75)
	elseif mine then
		CameraFX.Shake(if heavy then 0.5 else 0.12)
	end
	if heavy and (mine or hurt) then
		CameraFX.ImpactFrame({ attacker, victim }, 0.1, palette.Accent)
		CameraFX.FOVPunch(-6, 0.08)
	end

	if mine then
		local now = os.clock()
		if now - lastComboHit > Config.Combat.ComboCounterWindow then
			comboHits = 0
			comboDamage = 0
		end
		lastComboHit = now
		comboHits += 1
		comboDamage += hit.Damage
		HitFeedback.Combo:Fire(comboHits, comboDamage)
		FX.Popup(position + Vector3.new(0, 2.5, 0), string.format("%d", math.floor(hit.Damage + 0.5)), if heavy then palette.Accent else Color3.new(1, 1, 1), if heavy then 1.2 else 0.85)
	end

	-- The move's signature impact
	local s = MoveRunner.Script(hit.Move)
	if s and s.OnHit then
		task.spawn(s.OnHit, hit, palette)
	end

	if hit.Killed then
		FX.Popup(position + Vector3.new(0, 4, 0), "K.O.!", palette.Accent, 2.2, 1.4)
		FX.Explosion(position, palette, 7, { Crater = false, Debris = false })
		Sound.Play("KO", position)
		HitFeedback.Hype:Fire(1)
		if mine or hurt then
			CameraFX.ImpactFrame({ attacker, victim }, 0.16, palette.Accent)
		end
	elseif heavy then
		HitFeedback.Hype:Fire(0.4)
	end
	HitFeedback.Landed:Fire(hit)
end

function HitFeedback.Init()
	Remotes.Event("HitConfirmed").OnClientEvent:Connect(function(hit: HitInfo)
		local ok, err = pcall(function()
			onHit(hit)
		end)
		if not ok then
			warn("[HitFeedback]", err)
		end
	end)
end

return HitFeedback
