--[[
	Moves every fighter shares: the four dashes (which strike anyone they run into) and the evasive.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Characters)
local Clips = require(Shared.Anim.Clips)
local Config = require(Shared.Config)
local Pose = require(Shared.Anim.Pose)

local CameraFX = require(script.Parent.Parent.CameraFX)
local FX = require(script.Parent.Parent.FX)
local Kit = require(script.Parent.Kit)
local MoveRunner = require(script.Parent.Parent.MoveRunner)
local Sound = require(script.Parent.Parent.Sound)

type Ctx = MoveRunner.Ctx

-- The strike each class throws when its dash runs into an enemy, played to the clip's Contact mark.
type Strike = { Clip: Pose.Clip, Limb: string, Sound: string, Strength: number }
local STRIKES: { [string]: Strike } = {
	Soccer = { Clip = Clips.Soccer.KickFinisher, Limb = "RightFoot", Sound = "Kick", Strength = 1.6 }, -- a full kick
	Basketball = { Clip = Clips.Basketball.Jab, Limb = "RightHand", Sound = "Hit", Strength = 1.3 }, -- a straight punch
	Football = { Clip = Clips.Football.ShiverR, Limb = "RightLowerArm", Sound = "HeavyHit", Strength = 1.5 }, -- a forearm shiver
	Baseball = { Clip = Clips.Baseball.PowerSwing, Limb = "RightHand", Sound = "BatCrack", Strength = 1.6 }, -- a bat swing
}

-- The dash ran into `target` (or, on other screens, the server says it did): stop, face them and strike.
local function strike(ctx: Ctx, target: Model?)
	local root = ctx.Root
	local s = STRIKES[ctx.ClassId] or STRIKES.Soccer
	local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
	if targetRoot and targetRoot:IsA("BasePart") then
		ctx:Face(targetRoot.Position - root.Position)
	end
	local track = ctx:Play(s.Clip)
	Kit.LimbTrail(ctx, s.Limb, ctx.Palette.Primary, 0.8, (s.Clip.Marks.Contact or 0.15) + 0.12)
	Sound.Play("HeavyWhoosh", root.Position, 0.9)
	if not ctx:Until(track, "Contact") then
		return
	end
	local frame = Kit.Frame(ctx)
	local at = (CFrame.lookAt(root.Position, root.Position + root.CFrame.LookVector) * CFrame.new(0, 0, -3)).Position
	Kit.Contact(ctx, at, s.Strength)
	Sound.Play(s.Sound, at)
	if ctx.IsOwner then
		local hit = Kit.Front(ctx, "Strike", 3.4, Vector3.new(6, 6, 7))
		if #hit == 0 and target then
			-- They were caught a moment ago; strike them even if the knock nudged them out of the box
			ctx:Report("Strike", { target }, frame.Position)
		end
	end
	ctx:Until(track, "End")
end

local function dash(ctx: Ctx)
	local root = ctx.Root
	local look = root.CFrame.LookVector
	local right = root.CFrame.RightVector
	local v = ctx.Variant
	local dash = Config.Dash
	local dir, clip, distance
	if v == "B" then
		dir, clip, distance = -look, Clips.Common.DashBack, dash.BackDistance
	elseif v == "L" then
		dir, clip, distance = -right, Clips.Common.DashLeft, dash.SideDistance
	elseif v == "R" then
		dir, clip, distance = right, Clips.Common.DashRight, dash.SideDistance
	else
		dir, clip, distance = look, Clips.Common.DashFront, dash.Distance
	end
	local track = ctx:Play(clip)
	-- Eased dash (snappy start, soft stop), stopped by walls and the arena edge - see Client/Motion
	local push = ctx:Dash(dir, distance, dash.Duration, dash.Carry)
	local feet = root.Position - Vector3.new(0, 2.6, 0)
	FX.Afterimage(ctx.Character, ctx.Palette.Primary, 0.22, Enum.Material.ForceField)
	FX.Smoke(feet, Color3.fromRGB(200, 195, 185), 6, 1.2, 0.6, 2)
	FX.Ring(CFrame.lookAt(root.Position, root.Position + dir) * CFrame.Angles(math.pi / 2, 0, 0), ctx.Palette.Core, 1, 3.5, 0.2, 0.25, 12)
	Sound.Play("Whoosh", root.Position, 0.8)
	if ctx.IsOwner then
		CameraFX.SpeedLines(Config.Dash.Duration + 0.05, ctx.Palette.Core)
	end
	-- Watch the path: the owner looks for an enemy just ahead of the body, other screens wait for the
	-- server to confirm the owner's Catch
	local target: Model? = nil
	local caught = false
	local start = os.clock()
	while os.clock() - start < dash.Duration and ctx:Alive() do
		if ctx.IsOwner then
			local box = CFrame.lookAt(root.Position, root.Position + dir) * CFrame.new(0, 0, -dash.StrikeReach)
			local found = ctx:Report("Catch", ctx:QueryBox(box, dash.StrikeSize), root.Position)
			if #found > 0 then
				target, caught = found[1], true
				break
			end
		elseif ctx.Data.Caught then
			caught = true
			break
		end
		task.wait()
	end
	if not ctx:Alive() then
		return
	end
	if caught then
		-- Stop dead against them instead of ploughing through
		if push then
			push:Destroy()
		end
		if ctx.IsOwner then
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
		if track then
			track:Stop(0.05)
		end
		strike(ctx, target or ctx.Data.Target)
		return
	end
	FX.Afterimage(ctx.Character, ctx.Palette.Primary, 0.18, Enum.Material.ForceField)
	ctx:Wait(0.05)
end

-- Other screens: the server confirmed the dash ran into someone.
local function dashHit(hit: MoveRunner.HitInfo, _palette: Characters.Palette)
	if hit.Hit == "Catch" then
		local ctx = MoveRunner.Find(hit.Attacker, hit.Token)
		if ctx and not ctx.IsOwner then
			ctx.Data.Caught = true
			ctx.Data.Target = hit.Victim
		end
	end
end

local function evasive(ctx: Ctx)
	local root = ctx.Root
	ctx:Play(Clips.Common.Evasive)
	ctx:Velocity(-root.CFrame.LookVector * 55 + Vector3.new(0, 30, 0), 0.22)
	FX.Flash(root.Position, Color3.new(1, 1, 1), 8, 0.2)
	FX.Shell(root.Position, ctx.Palette.Primary, 1, 9, 0.3)
	FX.Ring(CFrame.new(root.Position - Vector3.new(0, 2.5, 0)), Color3.new(1, 1, 1), 1, 10, 0.3, 0.6)
	FX.Afterimage(ctx.Character, Color3.new(1, 1, 1), 0.3)
	FX.Popup(root.Position + Vector3.new(0, 3, 0), "EVASIVE", Color3.new(1, 1, 1), 1)
	Sound.Play("Whoosh", root.Position, 0.6)
	ctx:Wait(0.36)
end

return {
	Dash_Front = { Run = dash, OnHit = dashHit },
	Dash_Side = { Run = dash, OnHit = dashHit },
	Dash_Back = { Run = dash, OnHit = dashHit },
	Evasive = { Run = evasive },
} :: { [string]: MoveRunner.MoveScript }
